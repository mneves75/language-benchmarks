# OU Benchmark 1.4.0

One scalar Ornstein–Uhlenbeck workload implemented in **C, Rust, Zig, Swift, V,
and TypeScript/Bun**. The project compares these implementations, toolchains,
and runtime configurations on a recorded machine. It does not rank languages
for unrelated workloads.

[Current measurements and verification](DOCS/Run-Record-2026-10-02.md) ·
[Learning guide](DOCS/learn/README.md) · [Numerical specification](DOCS/Engineering-Exec-Spec.md) ·
[Changelog](CHANGELOG.md)

## Run

Install Bun, Rust/Cargo, a C compiler, Zig **0.16.0**, Swift, and V. The
[run record](DOCS/Run-Record-2026-10-02.md) lists the exact versions tested.
Rust uses edition 2024 and requires at least 1.88 for fixed-size slice chunks;
only the recorded toolchain was verified. There are no third-party package dependencies.

```bash
./run_all.sh
./run_all.sh 500000 1000 5 1 full json > results.jsonl
# Positional arguments: n runs warmup seed mode output
```

Build diagnostics go to stderr. JSON stdout contains exactly six records on
success, one per language. Always check the exit status before consuming results.
Both scripts resolve their own directory, so invocation from another directory works.

```bash
bash build.sh
BENCH_SKIP_BUILD=1 ./run_all.sh 1000 3 1 1 gn json
python3 tests/check.py --skip-build --scripts
```

`BENCH_SKIP_BUILD=1` explicitly reuses existing artifacts; rebuild after code or
flag changes. Builds go to git-ignored `.scratch/bin/`. Rust also uses
`rust/target/`. The old tracked `v/ou_bench` binary is a historical artifact;
the runner builds and uses `.scratch/bin/v`.

