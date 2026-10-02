# Chapter 3: Normal sampling and paired fills

The OU recurrence needs standard normal samples, with mean zero and variance
one. The benchmark uses Marsaglia polar rejection sampling.

Imagine throwing uniform points into a square around a unit circle. Keep points
inside the circle, reject the center, then scale accepted coordinates into a pair.

## Transform

```text
u = 2 * uniform() - 1
v = 2 * uniform() - 1
s = u*u + v*v
reject unless 0 < s < 1
m = sqrt((-2 * log(s)) / s)
z0 = u * m
z1 = v * m
```

Rejecting zero avoids division by zero and the logarithm of zero. Rejecting
`s>=1` enforces the domain. Do not clamp or reuse rejected points.

For independent continuous uniforms, acceptance probability is the area ratio
`pi/4`. Finite pseudorandom input approximates that model. This probability
is not a measured cycle count or speedup.

Marsaglia and Bray describe the transform in
[A Convenient Method for Generating Normal Variables](https://doi.org/10.1137/1006063).
It avoids the explicit trigonometric calls of basic Box–Muller. Which sampler is
faster on a particular machine requires measurement.

## Spare state and direct pairs

The scalar sampler returns `z0` and caches `z1`. Its next call returns the
spare without new uniform draws. The cache is part of the stochastic state and
persists across fills and timed runs.

The paired fills used by Rust, Zig, TypeScript, and Swift preserve this
exact stream. C and V retain their scalar cached samplers after paired-fill experiments
regressed generation performance under matched build policy.

The paired algorithm is:

1. Emit an incoming spare first, then clear its flag.
2. Generate pairs while at least two slots remain; write `diff*z0` then
   `diff*z1`.
3. For a final single slot, write `diff*z0` and cache the unscaled `z1`.

Compute each standard normal before diffusion scaling, in the original order.
Reordering multiplications can change rounding.

A fill of three emits `z0,z1,z2` and retains `z3`. The next fill must start
with `z3`. Discarding it shifts all later samples.

## What improves

Pair filling avoids alternating scalar calls for the two outputs and some
spare-flag checks. It uses the same accepted points, logarithms, square roots,
and sample order. Compiler inlining determines what calls remain in the artifact.

It does not halve logarithm work relative to the old cached scalar sampler:
that sampler already produced a pair per acceptance. Any improvement comes from
control flow and compiler behavior and must be measured.

The C and V decisions demonstrate that a cleaner pair loop need not be faster. Zig's
fill helper is explicitly inline to avoid a measured helper-call regression.
See the [run record](../Run-Record-2026-10-02.md) for experiment configurations
and final measurements rather than transferring one language's result to another.

Ziggurat or library distributions change the stream and workload. Compare them
as separately named experiments.

## Practice

- Trace fills of lengths `1,2,3,4`, with and without an incoming spare.
- Compare one fill of six with two fills of three; the streams must agree.
- Test even and odd `n`; noise length is `n-1`.
- Count rejections in a separate teaching program.
- Estimate sample mean and variance without treating one p-value as a
  deterministic correctness oracle.

Previous: [Random numbers](02-random-numbers.md).
Next: [C](04-c-implementation.md).
