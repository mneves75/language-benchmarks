# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ornstein-Uhlenbeck (OU) process microbenchmark comparing performance across five languages: TypeScript/Bun, Rust, Zig, C, and Swift. All implementations use **identical algorithms** to ensure fair comparison.

**Based on:** [🦀 Scientific Computing Benchmark: Rust 🦀 vs Zig ⚡ vs The Father C 👴](https://rust-dd.com/post/crab-scientific-computing-benchmark-rust-crab-vs-zig-zap-vs-the-father-c-older_man)

**Algorithms:**

- **PRNG**: xorshift128 (u32) seeded via splitmix32
- **Uniform distribution**: 53-bit double from two u32 draws
- **Normal distribution**: Marsaglia polar method with cached spare
- **OU simulation**: Euler update with precomputed a, b, and diffusion coefficients

## Build and Run Commands

### Run All Benchmarks
```bash
./run_all.sh [n] [runs] [warmup] [seed] [mode] [output]
# Default: n=500000 runs=1000 warmup=5 seed=1
```

### Individual Languages

**TypeScript/Bun:**
```bash
cd ts && bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1
```

**Rust:**
```bash
cd rust && cargo run --release -- --n=500000 --runs=1000 --warmup=5 --seed=1
# With native CPU optimization:
RUSTFLAGS="-C target-cpu=native" cargo run --release -- --n=500000 --runs=1000 --warmup=5 --seed=1
```

**C:**
```bash
cd c && cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1
```

**Zig:**
```bash
cd zig && zig build-exe ou_bench.zig -O ReleaseFast -fstrip -femit-bin=ou_bench
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1
```

**Swift:**
```bash
cd swift && swiftc -O -whole-module-optimization ou_bench.swift -o ou_bench_swift
./ou_bench_swift --n=500000 --runs=1000 --warmup=5 --seed=1
```

## Architecture

Each implementation follows the same structure:
1. **Argument parsing**: `--n`, `--runs`, `--warmup`, `--seed` flags
   - Additional flags: `--mode=full|gn|ou` and `--output=text|json`
2. **Buffer allocation**: `gn` (N-1 Gaussian increments) and `ou` (N trajectory points) allocated once
3. **Warmup phase**: Runs the simulation `warmup` times outside the timed region
4. **Timed runs**: Measures three stages per run:
   - `gen_normals`: Generate Gaussian random increments
   - `simulate`: Run the OU Euler simulation
   - `checksum`: Sum all trajectory points (prevents dead-store elimination)

## Important Notes

- Checksums may differ slightly across languages due to libm implementation differences
- Allocations and argument parsing occur outside timed regions
- The Rust release profile enables LTO and single codegen-unit for maximum optimization
