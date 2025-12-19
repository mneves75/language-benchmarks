# Chapter 4: C Implementation - The Baseline

## Why C Is the Baseline

When comparing programming languages for performance, **C is always the reference**. Not because it's always fastest (though it often is), but because:

1. **Close to the metal**: C maps directly to machine instructions with minimal abstraction
2. **Mature optimizers**: 50+ years of compiler development (GCC, Clang, MSVC)
3. **Predictable performance**: What you write is roughly what executes
4. **Industry standard**: Most systems code (Linux, Windows kernel, databases) is written in C

Think of C as the **speed of light** in physics - it's not just a measurement, it's the fundamental constant other measurements are compared against.

In our benchmark:
- **C achieves 3.71 ms average** (median 3.70 ms)
- This sets the bar for all other languages
- Languages within 10% of C are considered "competitive"
- Languages within 3% are considered "equivalent"

Zig (3.82 ms) and Rust (3.85 ms) are both within 4% - essentially equivalent to C for practical purposes.

## The Complete Implementation Structure

Our C implementation is a single file: `c/ou_bench.c` (376 lines). Let's break it down:

```
Lines 1-15:   Header comment and build instructions
Lines 17-24:  Include directives
Lines 26-100: RNG implementation (SplitMix32, XorShift128, Normal)
Lines 102-106: Timing function
Lines 108-126: Data structures and enums
Lines 128-169: Argument parsing
Lines 171-175: qsort comparator
Lines 177-375: main() function
  Lines 180-190: OU parameters
  Lines 192-197: Memory allocation
  Lines 199-243: Warmup phase
  Lines 245-340: Timed runs
  Lines 342-351: Statistics computation
  Lines 353-369: Output
  Lines 371-375: Cleanup and exit
```

Single-file design is intentional - makes it easy to compile, distribute, and understand.

## Include Directives and Portability

From `c/ou_bench.c:17-24`:

```c
#define _POSIX_C_SOURCE 199309L
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
```

### The POSIX Macro

```c
#define _POSIX_C_SOURCE 199309L
```

This enables POSIX features (specifically `clock_gettime()` for high-resolution timing). The value `199309L` corresponds to POSIX.1b (1993) standard.

**Without this**, `clock_gettime()` might not be available, and we'd have to use less precise timing mechanisms.

### Standard Headers

- `<stdint.h>`: Fixed-width integers (`uint32_t`, `uint64_t`)
- `<stddef.h>`: Standard definitions (`size_t`, `NULL`)
- `<stdio.h>`: I/O functions (`printf`, `fprintf`)
- `<stdlib.h>`: Memory allocation (`malloc`, `free`) and conversion (`atoll`, `strtoull`)
- `<string.h>`: String operations (`strcmp`, `strncmp`)
- `<time.h>`: Timing (`clock_gettime`, `struct timespec`)
- `<math.h>`: Math functions (`sqrt`, `log`)

**Build note**: `-lm` flag links the math library. On some systems (Linux), `libm` is separate and must be explicitly linked.

## High-Resolution Timing

From `c/ou_bench.c:102-106`:

```c
static inline uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
```

### Why CLOCK_MONOTONIC?

Linux provides several clock types:

| Clock | Description | Use Case |
|-------|-------------|----------|
| `CLOCK_REALTIME` | Wall-clock time | User-facing timestamps |
| `CLOCK_MONOTONIC` | Monotonic time | Benchmarking |
| `CLOCK_PROCESS_CPUTIME_ID` | CPU time used | Profiling |
| `CLOCK_THREAD_CPUTIME_ID` | Thread CPU time | Thread profiling |

**CLOCK_MONOTONIC** is ideal for benchmarking because:
- ✓ Never goes backward (unlike REALTIME, which can adjust for NTP)
- ✓ Unaffected by system time changes
- ✓ Includes time spent sleeping (unlike CPUTIME, which only counts active CPU time)

### Nanosecond Precision

```c
return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
```

This converts `struct timespec` (seconds + nanoseconds) into a single nanosecond value.

**Range**: With `uint64_t`, we can measure up to:
```
2^64 nanoseconds ≈ 584 years
```

More than sufficient for our benchmark!

