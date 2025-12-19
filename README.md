# OU Benchmark

A fair, methodology-fixed Ornstein-Uhlenbeck process benchmark comparing **C**, **Zig**, **Rust**, **Swift**, and **TypeScript/Bun**.

## Results

**Test Machine:** MacBook Pro, Apple M4 Pro (14 cores: 10P + 4E), 48 GB RAM

| Language | Avg (ms) | Median (ms) | Min (ms) | Max (ms) |
|----------|----------|-------------|----------|----------|
| **C**    | 3.71     | 3.70        | 3.44     | 5.08     |
| **Zig**  | 3.82     | 3.82        | 3.57     | 5.08     |
| **Rust** | 3.85     | 3.84        | 3.59     | 5.79     |
| **Bun**  | 6.15     | 6.13        | 5.77     | 18.32    |
| **Swift**| 9.25     | 9.25        | 8.82     | 9.95     |

*Default parameters: n=500000, runs=1000, warmup=5, seed=1*

## Quick Start

```bash
./run_all.sh
```

Or with custom parameters:
```bash
./run_all.sh [n] [runs] [warmup] [seed] [mode] [output]
./run_all.sh 500000 1000 5 1 full text
```

## What Makes This Fair

All implementations use **identical algorithms**:

- **PRNG**: xorshift128 (32-bit) seeded via splitmix32
- **Normal sampler**: Marsaglia polar (Box-Muller polar) with cached spare
- **Memory strategy**: `gn` (N-1) and `ou` (N) buffers allocated once and reused
- **Timing boundaries**: allocations and parsing happen outside timed region
- **Anti-optimization**: full checksum readback prevents dead-store elimination

## Output Format

Each benchmark prints:
- Parameters: n, runs, warmup, seed
- Timing: total_s, avg_ms, median_ms, min_ms, max_ms
- Stage breakdown: gen_normals, simulate, checksum (in seconds)
- Checksum (for correctness verification)

**Note:** Checksums may differ slightly across languages due to libm differences. This is expected.

Additional flags (all languages):
- `--mode=full|gn|ou` (default `full`)
- `--output=text|json` (default `text`)

## Individual Language Commands

### TypeScript/Bun
```bash
cd ts && bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Rust
```bash
cd rust && cargo build --release
./target/release/ou_bench_unified --n=500000 --runs=1000 --warmup=5 --seed=1

# Optional: native CPU optimizations
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

### C
```bash
cd c && cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Zig
```bash
cd zig && zig build-exe ou_bench.zig -O ReleaseFast -fstrip -femit-bin=ou_bench
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Swift
```bash
cd swift && swiftc -O -whole-module-optimization ou_bench.swift -o ou_bench_swift
./ou_bench_swift --n=500000 --runs=1000 --warmup=5 --seed=1
```

## Tips for Clean Comparisons

- Run on AC power, close background apps
- Compare **medians** rather than means (more robust to outliers)
- Pin CPU frequency if possible (Linux: performance governor)
- Run multiple times to verify consistency

## Reproducibility

- Use `DOCS/Run-Record-Template.md` to capture environment and toolchain details.
- For diffing runs, capture JSON output and compare with `DOCS/scripts/compare_runs.sh`.

## Project Structure

```
.
├── run_all.sh      # Build and run all benchmarks
├── ts/             # TypeScript/Bun implementation
├── rust/           # Rust implementation
├── zig/            # Zig implementation
├── c/              # C implementation
└── swift/          # Swift implementation
```