If an executable is not on PATH, set `V`, `CC`, or `BUN` to its executable
path. For example, after installing [V](https://github.com/vlang/v/releases)
inside this checkout:

```bash
V="$PWD/.scratch/toolchains/v/v" bash build.sh
```

The build script confines default V modules/temp files and compiler caches to
`.scratch/`. It does not install or update host toolchains.

## CLI contract

Each implementation accepts `--key=value`:

| Option | Default | Accepted values |
|---|---:|---|
| `--n` | 500000 | Decimal integer, 2–2147483647 |
| `--runs` | 1000 | Decimal integer, 1–2147483647 |
| `--warmup` | 5 | Decimal integer, 0–2147483647 |
| `--seed` | 1 | Decimal integer, 0–18446744073709551615; reduced modulo 2^32 |
| `--mode` | full | `full`, `gn`, `ou` |
| `--output` | text | `text`, `json` |

Only ASCII decimal digits are accepted for integers. Signs, spaces, decimals,
exponents, unknown options, positional arguments, and missing values fail with
a nonzero exit and a stderr diagnostic. Repeated recognized options use the
last value. Leading zeroes are allowed. Count limits match V's signed 32-bit
index representation; they do not guarantee sufficient memory or reasonable
execution time. Array storage is roughly `8 * (2*n - 1 + runs)` bytes,
excluding runtime overhead.

After building, run any native binary directly:

```bash
.scratch/bin/c --n=1000 --runs=3 --warmup=1 --seed=1 --mode=full --output=json
.scratch/bin/rust --n=1000 --runs=3 --warmup=1 --seed=1 --mode=gn --output=json
.scratch/bin/zig --n=1000 --runs=3 --warmup=1 --seed=1 --mode=ou --output=json
.scratch/bin/swift --n=1000 --runs=3 --warmup=1 --seed=1
.scratch/bin/v --n=1000 --runs=3 --warmup=1 --seed=1
bun ts/ou_bench.ts --n=1000 --runs=3 --warmup=1 --seed=1
```

[build.sh](build.sh) is the authoritative compiler invocation:
C/V use native CPU optimization with fast-math and FMA contraction disabled;
Rust uses release LTO, one codegen unit, and native CPU targeting;
Swift uses `-O -whole-module-optimization -swift-version 6`;
Zig uses ReleaseFast with strict floating-point semantics.
Native targeting makes binaries specific to the build machine.

Swift retains runtime checks. Zig ReleaseFast disables many runtime checks:
validate separately with `ZIG_OPTIMIZE=ReleaseSafe bash build.sh`.
These builds do not provide equal memory-safety guarantees. Avoid mixing
different flag policies in one performance ranking.

## Workload and timing

All six implementations preserve:

- SplitMix32 seeding and xorshift128 with wrapping 32-bit arithmetic.
- A 53-bit uniform from two successive PRNG words.
- Marsaglia polar normals, emitting both values in order with spare carry.
- Euler–Maruyama recurrence, `x = a*x + b + noise`.
- `theta=1`, `mu=0`, `sigma=0.1`, `x0=0`, and `dt=1/n`.

There are `n` stored points and `n-1` updates. The final simulated time is
`(n-1)/n`, not exactly 1. This historical time-grid convention is preserved.

| Mode | Timed work |
|---|---|
| `full` | Generate scaled normals, simulate/store path, sum path |
| `gn` | Generate scaled normals, sum noise |
| `ou` | Simulate/store path using one prefilled noise buffer, sum path |

Buffers are allocated once. Parsing, allocation, warmup, sorting, and formatting
are outside timed intervals. RNG and spare state restart after warmup, then
continue across measured generation runs. Bun requests GC before measurement.
That does not guarantee an allocation-free runtime or a fully warmed JIT.

The checksum reads every stored value in order and makes the result observable.
It is not a universal compiler optimization barrier. Rust additionally uses
`black_box` on the checksum input. Cross-language math-library rounding can
differ; the E2E reference tolerance is `1e-10` absolute or relative.

Output fields remain `language`, `mode`, `n`, `runs`, `warmup`, `seed`,
`total_s`, `avg_ms`, `median_ms`, `min_ms`, `max_ms`, `breakdown_s`,
and `checksum`. The breakdown contains aggregate seconds for
`gen_normals`, `simulate`, and `checksum`. Seconds are rounded to six
decimal places, so very small cases can display zero.

## Verify and compare

```bash
# Builds first; set V if needed.
python3 tests/check.py --scripts
# Recheck existing binaries, or a selected build directory.
python3 tests/check.py --skip-build --scripts
python3 tests/check.py --skip-build --bin-dir .scratch/safe --languages c zig swift v rust
cargo fmt --manifest-path rust/Cargo.toml --check
cargo clippy --manifest-path rust/Cargo.toml --locked --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml --locked
zig fmt --check zig/ou_bench.zig
shellcheck build.sh run_all.sh DOCS/scripts/compare_runs.sh
```

The Python suite drives real processes with a scalar numerical reference, odd/even
tails, wide seeds, warmup resets, text/JSON checks, and malformed inputs.
Cargo's test command checks compilation; behavioral coverage lives in the CLI suite.

```bash
./DOCS/scripts/compare_runs.sh baseline.jsonl candidate.jsonl
```

Comparison rejects empty/duplicate records, incompatible parameters, missing
language/mode pairs, invalid timings, and checksum drift. Use one record per
language/mode in each file. Build flags, toolchain identity, and machine state
must also match; these are recorded separately, not inferred from the JSON.

Measure multiple fresh processes with alternating baseline/candidate order,
record raw data and toolchains, and report variability. The
[methodology guide](DOCS/learn/09-benchmarking-methodology.md) explains the limits.
The 2025 fast-math/unchecked results remain
[historical](DOCS/Run-Record-2025-12-19.md).

## Credits

Inspired by [rust-dd's OU benchmark article](https://rust-dd.com/post/crab-scientific-computing-benchmark-rust-crab-vs-zig-zap-vs-the-father-c-older_man)
and [probability-benchmark](https://github.com/rust-dd/probability-benchmark).
Thanks to Peter Steinberger for prompting examination of compiler flags.
See [LICENSE](LICENSE).
