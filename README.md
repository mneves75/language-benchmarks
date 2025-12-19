# OU Benchmark

A fair, methodology-fixed Ornstein-Uhlenbeck process benchmark comparing **C**, **Zig**, **Rust**, and **TypeScript/Bun**.

## Results

**Test Machine:** MacBook Pro, Apple M4 Pro (14 cores: 10P + 4E), 48 GB RAM

| Language | Avg (ms) | Median (ms) | Min (ms) | Max (ms) |
|----------|----------|-------------|----------|----------|
| **C**    | 3.76     | 3.76        | 3.48     | 5.16     |
| **Zig**  | 3.92     | 3.91        | 3.63     | 4.89     |
| **Rust** | 3.92     | 3.91        | 3.62     | 5.08     |
| **Bun**  | 6.50     | 6.48        | 6.05     | 15.58    |

*Default parameters: n=500000, runs=1000, warmup=5, seed=1*

## Quick Start

```bash
./run_all.sh
```

Or with custom parameters:
```bash
./run_all.sh [n] [runs] [warmup] [seed]
./run_all.sh 500000 1000 5 1
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

## Tips for Clean Comparisons

- Run on AC power, close background apps
- Compare **medians** rather than means (more robust to outliers)
- Pin CPU frequency if possible (Linux: performance governor)
- Run multiple times to verify consistency

## Project Structure

```
.
├── run_all.sh      # Build and run all benchmarks
├── ts/             # TypeScript/Bun implementation
├── rust/           # Rust implementation
├── zig/            # Zig implementation
└── c/              # C implementation
```
