# Chapter 0: What the benchmark measures

The project runs one scalar stochastic workload in six languages: C, Zig, Rust,
TypeScript on Bun, Swift, and V. It compares concrete implementations on a
recorded machine and toolchain configuration.

Think of the implementations as following the same recipe. Matching the recipe
helps, but equipment and execution still matter. One recipe cannot rank every
language for every application.

## The pipeline

1. Expand the seed into four 32-bit PRNG state words.
2. Generate uniforms and transform them into normal samples.
3. Scale normals into noise increments.
4. Store a path using the Euler approximation of the OU process.
5. Sum stored values and report the checksum and timings.

The algorithms are SplitMix32, xorshift128, Marsaglia polar, and Euler–Maruyama.
The next three chapters explain them.

| Mode | Timed computation | Checksum reads |
|---|---|---|
| `full` | Normal generation, OU simulation, checksum | OU path |
| `gn` | Normal generation, checksum | Scaled noise |
| `ou` | OU simulation, checksum; noise prefilled outside timing | OU path |

The checksum is timed in every mode. `gn` therefore does not measure only the
sampler. `ou` repeatedly uses the same prefilled noise and path.

CLI parsing, allocation, warmup, sorting timing samples, and final output are
outside the measured computation. Warmup uses separate random state. Timed
generation restarts from the requested seed, then continues across runs.
Increasing warmup should not change the timed checksum.

## First run

From the repository root:

```bash
./run_all.sh 1000 3 1 42 full json
```

JSON mode emits six objects, one per line on stdout, with build messages on
stderr. It is JSON Lines, not one JSON array. The [README](../../README.md)
defines prerequisites, individual commands, numeric limits, and CLI tests.

Integer values require decimal digits. The count ceiling is `2147483647`, with
`n>=2`, `runs>=1`, and `warmup>=0`. The seed ceiling is
`18446744073709551615`; its effective value is reduced modulo `2^32`.
Repeated recognized keys use the last value. Accepted counts can still exceed
available memory or require an impractically long run.

Use small inputs to learn the output. Use documented repeated experiments to
measure performance; default runs can be much more expensive.

## Interpretation

`n` counts stored points, including the initial zero. There are `n-1` updates
and noise increments. With `dt=1/n`, the final time is `(n-1)/n`.

Output reports aggregate seconds, per-run milliseconds, and phase totals.
The printed checksum makes results observable and helps detect regressions.
It cannot prove every sample correct or prevent every compiler transformation.
Use the independent numeric reference and negative controls in CLI tests.

Small floating-point differences can occur across languages. A changed PRNG
word, sample order, mode, or time step is a correctness issue, not rounding noise.

Practice: explain the pipeline without language names. Predict which mode
changes when normal generation improves, then inspect phase measurements.

Next: [The OU process](01-ou-process.md).