**Precision**: Modern CPUs provide nanosecond-resolution timers, but **accuracy** depends on:
- CPU frequency scaling
- Turbo Boost
- Thermal throttling
- Background processes

This is why we run 1000 iterations and use median instead of mean.

## Data Structures and Enums

From `c/ou_bench.c:108-126`:

```c
typedef struct {
    size_t n;
    size_t runs;
    size_t warmup;
    uint32_t seed;
    int mode;
    int output;
} args_t;

enum {
    MODE_FULL = 0,
    MODE_GN = 1,
    MODE_OU = 2
};

enum {
    OUTPUT_TEXT = 0,
    OUTPUT_JSON = 1
};
```

### The args_t Structure

This holds all command-line arguments:

- `n`: Number of simulation points (default 500,000)
- `runs`: Number of timed iterations (default 1,000)
- `warmup`: Number of warmup iterations (default 5)
- `seed`: RNG seed (default 1)
- `mode`: Which stage to benchmark (full/gn/ou)
- `output`: Output format (text/json)

**Design choice**: Using a struct makes it easy to pass all parameters to functions without having many individual parameters.

### Benchmark Modes

Three modes allow isolated benchmarking:

1. **MODE_FULL**: Benchmark all three stages (gen_normals + simulate + checksum)
2. **MODE_GN**: Benchmark only random number generation
3. **MODE_OU**: Benchmark only OU simulation + checksum (pre-generate normals)

This helps identify bottlenecks. For example, if MODE_GN takes 2.5 ms and MODE_FULL takes 3.7 ms, we know:
- RNG: 2.5 ms (68% of time)
- OU + checksum: 1.2 ms (32% of time)

### Output Formats

- **OUTPUT_TEXT**: Human-readable (for terminal display)
- **OUTPUT_JSON**: Machine-readable (for automated analysis)

JSON output example:
```json
{
  "language": "C",
  "mode": "full",
  "n": 500000,
  "runs": 1000,
  "avg_ms": 3.71,
  "median_ms": 3.70,
  ...
}
```

This enables scripting like:
```bash
./ou_bench_c --output=json | jq '.median_ms'
```

## Argument Parsing

From `c/ou_bench.c:128-169`:

```c
static args_t parse_args(int argc, char **argv) {
    args_t a;
    a.n = 500000;        // Default values
    a.runs = 1000;
    a.warmup = 5;
    a.seed = 1;
    a.mode = MODE_FULL;
    a.output = OUTPUT_TEXT;

    for (int i = 1; i < argc; i++) {
        const char *s = argv[i];
        if (strncmp(s, "--n=", 4) == 0) {
            long long v = atoll(s + 4);
            if (v < 2) { fprintf(stderr, "--n must be >= 2\n"); exit(1); }
            a.n = (size_t)v;
        } else if (strncmp(s, "--runs=", 7) == 0) {
            long long v = atoll(s + 7);
            if (v < 1) { fprintf(stderr, "--runs must be >= 1\n"); exit(1); }
            a.runs = (size_t)v;
        }
        // ... (similar for other arguments)
    }

    return a;
}
```

### Why Manual Parsing?

C doesn't have a standard argument parsing library (like Python's `argparse`). Options:

1. **Manual parsing** (our choice) - Simple, no dependencies
2. **getopt** (POSIX standard) - More complex syntax
3. **External library** (e.g., argtable3) - Extra dependency

For a benchmark, minimizing dependencies is critical - we don't want to measure library overhead!

### Argument Format

We use `--name=value` format:
```bash
./ou_bench_c --n=500000 --runs=1000 --seed=1
```

This is simpler than alternatives:
```bash
# Space-separated (requires getopt)
./ou_bench_c --n 500000 --runs 1000

# Short flags (harder to remember)
./ou_bench_c -n 500000 -r 1000
```

### Validation

Each argument is validated:
```c
if (v < 2) { fprintf(stderr, "--n must be >= 2\n"); exit(1); }
```

**Why n >= 2?** Because we allocate `n-1` normals and `n` OU values. With n=1, we'd allocate 0 normals, which doesn't make sense for this simulation.

### Type Conversion

