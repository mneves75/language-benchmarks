# Changelog

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
  - `07-typescript-bun.md`: TypeScript/Bun implementation walkthrough
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
- Initial release with unified OU benchmark implementations in C, Zig, Rust, and TypeScript/Bun
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
