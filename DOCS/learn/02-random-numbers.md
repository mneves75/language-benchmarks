# Chapter 2: Deterministic random numbers

A pseudorandom generator is a state machine. The same initial state and call
sequence produce the same integer stream. This avoids comparing different random
libraries while comparing languages.

The repository expands seeds with a SplitMix32-style mixer, then uses the
four-word recurrence from Marsaglia's
[Xorshift RNGs](https://www.jstatsoft.org/article/view/v008i14).
These are workload choices, not cryptographic generators or a certification of
quality for arbitrary scientific simulations.

## Seed expansion

The CLI accepts a decimal unsigned 64-bit seed. Its effective value is
`seed mod 2^32`. Parse exactly before reducing it; a JavaScript `number`
cannot represent every 64-bit integer exactly.

Initialize mixer state `s` from the effective seed, then repeat four times:

```text
s = s + 0x9E3779B9                 (mod 2^32)
z = (s xor (s >> 16)) * 0x85EBCA6B (mod 2^32)
z = (z xor (z >> 13)) * 0xC2B2AE35 (mod 2^32)
return z xor (z >> 16)
```

The four outputs initialize `x,y,z,w`. If all are zero, set `w=1`:
an all-zero xorshift state cannot escape zero.

In C, unsigned overflow wraps; signed overflow has different rules. Rust, Zig,
and Swift use explicit wrapping operations for the mixer.

## Xorshift128

```text
t = x xor (x << 11)       (keep low 32 bits)
x = y
y = z
z = w
w = w xor (w >> 19) xor t xor (t >> 8)
return w
```

Right shifts are logical. JavaScript requires `>>>` rather than the
sign-extending `>>`. Parallel calls on one state change the sequence or
create a race. Separate seeds alone do not establish independent streams.

## 53-bit uniforms

Each uniform consumes two outputs:

```text
hi = next_u32() >> 5      // 27 bits
lo = next_u32() >> 6      // 26 bits
k = hi * 2^26 + lo
U = k / 2^53
```

The maximum `k` is `2^53-1`, so `U<1`; zero is possible.
The combination is exactly representable in binary64. It does not establish
perfect statistical uniformity of the underlying deterministic stream.

JavaScript uses multiplication by `2^26` for this combination: number
bitwise shifts would truncate it to 32 bits. For mixer multiplication,
`Math.imul` returns the low 32-bit product, as defined by the
[ECMAScript specification](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-math.imul).

## Verification

Exact integer vectors detect shifts, wrapping, and seed-expansion mistakes.
Uniform endpoint checks detect conversion errors. Numeric CLI reference checks
also detect integration and reset errors. Histograms reveal some gross problems
but can hide a wrong deterministic stream.

Timed state restarts after warmup and continues across runs, including the normal
sampler's spare. Do not reset on every timed iteration.

## Practice

- Implement the mixer in Python with explicit `& 0xffffffff` masks.
- Trace two xorshift updates without overwriting state too early.
- Explain why seeds `1` and `4294967297` have the same effective seed.
- Explain why `18446744073709551615` requires exact parsing.
- Compute the largest possible uniform and show that it is below one.

Previous: [OU process](01-ou-process.md).
Next: [Normal sampling](03-normal-distribution.md).