```c
long long v = atoll(s + 4);  // Parse string to long long
a.n = (size_t)v;              // Convert to size_t
```

**Why long long first?** To handle large values (up to 2^63-1) before converting to `size_t`.

**Safety issue**: No overflow check! If user provides `--n=99999999999999999999`, overflow occurs. A production implementation would validate this.

## Memory Allocation Strategy

From `c/ou_bench.c:192-197`:

```c
double *gn = (double*)malloc((n - 1) * sizeof(double));
double *ou = (double*)malloc(n * sizeof(double));
if (!gn || !ou) {
    fprintf(stderr, "allocation failed\n");
    return 1;
}
```

### Why Heap Allocation?

With default `n=500,000`:
- `gn` array: 499,999 × 8 bytes = 3.99 MB
- `ou` array: 500,000 × 8 bytes = 4.00 MB
- **Total**: ~8 MB

Stack allocation (`double gn[500000]`) would:
- ❌ Exceed typical stack size (Linux default: 8 MB)
- ❌ Cause stack overflow
- ❌ Not work for variable `n`

Heap allocation:
- ✓ Supports arbitrary size (limited by RAM)
- ✓ Works for runtime-determined `n`
- ✓ Standard practice for large buffers

### Why (n-1) Normals?

The OU process has `n` points, but only needs `n-1` random values:

```
ou[0] = 0.0        (initial condition, no random value)
ou[1] = a*ou[0] + b + gn[0]
ou[2] = a*ou[1] + b + gn[1]
...
ou[n-1] = a*ou[n-2] + b + gn[n-2]
```

Allocating exactly what we need avoids wasting memory.

### Allocation Outside Timing

**Critical**: Memory allocation happens **before** timing starts. This ensures we're measuring computation, not allocation overhead.

If allocation were inside the timing loop:
```c
// BAD: Measures allocation, not computation
uint64_t t0 = now_ns();
double *ou = malloc(n * sizeof(double));  // Included in timing!
for (...) { ... }
uint64_t t1 = now_ns();
```

Our approach:
```c
// GOOD: Allocation before timing
double *ou = malloc(n * sizeof(double));  // Not timed

uint64_t t0 = now_ns();  // Start timer
for (...) { ... }        // Only this is timed
uint64_t t1 = now_ns();  // Stop timer
```

## The Warmup Phase

From `c/ou_bench.c:208-243`:

```c
// Warmup
{
    xorshift128_t rng = xorshift128_new(args.seed);
    normal_polar_t norm;
    normal_polar_init(&norm);

    for (size_t r = 0; r < args.warmup; r++) {
        double s = 0.0;
        if (args.mode == MODE_FULL) {
            // Generate normals
            for (size_t i = 0; i < n - 1; i++) {
                gn[i] = diff * normal_polar_next(&norm, &rng);
            }
            // Simulate OU
            double x = 0.0;
            ou[0] = x;
            for (size_t i = 1; i < n; i++) {
                x = a * x + b + gn[i - 1];
                ou[i] = x;
            }
            // Checksum
            for (size_t i = 0; i < n; i++) s += ou[i];
        }
        // ... (similar for MODE_GN and MODE_OU)
        if (s == 123456789.0) printf("impossible\n");
    }
}
```

### Why Warmup?

Modern CPUs have multiple performance states:

1. **Cold start**: CPU at low frequency, caches empty
2. **Warmed up**: CPU at turbo frequency, caches hot

First iteration of a benchmark is often 2-5× slower than subsequent iterations due to:
- **Instruction cache misses**: Code not yet in L1/L2 cache
- **Data cache misses**: Arrays not yet cached
- **Branch prediction misses**: CPU learning branch patterns
- **CPU frequency scaling**: Ramping up from idle state

By running 5 warmup iterations (default), we ensure the timed runs measure **steady-state performance**, not cold-start overhead.

### Separate RNG for Warmup

Notice:
```c
// Warmup RNG (inside a block scope)
{
    xorshift128_t rng = xorshift128_new(args.seed);
    normal_polar_t norm;
    normal_polar_init(&norm);
    // ... warmup loops
}  // rng and norm go out of scope

// Timed runs RNG (fresh initialization)
xorshift128_t rng = xorshift128_new(args.seed);
normal_polar_t norm;
normal_polar_init(&norm);
```

