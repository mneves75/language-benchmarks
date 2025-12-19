# Chapter 9: Benchmarking Methodology - Measuring Performance Correctly

## The Problem with Performance Claims

Have you ever heard someone say "My code is twice as fast!" only to discover they measured it wrong?

**Bad benchmarking is everywhere:**
- "I ran it once and it took 5ms!" (What about the second run?)
- "The average time is 10ms!" (What if one run took 1000ms?)
- "Language X is faster than Language Y!" (Under what conditions?)

**The harsh truth**: Most performance comparisons are **flawed**. This chapter teaches you how to measure correctly.

## What Is Benchmarking?

**Benchmarking** is the science of measuring software performance in a **fair**, **reproducible**, and **statistically valid** way.

Think of it like comparing race car speeds:
- ❌ Bad: Watch one lap and declare a winner
- ✓ Good: Run 1000 laps, measure all times, analyze statistically

### The Three Principles

1. **Fairness**: Same conditions for all competitors
2. **Reproducibility**: Others can verify your results
3. **Statistical validity**: Account for variance and outliers

Our benchmark follows all three principles.

## Common Benchmarking Mistakes

### Mistake 1: Running Only Once

```bash
# BAD
time ./my_program
# 3.5 seconds

# Conclusion: "My program takes 3.5 seconds"
```

**Problem**: That run could be an outlier!

**Why?**
- First run might load libraries (cold cache)
- Background processes might interfere
- CPU frequency might vary

**Solution**: Run many times.

```bash
# GOOD
for i in {1..1000}; do
    time ./my_program
done
# Collect all times, analyze statistically
```

### Mistake 2: Using Average (Mean) Instead of Median

**Mean** is sensitive to outliers:

```
Times: [3, 3, 3, 3, 100]  # One garbage collection pause
Mean: (3+3+3+3+100)/5 = 22.4 ms  # Misleading!
Median: 3 ms                      # Representative!
```

**Median** is the middle value when sorted - it ignores outliers.

**Analogy**: Measuring a sprinter's speed
- If they trip once, should we average all runs? (Mean)
- Or report their typical performance? (Median)

We use **median** in our benchmark.

### Mistake 3: No Warmup Phase

