# Chapter 8: Swift — value state and buffer lifetimes

Read [swift/ou_bench.swift](../../swift/ou_bench.swift). The canonical
[README](../../README.md) defines the optimized build and verification commands.

## Mutating state and explicit wrapping

The PRNG and normal sampler use structs. A `mutating` method changes the
stored state; `inout` passes mutation through a parameter.

The seed mixer uses `&+` and `&*` to wrap intentionally. Ordinary addition
and multiplication have overflow checks. The
[Swift advanced-operators guide](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/)
explains the wrapping operators.

Parse decimal input into the required wide unsigned type before reducing the
seed to `UInt32`. Avoid force-unwrapping an invalid conversion.

## Array ownership and buffers

Swift arrays have value semantics and copy-on-write storage. Mutating a uniquely
owned array can use existing storage; sharing it and then mutating can require
a copy. That does not mean every indexed write copies an array.

The implementation borrows buffer pointers to expose contiguous storage to its
hot loops. They remain inside their borrowing closures; every index must stay within
the validated count. They should not escape or outlive the array.

Allocate path, noise, and timing storage before timed computation. Preserve the
`n-1` noise length, `n` path length, scalar recurrence, ordered checksum,
and spare state across fills.

The [Swift Array documentation](https://developer.apple.com/documentation/swift/array)
describes value semantics, storage sharing, and buffer access.

## Optimize while retaining checks

The default build uses `-O` and whole-module optimization. It does not use
`-Ounchecked`. Removing runtime checks is a separate safety contract and
must not be mixed silently into the default comparison.

Whole-module optimization lets the compiler reason across declarations. It
does not establish which checks or calls remain in the final executable.

Use `DispatchTime.now().uptimeNanoseconds` for elapsed intervals. Nanosecond
representation does not prove nanosecond measurement accuracy.

## Avoid unsupported explanations

A slower Swift result does not by itself prove ARC overhead, protocol dispatch,
copy-on-write, or bounds checks caused it. This workload uses concrete numeric
state. Inspect profiles and generated code before assigning causality.

Likewise, Swift being compiled ahead of time does not guarantee it will beat
a JIT runtime on this workload.

## Practice

- Explain why `mutating` is needed for the sampler's spare flag.
- Trace wrapping at `UInt32.max`.
- Show array copy-on-write in a separate tiny program.
- Compare safe indexed loops with scoped buffer access after numeric checks.
- Profile an optimized build and distinguish evidence from hypotheses.

Previous: [TypeScript/Bun](07-typescript-bun.md).
Next language: [V](11-v-implementation.md).
Then: [Methodology](09-benchmarking-methodology.md).