This ensures warmup doesn't affect the timed sequence - both start from the same seed.

### The Impossible Check

```c
if (s == 123456789.0) printf("impossible\n");
```

This prevents the compiler from optimizing away the warmup loop. Without it:
```c
// Compiler thinks: "s is never used, skip this work!"
double s = 0.0;
for (...) { s += ou[i]; }
// s goes out of scope, never printed
```

The check says: "We might print s (even though we never will), so you can't eliminate this computation."

This is similar to the checksum in timed runs - forces the compiler to do the work.

## The Timed Benchmark Loop

From `c/ou_bench.c:265-340`:

```c
for (size_t r = 0; r < args.runs; r++) {
    double gen = 0.0;
    double sim = 0.0;
    double chk = 0.0;
    double run = 0.0;

    if (args.mode == MODE_FULL) {
        uint64_t t0 = now_ns();
        // Stage 1: Generate normals
        for (size_t i = 0; i < n - 1; i++) {
            gn[i] = diff * normal_polar_next(&norm, &rng);
        }
        uint64_t t1 = now_ns();

        // Stage 2: Simulate OU
        double x = 0.0;
        ou[0] = x;
        for (size_t i = 1; i < n; i++) {
            x = a * x + b + gn[i - 1];
            ou[i] = x;
        }
        uint64_t t2 = now_ns();

        // Stage 3: Checksum
        double s = 0.0;
        for (size_t i = 0; i < n; i++) s += ou[i];
        checksum += s;
        uint64_t t3 = now_ns();

        gen = (double)(t1 - t0) * 1e-9;  // Convert ns to seconds
        sim = (double)(t2 - t1) * 1e-9;
        chk = (double)(t3 - t2) * 1e-9;
        run = (double)(t3 - t0) * 1e-9;
    }
    // ... (similar for MODE_GN and MODE_OU)

    total_gen_s += gen;
    total_sim_s += sim;
    total_chk_s += chk;
    total_s += run;
    run_times[r] = run;

    if (run < min_s) min_s = run;
    if (run > max_s) max_s = run;
}
```

### Three Timing Points

We measure each stage separately:

```
t0 ──────> t1 ──────> t2 ──────> t3
   gen_normals  simulate  checksum
```

This breakdown helps identify bottlenecks:

| Stage | Work | Typical % |
|-------|------|-----------|
| gen_normals | RNG + normal sampling | ~70% |
| simulate | OU formula | ~20% |
| checksum | Array summation | ~10% |

### Timing Overhead

Each call to `now_ns()` takes ~20-30 nanoseconds. With 4 calls per iteration and 1000 iterations:
```
Overhead = 4 × 30 ns × 1000 = 120,000 ns = 0.12 ms
```

This is only 3% of total time (3.7 ms), acceptable overhead.

### The Checksum Accumulator

```c
double checksum = 0.0;  // Outside the loop

for (size_t r = 0; r < args.runs; r++) {
    double s = 0.0;
    for (size_t i = 0; i < n; i++) s += ou[i];
    checksum += s;  // Accumulate across all runs
}
```

After 1000 runs with 500,000 points each, `checksum` contains the sum of 500,000,000 values. This is printed at the end, ensuring the compiler can't eliminate any computation.

### Single-Pass RNG

Notice the RNG is initialized once and used across all runs:
```c
xorshift128_t rng = xorshift128_new(args.seed);  // Outside loop

for (size_t r = 0; r < args.runs; r++) {
    // Use same rng across iterations
    gn[i] = diff * normal_polar_next(&norm, &rng);
}
```

This means each run gets **different** random values. Run 1 might get values 1-500,000, run 2 gets 500,001-1,000,000, etc.

**Alternative design** would reset RNG each run:
```c
for (size_t r = 0; r < args.runs; r++) {
    xorshift128_t rng = xorshift128_new(args.seed);  // Same values every run
    ...
}
```

Our design gives more diverse testing across runs.

## Statistics Computation

From `c/ou_bench.c:342-351`:

