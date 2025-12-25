# OU Benchmark

A fair, methodology-fixed Ornstein-Uhlenbeck process benchmark comparing **C**, **Zig**, **Rust**, **Swift**, **V**, and **TypeScript (Bun runtime)**.

## What is the OU Process?

The **Ornstein-Uhlenbeck (OU) process** is a mathematical model that describes random motion with mean reversion—think of a particle bouncing around in water, constantly pulled back toward an equilibrium position. It's widely used in:

- **Finance**: Modeling interest rates and volatility
- **Physics**: Describing Brownian motion with friction
- **Biology**: Population dynamics and neural activity

**The Benchmark Algorithm:**

1. **Generate Random Numbers**: Create N-1 Gaussian (normally-distributed) random values using the Marsaglia polar method
2. **Simulate the Process**: Calculate N trajectory points using the Euler-Maruyama method with mean-reversion dynamics
3. **Compute Checksum**: Sum all values to prevent compiler dead-store elimination

This is a realistic scientific computing workload that tests: floating-point math, memory access patterns, and random number generation—making it ideal for comparing language performance in numerical computing.

## Results

**Test Machine:** MacBook Pro, Apple M4 Pro (14 cores: 10P + 4E), 48 GB RAM

| Language | Avg (ms) | Median (ms) | Min (ms) | Max (ms) |
|----------|----------|-------------|----------|----------|
| **C**    | 3.25     | 3.25        | 2.98     | 3.85     |
| **V**    | 3.25     | 3.24        | 3.16     | 4.30     |
| **Zig**  | 3.93     | 3.93        | 3.61     | 4.76     |
| **Rust** | 4.04     | 3.95        | 3.64     | 15.10    |
| **Swift**| 4.44     | 4.44        | 4.18     | 5.06     |
| **TypeScript (Bun runtime)**  | 6.28     | 6.25        | 5.89     | 19.13    |

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

**Note:** Checksums may differ slightly across languages due to libm differences and aggressive optimizer flags. This is expected.

Additional flags (all languages):
- `--mode=full|gn|ou` (default `full`)
- `--output=text|json` (default `text`)

## Individual Language Commands

### TypeScript (Bun runtime)
```bash
cd ts && bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Rust
```bash
cd rust && RUSTFLAGS="-C target-cpu=native" cargo build --release
./target/release/ou_bench_unified --n=500000 --runs=1000 --warmup=5 --seed=1
```

### C
```bash
cd c && cc -O3 -ffast-math -march=native -fno-math-errno -fno-trapping-math -std=c11 ou_bench.c -lm -o ou_bench_c
./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Zig
```bash
cd zig && zig build-exe ou_bench.zig -O ReleaseFast -mcpu=native -fstrip -femit-bin=ou_bench
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1
```

### Swift
```bash
cd swift && swiftc -Ounchecked -whole-module-optimization ou_bench.swift -o ou_bench_swift
./ou_bench_swift --n=500000 --runs=1000 --warmup=5 --seed=1
```

### V
```bash
cd v && v -prod -cstrict -cc gcc -skip-unused -cflags '-O3 -ffast-math -march=native -fno-math-errno -fno-trapping-math' ou_bench.v
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1
```

## Tips for Clean Comparisons

- Run on AC power, close background apps
- Compare **medians** rather than means (more robust to outliers)
- Pin CPU frequency if possible (Linux: performance governor)
- Run multiple times to verify consistency

## Reproducibility

- Capture JSON output with `--output=json` for precise comparisons
- Use `DOCS/scripts/compare_runs.sh` to diff multiple benchmark runs

## Project Structure

```
.
├── run_all.sh      # Build and run all benchmarks
├── ts/             # TypeScript (Bun runtime) implementation
├── rust/           # Rust implementation
├── zig/            # Zig implementation
├── c/              # C implementation
├── swift/          # Swift implementation
└── v/              # V implementation
```

## Acknowledgments

This benchmark is inspired by and extends the work from the original article and implementation:

**[🦀 Scientific Computing Benchmark: Rust 🦀 vs Zig ⚡ vs The Father C 👴](https://rust-dd.com/post/crab-scientific-computing-benchmark-rust-crab-vs-zig-zap-vs-the-father-c-older_man)**

**Original Repository:** [rust-dd/probability-benchmark](https://github.com/rust-dd/probability-benchmark)

Thanks to:
- **[rust-dd](https://github.com/rust-dd)** for the original benchmark implementation and methodology
- **[Peter Steinberger](https://x.com/steipete)** for the heads up about the compiler flags

The original benchmark compared C, Zig, and Rust for scientific computing using the Ornstein-Uhlenbeck process. This repository adds TypeScript (Bun runtime), Swift, and V implementations while maintaining the same fair methodology.

## Language Resources

- **C** - [ISO C Standard](https://www.iso.org/standard/74528.html)
- **Zig** - [ziglang.org](https://ziglang.org/)
- **Rust** - [rust-lang.org](https://www.rust-lang.org/)
- **V** - [vlang.io](https://vlang.io/)
- **TypeScript** - [typescriptlang.org](https://www.typescriptlang.org/)
- **Bun Runtime** - [bun.sh](https://bun.sh/)
- **Swift** - [swift.org](https://www.swift.org/)

## Installing V

To run the V benchmark, you'll need to install the V compiler:

```bash
# Install V
git clone https://github.com/vlang/v
cd v
make
sudo ./v symlink  # Optional: creates a system-wide 'v' command
```

Or visit [vlang.io](https://vlang.io/) for other installation options.
