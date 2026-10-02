# Repository guidelines

This repository implements one OU workload in C, Rust, Zig, Swift, V, and
TypeScript/Bun. Read [README.md](README.md) for CLI/build policy and
[DOCS/Engineering-Exec-Spec.md](DOCS/Engineering-Exec-Spec.md) for numerical invariants.

## Structure and ownership

- `c/`, `rust/`, `zig/`, `swift/`, `v/`, `ts/`: six source implementations.
- `build.sh`: authoritative optimized compiler commands; outputs `.scratch/bin/`.
- `run_all.sh`: common parameters, six result records; build messages on stderr.
- `tests/check.py`: dependency-free Python E2E suite through real executables.
- `DOCS/learn/`: tutorials; `DOCS/results/`: dated, reproducible raw measurements.
- `VERSION`, Cargo package version, README, and CHANGELOG move together.
- Build products and large local evidence belong in ignored `.scratch/` or `rust/target/`.
  Never treat the legacy tracked `v/ou_bench` executable as current source evidence.

## Required validation

Write a failing E2E regression before a behavioral fix. Preserve the scalar
reference; do not change expected results merely to match a new implementation.

```bash
python3 tests/check.py --scripts
cargo fmt --manifest-path rust/Cargo.toml --check
cargo clippy --manifest-path rust/Cargo.toml --locked --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml --locked
zig fmt --check zig/ou_bench.zig
shellcheck build.sh run_all.sh DOCS/scripts/compare_runs.sh
git diff --check
```

Set `V` to the installed V executable when needed. Cargo test currently has no
unit tests; the E2E suite supplies behavioral coverage. Use
`--skip-build --bin-dir <directory> --languages ...` for sanitizer/safety artifacts.
Changes to hot loops also need repeated before/after measurements using matching
compiler policies and numeric checks first. Record unfavorable observations.

## Parity and review

Keep SplitMix32/xorshift128, 53-bit uniforms, polar acceptance/order/spare state,
`dt=1/n`, Euler recurrence, and ordered checksum traversal aligned across all six
implementations. Warmup must not change the timed random stream. Preserve mode
semantics, output fields, buffer reuse, and timing boundaries.

Per-language loop structure may differ when it preserves the numerical contract
and measured evidence supports it. A different PRNG, sampler, exact OU transition,
parallel execution, or reassociated reduction requires a separately named workload.

Reject malformed/unknown CLI input before allocation. Counts use the common
signed-32-bit ceiling; seeds parse exactly as u64 before reduction. Do not use
fast-math, Swift unchecked mode, or unchecked indexing to hide correctness failures.
Zig ReleaseFast is the benchmark default; validate changed loops in ReleaseSafe too.

Keep code readable and native to its language. Rust uses rustfmt; Zig uses zig fmt;
V uses v fmt; Swift uses swift-format. Avoid unrelated formatting churn.
Prefer safe iterators/slices and clear error paths. Add no dependencies for
functionality already available in the standard libraries.

Update affected docs and the changelog with visible changes. Preserve historical
measurements as historical; new results need hardware, versions, flags, parameters,
raw records, and limitations. Use Conventional Commits. Never assert a universal
language ranking or a speedup from source inspection alone.