```c
// Sort run_times for median
qsort(run_times, args.runs, sizeof(double), cmp_double);
double median_s = (args.runs % 2 == 1)
    ? run_times[args.runs / 2]
    : (run_times[args.runs / 2 - 1] + run_times[args.runs / 2]) / 2.0;

double avg_ms = (total_s / (double)args.runs) * 1000.0;
double median_ms = median_s * 1000.0;
double min_ms = min_s * 1000.0;
double max_ms = max_s * 1000.0;
```

### Why Median Over Mean?

Consider these run times (milliseconds):
```
3.5, 3.6, 3.7, 3.7, 3.7, 3.8, 3.8, 3.9, 18.2, 3.9
```

One run had a spike (18.2 ms) due to OS interruption.

**Mean**: (3.5 + 3.6 + ... + 18.2) / 10 = 5.58 ms (misleading!)
**Median**: 3.75 ms (representative)

Median is **robust to outliers**, making it better for benchmarking.

### The Comparator Function

```c
static int cmp_double(const void *a, const void *b) {
    const double da = *(const double*)a;
    const double db = *(const double*)b;
    return (da < db) ? -1 : (da > db) ? 1 : 0;
}
```

This is required by `qsort()`. It returns:
- **Negative**: a < b
- **Zero**: a == b
- **Positive**: a > b

**Why not just `return da - db`?** Because:
1. `qsort` expects `int`, not `double`
2. Subtraction can lose precision for very close values
3. Overflow possible for large differences

The three-way comparison is safe and correct.

### Odd vs Even Run Counts

**Odd** (e.g., 1001 runs):
```c
median = run_times[1001 / 2]  // run_times[500] (middle value)
```

**Even** (e.g., 1000 runs):
```c
median = (run_times[999] + run_times[1000]) / 2  // Average of two middle values
```

This is the standard median definition.

## Output Formatting

From `c/ou_bench.c:355-369`:

```c
if (args.output == OUTPUT_JSON) {
    printf(
        "{\"language\":\"C\",\"mode\":\"%s\",\"n\":%zu,\"runs\":%zu,\"warmup\":%zu,\"seed\":%u,\"total_s\":%.6f,\"avg_ms\":%.6f,\"median_ms\":%.6f,\"min_ms\":%.6f,\"max_ms\":%.6f,\"breakdown_s\":{\"gen_normals\":%.6f,\"simulate\":%.6f,\"checksum\":%.6f},\"checksum\":%.17g}\n",
        mode_str, args.n, args.runs, args.warmup, args.seed,
        total_s, avg_ms, median_ms, min_ms, max_ms,
        total_gen_s, total_sim_s, total_chk_s, checksum
    );
} else {
    printf("== OU benchmark (C, unified algorithms) ==\n");
    printf("n=%zu runs=%zu warmup=%zu seed=%u\n", args.n, args.runs, args.warmup, args.seed);
    printf("total_s=%.6f\n", total_s);
    printf("avg_ms=%.6f median_ms=%.6f min_ms=%.6f max_ms=%.6f\n", avg_ms, median_ms, min_ms, max_ms);
    printf("breakdown_s gen_normals=%.6f simulate=%.6f checksum=%.6f\n", total_gen_s, total_sim_s, total_chk_s);
    printf("checksum=%.17g\n", checksum);
}
```

### JSON Precision

Notice `%.17g` for checksum:
```c
printf("\"checksum\":%.17g}\n", checksum);
```

**Why 17 digits?** IEEE 754 double precision has ~15-17 decimal digits of precision. Using 17 ensures we capture the full value for comparison across languages.

Example:
```
%.6g:  -123.456
%.17g: -123.45678901234567
```

The extra precision helps verify all languages produce identical results (within floating-point tolerance).

### Format Specifiers

- `%zu`: `size_t` (platform-independent)
- `%u`: `uint32_t`
- `%.6f`: 6 decimal places for times (microsecond precision)
- `%.17g`: 17 significant digits (general format)

Using the correct specifier avoids warnings and ensures portability.

## Compilation and Optimization

From the header comment (`c/ou_bench.c:11`):

```bash
cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
```

### Compiler Flags Explained

**`-O3`**: Maximum optimization
- Inline functions
- Loop unrolling
- Vectorization (SIMD)
- Dead code elimination
- Constant folding
- Function inlining across files

