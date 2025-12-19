# Engineering Exec Spec: OU Benchmark Parity and Methodology Hardening

## Goal
- Preserve algorithmic parity across C, Zig, Rust, and TypeScript/Bun while improving the interpretability and repeatability of results.
- Add narrowly scoped benchmark modes to separate RNG/normal generation cost from OU simulation cost.
- Strengthen measurement practice without introducing external benchmarking frameworks or large dependencies.

## Non-goals
- Changing the core OU algorithm, PRNG, or normal sampler.
- Enforcing cross-language bit-identical floating point results.
- Adding heavy tooling (e.g., Criterion/Google Benchmark) or CI benchmarking.

## Current State (Repo Review)
- All four implementations align on PRNG (splitmix32 + xorshift128), Marsaglia polar, and Euler OU update.
- Timing excludes argument parsing and allocation; per-run breakdown includes gen_normals, simulate, checksum.
- Median, min, and max are reported in each language.
- Bun run uses `Bun.gc(true)` before timed runs to reduce GC noise.
- `run_all.sh` separates build and run phases and uses identical CLI flags.
- Zig uses `std.debug.print`, which writes to stderr (unlike other languages that use stdout).
- C median uses O(runs^2) sort; acceptable at runs=1000, but not scalable.

## Best-Practice Alignment (External)
Current design aligns with several microbenchmarking best practices:
- Warmup runs to stabilize caches/JITs before measurement.
- Avoiding dead-code elimination via checksum readback.
- Reporting distributions (median/min/max), not just mean.
- Optional GC before timed runs in managed runtimes (Bun).

References are listed at the end of this document.

## Proposed Approach (Options + Tradeoffs)
Option A: Document-only tightening
- Update README/CLAUDE with best-practice notes and add benchmark hygiene tips.
- Lowest risk; does not improve interpretability.

Option B: Add measurement modes + structured output (preferred)
- Add `--mode=full|gn|ou` and `--output=text|json` across all languages.
- Improves interpretability while keeping algorithm parity and simple tooling.
- Requires synchronized edits across all implementations and docs.

Option C: Integrate formal benchmarking frameworks
- Highest statistical rigor.
- Introduces dependencies, heavier build steps, and breaks parity across languages.

Decision: Option B.

## Architecture / Data Flow Changes
- CLI parsing extends to two flags:
  - `--mode=full|gn|ou` (default `full`):
    - `full`: current behavior.
    - `gn`: generate normals only (store in `gn`), skip OU step.
    - `ou`: reuse a prefilled `gn` (from a deterministic fill) and time OU only.
  - `--output=text|json` (default `text`).
- Result computation stays the same; JSON output mirrors current text fields.
- All languages keep same allocation boundaries and timing windows.

## Phased Plan with Milestones
Phase 0: Discovery and success metrics
- Confirm desired default output remains backward compatible.
- Success metric: `run_all.sh` output fields unchanged in `full` mode.

Phase 1: Mode support (gn/ou/full)
- Implement `mode` flag in all four languages with identical behavior.
- Add `run_all.sh` passthrough for `mode`.
- Update README.md and CLAUDE.md with new flags and examples.
- Acceptance: `--mode=gn` and `--mode=ou` produce valid timings and checksums.

Phase 2: Structured output and stability improvements
- Add `--output=json` with identical keys across languages.
- Replace O(runs^2) sort in C with O(runs log runs) (e.g., qsort) for scalability.
- Route Zig output to stdout to prevent stderr-only output.
- Acceptance: JSON parses, keys match, and text output remains identical.

Phase 3: Reproducibility harness
- Add `DOCS/` template for recording hardware/software metadata and run parameters.
- Provide a small script to compare results across runs and flag regressions.
- Acceptance: one recorded run includes CPU model, OS, compiler/runtime versions.

## Detailed Multi-Phase TODO (Engineer Checklist)
- Phase 0
  - Inventory all current CLI flags and outputs; capture example outputs for baseline.
  - Define success criteria for parity (output keys, checksum stability).
- Phase 1
  - Add `mode` parsing to `ts/ou_bench.ts`.
  - Add `mode` parsing to `rust/src/main.rs`.
  - Add `mode` parsing to `c/ou_bench.c`.
  - Add `mode` parsing to `zig/ou_bench.zig`.
  - Implement `gn`-only and `ou`-only branches with identical timing boundaries.
  - Update `run_all.sh` to forward `--mode`.
  - Update `README.md` and `CLAUDE.md` (new flags + examples).
- Phase 2
  - Implement JSON output in all languages with identical field names.
  - Switch C median sort to `qsort`.
  - Switch Zig output to stdout (use `std.io.getStdOut().writer()`).
  - Ensure `--output=text` matches current output exactly.
- Phase 3
  - Add `DOCS/Run-Record-Template.md` (machine + runtime metadata).
  - Add a lightweight comparison script (optional: `DOCS/scripts/compare_runs.sh`).
  - Document expected variance and interpretation guidance.

## Testing Strategy
- Manual run matrix:
  - `run_all.sh` in `full` mode with defaults.
  - Each language with `--mode=gn` and `--mode=ou`.
  - JSON output validation: basic parse and key existence.
- Verify checksum stability within each language build.
- Verify text output in `full` mode remains unchanged.

## Observability
- Keep stdout as primary output channel.
- JSON output enables machine parsing and diffing in later scripts.

## Rollout Plan
- Land Phase 1, verify outputs, then Phase 2, then Phase 3.
- Each phase is reversible by reverting the specific commits.

## Rollback Plan
- Revert to previous tags/commits; keep `full` mode as fallback.

## Risks and Mitigations
- Risk: parity drift across languages.
  - Mitigation: update all four implementations in a single PR and add checklist.
- Risk: output format breakage.
  - Mitigation: keep `--output=text` identical; add explicit acceptance check.
- Risk: performance impact from new branches.
  - Mitigation: keep branch structure minimal, avoid extra allocations.

## Open Questions (Non-blocking)
- Do we want to standardize formatting precision across languages?
- Do we want to add a `--runs-report` or `--samples` alias to align with common benchmarking terminology?

## References
- https://github.com/google/benchmark/blob/main/docs/user_guide.md
- https://bheisler.github.io/criterion.rs/book/user_guide.html
- https://bun.sh/docs/api/gc
