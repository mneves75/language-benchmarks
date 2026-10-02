# Chapter 9: Measuring performance with explicit limits

A useful result identifies the artifact, input, machine, timer, flags, and
measurement boundaries. It also separates correctness checks from performance
observations.

Matching algorithms improves comparability. It does not isolate a universal
property called language speed: compiler, library, runtime, storage, and hardware
all contribute.

## What is measured

| Mode | Generation | Simulation | Checksum |
|---|---|---|---|
| `full` | Timed | Timed | Timed over path |
| `gn` | Timed | Absent | Timed over scaled noise |
| `ou` | Prefilled outside timing | Timed | Timed over path |

Parsing, buffer allocation, warmup, timing-sample sorting, and output formatting
are excluded. The buffers are reused. RNG and sampler restart after warmup,
then continue across timed `full`/`gn` runs. `ou` reuses one noise buffer.

`n` means stored points, not update count. There are `n-1` updates at
`dt=1/n`. Record mode and parameters before comparing records.

## Output schema and units

Each implementation emits one object in JSON mode:

- `language`, `mode`, `n`, `runs`, `warmup`, and effective `seed`
  identify the configuration.
- `total_s` is aggregate timed duration in seconds.
- `avg_ms`, `median_ms`, `min_ms`, and `max_ms` summarize per-run
  total duration in milliseconds.
- `breakdown_s` contains aggregate `gen_normals`, `simulate`, and
  `checksum` durations in seconds.
- `checksum` is the accumulated result across timed runs.

The runner emits six JSON Lines records. Build diagnostics go to stderr.
There are no per-iteration timing arrays, percentiles, standard deviations, or
confidence intervals in this schema. Do not write an analysis that reads
invented `all_times` or `p95` fields.

A histogram of individual iterations requires a separately instrumented run.
A histogram of repeated process medians describes process-level summaries.

## Correctness before speed

Run the real CLI suite described in the [README](../../README.md). It checks
an independent numeric reference, modes, seed boundaries, malformed input,
odd/even noise counts, and warmup reset.

A deterministic checksum helps detect drift but can miss compensating errors.
Negative controls must demonstrate that a corrupted implementation or invalid
record is rejected. Timing values alone cannot show the right work ran.

Cross-language rounding can differ because math libraries and compiler
contraction behavior differ. This does not excuse a different integer stream,
sample order, Euler step, or checksum traversal.

## A repeatable experiment

1. Record the Git revision, hardware, OS, exact toolchain versions, and effective
   build flags, following the [run record](../Run-Record-2026-10-02.md).
2. Build outside timing and verify correctness.
3. Run sequentially on the same machine, with the same parameters and mode.
4. Repeat in fresh processes; alternate baseline/candidate order where practical.
5. Preserve raw JSONL and stderr with exit status.
6. Compare only matching metadata and inspect variability before claiming a gain.

The [2026 record](../Run-Record-2026-10-02.md) holds modernization evidence.
The [2025 record](../Run-Record-2025-12-19.md) remains historical; changed flags
and artifacts can make its ranking unsuitable as a current baseline.

The [comparison helper](../scripts/compare_runs.sh) is an analysis aid, not a
substitute for checking parameters and successful exits.

## Statistics without false certainty

The mean responds to slow outliers; the median describes the middle observed
iteration. Report both when relevant. Neither should hide real pauses. Minimum
is a best observation, not typical throughput; maximum is sample-dependent.

Five warmup runs do not prove steady-state JIT optimization or a stable CPU
frequency. One thousand correlated iterations are not one thousand independent
experiments. Thermal drift and fixed execution order can bias comparisons.

There is no universal percentage below which a difference is noise. A large gap
can also come from wrong flags, workloads, or timings. Use repeated process
measurements and predeclared criteria.

Do not apply `1.96*stddev/sqrt(n)` to claim a confidence interval for a median.
Confidence procedures depend on the statistic, sampling assumptions, and data.
This harness provides summaries, not statistical inference.

The [Google Benchmark user guide](https://github.com/google/benchmark/blob/main/docs/user_guide.md)
discusses repetitions, aggregates, and making work observable. Its framework
features are methodological references; this project does not use that framework.

## Compiler and timer caveats

The default build policy avoids fast-math and Swift unchecked optimization.
Zig ReleaseFast still disables many runtime safety checks; strict float mode is
a separate property. Do not describe all languages as having equal safety checks.

A checksum makes results observable but is not a general optimization barrier.
Investigate suspicious timings with profiles or generated code.

A timer's units are not its resolution or accuracy. Tiny cases are useful for
correctness but can be dominated by timestamp overhead. Timed setup excludes
application allocation; it cannot guarantee no GC, page faults, or runtime work.

## Practice

- Compare fresh-process runs with warmup zero and five; checksums must agree.
- Compare mode breakdowns without subtracting medians from different processes
  and treating the difference as an exact phase cost.
- Measure repeated baseline/candidate pairs and report raw ranges.
- Write a claim with its configuration and uncertainty instead of a universal
  language ranking.

Previous language: [V](11-v-implementation.md).
Next: [Exercises](10-exercises-projects.md).