Typical speedup over `-O0` (no optimization): 3-10×

**`-march=native`**: Use CPU-specific instructions
- AVX2 (256-bit SIMD)
- FMA (fused multiply-add)
- BMI (bit manipulation instructions)

Without this flag, the compiler generates generic x86-64 code that works on any CPU but isn't optimized for your specific processor.

**Impact**: ~10-30% faster on modern CPUs

**`-std=c11`**: C11 standard (2011)
- Better than C99 (1999)
- Supports anonymous structs, `static_assert`, etc.
- Widely supported (GCC 4.9+, Clang 3.1+)

**`-lm`**: Link math library
- Provides `sqrt()`, `log()`, `sin()`, etc.
- On some systems (Linux), `libm` is separate from `libc`

**`-o ou_bench_c`**: Output filename

### Alternative Compilers

**GCC** (GNU Compiler Collection):
```bash
gcc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
```

**Clang** (LLVM):
```bash
clang -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
```

**ICC** (Intel C Compiler):
```bash
icc -O3 -xHost -std=c11 ou_bench.c -lm -o ou_bench_c
```

In our testing, all three produce similar performance (within 5%).

### Additional Optimization Flags

For even more aggressive optimization (not used by default):

```bash
cc -O3 -march=native -std=c11 -flto -ffast-math ou_bench.c -lm -o ou_bench_c
```

**`-flto`**: Link-Time Optimization
- Optimizes across all source files at link time
- Enables more aggressive inlining
- ~5-10% faster

**`-ffast-math`**: Relax IEEE 754 compliance
- Allows algebraic simplifications (`x + 0` → `x`)
- Assumes no NaNs or infinities
- Can change results slightly

We **don't use** `-ffast-math` because:
- Changes numerical results (defeats cross-language comparison)
- Minimal benefit for our code (~2%)

## Performance Analysis

### Cache Utilization

With `n = 500,000`:
- `gn` array: 3.99 MB
- `ou` array: 4.00 MB
- **Total**: ~8 MB

Typical CPU caches:
- L1: 32 KB (per core)
- L2: 256 KB (per core)
- L3: 16-32 MB (shared)

Our data (8 MB) exceeds L2 but fits in L3. This means:
- ✓ Most array accesses hit L3 (~15 cycles)
- ✗ Too large for L2 (~4 cycles)
- ✗ Way too large for L1 (~1 cycle)

**Optimization opportunity**: Smaller `n` would fit in L2, dramatically faster. But we want `n=500,000` to stress the system.

### CPU Bottleneck Analysis

Using `MODE_FULL` with default parameters:
- Total time: 3.7 ms
- gen_normals: 2.6 ms (70%)
- simulate: 0.7 ms (19%)
- checksum: 0.4 ms (11%)

**gen_normals** dominates because:
- ~2.7 million RNG calls (XorShift128)
- ~1 million normal samples (Marsaglia Polar)
- Includes `sqrt()` and `log()` (~45 cycles each)

**simulate** is fast because:
- Simple arithmetic (multiply, add)
- Sequential memory access (good cache behavior)
- Compiler can vectorize (process 4 values at once with SIMD)

**checksum** is fast because:
- Just addition
- Sequential memory access
- Modern CPUs can issue multiple adds per cycle

### Instruction-Level Parallelism

The OU simulation loop:
```c
for (size_t i = 1; i < n; i++) {
    x = a * x + b + gn[i - 1];
    ou[i] = x;
}
```

Has a **data dependency**: each iteration needs the previous `x`. This limits parallelism.

The compiler can't do:
```c
// Impossible: x₂ depends on x₁
x₁ = a * x₀ + b + gn[0];  }  Execute
x₂ = a * x₁ + b + gn[1];  }  in parallel
```

But it can overlap:
- Load `gn[i-1]` (memory)
- Multiply `a * x` (ALU)
- Add `b` (ALU)
- Store `ou[i]` (memory)

Modern CPUs can do all four in the same cycle (out-of-order execution).

## Memory Management and Cleanup

From `c/ou_bench.c:371-375`:

```c
free(gn);
free(ou);
free(run_times);
return 0;
```

