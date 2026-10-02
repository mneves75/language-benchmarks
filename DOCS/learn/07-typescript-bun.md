# Chapter 7: TypeScript on Bun — numbers and storage

Read [ts/ou_bench.ts](../../ts/ou_bench.ts). TypeScript annotations help check
source; Bun executes JavaScript semantics. Use the [README](../../README.md)
for the current run command.

## Two numeric domains

PRNG arithmetic needs 32-bit modular integers. The OU update needs binary64
floating-point values.

JavaScript number bitwise operators convert to 32-bit integers. `>>>` shifts
logically and `>>>0` exposes the unsigned representation. `Math.imul`
preserves the low 32 bits of multiplication without first forming a potentially
inexact large floating-point product.

```typescript
z = Math.imul(z ^ (z >>> 16), 0x85ebca6b);
const unsigned = z >>> 0;
```

Bitwise XOR already applies integer conversion; adding `|0` is not
universally necessary or automatically faster. Preserve logical right shifts
and prove integer vectors.

A 53-bit uniform combines high and low parts with multiplication and addition,
not a 32-bit left shift.

The [ECMAScript specification for Math.imul](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-math.imul)
defines low-word multiplication. Its
[Number semantics](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-ecmascript-language-types-number-type)
explain the binary64 representation.

## Parse 64-bit seeds exactly

Validate decimal digits, parse using `BigInt`, enforce the unsigned 64-bit
limit, reduce modulo `2^32`, then convert the reduced value to a number.
Converting the full seed with `Number` first loses information above its
exact-integer range.

For example, `4294967297` reduces to one. Boundary tests also include
`18446744073709551615`; this value must not be rounded before reduction.

## Typed buffers

`Float64Array` gives contiguous binary64 element storage with a fixed length.
Create the noise and path buffers before timing and reuse them. Bun's
[binary-data documentation](https://bun.sh/docs/runtime/binary-data)
describes JavaScript typed-array storage and views.

This change does not guarantee a speedup on every runtime. Benchmark the actual
engine and version. Avoid temporary pair arrays or objects in the hot fill loop.

## JIT and garbage collection

Bun uses JavaScriptCore. Warmup may change optimization tier, but a fixed number
of warmup runs does not prove steady state. A pre-run garbage collection does
not prevent later GC or allocation within the runtime.

Use `performance.now()` for elapsed milliseconds; units do not guarantee a
fixed microsecond resolution. Keep setup and output outside measured computation.

Do not attribute an observed gap to type checks, GC, or integer conversions
without profiles or controlled experiments. Bun/Node performance comparisons
require measuring both; they are not consequences of runtime names.

## Practice

- Replace one logical shift with a signed shift in a disposable copy; find a seed
  that makes the reference check fail.
- Compare exact BigInt seed parsing with a Number-first conversion at boundaries.
- Compare ordinary arrays and typed arrays with identical sample order.
- Vary warmup across fresh processes; record timings and invariant checksums.

Previous: [Rust](06-rust-implementation.md).
Next: [Swift](08-swift-implementation.md).
