# V: C backend, mutable state, and runtime choices

Read [v/ou_bench.v](../../v/ou_bench.v) and
[the optimization notes](../../v/OPTIMIZATIONS.md). V is the sixth implementation.
Build commands belong in the [README](../../README.md).

## Shared numerical state

Mutable structs hold the mixer, four-word PRNG, and normal spare. V's `mut`
parameters make state updates visible at call sites. Preserve unsigned 32-bit
operations, logical shifts, and widening before the 53-bit uniform combination.

The scalar cached sampler emits one normal per call and retains the other value
from each accepted pair. Spare state persists across odd-length buffers. Paired-fill
helpers preserved this stream but were slower in the measured V builds.

## C backend and configuration

The C backend generates C that a selected C compiler optimizes. Record the V
version, backend compiler, flags, and memory-management configuration. Generated
C is not guaranteed identical to handwritten C.

V supports garbage collection and other memory-management configurations.
There is no general rule that V has no runtime or GC. Its
[official documentation](https://docs.vlang.io/) and
[documentation source](https://github.com/vlang/v/blob/master/doc/docs.md)
describe build options, arrays, unsafe operations, and memory management.

Production mode and inline attributes do not prove every bounds check or call
was removed. Inspect generated C and profiles for a concrete hypothesis.

## Safety and timing boundaries

Validate decimal input and wide seeds before narrowing. Check counts before
allocation and distinguish parsing errors from unavailable memory.

Only noise-buffer stores use narrow unsafe blocks. The surrounding `0 .. n-1`
loop traverses exactly the allocated noise-buffer indices. The buffer does not
resize during filling. Sampling and other array accesses remain outside those
blocks.

Generated C inspection found general array setters in the checked-fill
candidate. The scoped stores avoid that path while other array access remains
ordinary. This is a specific tradeoff, not a reason to wrap entire loops or the
benchmark in unsafe blocks. It requires numeric regression checks and sanitizer
validation; their completion belongs in the
[run record](../Run-Record-2026-10-02.md).

All modes retain separate checksum reads and timing stages. Keep parsing,
allocation, warmup, and prefill outside measured computation. Memory reuse
reduces application allocations but does not establish zero runtime activity.

## Practice

- Trace one mutable state update and compare it with C.
- Inspect generated C for one hot function and the chosen backend flags.
- Verify odd-tail carry across two fills.
- Compare labeled memory-management configurations only after correctness checks.
- Explain why a percentage gap from C requires measured evidence.

Previous language: [Swift](08-swift-implementation.md).
Next: [Methodology](09-benchmarking-methodology.md).