Many languages have **JIT compilation** (JavaScript, Java, C#):

```
Run 1: 100ms  (interpreter)
Run 2: 50ms   (JIT compiling)
Run 3: 10ms   (optimized)
Run 4: 10ms   (optimized)
Run 5: 10ms   (optimized)
```

If you average runs 1-5, you get 36ms. But the "real" performance is 10ms.

**Solution**: Warmup phase.

```javascript
// Warmup: Let JIT optimize
for (let i = 0; i < 5; i++) {
    runBenchmark();  // Discard results
}

// Timed runs
for (let i = 0; i < 1000; i++) {
    const time = measureRunBenchmark();
    times.push(time);
}
```

Our benchmark uses **5 warmup runs** for all languages.

### Mistake 4: Measuring the Wrong Thing

```c
// BAD: Measures printf overhead too
start = now();
result = compute();
printf("Result: %f\n", result);
end = now();
```

**Problem**: You're timing `printf`, not `compute`.

**Solution**: Measure only the computation.

```c
// GOOD: Measure only compute
start = now();
result = compute();
end = now();
// Print after timing
printf("Result: %f\n", result);
```

Our benchmark times only the computation, not I/O.

### Mistake 5: Compiler Optimizes Away Your Code

Modern compilers are **smart**. They might:
- Eliminate dead code
- Cache results
- Inline everything

```c
// Compiler might optimize this away!
double result = expensive_calculation();
// result never used
```

**Solution**: Use the result.

```c
double result = expensive_calculation();
printf("%f\n", result);  // Forces computation
```

Or use compiler intrinsics:
```c
__asm__ __volatile__("" : "+r" (result));  // Prevents optimization
```

Our benchmark **checksums** all results to prevent elimination.

## Statistical Concepts for Benchmarking

### Mean (Average)

**Definition**: Sum of all values divided by count.

```
Mean = (sum of all values) / count
```

**Example**:
```
Times: [3, 4, 3, 3, 100]
Mean = (3+4+3+3+100)/5 = 22.6 ms
```

**Problem**: Outliers (100ms) skew the result.

### Median

**Definition**: The middle value when sorted.

**Algorithm**:
1. Sort values: [3, 3, 3, 4, 100]
2. Pick middle: **3 ms**

For even count, average the two middle values:
```
Times: [3, 3, 4, 4]
Median = (3+4)/2 = 3.5 ms
```

**Why better?** Outliers don't affect it.

```
Times: [3, 3, 3, 4, 100]      → Median = 3
Times: [3, 3, 3, 4, 1000000]  → Median = 3 (still!)
```

### Percentiles

**95th percentile**: 95% of runs were faster than this.

**Algorithm**:
1. Sort times: [3, 3, 3, 4, 5, 6, 7, 8, 100]
2. 95th percentile = value at position 0.95 × 9 = 8.55 → **100 ms**

**Use case**: Guaranteeing performance
- "95% of requests complete in under 10ms"

### Variance and Standard Deviation

**Variance** measures spread:

```
Variance = average of (value - mean)²
```

**Standard deviation** is the square root of variance:

```
StdDev = √Variance
```

**Example**:
```
Times: [3, 3, 3, 3, 3]  → Mean=3, StdDev=0 (no variance)
Times: [1, 2, 3, 4, 5]  → Mean=3, StdDev=1.41 (high variance)
```

**Interpretation**:
- Low StdDev: Consistent performance ✓
- High StdDev: Unpredictable performance ✗

## Our Benchmark Methodology

Let's examine how our benchmark implements best practices.

### Command-Line Interface

All implementations support the same flags:

```bash
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1 --mode=full --output=text
```

**Parameters**:
- `--n`: Number of time steps (default: 500,000)
- `--runs`: Number of timed runs (default: 1,000)
- `--warmup`: Warmup runs to discard (default: 5)
- `--seed`: RNG seed for reproducibility (default: 1)
- `--mode`: What to measure (`full`, `gn`, `ou`)
- `--output`: Output format (`text`, `json`)

This ensures **fair comparison** - same parameters for all languages.

### The Benchmark Loop Structure

From C implementation (`c/ou_bench.c:160-220`):

```c
// 1. Warmup phase (discard results)
for (int r = 0; r < args.warmup; ++r) {
    run_simulation(/* ... */);  // Not timed
}

// 2. Timed runs
double times[args.runs];
for (int r = 0; r < args.runs; ++r) {
    uint64_t t0 = now_ns();

    run_simulation(/* ... */);

    uint64_t t1 = now_ns();
    times[r] = (t1 - t0) * 1e-9;  // Convert to seconds
}

// 3. Sort times for median calculation
qsort(times, args.runs, sizeof(double), compare_double);

// 4. Calculate statistics
double median = times[args.runs / 2];
double mean = calculate_mean(times, args.runs);
double p95 = times[(int)(args.runs * 0.95)];
```

**Key features**:
1. **Warmup phase**: 5 runs discarded
2. **Many runs**: 1000 timed iterations
3. **Sort for percentiles**: Median, P95, P99
4. **Reproducible seed**: Same RNG sequence every time

### Preventing Compiler Optimizations

The compiler might optimize away unused code. We prevent this with **checksums**:

```c
double checksum = 0.0;

for (int r = 0; r < args.runs; ++r) {
    double result = run_simulation(/* ... */);
    checksum += result;  // Use the result!
}

// Print checksum after all runs
printf("checksum=%.6f\n", checksum);
```

The checksum:
- ✓ Forces computation (can't be eliminated)
- ✓ Verifies correctness (same checksum = correct)
- ✓ Doesn't affect timing (happens after measurement)

**Important**: We accumulate checksums **outside** the timed section:

```c
// Timed section
uint64_t t0 = now_ns();
double result = run_simulation();
uint64_t t1 = now_ns();

// After timing (doesn't affect measurement)
checksum += result;
```

### Timing Precision

Different languages use different timers:

**C** (POSIX `clock_gettime`):
```c
struct timespec ts;
clock_gettime(CLOCK_MONOTONIC, &ts);
uint64_t ns = ts.tv_sec * 1000000000ULL + ts.tv_nsec;
```
- Resolution: **1 nanosecond**
- Monotonic: Yes (doesn't go backward)

**Rust** (`std::time::Instant`):
```rust
let t0 = Instant::now();
// work
let elapsed = t0.elapsed().as_secs_f64();
```
- Resolution: Platform-dependent (nanoseconds on Unix)
- Monotonic: Yes

**TypeScript (Bun runtime)** (`performance.now()`):
```typescript
const t0 = performance.now();  // Milliseconds with microsecond precision
// work
const elapsed = (performance.now() - t0) / 1000;  // Convert to seconds
```
- Resolution: **~1 microsecond**
- Monotonic: Yes

**Swift** (`DispatchTime`):
```swift
let t0 = DispatchTime.now().uptimeNanoseconds
// work
let elapsed = (DispatchTime.now().uptimeNanoseconds - t0)
```
- Resolution: **1 nanosecond**
- Monotonic: Yes

**Zig** (standard library):
```zig
const t0 = std.time.nanoTimestamp();
// work
const elapsed = std.time.nanoTimestamp() - t0;
```
- Resolution: **1 nanosecond**
- Monotonic: Yes

All timers are **monotonic** (unaffected by system clock changes).

### Three-Phase Timing

Our benchmark times three phases separately:

```c
// Phase 1: Generate Gaussian noise
uint64_t t0 = now_ns();
for (int i = 0; i < n - 1; ++i) {
    gn[i] = diff * marsaglia_polar(rng, norm);
}
uint64_t t1 = now_ns();

// Phase 2: Simulate OU process
for (int i = 1; i < n; ++i) {
    x = a * x + b + gn[i - 1];
    ou[i] = x;
}
uint64_t t2 = now_ns();

// Phase 3: Checksum
double sum = 0.0;
for (int i = 0; i < n; ++i) {
    sum += ou[i];
}
uint64_t t3 = now_ns();

// Calculate times
double gen_time = (t1 - t0) * 1e-9;
double sim_time = (t2 - t1) * 1e-9;
double chk_time = (t3 - t2) * 1e-9;
```

**Why three phases?**
- Understand where time is spent
- Identify bottlenecks
- Compare different aspects (RNG vs simulation)

**Results breakdown**:
```
C:
  Generation: 1.2 ms (32%)
  Simulation: 1.8 ms (49%)
  Checksum:   0.7 ms (19%)
  Total:      3.7 ms
```

### Statistical Output

Our benchmark outputs comprehensive statistics:

```
=== OU Benchmark ===
n=500000 runs=1000 warmup=5 seed=1
language=c mode=full
checksum=-1504.849609

Times (s):
  median=0.003700
  mean=0.003724
  p95=0.003920
  p99=0.004150
  min=0.003520
  max=0.006100
```

**Key metrics**:
- **median**: Typical performance (50th percentile)
- **mean**: Average (affected by outliers)
- **p95**: 95% of runs were faster
- **p99**: 99% of runs were faster
- **min**: Best case
- **max**: Worst case

### JSON Output for Analysis

For programmatic analysis:

```bash
./ou_bench --output=json
```

```json
{
  "config": {
    "n": 500000,
    "runs": 1000,
    "warmup": 5,
    "seed": 1,
    "language": "c",
    "mode": "full"
  },
  "results": {
    "checksum": -1504.849609,
    "median": 0.003700,
    "mean": 0.003724,
    "p95": 0.003920,
    "p99": 0.004150,
    "min": 0.003520,
    "max": 0.006100
  }
}
```

This enables:
- Automated comparison scripts
- Plotting with Python/R
- CI/CD integration

## Fair Comparison Principles

### 1. Same Algorithm

All five implementations use **identical algorithms**:
- SplitMix32 for seed expansion
- XorShift128 for PRNG
- Marsaglia Polar for normal distribution
- Euler-Maruyama for OU process

**Why important?** Different algorithms = unfair comparison.

```
Algorithm A: O(n²)
Algorithm B: O(n log n)
```

Comparing these would measure **algorithms**, not **languages**.

### 2. Same Parameters

All runs use identical parameters:
- n = 500,000 time steps
- runs = 1,000 iterations
- seed = 1 (same RNG sequence)

This ensures **reproducibility**.

### 3. Same Optimizations

All languages compiled with maximum optimization:

**C**:
```bash
gcc -O3 -march=native -flto ou_bench.c -o ou_bench
```

**Rust**:
```toml
[profile.release]
opt-level = 3
lto = true
```

**Zig**:
```bash
zig build-exe -O ReleaseFast ou_bench.zig
```

**Swift**:
```bash
swiftc -O -whole-module-optimization ou_bench.swift
```

**Bun**: JIT automatically optimizes

**Why important?** Comparing debug builds to release builds is meaningless.

### 4. Same Machine

All benchmarks run on the **same hardware**:
- CPU: Same processor
- RAM: Same memory
- OS: Same operating system

**Example setup**:
```
CPU: Apple M1 Pro (10 cores)
RAM: 16 GB
OS: macOS 14.0
```

**Why important?** Different CPUs have different performance characteristics.

### 5. Isolated Environment

Run benchmarks in **isolation**:
- Close other applications
- Disable background tasks
- Run one benchmark at a time

```bash
# Bad: Running benchmarks concurrently
./c_bench & ./rust_bench & ./zig_bench &

# Good: Run sequentially
./c_bench
./rust_bench
./zig_bench
```

### 6. Multiple Runs

Never trust a single run. We use:
- **5 warmup runs**: Let JIT optimize
- **1000 timed runs**: Statistical significance

**Rule of thumb**: More runs = more confidence in results.

## Analyzing Results

### Comparing Medians

Our results:

| Language | Median (ms) | vs C | Relative |
|----------|-------------|------|----------|
| C        | 3.70        | baseline | 1.00× |
| Zig      | 3.82        | +3%  | 1.03× |
| Rust     | 3.84        | +4%  | 1.04× |
| TypeScript (Bun runtime) | 6.13        | +66% | 1.66× |
| Swift    | 9.25        | +150% | 2.50× |

**How to interpret**:
- C, Zig, Rust: Within 4% (essentially identical)
- Bun: 66% slower (still impressive for JIT)
- Swift: 150% slower (safety overhead)

### Variance Analysis

Lower variance = more consistent:

```
C:     StdDev = 0.05 ms  (1.4%)  ← Very consistent
Rust:  StdDev = 0.06 ms  (1.6%)  ← Very consistent
Bun:   StdDev = 0.20 ms  (3.3%)  ← Some variance (GC?)
Swift: StdDev = 0.30 ms  (3.2%)  ← Some variance (ARC?)
```

**Interpretation**:
- Compiled languages: Predictable
- JIT languages: Some unpredictability (GC pauses)

### Distribution Plots

Visualizing with histograms:

```
C (median=3.70ms):
3.5-3.6: ██
3.6-3.7: ████████
3.7-3.8: ████████████████  ← Most runs
3.8-3.9: ████
3.9-4.0: ██
```

**Ideal distribution**: Narrow peak around median.

**Bad distribution**: Wide spread or multiple peaks (indicates inconsistency).

## Common Pitfalls to Avoid

### Pitfall 1: Timing Includes Startup

```c
// BAD: Times program startup
int main() {
    uint64_t t0 = now_ns();
    initialize();  // Loads libraries, allocates memory
    run_benchmark();
    uint64_t t1 = now_ns();
}

// GOOD: Time only the work
int main() {
    initialize();
    uint64_t t0 = now_ns();
    run_benchmark();
    uint64_t t1 = now_ns();
}
```

### Pitfall 2: Memory Allocation Inside Timing

```c
// BAD: Times allocation
uint64_t t0 = now_ns();
double *arr = malloc(n * sizeof(double));  // Allocation overhead!
compute(arr);
uint64_t t1 = now_ns();
free(arr);

// GOOD: Allocate before timing
double *arr = malloc(n * sizeof(double));
uint64_t t0 = now_ns();
compute(arr);
uint64_t t1 = now_ns();
free(arr);
```

### Pitfall 3: Cache Effects

First run might be slower (cold cache):

```
Run 1: 10ms  (cold cache)
Run 2: 3ms   (hot cache)
Run 3: 3ms
```

**Solution**: Warmup runs.

### Pitfall 4: CPU Frequency Scaling

Modern CPUs change frequency:
- Idle: Low frequency (save power)
- Active: High frequency (performance)

```
Run 1: 10ms  (CPU ramping up)
Run 2: 5ms   (CPU at full speed)
Run 3: 5ms
```

**Solutions**:
1. Warmup runs
2. Disable frequency scaling (requires root):
   ```bash
   sudo cpupower frequency-set --governor performance
   ```

### Pitfall 5: Thermal Throttling

If CPU overheats, it slows down:

```
Runs 1-100:  3ms each  (CPU cool)
Runs 101-500: 4ms each  (CPU throttling)
```

**Solution**:
- Run shorter benchmarks
- Cool system between runs
- Monitor CPU temperature

## Advanced Topics

### Microbenchmarking vs Macrobenchmarking

**Microbenchmark**: Measures tiny operations (microseconds)
```c
// Measure single RNG call (~10ns)
uint64_t t0 = now_ns();
uint32_t r = xorshift128_next(&rng);
uint64_t t1 = now_ns();
```

**Problem**: Timer overhead might dominate!

**Solution**: Batch operations:
```c
uint64_t t0 = now_ns();
for (int i = 0; i < 1000000; ++i) {
    xorshift128_next(&rng);
}
uint64_t t1 = now_ns();
// Divide by 1,000,000 to get per-call time
```

**Macrobenchmark**: Measures complete programs (milliseconds+)
- Our benchmark is a macrobenchmark (3-9ms)
- Timer overhead is negligible

### Statistical Significance

**Question**: Is Rust really 4% slower than C, or is it noise?

**Answer**: Use statistical tests (t-test, Mann-Whitney U).

**Rule of thumb**:
- Difference < 5%: Likely noise
- Difference > 10%: Probably real
- Difference > 50%: Definitely real

Our results:
- C vs Zig: 3% (might be noise)
- C vs Rust: 4% (might be noise)
- C vs Bun: 66% (definitely real)
- C vs Swift: 150% (definitely real)

### Confidence Intervals

Instead of "median = 3.70ms", report:

```
median = 3.70ms ± 0.05ms (95% confidence)
```

This means: "We're 95% confident the true median is between 3.65ms and 3.75ms."

**How to calculate**:
1. Compute standard error: `SE = StdDev / √n`
2. Multiply by 1.96 for 95% confidence: `CI = 1.96 × SE`

### Regression Detection

Monitor performance over time:

```
Commit 1: median = 3.70ms
Commit 2: median = 3.71ms  (+0.3% - noise)
Commit 3: median = 4.20ms  (+13% - REGRESSION!)
```

**Solution**: Automated benchmarking in CI/CD.

## Practical Benchmarking Script

Here's a script to run all benchmarks fairly:

```bash
#!/bin/bash
# run_all.sh - Fair benchmark comparison

# Common parameters
N=500000
RUNS=1000
WARMUP=5
SEED=1

# Ensure system is idle
echo "Waiting for system to idle..."
sleep 5

# Run benchmarks sequentially
echo "=== C ==="
./c/ou_bench --n=$N --runs=$RUNS --warmup=$WARMUP --seed=$SEED

echo "=== Zig ==="
./zig/ou_bench --n=$N --runs=$RUNS --warmup=$WARMUP --seed=$SEED

echo "=== Rust ==="
./rust/target/release/ou_bench_unified --n=$N --runs=$RUNS --warmup=$WARMUP --seed=$SEED

echo "=== Bun ==="
bun ts/ou_bench.ts --n=$N --runs=$RUNS --warmup=$WARMUP --seed=$SEED

echo "=== Swift ==="
./swift/ou_bench --n=$N --runs=$RUNS --warmup=$WARMUP --seed=$SEED
```

**Best practices**:
- Sequential execution (no parallelism)
- Same parameters for all
- Wait between runs (cool down)

## Exercises

### Exercise 1: Measure Timer Overhead

How much overhead does the timer add?

```c
#include <stdio.h>
#include <stdint.h>
#include <time.h>

uint64_t now_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

int main() {
    const int RUNS = 1000000;
    uint64_t total = 0;

    for (int i = 0; i < RUNS; ++i) {
        uint64_t t0 = now_ns();
        uint64_t t1 = now_ns();
        total += (t1 - t0);
    }

    printf("Timer overhead: %lu ns\n", total / RUNS);
    return 0;
}
```

**Expected result**: 20-50 ns per call.

### Exercise 2: Analyze Your Results

Run the C benchmark and analyze:

```bash
./c/ou_bench --runs=1000 --output=json > results.json
```

Write a Python script to:
1. Load results
2. Plot histogram of times
3. Calculate variance
4. Identify outliers (> 2 standard deviations)

```python
import json
import matplotlib.pyplot as plt

with open('results.json') as f:
    data = json.load(f)

times = data['all_times']
plt.hist(times, bins=50)
plt.xlabel('Time (s)')
plt.ylabel('Frequency')
plt.title('Benchmark Time Distribution')
plt.show()
```

### Exercise 3: Compare Mean vs Median

Modify the benchmark to inject outliers:

```c
// After normal run, inject outlier
if (r == args.runs / 2) {
    sleep(1);  // Inject 1-second delay
}
```

Compare:
- Mean (affected by outlier)
- Median (robust to outlier)

Which is more representative?

### Exercise 4: Warmup Effect

Run Bun benchmark with different warmup counts:

```bash
bun ou_bench.ts --warmup=0 --runs=20
bun ou_bench.ts --warmup=5 --runs=20
bun ou_bench.ts --warmup=10 --runs=20
```

Plot the first 20 run times for each. Does warmup matter?

### Exercise 5: Compiler Optimization Levels

Compare C with different optimization levels:

```bash
# No optimization
gcc ou_bench.c -o ou_bench_O0
./ou_bench_O0 --runs=100

# -O2
gcc -O2 ou_bench.c -o ou_bench_O2
./ou_bench_O2 --runs=100

# -O3
gcc -O3 ou_bench.c -o ou_bench_O3
./ou_bench_O3 --runs=100
```

**Expected results**:
- O0: ~50ms (10× slower)
- O2: ~4ms
- O3: ~3.7ms

Optimization matters!

### Exercise 6: Statistical Significance

Run C benchmark 10 times (each producing median):

```bash
for i in {1..10}; do
    ./c/ou_bench --runs=1000 | grep "median="
done
```

Calculate:
1. Mean of medians
2. Standard deviation of medians
3. 95% confidence interval

Is the performance consistent?

### Exercise 7: Checksum Verification

Run all benchmarks with same seed:

```bash
./c/ou_bench --seed=42 | grep checksum
./rust/ou_bench --seed=42 | grep checksum
./zig/ou_bench --seed=42 | grep checksum
```

Are checksums identical? (They should be - same algorithm, same seed)

### Exercise 8: Phase Analysis

Modify the benchmark to output phase times:

```
Generation: 1.2ms (32%)
Simulation: 1.8ms (49%)
Checksum:   0.7ms (19%)
```

Which phase is the bottleneck? How does it vary by language?

## Summary

**Key principles of good benchmarking**:

1. **Run many times** (not just once)
2. **Use median** (not mean) for typical performance
3. **Warmup phase** for JIT languages
4. **Prevent optimizations** from eliminating code
5. **Fair comparison**: same algorithm, parameters, machine
6. **Statistical analysis**: variance, percentiles, confidence intervals
7. **Reproducibility**: fixed seed, documented setup

**Our benchmark follows all best practices**:
- ✓ 1000 timed runs
- ✓ 5 warmup runs
- ✓ Median-based reporting
- ✓ Checksum prevents optimization
- ✓ Identical algorithms across languages
- ✓ Same parameters for all
- ✓ Comprehensive statistics

**Common mistakes to avoid**:
- ✗ Single run measurements
- ✗ Using mean for skewed distributions
- ✗ No warmup for JIT
- ✗ Timing I/O or startup
- ✗ Different algorithms/parameters

**Statistical concepts**:
- **Median**: Middle value (robust to outliers)
- **Mean**: Average (affected by outliers)
- **Percentiles**: P95 = 95% faster than this
- **Variance**: Spread of values
- **Standard deviation**: √Variance

**Results interpretation**:
- C, Zig, Rust: 3-4% variation (essentially identical)
- Bun: 66% slower (impressive for JIT)
- Swift: 150% slower (safety overhead)

**The benchmark proves**:
- Modern systems languages (Zig, Rust) match C performance
- JIT compilation (Bun) can be surprisingly fast
- Safety features (Swift) have measurable cost
- Proper methodology is crucial for fair comparison

Benchmarking is both **science** and **art** - it requires understanding of statistics, systems, and potential pitfalls. Follow these principles and your performance claims will be **credible** and **reproducible**.

---

**Previous**: [Chapter 8: Swift - Apple Ecosystem Performance](08-swift-implementation.md)
**Next**: [Chapter 10: Exercises and Projects](10-exercises-projects.md)

## References

- [How to Benchmark Code Correctly](https://easyperf.net/blog/2018/08/26/Microarchitectural-performance-events)
- [Statistics for Benchmarking](https://www.brendangregg.com/blog/2018-06-30/benchmarking-checklist.html)
- [JMH (Java Microbenchmark Harness) Best Practices](https://github.com/openjdk/jmh)
- [Rust Criterion.rs Benchmarking](https://github.com/bheisler/criterion.rs)
- [Google Benchmark Library](https://github.com/google/benchmark)
