# Engineering Exec Spec: OU Benchmark Parity and Methodology Hardening

## Goal
- Preserve algorithmic parity across C, Zig, Rust, Swift, and TypeScript/Bun while improving interpretability and repeatability.
- Add narrowly scoped benchmark modes to separate RNG/normal generation cost from OU simulation cost.
- Strengthen measurement practice without introducing heavy benchmarking frameworks.

## Non-goals
- Changing the core OU algorithm, PRNG, or normal sampler.
- Enforcing cross-language bit-identical floating point results.
- Introducing external benchmark frameworks or CI benchmarking in this phase.

## Current State (Repo Review)
- Five implementations align on PRNG (splitmix32 + xorshift128), Marsaglia polar, and Euler OU update.
- Timing excludes argument parsing and allocation; per-run breakdown includes gen_normals, simulate, checksum.
- Median, min, and max are reported in each language.
- Bun run uses `Bun.gc(true)` before timed runs to reduce GC noise.
- `run_all.sh` separates build and run phases and uses identical CLI flags.

## Best-Practice Alignment (External)
- Warmup runs stabilize caches/JITs before measurement.
- Checksum readback reduces dead-code elimination risk.
- Reporting median/min/max improves robustness vs mean-only reporting.
- Optional GC before timed runs in managed runtimes.

## Proposed Approach (Options + Tradeoffs)
Option A: Document-only tightening
- Update README/CLAUDE with best-practice notes and hygiene tips.
- Lowest risk; limited interpretability improvement.

Option B: Add measurement modes + structured output + Swift (preferred)
- Add `--mode=full|gn|ou` and `--output=text|json` across all languages.
- Add Swift implementation with identical algorithms and output format.
- Improves interpretability while keeping algorithm parity and light tooling.
- Requires synchronized changes across languages and docs.

Option C: Integrate formal benchmarking frameworks
- Highest statistical rigor.
- Adds dependencies and breaks parity across languages.

Decision: Option B.

## Architecture / Data Flow Changes
- CLI parsing extends to:
  - `--mode=full|gn|ou` (default `full`)
    - `full`: current behavior.
    - `gn`: generate normals only, checksum on `gn`.
    - `ou`: prefill `gn`, time OU only, checksum on `ou`.
  - `--output=text|json` (default `text`).
- JSON output mirrors text fields and uses identical keys across languages.
- Allocation boundaries and timing windows remain unchanged.

## Phased Plan with Milestones
Phase 0: Discovery and success metrics
- Confirm default output remains backward compatible in `full` mode.
- Success metric: `run_all.sh` text output fields unchanged.

Phase 1: Mode support (gn/ou/full) + Swift
- Add `mode` flag in all languages.
- Add Swift implementation and wire into `run_all.sh`.
- Update README/CLAUDE with new flags and examples.
- Acceptance: `--mode=gn` and `--mode=ou` produce valid timings and checksums.

Phase 2: Structured output and stability improvements
- Add `--output=json` with identical keys across languages.
- Replace O(runs^2) sort in C with `qsort`.
- Route Zig output to stdout (Zig 0.15: `std.fs.File.stdout().deprecatedWriter()`).
- Acceptance: JSON parses; text output remains identical.

Phase 3: Reproducibility harness
- Add template for recording hardware/software metadata and run parameters.
- Provide a comparison script to diff JSON outputs across runs.
- Acceptance: one recorded run includes CPU model, OS, and toolchain versions.

## Detailed Multi-Phase TODO (Engineer Checklist)
Phase 0
- [x] Inventory current CLI flags and outputs; capture baseline output format.
- [x] Define parity success criteria (output keys and checksum stability).

Phase 1
- [x] Add `--mode` parsing to `ts/ou_bench.ts`.
- [x] Add `--mode` parsing to `rust/src/main.rs`.
- [x] Add `--mode` parsing to `c/ou_bench.c`.
- [x] Add `--mode` parsing to `zig/ou_bench.zig`.
- [x] Add Swift implementation with identical algorithms and flags.
- [x] Implement `gn`-only and `ou`-only branches with identical timing boundaries.
- [x] Update `run_all.sh` to forward `--mode`.
- [x] Update `README.md` and `CLAUDE.md` with new flags and examples.

Phase 2
- [x] Implement `--output=json` in all languages with identical field names.
- [x] Switch C median sort to `qsort`.
- [x] Route Zig output to stdout (Zig 0.15 compatible).
- [x] Keep `--output=text` identical to prior output.

Phase 3
- [x] Add `DOCS/Run-Record-Template.md`.
- [x] Add `DOCS/scripts/compare_runs.sh`.
- [x] Document variance guidance in README.

## Testing Strategy
- Manual run matrix:
  - `run_all.sh` in `full` mode with defaults.
  - Each language with `--mode=gn` and `--mode=ou`.
  - JSON output validation (parse and key check).
- Verify checksum stability within each language build.
- Verify text output in `full` mode remains unchanged.

## Observability
- Stdout as primary output channel.
- JSON output supports downstream parsing and diffing.

## Rollout Plan
- Land Phase 1, verify outputs, then Phase 2, then Phase 3.
- Each phase reversible by reverting the specific changes.

## Rollback Plan
- Revert to previous tag/commit; keep `full` mode as fallback.

## Risks and Mitigations
- Risk: parity drift across languages.
  - Mitigation: update all five implementations in a single PR and use the checklist.
- Risk: output format breakage.
  - Mitigation: keep `--output=text` identical; add explicit acceptance checks.
- Risk: performance impact from new branches.
  - Mitigation: keep branch structure minimal and avoid extra allocations.

## Open Questions (Non-blocking)
- Standardize numeric formatting precision across languages?
- Add an alias flag (e.g., `--samples`) to align with common terminology?

## Verification Log
- `./run_all.sh 1000 3 1 1 full text`
- `./run_all.sh 1000 2 1 1 gn json`
- `./run_all.sh 1000 2 1 1 ou json`
- `./run_all.sh` (defaults: n=500000 runs=1000 warmup=5 seed=1)

## References
- https://github.com/google/benchmark/blob/main/docs/user_guide.md
- https://bheisler.github.io/criterion.rs/book/user_guide.html
- https://bun.sh/docs/api/gc

## Status
- Completed: mode/output flags in all languages, Swift implementation, JSON output, C qsort median, Zig stdout output.
- Completed: `DOCS/Run-Record-Template.md` and `DOCS/scripts/compare_runs.sh`.
- Last verified: 2025-12-19.
