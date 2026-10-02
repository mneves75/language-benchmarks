# Chapter 10: Exercises with observable acceptance

Work in a disposable copy or branch for algorithm experiments. Keep benchmark
changes aligned across all six languages. Start with a failing check, then make
the smallest change that satisfies it.

The examples below are projects to build, not implemented features or measured
results. Build and CLI commands belong in the [README](../../README.md).

## Foundations

### 1. Trace the integer stream

Implement SplitMix32 and xorshift128 in a small Python reference using explicit
32-bit masks. Print the first few words for selected seeds.

Acceptance: exact integer agreement with the repository recurrence; an altered
shift must fail comparison. Explain why a logical right shift matters.

### 2. Check paired normal carry

Implement both scalar cached sampling and paired filling over the same PRNG.

Acceptance: concatenated fills of lengths `1,2,3,4` match one scalar stream.
Include an incoming spare and an odd tail. Deliberately drop the spare and show
that the test fails. Check sample order before checking distributions.

### 3. Trace the time grid

Use `n=4` with known scaled noise and compute each Euler update by hand.

Acceptance: four points at `0,0.25,0.5,0.75`, three noise values, and an ordered
checksum. A version using `dt=1/(n-1)` must fail the reference.

### 4. Validate CLI behavior

Run each executable with small valid cases, then malformed values, unknown keys,
negative counts, invalid modes, oversized integers, and wide seeds.

Acceptance: valid results parse with the documented schema. Invalid commands
exit nonzero, explain the error on stderr, and do not emit a benchmark result.
Wide seeds reduce exactly modulo `2^32`.

### 5. Separate statistical and deterministic checks

Generate samples in a teaching program and estimate mean, variance, and a
histogram. Document the sample count and seeds.

Acceptance: explain sampling variation and false positives. A single p-value
above 0.05 does not establish distribution correctness; a low value does not
automatically prove broken code. Exact parity tests and statistical diagnostics
answer different questions.

## Measurement projects

### 6. Parse six-language JSON Lines

Read runner output one line at a time and check unique language records and
matching parameters. Build a comparison table using `median_ms`.

Acceptance: reject duplicate languages, missing records, incompatible modes, and
non-finite values. Keep raw records and commands. Do not expect nonexistent
per-iteration arrays or percentile fields.

### 7. Compare one optimization

Select a small change, such as scalar calls versus paired filling or a loop
structure that may remove redundant bounds checks.

Acceptance: numeric checks pass before timing. Record compiler flags and repeated
fresh-process measurements for baseline and candidate. Report unfavorable as
well as favorable observations. Do not promise a speedup.

### 8. Investigate size and warmup

Vary `n` and warmup with fixed mode and seed, repeating fresh processes.
Plot process medians and phase totals.

Acceptance: label `n` as stored points. Explain that memory footprint, timer
overhead, cache behavior, JIT tiers, and thermal conditions may affect scaling.
Warmup changes must leave the timed checksum invariant.

### 9. Profile a concrete hotspot

Use a profiler supported by the host and toolchain. Profile optimized code with
suitable symbol information.

Acceptance: identify sampled functions or instructions, state the profiler's
limits, and propose one controlled experiment. A timing gap does not establish
ARC, GC, dispatch, or bounds checks as its cause.

## Separate algorithm experiments

### 10. Exact OU transition

Compare Euler with the exact Gaussian OU transition in a new named experiment.

Acceptance: derive expected mean/variance and quantify discretization error
over an ensemble. Do not claim seeded checksum parity with the Euler workload.

### 11. SIMD or GPU across paths

Process several independent paths, with a documented stream construction and
memory layout. Sequential updates within each path remain dependent.

Acceptance: compare with a scalar implementation of the same multi-path
workload, including transfer and setup costs when relevant. No fixed speedup
target follows from using SIMD or a GPU.

### 12. Alternative PRNG or normal sampler

Implement a specified alternative and document its state, stream, and validation.

Acceptance: give the experiment a distinct name and compare quality and cost
with appropriate evidence. A replacement sampler or PRNG is not a
parity-preserving optimization of this benchmark.

## Explain what you learned

For any exercise, finish with a short explanation:

- What stays invariant?
- What result would falsify correctness?
- What work is timed?
- What did you actually observe?
- What remains uncertain?

A passing check proves only its stated acceptance. A visually plausible path,
a fast median, or one statistical test does not establish the whole system.

Previous: [Methodology](09-benchmarking-methodology.md).
Return to [the learning index](README.md).
