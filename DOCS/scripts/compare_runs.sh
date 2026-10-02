#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 baseline.jsonl candidate.jsonl" >&2
  exit 1
fi

python3 - "$1" "$2" <<'PY'
import json
import math
import sys

TIMINGS = ("total_s", "avg_ms", "median_ms", "min_ms", "max_ms")
CONFIG = ("n", "runs", "warmup", "seed")
LANGUAGES = {"C", "Rust", "Zig", "Swift", "V", "TypeScript/Bun"}


def number(value, nonnegative=False):
    return type(value) in (int, float) and math.isfinite(value) and (not nonnegative or value >= 0)


def load(path):
    data = {}
    with open(path, encoding="utf-8") as file:
        for line_number, line in enumerate(file, 1):
            if not line.strip():
                continue
            obj = json.loads(line)
            if not isinstance(obj, dict):
                raise ValueError(f"{path}:{line_number}: expected an object")
            key = (obj.get("language"), obj.get("mode"))
            if key[0] not in LANGUAGES or key[1] not in ("full", "gn", "ou"):
                raise ValueError(f"{path}:{line_number}: invalid language or mode")
            if key in data:
                raise ValueError(f"{path}:{line_number}: duplicate {key}")
            for name, minimum, maximum in (("n", 2, 2147483647), ("runs", 1, 2147483647), ("warmup", 0, 2147483647), ("seed", 0, 4294967295)):
                if type(obj.get(name)) is not int or not minimum <= obj[name] <= maximum:
                    raise ValueError(f"{key}: invalid {name}")
            for name in TIMINGS:
                if not number(obj.get(name), nonnegative=True):
                    raise ValueError(f"{key}: invalid {name}")
            if not number(obj.get("checksum")):
                raise ValueError(f"{key}: invalid checksum")
            stages = obj.get("breakdown_s")
            if not isinstance(stages, dict) or set(stages) != {"gen_normals", "simulate", "checksum"}:
                raise ValueError(f"{key}: invalid breakdown_s")
            if not all(number(value, nonnegative=True) for value in stages.values()):
                raise ValueError(f"{key}: invalid stage time")
            if not obj["min_ms"] <= obj["median_ms"] <= obj["max_ms"]:
                raise ValueError(f"{key}: inconsistent timing range")
            if not obj["min_ms"] - 1e-6 <= obj["avg_ms"] <= obj["max_ms"] + 1e-6:
                raise ValueError(f"{key}: inconsistent average")
            if abs(sum(stages.values()) - obj["total_s"]) > 2.1e-6:
                raise ValueError(f"{key}: inconsistent stage total")
            if abs(obj["avg_ms"] * obj["runs"] / 1000 - obj["total_s"]) > 1e-6 + obj["runs"] * 0.5e-9:
                raise ValueError(f"{key}: inconsistent total time")
            if key[1] == "gn" and stages["simulate"] != 0 or key[1] == "ou" and stages["gen_normals"] != 0:
                raise ValueError(f"{key}: inactive stage is nonzero")
            data[key] = obj
    if not data:
        raise ValueError(f"{path}: no records")
    return data


def main():
    baseline, candidate = map(load, sys.argv[1:])
    if baseline.keys() != candidate.keys():
        raise ValueError("language/mode sets differ")
    # Validate every pair before printing any comparisons.
    for key, old in baseline.items():
        new = candidate[key]
        if any(old[name] != new[name] for name in CONFIG):
            raise ValueError(f"{key}: parameters differ")
        if not math.isclose(old["checksum"], new["checksum"], rel_tol=1e-10, abs_tol=1e-10):
            raise ValueError(f"{key}: checksums differ")
    for key in sorted(baseline):
        print("|".join(key))
        for name in TIMINGS[1:]:
            old, new = baseline[key][name], candidate[key][name]
            change = f"{(new - old) / old * 100:+.2f}%" if old else "n/a (zero baseline)"
            print(f"  {name}: {old:.6f} -> {new:.6f} ({change})")


try:
    main()
except (OSError, ValueError, TypeError, KeyError) as error:
    print(f"error: {error}", file=sys.stderr)
    sys.exit(1)
PY
