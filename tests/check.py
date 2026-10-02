#!/usr/bin/env python3
"""Dependency-free E2E checks against real benchmark processes, never imported internals."""

import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"c": "C", "rust": "Rust", "zig": "Zig", "swift": "Swift", "v": "V", "ts": "TypeScript/Bun"}
FIELDS = {"language", "mode", "n", "runs", "warmup", "seed", "total_s", "avg_ms", "median_ms", "min_ms", "max_ms", "breakdown_s", "checksum"}


def reference(n, runs, seed, mode):
    """Scalar oracle: deliberately retains one-at-a-time normal generation."""
    mask = 0xFFFFFFFF
    state = []
    s = seed & mask
    for _ in range(4):
        s = (s + 0x9E3779B9) & mask
        z = ((s ^ (s >> 16)) * 0x85EBCA6B) & mask
        z = ((z ^ (z >> 13)) * 0xC2B2AE35) & mask
        state.append(z ^ (z >> 16))
    if not any(state):
        state[3] = 1

    def word():
        x, y, z, w = state
        t = (x ^ (x << 11)) & mask
        w = (w ^ (w >> 19) ^ t ^ (t >> 8)) & mask
        state[:] = y, z, state[3], w
        return w

    def uniform():
        return (((word() >> 5) << 26) | (word() >> 6)) / 2**53

    spare = None

    def normal():
        nonlocal spare
        if spare is not None:
            value, spare = spare, None
            return value
        while True:
            u, v = 2 * uniform() - 1, 2 * uniform() - 1
            radius = u * u + v * v
            if 0 < radius < 1:
                scale = math.sqrt(-2 * math.log(radius) / radius)
                spare = v * scale
                return u * scale

    diffusion = 0.1 * math.sqrt(1 / n)
    a = 1 - 1 / n
    increments = [diffusion * normal() for _ in range(n - 1)] if mode == "ou" else None
    checksum = 0.0
    for _ in range(runs):
        if mode != "ou":
            increments = [diffusion * normal() for _ in range(n - 1)]
        subtotal = 0.0
        x = 0.0
        for increment in increments:
            if mode == "gn":
                subtotal += increment
            else:
                x = a * x + 0.0 + increment
                subtotal += x
        checksum += subtotal
    return checksum


def invoke(command, args, cwd=ROOT, env=None):
    return subprocess.run([*map(str, command), *args], cwd=cwd, env=env, capture_output=True, text=True, timeout=5)


