# V implementation: optimization contract

The V implementation uses the same SplitMix32/xorshift128, 53-bit uniforms,
Marsaglia polar sample order, and scalar Euler workload as the other five
languages. Build commands and effective flags belong in the
[root README](../README.md) and shared build script.

## Changes that preserve the workload

- Retain the scalar cached sampler; paired-fill helpers regressed measured generation.
- Preserve the unscaled spare across every call and odd-length buffer.
- Keep noise/path buffers allocated before measured computation and reused.
- Keep the scalar OU state in a local variable while storing every path point.
- Read the stored buffer in a separate ordered checksum stage.
- Validate decimal integers, exact wide seeds, and count/allocation ranges before
  entering the benchmark.
- Use narrow unsafe blocks only around normal-buffer stores with loop-proven
  indices, preserving ordinary array access elsewhere.

The scalar sampler already caches the second normal. Pair filling did not reduce
expensive math calls and was rejected after measurement.

## Backend and build policy

The default optimized C-backend build avoids fast-math. The selected C compiler,
V version, optimization flags, native CPU targeting, and memory-management
configuration are part of the measured artifact.

V generates C, but generated code is not guaranteed identical to handwritten C.
Inlining annotations and production mode do not prove all calls or bounds checks
disappear. Inspect generated C or assembly to answer those questions.

V supports GC and alternative memory-management configurations. The former claim
that V has no GC or runtime was incorrect. See the
[official V documentation](https://docs.vlang.io/) and
[its source](https://github.com/vlang/v/blob/master/doc/docs.md).

## Safety and floating point

Generated C inspection showed general array setters in the fully checked fill
candidate. The selected scalar loops restrict unchecked access to `gn[i]` stores.
Each loop traverses `0 .. n-1`, exactly the valid indices of the fixed-size noise
buffer. The buffer cannot resize during filling. Both checked and narrowly
unchecked paired-fill helpers were measured and rejected.

Other array access remains ordinary. This scoped choice avoids broad unsafe
loops and keeps its proof local. It requires real CLI numeric checks for small
cases, modes, odd/even tails, and sanitizer validation. Completed validation and
measurements belong in the run record; source inspection alone does not prove
runtime safety.

Fast-math can change numerical assumptions and operation ordering. It is a
separate configuration, not a small precision adjustment to mix into the default
comparison. GCC's
[optimization documentation](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)
describes those effects.

Native CPU targeting also limits portability of generated executables.
Application buffer reuse does not prove that runtime or GC activity is absent.

## Evidence

No fixed gap from C is promised. Compare repeated runs on the same machine,
parameters, mode, and compatible flags after numeric verification. Current
observations belong in [the 2026 run record](../DOCS/Run-Record-2026-10-02.md).
Historical measurements are not proof of current performance.

For a guided source walkthrough, see
[the V learning chapter](../DOCS/learn/11-v-implementation.md).