### Why Free?

In a benchmark that exits immediately, freeing memory is technically optional - the OS reclaims all memory on process exit.

But we free anyway because:
1. **Good practice**: Prevents memory leaks in production code
2. **Valgrind clean**: Memory checkers report no leaks
3. **Embeddability**: If this code were integrated into a larger program, leaks would accumulate

### Memory Leak Detection

Run with Valgrind:
```bash
valgrind --leak-check=full ./ou_bench_c --n=1000 --runs=10
```

Expected output:
```
HEAP SUMMARY:
    in use at exit: 0 bytes in 0 blocks
  total heap usage: 3 allocs, 3 frees
```

Perfect! No leaks.

### What If Malloc Fails?

Our code checks:
```c
if (!gn || !ou) {
    fprintf(stderr, "allocation failed\n");
    return 1;
}
```

When does `malloc()` fail?
- Out of memory (OOM)
- Requesting > available address space
- System limits (ulimit)

With default `n=500,000`, allocation is ~8 MB. On a modern system with GB of RAM, failure is extremely unlikely. But for large `n`:

```bash
./ou_bench_c --n=1000000000  # Request 8 GB
```

This might fail on a system with insufficient RAM or swap.

## Common Pitfalls and Best Practices

### ❌ Pitfall 1: Not Linking Math Library

```bash
cc -O3 ou_bench.c -o ou_bench_c
# Error: undefined reference to `sqrt`, `log`
```

**Fix**: Add `-lm`

### ❌ Pitfall 2: Forgetting static inline

Without `static inline`:
```c
double xorshift128_next_f64(xorshift128_t *rng) { ... }
```

The compiler might:
- Not inline (function call overhead)
- Generate external symbols (slower linking)

With `static inline`:
- Compiler inlines (no call overhead)
- Each compilation unit has own copy (faster)

### ❌ Pitfall 3: Integer Overflow in Time Conversion

```c
// BAD: Might overflow if time is large
uint32_t ns = now_ns();
double sec = ns * 1e-9;
```

**Fix**: Use `uint64_t` for nanoseconds

### ❌ Pitfall 4: Using time() Instead of clock_gettime()

```c
// BAD: Only 1-second resolution
time_t t0 = time(NULL);
// ... work ...
time_t t1 = time(NULL);
double elapsed = difftime(t1, t0);  // Seconds, no subsecond precision
```

**Fix**: Use `clock_gettime()` for nanosecond precision

### ✓ Best Practice: Volatile for Checksum

Some aggressive optimizers might eliminate the checksum. A defensive approach:
```c
volatile double checksum = 0.0;
```

This tells the compiler: "Don't optimize this variable away." We don't use it because our printing is sufficient.

## Exercises

### Exercise 1: Measure Compiler Impact

Compile with different optimization levels:
```bash
cc -O0 -std=c11 ou_bench.c -lm -o ou_bench_O0
cc -O1 -std=c11 ou_bench.c -lm -o ou_bench_O1
cc -O2 -std=c11 ou_bench.c -lm -o ou_bench_O2
cc -O3 -std=c11 ou_bench.c -lm -o ou_bench_O3
```

Run each and compare:
```bash
./ou_bench_O0 --runs=100
./ou_bench_O1 --runs=100
./ou_bench_O2 --runs=100
./ou_bench_O3 --runs=100
```

Questions:
1. What is the speedup from O0 to O3?
2. Is there a difference between O2 and O3?
3. What about `-march=native`?

### Exercise 2: Profile with perf

Use Linux `perf` to identify hotspots:
```bash
perf record ./ou_bench_c --runs=1000
perf report
```

Questions:
1. Which function uses the most CPU time?
2. What percentage is spent in `normal_polar_next`?
3. What percentage in `sqrt` and `log`?

### Exercise 3: Measure Cache Impact

Try different values of `n`:
```bash
./ou_bench_c --n=1000 --runs=10000     # Fits in L1
./ou_bench_c --n=10000 --runs=10000    # Fits in L2
./ou_bench_c --n=100000 --runs=1000    # Fits in L3
./ou_bench_c --n=10000000 --runs=100   # Exceeds L3
```