def record(command, **params):
    result = invoke(command, [f"--{k}={v}" for k, v in params.items()] + ["--output=json"])
    assert result.returncode == 0, (result.returncode, result.stderr)
    assert not result.stderr, result.stderr
    data = json.loads(result.stdout)
    assert set(data) == FIELDS, set(data)
    for key in ("n", "runs", "warmup", "mode"):
        assert data[key] == params[key], (key, data[key])
    assert data["seed"] == params["seed"] & 0xFFFFFFFF
    for key in ("total_s", "avg_ms", "median_ms", "min_ms", "max_ms"):
        assert math.isfinite(data[key]) and data[key] >= 0, (key, data[key])
    assert data["min_ms"] <= data["median_ms"] <= data["max_ms"]
    assert data["min_ms"] - 1e-6 <= data["avg_ms"] <= data["max_ms"] + 1e-6
    stages = data["breakdown_s"]
    assert set(stages) == {"gen_normals", "simulate", "checksum"}
    assert all(math.isfinite(v) and v >= 0 for v in stages.values())
    assert abs(sum(stages.values()) - data["total_s"]) <= 2.1e-6
    assert abs(data["avg_ms"] * params["runs"] / 1000 - data["total_s"]) <= 1e-6
    if params["mode"] == "gn":
        assert stages["simulate"] == 0
    if params["mode"] == "ou":
        assert stages["gen_normals"] == 0
    expected = reference(params["n"], params["runs"], params["seed"], params["mode"])
    assert math.isclose(data["checksum"], expected, rel_tol=1e-10, abs_tol=1e-10), (data["checksum"], expected)
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--bin-dir", type=Path, default=ROOT / ".scratch/bin")
    parser.add_argument("--languages", nargs="+", choices=LANGUAGES, default=list(LANGUAGES))
    parser.add_argument("--scripts", action="store_true", help="also check runner and comparison helper")
    options = parser.parse_args()
    if not options.skip_build:
        subprocess.run(["bash", str(ROOT / "build.sh")], cwd=ROOT, check=True)
    failures = []
    passed = 0

    def check(label, run):
        nonlocal passed
        try:
            run()
            passed += 1
        except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as error:
            failures.append(label)
            print(f"FAIL {label}: {error}", flush=True)

    for language in options.languages:
        command = [os.environ.get("BUN", "bun"), str(ROOT / "ts/ou_bench.ts")] if language == "ts" else [options.bin_dir.resolve() / language]
        for mode in ("full", "gn", "ou"):
            for n, runs, seed in ((2, 1, 0), (3, 2, 1), (4, 3, 42), (17, 4, 0xFFFFFFFF), (32, 3, 2**32 + 1), (257, 3, 2**64 - 1), (4096, 2, 12345)):
                def valid(mode=mode, n=n, runs=runs, seed=seed):
                    params = dict(n=n, runs=runs, warmup=0, seed=seed, mode=mode)
                    first = record(command, **params)
                    assert first["language"] == LANGUAGES[language]
                    again = record(command, **{**params, "warmup": 2})
                    assert first["checksum"] == again["checksum"], "warmup changed measured RNG stream"
                check(f"{language}/{mode}/n={n}/runs={runs}/seed={seed}", valid)

        invalid = ["--unknown=1", "argument", "--n", "--n=", "--n=1", "--n=2.5", "--n=2x", "--n=+2", "--n= 2", "--n=0x10", "--n=1e2", "--n=18446744073709551616", "--runs=0", "--runs=-1", "--runs=3.5", "--runs=2147483648", "--warmup=-1", "--warmup=oops", "--warmup=", "--seed=-1", "--seed=1x", "--seed=+1", "--seed=", "--seed=18446744073709551616", "--mode=oops", "--output=oops"]
        for arg in invalid:
            def rejects(arg=arg):
                result = invoke(command, ["--n=2", "--runs=1", "--warmup=0", arg])
                assert result.returncode > 0, ("must exit normally with a nonzero code", result.returncode, result.stdout)
                assert not result.stdout, result.stdout
                assert result.stderr.strip(), "missing error diagnostic"
            check(f"{language}/reject/{arg}", rejects)

        def text_output():
            result = invoke(command, ["--n=17", "--runs=2", "--warmup=0", "--seed=1", "--mode=full"])
            assert result.returncode == 0, result.stderr
            for field in ("n=17", "runs=2", "warmup=0", "seed=1", "total_s=", "avg_ms=", "median_ms=", "min_ms=", "max_ms=", "breakdown_s", "gen_normals=", "simulate=", "checksum="):
                assert field in result.stdout, field
        check(f"{language}/text", text_output)

    if options.scripts:
        def runner():
            env = {**os.environ, "BENCH_SKIP_BUILD": "1"}
            with tempfile.TemporaryDirectory(dir=ROOT / ".scratch") as directory:
                result = invoke(["bash", ROOT / "run_all.sh"], ["17", "2", "0", "1", "full", "json"], cwd=directory, env=env)
            assert result.returncode == 0, result.stderr
            rows = [json.loads(line) for line in result.stdout.splitlines()]
            assert len(rows) == 6 and {r["language"] for r in rows} == set(LANGUAGES.values())
        check("runner/foreign-cwd-jsonl", runner)

        def redirected_runner():
            env = {**os.environ, "BENCH_SKIP_BUILD": "1"}
            with tempfile.TemporaryDirectory(dir=ROOT / ".scratch") as directory:
                output = Path(directory) / "results.jsonl"
                with output.open("w") as file:
                    result = subprocess.run(["bash", str(ROOT / "run_all.sh"), "17", "2", "0", "1", "full", "json"], cwd=directory, env=env, stdout=file, stderr=subprocess.PIPE, text=True, timeout=5)
                assert result.returncode == 0, result.stderr
                rows = [json.loads(line) for line in output.read_text().splitlines()]
                assert len(rows) == 6 and {r["language"] for r in rows} == set(LANGUAGES.values()), rows
        check("runner/redirected-file-jsonl", redirected_runner)

        def comparison():
            sample = record([options.bin_dir.resolve() / "c"], n=17, runs=2, warmup=0, seed=1, mode="full")
            with tempfile.TemporaryDirectory(dir=ROOT / ".scratch") as directory:
                old, new = Path(directory) / "old.jsonl", Path(directory) / "new.jsonl"
                old.write_text(json.dumps(sample) + "\n")
                new.write_text(json.dumps(sample) + "\n")
                command = ["bash", ROOT / "DOCS/scripts/compare_runs.sh"]
                assert invoke(command, [str(old), str(new)]).returncode == 0
                cases = [{**sample, "n": 18}, {**sample, "seed": 2}, {**sample, "checksum": sample["checksum"] + 1}, {**sample, "avg_ms": -1}, {**sample, "median_ms": float("nan")}, {**sample, "mode": "gn"}]
                for changed in cases:
                    new.write_text(json.dumps(changed) + "\n")
                    assert invoke(command, [str(old), str(new)]).returncode != 0, changed
                for contents in ("", json.dumps(sample) + "\n" + json.dumps(sample) + "\n", "{}\n"):
                    new.write_text(contents)
                    assert invoke(command, [str(old), str(new)]).returncode != 0, contents
        check("comparison/positive-and-negative-controls", comparison)

    print(f"{passed} passed; {len(failures)} failed", flush=True)
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
