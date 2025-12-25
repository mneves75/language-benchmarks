# Changelog

## [1.3.0] - 2025-12-25

### Added
- V language implementation with maximum optimizations
- V achieves C-level performance (avg_ms=3.25, identical to C)
- Optimizations applied:
  - `@[inline]` attributes on all hot-path functions
  - `unsafe` blocks around array access loops to eliminate bounds checking
  - Compiler flags: `-prod -cstrict -cc gcc -skip-unused` with `-O3 -ffast-math -march=native`
- `v/OPTIMIZATIONS.md` documenting V-specific performance optimizations
- Updated README.md, CLAUDE.md, and run_all.sh to include V
- V installation instructions in README.md

### Benchmark Results
- V (vlang.io): avg/median/min/max = 3.25/3.24/3.16/4.30 ms
- Matches C performance within measurement error

## [1.2.3] - 2025-12-19

### Changed
- Updated benchmark results after enabling maximum optimization flags (run params: `n=500000 runs=1000 warmup=5 seed=1`)
- Rust: `RUSTFLAGS="-C target-cpu=native"`; avg/median/min/max change vs prior table: +0.19/+0.11/+0.05/+9.31 ms
- C: `-O3 -ffast-math -march=native -fno-math-errno -fno-trapping-math`; avg/median/min/max change: -0.46/-0.45/-0.46/-1.23 ms
- Zig: `-mcpu=native` (ReleaseFast retained); avg/median/min/max change: +0.11/+0.11/+0.04/-0.32 ms
- Swift: `-Ounchecked -whole-module-optimization`; avg/median/min/max change: -4.81/-4.81/-4.64/-4.89 ms
- TypeScript/Bun: no compiler flag change; avg/median/min/max change: +0.13/+0.12/+0.12/+0.81 ms
- Thanks to Peter Steinberger (`https://x.com/steipete`) for the heads up about the compiler flags

## [1.2.2] - 2025-12-19

### Changed
- Build scripts and docs now default to maximum optimization flags across Rust/C/Zig/Swift
- C compile flags use `-O3 -ffast-math` to match clang guidance

## [1.2.1] - 2025-12-19

### Changed
- Build scripts and docs now default to maximum optimization flags across Rust/C/Zig/Swift
- Documented that aggressive optimization may affect checksum differences

## [1.2.0] - 2025-12-19

### Added
- Educational tutorial series in `DOCS/learn/`:
  - `00-introduction.md`: Comprehensive introduction to language benchmarking
  - `01-ou-process.md`: Detailed explanation of the Ornstein-Uhlenbeck process
  - `02-random-numbers.md`: Random number generation and xorshift128 PRNG
  - `03-normal-distribution.md`: Normal distribution and Marsaglia polar method
  - `04-c-implementation.md`: C implementation walkthrough
  - `05-zig-implementation.md`: Zig implementation walkthrough
  - `06-rust-implementation.md`: Rust implementation walkthrough
  - `07-typescript-bun.md`: TypeScript (Bun runtime) implementation walkthrough
  - `08-swift-implementation.md`: Swift implementation walkthrough
  - `09-benchmarking-methodology.md`: Benchmarking methodology and best practices
  - `10-exercises-projects.md`: Hands-on exercises and projects
  - `README.md`: Tutorial series index and learning path

### Removed
- `DOCS/Old-benchmark-analysis.md`: Outdated benchmark analysis
- `DOCS/Run-Record-Template.md`: Obsolete run record template

## [1.1.1] - 2025-12-19

### Added
- Reference to original benchmark article in README.md and CLAUDE.md

## [1.1.0] - 2025-12-19

### Added
- Swift implementation aligned with all other languages
- `--mode=full|gn|ou` to separate RNG/normal generation from OU simulation
- `--output=text|json` with identical keys across languages
- Run record template in `DOCS/Run-Record-Template.md`
- Comparison helper `DOCS/scripts/compare_runs.sh`

### Changed
- `run_all.sh` accepts `mode` and `output` parameters and builds Swift
- C median calculation uses `qsort` for scalability
- Zig output routed to stdout for consistent capture
- README results table updated with Swift and latest verified metrics

## [1.0.0] - 2024-12-19

### Added
- Initial release with unified OU benchmark implementations in C, Zig, Rust, and TypeScript (Bun runtime)
- All implementations use identical algorithms (xorshift128 PRNG, Marsaglia polar normal sampler)
- `run_all.sh` script with separate build and run phases
- Median statistic in all implementations for robust comparison
- Bun GC call before timed runs to reduce variance
- CLAUDE.md for AI assistant guidance
- README.md with results table and documentation

### Benchmark Features
- Configurable parameters: n, runs, warmup, seed
- Stage breakdown timing (gen_normals, simulate, checksum)
- Checksum verification to prevent dead-store elimination
- Memory allocated once and reused across runs