Plot time per iteration vs array size. Do you see the cache hierarchy?

### Exercise 4: Implement Your Own Timing

Replace `clock_gettime()` with `rdtsc` (CPU cycle counter):

```c
static inline uint64_t rdtsc(void) {
    uint32_t lo, hi;
    __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}
```

Convert cycles to time using your CPU frequency.

### Exercise 5: Add Standard Deviation

Extend the statistics to include standard deviation:

```c
// After computing median
double variance = 0.0;
for (size_t i = 0; i < args.runs; i++) {
    double diff = run_times[i] - avg_ms;
    variance += diff * diff;
}
variance /= args.runs;
double stddev_ms = sqrt(variance);

printf("stddev_ms=%.6f\n", stddev_ms);
```

What is the typical stddev for 1000 runs?

## Advanced Topics

### Compiler Optimization Strategies

GCC/Clang at `-O3` apply hundreds of transformations. Key ones for our code:

**Loop Unrolling**:
```c
// Original
for (int i = 0; i < n; i++) {
    ou[i] = ...;
}

// Unrolled (4x)
for (int i = 0; i < n; i += 4) {
    ou[i+0] = ...;
    ou[i+1] = ...;
    ou[i+2] = ...;
    ou[i+3] = ...;
}
```

Reduces loop overhead (increment, comparison, branch).

**Inlining**:
```c
// Before inlining
double v = xorshift128_next_f64(&rng);

// After inlining (no function call)
uint32_t a = xorshift128_next_u32(&rng);
uint32_t b = xorshift128_next_u32(&rng);
uint64_t u = ...;
double v = (double)u * (1.0 / 9007199254740992.0);
```

Eliminates call overhead and enables further optimizations.

**Vectorization**:
```c
// Scalar
for (int i = 0; i < n; i++) {
    sum += ou[i];
}

// Vectorized (AVX2, 4 doubles at once)
for (int i = 0; i < n; i += 4) {
    v = _mm256_load_pd(&ou[i]);    // Load 4 doubles
    sum_vec = _mm256_add_pd(sum_vec, v);  // Add 4 at once
}
```

4× throughput for summation.

### Alignment and Padding

For optimal SIMD performance, arrays should be aligned:

```c
// 32-byte aligned (AVX2 requirement)
double *ou = aligned_alloc(32, n * sizeof(double));
```

Without alignment, vectorized loads/stores are slower (or cause crashes on some architectures).

### The Memory Model

C11 introduced a formal memory model for multithreading. Our code is single-threaded, but understanding memory ordering matters:

- **Sequential consistency**: Operations happen in program order
- **Relaxed**: Compiler can reorder (within constraints)

For our benchmark, the compiler can reorder independent operations:
```c
x = a * x + b + gn[i - 1];  // Must happen in order
ou[i] = x;
s += ou[i];  // Can be reordered (no dependency)
```

This reordering improves instruction-level parallelism.

## Summary

The C implementation demonstrates:

1. **Simplicity**: Single file, <400 lines, no external dependencies
2. **Performance**: Bare metal speed, aggressive optimization
3. **Portability**: Standard C11, works on Linux/macOS/Windows
4. **Instrumentation**: Three-stage timing, JSON output
5. **Correctness**: Validated against mathematical specification

Key design decisions:
- **Manual argument parsing**: No dependencies
- **Heap allocation**: Supports arbitrary `n`
- **Warmup phase**: Eliminates cold-start effects
- **Median statistics**: Robust to outliers
- **Checksum accumulation**: Prevents dead-code elimination

This sets the **performance baseline** that all other languages aim to match.

---

**Previous**: [Chapter 3: Normal Distribution Sampling](03-normal-distribution.md)
**Next**: [Chapter 5: Zig - Modern Systems Programming](05-zig-implementation.md)

## References

- [C11 Standard (ISO/IEC 9899:2011)](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf)
- [GCC Optimization Options](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)
- [Clang Optimization](https://clang.llvm.org/docs/CommandGuide/clang.html#code-generation-options)
- [POSIX.1-2017 clock_gettime()](https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_gettime.html)
- [IEEE 754 Floating Point](https://en.wikipedia.org/wiki/IEEE_754)
- [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html)
