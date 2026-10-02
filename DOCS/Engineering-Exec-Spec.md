# Engineering specification: six-language OU parity

This document defines the numerical and measurement contract for the 1.4.0
modernization. Build commands and CLI limits belong in the [README](../README.md).
Verification results and measured observations belong in
[the 2026 run record](Run-Record-2026-10-02.md); this specification does not
itself assert that acceptance checks passed.

## Goal and scope

Maintain one workload across C, Zig, Rust, TypeScript/Bun, Swift, and V while
improving hot-loop structure, CLI validation, reproducibility, and documentation.

Do not replace the PRNG, normal sampler, Euler recurrence, time grid, checksum
traversal, or timing boundaries. Exact transitions, alternate distributions,
parallel paths, and SIMD/GPU variants require separately named experiments.

## Numerical invariants

- Expand the effective 32-bit seed using the existing SplitMix32 constants and
  unsigned wrapping; initialize four xorshift128 words in order.
- Preserve the xorshift128 shifts `11,19,8` and logical right shifts.
- Construct each 53-bit uniform from two successive words, with 27 and 26 retained
  bits, in `[0,1)`.
- Accept Marsaglia polar points only when `0<s<1`; emit the first coordinate
  before the second and preserve unscaled spare state.
- Use `theta=1`, `mu=0`, `sigma=0.1`, `X[0]=0`, and `dt=1/n`.
  Store `n` points from `n-1` updates; final time is `(n-1)/n`.
- Preserve scalar recurrence and ordered checksum summation.
- Restart stochastic state after warmup; continue it across timed generation runs.

Identical integer streams are required. Cross-language bit-identical
floating-point results are not a general promise; compare against the independent
reference with documented tolerance and investigate unexplained drift.

## Optimization decision

Rust, Zig, TypeScript, and Swift fill normals in pairs while retaining an
incoming spare and an odd trailing spare. This preserves the cached scalar stream
and removes some calls and branches. It does not reduce logarithm/square-root
count relative to cached scalar sampling. C and V retain scalar cached loops
because paired-fill candidates slowed generation under matched build policy.

Zig explicitly inlines the fill helper to avoid an observed helper-call
regression. V uses narrow unsafe blocks only around normal-buffer stores inside
`0 .. n-1` loops. That range is exactly the fixed-size buffer's index range.
Other array accesses remain ordinary.
Generated C inspection showed general array setters in the fully checked fill;
numeric checks and sanitizer validation are required for the scoped alternative.

Use storage and loop structure appropriate to each language, including typed
numeric buffers in TypeScript. Allocate once outside measured work and reuse.
Do not fuse checksum with simulation or silently relax floating-point semantics.

Rejected local candidates include paired filling in C and V, including both
checked and narrowly unchecked V pair-fill helpers. They preserve the workload but were less suitable after measured
regressions and generated-C inspection. The run record owns the comparison
parameters, final repeated measurements, and validation outcomes.

Replacing the sampler or parallelizing paths is a different alternative: it may
improve throughput but changes the workload or seeded sequence, so it cannot
satisfy parity acceptance here.

## CLI and runner

All implementations accept the same `--key=value` flags:
`n`, `runs`, `warmup`, `seed`, `mode`, and `output`.
Require nonempty decimal digits for integers, enforce documented bounds before
narrowing/allocation, and reject unknown arguments.

The shared count ceiling is `2147483647`, matching V's signed 32-bit count
representation. Minima are `n>=2`, `runs>=1`, and `warmup>=0`. These limits do
not promise that every accepted request fits available memory or completes
quickly. Repeated recognized keys use the last value.

Seeds accept the full unsigned 64-bit decimal range, then reduce modulo
`2^32`. TypeScript must not route the unreduced seed through Number.

The shared build script owns default optimized flags. Defaults avoid C/V
fast-math and Swift unchecked optimization; Zig retains strict float semantics
in ReleaseFast. This does not imply equivalent runtime safety across languages.

The runner resolves paths from its own location. JSON mode emits one object per
language on stdout, six JSON Lines records total. Build diagnostics go to stderr.
Failures return nonzero rather than creating a partial successful-looking result.

## Timing contract

| Mode | Timed stages | Setup |
|---|---|---|
| `full` | Generate, simulate, checksum path | Allocate and warm up |
| `gn` | Generate, checksum noise | Allocate and warm up |
| `ou` | Simulate, checksum path | Allocate, prefill once, warm up |

Argument parsing, allocation, warmup, timing-sample sorting, and formatting remain
outside timed computation. Output retains configuration, total seconds,
average/median/min/max milliseconds, aggregate phase seconds, and checksum.
Do not claim percentile or per-iteration output that is not provided.

## Observable acceptance

Run the real-entry-point Python checks described in the README. They must cover
all six implementations, all modes, independent numeric reference, odd/even
noise counts, seed boundaries, warmup reset, JSON/text output, malformed input,
overflow/range rejection, and script behavior outside the root directory.

The regression evidence must include a failing control before implementation,
final successful checks, and a negative control proving validation can fail.
Do not substitute a checksum spot check for this matrix.

Record exact toolchains, flags, parameters, Git identity, raw results, and
repeated baseline/candidate measurements. No performance improvement is required
by language reputation or inferred solely from cleaner source.

Complete the requested independent review and verification before delivery.
Keep failures and unrun checks explicit in the evidence record.

## Measurement limits

Fixed execution order, thermal drift, JIT state, math libraries, native CPU
features, timer overhead, and runtime allocation can affect results. Do not
compare historical fast-math/unchecked artifacts with strict candidates and
attribute the entire gap to a source optimization.

The [methodology chapter](learn/09-benchmarking-methodology.md) explains these
limits. The [2025 record](Run-Record-2025-12-19.md) remains historical.
