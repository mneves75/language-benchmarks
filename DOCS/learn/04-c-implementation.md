# Chapter 4: C — explicit arithmetic and memory

Read [c/ou_bench.c](../../c/ou_bench.c). The single translation unit contains
state structs, sampling, CLI parsing, allocation, warmup, timed modes, and output.
Build with the canonical commands in the [README](../../README.md).

C is a useful reference implementation here because its loops and memory
operations are explicit. It is not a universal performance ceiling.

## Integer semantics

The PRNG uses `uint32_t`. Unsigned addition and multiplication wrap modulo
`2^32`; this is required by seed expansion. Signed overflow is not an
equivalent substitute. Uniform construction widens to `uint64_t` before
the 26-bit shift so the 53-bit value is retained.

`static inline` keeps helpers local and permits inlining. It does not guarantee
that every call disappears. Inspect optimized assembly if that matters.

These arithmetic rules are specified by the
[C11 draft, sections 6.2.5 and 6.5](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf).

## Parse before allocating

The CLI requires nonempty decimal digits, valid ranges, and recognized keys.
Convenience conversions such as `atoll` cannot by themselves establish that
the entire input is valid. Validate the grammar and overflow before narrowing.

Allocation sizes require bounds checks before multiplication, including
`n*sizeof(double)` and `runs*sizeof(double)`. A valid integer is not
automatically a feasible allocation. Check allocation results and free owned
buffers on success and failure.

The shared contract uses one noise buffer of `n-1` doubles, one path buffer of
`n` doubles, and timing storage. Allocate outside measured computation and
reuse buffers.

## Hot loops

C retains the scalar cached-normal loop: each call either returns an incoming
spare or generates a pair and retains its second value. Paired-fill candidates
were rejected after slower generation in matched-policy local experiments.
The [run record](../Run-Record-2026-10-02.md) owns parameters and measurements.

OU simulation carries the scalar `x` through the loop and stores every path
point. Checksum summation then reads the stored buffer in order. This preserves
the same sample stream as V's scalar loop and the other languages' paired fills.

The OU recurrence has a dependency on the previous `x`. Ordinary loop
unrolling cannot turn successive steps into independent SIMD lanes. SIMD across
independent paths changes the workload.

Do not fuse checksum into simulation: it changes storage traffic and phase
boundaries. Do not reassociate the sum for this benchmark.

## Optimization and timing

The default optimized build excludes fast-math. GCC documents that
[`-ffast-math` enables assumptions that can change numerical behavior](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html).
A faster run with those assumptions is a separate configuration.

The implementation uses `CLOCK_MONOTONIC` elapsed timing. Nanosecond units do
not imply nanosecond accuracy or negligible timer cost. See the
[POSIX clock specification](https://pubs.opengroup.org/onlinepubs/9799919799/functions/clock_gettime.html).

## Practice

- Trace unsigned wrapping at `UINT32_MAX`; compare it with signed overflow rules.
- Run malformed CLI inputs and assert nonzero exit, stderr diagnostics, and no result.
- Compare optimization levels with identical flags otherwise, after correctness checks.
- Profile the optimized executable; do not infer hotspots from source line counts.

Previous: [Normal sampling](03-normal-distribution.md).
Next: [Zig](05-zig-implementation.md).
