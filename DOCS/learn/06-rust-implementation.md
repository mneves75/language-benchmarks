# Chapter 6: Rust — ownership and optimizable slices

Read [rust/src/main.rs](../../rust/src/main.rs) and
[Cargo.toml](../../rust/Cargo.toml). Use the [README](../../README.md) for build
commands and tests.

## State and ownership

Small structs hold PRNG and sampler state. Methods taking `&mut self`
advance one owned state instead of hiding mutation in globals. A mutable slice
lets a fill routine update a buffer without allocating a replacement.

A vector owns its heap allocation and drops it when its owner leaves scope.
Borrowing prevents conflicting safe references. These guarantees do not
establish correct math, and unsafe code can introduce obligations outside the
compiler's checks. The
[Rust ownership chapter](https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html)
explains the basic model.

The seed mixer uses `wrapping_add` and `wrapping_mul`, whose modular behavior
is explicit even if release overflow checks change. Parse a seed as `u64`
before reducing to `u32`.

## Pair filling without unchecked indexing

The fill routine can use slices, indexed loops, or iteration over pairs.
Readable bounds and loop structure give the optimizer opportunities to remove
redundant checks. Unchecked indexing is not an automatic requirement for fast
code; it needs independent justification and proof of every access.

The incoming spare and odd tail matter even when the loop handles two elements
at a time. Small odd/even cases should be checked before measuring large ones.

## Release configuration

The manifest selects optimization level 3, LTO, one codegen unit, and aborting
panics. The shared build also selects the native CPU. Record both the manifest
and effective build flags.

The [Cargo profile documentation](https://doc.rust-lang.org/cargo/reference/profiles.html)
explains that these settings affect optimization, build cost, and panic
behavior. Higher optimization levels do not guarantee faster execution.

A native CPU build may not run on another CPU. Panic abort is an error-handling
choice, not a blanket numerical optimization. Neither makes unsafe memory access
acceptable.

## Timing and errors

`Instant` represents elapsed-time measurements. Keep parsing, allocation,
warmup, sorting, and serialization out of the measured region. Report errors
explicitly; `unwrap` on untrusted CLI data is not a clear parsing contract.

The same noise/path/storage and ordered checksum obligations apply as in C.

## Practice

- Explain the difference between moving a vector and borrowing a mutable slice.
- Compare a slice loop with an iterator loop after verifying identical results.
- Trace why wrapping arithmetic must not depend on the release profile.
- Compare LTO settings with all other inputs held constant.
- Run the CLI numeric reference and malformed-input cases before profiling.

Previous: [Zig](05-zig-implementation.md).
Next: [TypeScript/Bun](07-typescript-bun.md).
