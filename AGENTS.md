# Repository Guidelines

## Project Structure & Module Organization

- `ts/`, `rust/`, `zig/`, `c/`: language-specific implementations of the same OU benchmark (keep algorithms aligned across languages).
- `run_all.sh`: convenience script that builds/runs all implementations with the same parameters.
- `DOCS/`: background notes and analysis (non-code documentation).
- `README.md` and `CLAUDE.md`: usage and methodology notes; update if you change the algorithm or CLI flags.
- Build artifacts (e.g., `c/ou_bench_c`, `zig/ou_bench`) are generated locally and should not be edited by hand.

## Build, Test, and Development Commands

- Run everything with shared parameters:
  - `./run_all.sh [n] [runs] [warmup] [seed]`
- TypeScript (Bun):
  - `cd ts && bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1`
- Rust:
  - `cd rust && cargo run --release -- --n=500000 --runs=1000 --warmup=5 --seed=1`
  - Optional CPU tuning: `RUSTFLAGS="-C target-cpu=native" cargo run --release -- ...`
- C (clang/gcc):
  - `cd c && cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c`
  - `./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1`
- Zig:
  - `cd zig && zig build-exe ou_bench.zig -O ReleaseFast -fstrip -femit-bin=ou_bench`
  - `./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1`

## Coding Style & Naming Conventions

- Match existing style per language:
  - TypeScript uses 2-space indentation and camelCase names.
  - Rust/Zig/C use 4-space indentation and snake_case identifiers.
- Keep algorithm steps and constants consistent across languages (PRNG, normal sampler, OU update).
- No formatter/linter is configured; avoid stylistic rewrites that make cross-language diffs harder to compare.

## Testing Guidelines

- There are no automated tests. Validate changes by running the benchmarks and ensuring:
  - Output fields remain consistent (N, runs, warmup, seed, timing breakdown, checksum).
  - Checksums remain stable within each language build (cross-language checksums may differ).

## Commit & Pull Request Guidelines

- The repository has no commit history yet, so no formal convention is established.
- Use concise, imperative commit messages (e.g., "Align Zig RNG with Rust").
- In PRs, describe:
  - What changed and why it preserves algorithm parity.
  - Any performance impact and how you measured it (command and parameters).
  - If CLI flags or output format changed, update `README.md`.

## Benchmark Parity Checklist

- If you change the algorithm or parameters in one language, mirror it across all four implementations.
- Keep allocation strategy and timing boundaries consistent with the README.
