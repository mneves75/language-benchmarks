# Chapter 5: Zig — explicit resource and error handling

Read [zig/ou_bench.zig](../../zig/ou_bench.zig) beside the
[README build commands](../../README.md). This modernization targets Zig 0.16
and its `std.process.Init`/`std.Io` APIs. The exact compiler version remains part
of the run record.

## Wrapping arithmetic

The seed mixer requires modular arithmetic:

```zig
self.s +%= 0x9E37_79B9;
z = (z ^ (z >> 16)) *% 0x85EB_CA6B;
```

`+%` and `*%` make wrapping deliberate. Ordinary arithmetic has different
overflow behavior depending on build mode. This is not evidence that C unsigned
arithmetic is undefined: it also wraps.

## Errors and cleanup

A return type `!Args` represents either arguments or an error.
`try` propagates failures; `catch` handles them. Validate complete decimal
input and range before converting allocation counts.

An allocator owns allocated storage. Register `defer allocator.free(buffer)`
after acquiring it so cleanup occurs on normal and error returns.
Slices carry a pointer and length; `const` on a slice binding does not
necessarily make its elements immutable.

Avoid copying the state while sampling: the PRNG and spare cache must advance
together across fills.

## Build mode is part of the result

The benchmark uses an optimized ReleaseFast build with strict floating-point
semantics. ReleaseFast disables many runtime safety checks; it is not a
memory-safety guarantee. Floating-point mode is a separate choice: strict
mode constrains transformations, while optimized builds can still remove
redundant checks and inline code.

The [Zig 0.16 language reference](https://ziglang.org/documentation/0.16.0/)
documents wrapping operations, error unions, `defer`, build modes, and
`@setFloatMode`. Use the versioned reference matching the compiler in the run
record when checking API compatibility.

## Hot loops

Pair filling consumes an existing spare first, writes accepted pairs, and retains
a trailing spare. The recurrence stores each scalar update. Keep checksum
reading and phase timing separate.

The fill helper is declared `inline fn`. An out-of-line candidate regressed
generation performance in local comparison, so this is a measured implementation
choice rather than a rule to inline every function. Zig's `inline fn` has
stronger semantics than a C inline hint; inspect the versioned language reference
and [run record](../Run-Record-2026-10-02.md).

Zig's ability to expose explicit low-level operations does not by itself prove
an implementation faster than C or Rust. Check the measured artifact.

The implementation obtains elapsed timestamps through the monotonic `.awake`
clock supplied by `std.Io`. Do not substitute an old wall-clock timestamp API
because its integer output also happens to use nanosecond units.

## Practice

- Compare ReleaseSafe with ReleaseFast as separately labeled configurations.
- Trace the distinction between `const slice` and read-only elements.
- Create an invalid index in a disposable example and observe safety-mode behavior.
- Inspect whether the timer API is monotonic in the compiler version being used.
- Verify JSON reaches stdout while diagnostics reach stderr.

Previous: [C](04-c-implementation.md).
Next: [Rust](06-rust-implementation.md).
