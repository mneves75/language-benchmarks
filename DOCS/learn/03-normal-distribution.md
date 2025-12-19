# Chapter 3: Normal Distribution Sampling

## The Dartboard Analogy

Imagine throwing darts at a dartboard. If you're an average player:
- Most darts land near the center (bullseye)
- Some darts land in the middle rings
- Few darts land at the outer edges
- Almost no darts miss the board entirely

If you plot where the darts land, you'll see a **bell curve** - dense in the middle, sparse at the edges. This is a **normal distribution** (also called Gaussian distribution).

In our Ornstein-Uhlenbeck simulation, we need random "kicks" that follow this pattern. Most kicks are small (near center), occasional kicks are medium, and rare kicks are large. This models real-world randomness like:
- Stock price fluctuations
- Measurement errors
- Thermal motion of particles

## What Is a Normal Distribution?

### The Bell Curve

A normal distribution with mean μ and standard deviation σ has this probability density function (PDF):

```
f(x) = (1 / (σ√(2π))) * e^(-(x-μ)²/(2σ²))
```

Don't panic! Let's break it down:

**Visual representation**:
```
     Probability
        ^
        |       *****
        |     **     **
        |   **         **
        |  *             *
        | *               *
        |*                 *_______________> x
       μ-3σ  μ-2σ  μ-σ  μ  μ+σ  μ+2σ  μ+3σ
```

**Key properties**:
- **Mean (μ)**: Center of the bell curve
- **Standard deviation (σ)**: Width of the curve
- **68% of values**: Within μ ± σ
- **95% of values**: Within μ ± 2σ
- **99.7% of values**: Within μ ± 3σ

### Standard Normal Distribution

When μ = 0 and σ = 1, we have the **standard normal distribution** N(0, 1):

```
f(x) = (1/√(2π)) * e^(-x²/2)
```

This is what we generate in our code. To get N(μ, σ), we simply:
```
X ~ N(0, 1)  (generate standard normal)
Y = μ + σ * X  (scale and shift)
```

In our OU benchmark, we use μ = 0, so we can use standard normals directly.

## The Challenge: From Uniform to Normal

We have:
- **XorShift128**: Generates uniform random numbers U ~ Uniform[0, 1)
- **Need**: Normal random numbers X ~ N(0, 1)

How do we transform uniform → normal?

### Naive Approach: Central Limit Theorem

The **Central Limit Theorem** says that averaging many random variables produces a normal distribution. We could do:

```python
def normal_clt():
    sum = 0
    for i in range(12):  # Average 12 uniform samples
        sum += random_uniform()
    return sum - 6  # Shift to center at 0
```

**Problems**:
- ❌ Requires 12 calls to RNG (slow!)
- ❌ Only approximate (not exact normal)
- ❌ Tails are cut off (can't generate values < -6 or > +6)

We need something better.

### Better Approaches

Several algorithms exist:

1. **Box-Muller Transform** - Uses logarithm and trigonometry
2. **Marsaglia Polar Method** - Optimized version of Box-Muller
3. **Ziggurat Algorithm** - Fastest, but complex to implement

We use **Marsaglia Polar Method** because it:
- ✓ Is exact (produces true normal distribution)
- ✓ Is fast (rejects ~21% of samples on average)
- ✓ Is simple to implement identically across languages
- ✓ Produces two values per iteration (caches the spare)

## The Box-Muller Transform

Before understanding Marsaglia Polar, let's understand Box-Muller, which it's based on.

### The Mathematics

Given two independent uniform random numbers U₁, U₂ ~ Uniform[0, 1), Box-Muller produces two independent standard normals:

```
Z₁ = √(-2 ln U₁) * cos(2π U₂)
Z₂ = √(-2 ln U₁) * sin(2π U₂)
```

Where:
- **ln**: Natural logarithm
- **cos, sin**: Trigonometric functions
- Both Z₁ and Z₂ are ~ N(0, 1)

### Why This Works (Intuition)

Imagine points in 2D space:
- Convert (U₁, U₂) from Cartesian to polar coordinates
- The radius follows a specific distribution related to -2 ln U₁
- The angle is uniform (2π U₂)
- This magically produces normally-distributed x and y coordinates!

The math proof requires multivariable calculus, but the key insight: **uniform distribution on a disk → normal distribution on each axis**.

### The Problem with Box-Muller

Computing `cos` and `sin` is **slow**:
- `cos`: ~30-50 CPU cycles
- `sin`: ~30-50 CPU cycles
- `ln`: ~20-30 CPU cycles

For comparison:
- Multiplication: 3-5 cycles
- XOR/shift: 1 cycle

Box-Muller is correct but expensive.

## The Marsaglia Polar Method

Marsaglia's insight: **avoid trigonometric functions** by using rejection sampling.

### The Algorithm

```
1. Generate two uniform random numbers in [-1, 1):
   u = 2*U₁ - 1
   v = 2*U₂ - 1

2. Compute s = u² + v²

3. If s >= 1 or s == 0, reject and go to step 1

4. Compute m = √(-2 ln(s) / s)

5. Return two normals:
   z₁ = u * m
   z₂ = v * m
```

### Visual Explanation

Step 1-3: **Rejection Sampling**

Imagine a square from -1 to +1 on both axes, with an inscribed circle of radius 1:

```
         -1                0                1
          |                |                |
      1   +----------------+----------------+
          |       *****    |    *****       |
          |    ***     *** | ***     ***    |
          |   *           *|*           *   |
          |  *             |             *  |
          | *              |              * |
      0   +*---------------+---------------*+
          | *              |              * |
          |  *             |             *  |
          |   *           *|*           *   |
          |    ***     *** | ***     ***    |
          |       *****    |    *****       |
     -1   +----------------+----------------+
          |                |                |
```

We generate points (u, v) in the square [-1, 1) × [-1, 1). We **reject** points outside the unit circle (where s = u² + v² >= 1). We **accept** points inside the circle.

**Acceptance rate**:
```
Area of circle / Area of square = π / 4 ≈ 0.785 (78.5%)
```

So ~21.5% of points are rejected.

Step 4-5: **Transform to Normal**

Once we have a point (u, v) inside the unit circle, we compute:
```
m = √(-2 ln(s) / s)
z₁ = u * m
z₂ = v * m
```

This transformation (derived from Box-Muller but avoiding trig) produces two independent standard normals.

### Why This Is Faster

**Operations used**:
- ✓ Multiplication, addition, subtraction: Fast
- ✓ Square root: Moderate (~20 cycles)
- ✓ Natural log: Moderate (~25 cycles)
- ✗ No trigonometric functions: Avoided!

Even accounting for the 21.5% rejection rate, Marsaglia Polar is **faster** than Box-Muller.

## The Spare Value Optimization

Notice that each iteration produces **two** normal values (z₁ and z₂), but we usually only need **one** at a time.

**Optimization**: Cache the spare!

```c
typedef struct {
    int has_spare;      // Do we have a cached value?
    double spare;       // The cached value
} normal_polar_t;
```

**Flow**:
1. First call: Generate both z₁ and z₂, return z₁, cache z₂
2. Second call: Return cached z₂ (no RNG calls needed!)
3. Third call: Generate new pair, return z₁, cache z₂
4. And so on...

This effectively **halves** the number of RNG calls needed.

## The C Implementation

Let's examine the actual code from `c/ou_bench.c:74-100`:

```c
typedef struct {
    int has_spare;
    double spare;
} normal_polar_t;

static inline void normal_polar_init(normal_polar_t *n) {
    n->has_spare = 0;
    n->spare = 0.0;
}

static inline double normal_polar_next(normal_polar_t *n, xorshift128_t *rng) {
    // If we have a cached spare, return it
    if (n->has_spare) {
        n->has_spare = 0;
        return n->spare;
    }

    // Rejection sampling loop
    for (;;) {
        double u = 2.0 * xorshift128_next_f64(rng) - 1.0;  // [-1, 1)
        double v = 2.0 * xorshift128_next_f64(rng) - 1.0;  // [-1, 1)
        double s = u*u + v*v;

        // Accept if inside unit circle and not at origin
        if (s > 0.0 && s < 1.0) {
            double m = sqrt((-2.0 * log(s)) / s);
            n->spare = v * m;    // Cache z₂
            n->has_spare = 1;
            return u * m;        // Return z₁
        }
    }
}
```

### Step-by-Step Trace

Let's manually trace one call with these uniform random values:

**Attempt 1**:
```
U₁ = 0.6, U₂ = 0.9
u = 2*0.6 - 1 = 0.2
v = 2*0.9 - 1 = 0.8
s = 0.2² + 0.8² = 0.04 + 0.64 = 0.68
```

Check: `0 < s < 1` ✓ (Accept!)

```
m = √(-2 * ln(0.68) / 0.68)
m = √(-2 * (-0.3857) / 0.68)
m = √(0.7714 / 0.68)
m = √1.1344
m = 1.0651

z₁ = u * m = 0.2 * 1.0651 = 0.2130
z₂ = v * m = 0.8 * 1.0651 = 0.8521
```

Return: 0.2130 (cache 0.8521 for next call)

**Attempt 2** (rejected example):
```
U₁ = 0.9, U₂ = 0.95
u = 2*0.9 - 1 = 0.8
v = 2*0.95 - 1 = 0.9
s = 0.8² + 0.9² = 0.64 + 0.81 = 1.45
```

Check: `s >= 1` ✗ (Reject! Try again)

The loop continues until a point inside the circle is found.

## Cross-Language Implementations

All five languages implement the same logic. Let's compare:

### Rust Implementation

From `rust/src/main.rs:68-100`:

```rust
#[derive(Clone, Copy)]
struct NormalPolar {
    has_spare: bool,
    spare: f64,
}

impl NormalPolar {
    fn new() -> Self {
        Self {
            has_spare: false,
            spare: 0.0,
        }
    }

    #[inline(always)]
    fn next_standard(&mut self, rng: &mut XorShift128) -> f64 {
        if self.has_spare {
            self.has_spare = false;
            return self.spare;
        }

        loop {
            let u = 2.0 * rng.next_f64() - 1.0;
            let v = 2.0 * rng.next_f64() - 1.0;
            let s = u * u + v * v;
            if s > 0.0 && s < 1.0 {
                let m = (-2.0 * s.ln() / s).sqrt();
                self.spare = v * m;
                self.has_spare = true;
                return u * m;
            }
        }
    }
}
```

**Key differences**:
- Uses `loop` instead of `for (;;)`
- `s.ln()` and `.sqrt()` are methods on f64
- Pattern is identical to C

### TypeScript (Bun runtime) Implementation

From `ts/ou_bench.ts:124-145`:

```typescript
class NormalPolar {
  private hasSpare = false;
  private spare = 0.0;

  nextStandard(rng: XorShift128): number {
    if (this.hasSpare) {
      this.hasSpare = false;
      return this.spare;
    }
    while (true) {
      const u = 2.0 * rng.nextF64() - 1.0;
      const v = 2.0 * rng.nextF64() - 1.0;
      const s = u * u + v * v;
      if (s > 0.0 && s < 1.0) {
        const m = Math.sqrt((-2.0 * Math.log(s)) / s);
        this.spare = v * m;
        this.hasSpare = true;
        return u * m;
      }
    }
  }
}
```

**Key differences**:
- Uses `Math.sqrt()` and `Math.log()`
- `while (true)` instead of `for (;;)`
- Class-based with private fields
- Logic is identical

### Zig Implementation

From `zig/ou_bench.zig:119-140`:

```zig
const NormalPolar = struct {
    has_spare: bool = false,
    spare: f64 = 0.0,

    inline fn next(self: *NormalPolar, rng: *XorShift128) f64 {
        if (self.has_spare) {
            self.has_spare = false;
            return self.spare;
        }
        while (true) {
            const u = 2.0 * rng.nextF64() - 1.0;
            const v = 2.0 * rng.nextF64() - 1.0;
            const s = u * u + v * v;
            if (s > 0.0 and s < 1.0) {
                const m = @sqrt((-2.0 * @log(s)) / s);
                self.spare = v * m;
                self.has_spare = true;
                return u * m;
            }
        }
    }
};
```

**Key differences**:
- Uses `@sqrt()` and `@log()` builtins
- `and` instead of `&&`
- `const` for immutable values
- Logic is identical

### Swift Implementation

From `swift/ou_bench.swift:116-137`:

```swift
struct NormalPolar {
    var hasSpare: Bool = false
    var spare: Double = 0.0

    mutating func nextStandard(rng: inout XorShift128) -> Double {
        if hasSpare {
            hasSpare = false
            return spare
        }
        while true {
            let u = 2.0 * rng.nextF64() - 1.0
            let v = 2.0 * rng.nextF64() - 1.0
            let s = u * u + v * v
            if s > 0.0 && s < 1.0 {
                let m = sqrt((-2.0 * log(s)) / s)
                spare = v * m
                hasSpare = true
                return u * m
            }
        }
    }
}
```

**Key differences**:
- Uses `sqrt()` and `log()` from Foundation
- `mutating` keyword for struct modification
- `inout` parameter for RNG
- Logic is identical

### Output Consistency

All five implementations produce **identical sequences** for the same RNG seed because:
1. The RNG is identical (XorShift128)
2. The algorithm is identical (Marsaglia Polar)
3. IEEE 754 floating-point is standardized

Minor differences (< 0.0001%) may occur due to:
- Different math library implementations (`log`, `sqrt`)
- Rounding modes
- Compiler optimizations

For our benchmark, these differences are negligible.

## Statistical Validation

### Verifying Normality

How do we know this actually produces a normal distribution? We can:

1. **Visual check**: Histogram should look like a bell curve
2. **Statistical tests**: Kolmogorov-Smirnov test, Anderson-Darling test
3. **Moment check**: Mean ≈ 0, Standard deviation ≈ 1

**Python validation**:
```python
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats

# Generate 100,000 samples
rng = XorShift128(seed=1)
norm = NormalPolar()
samples = [norm.next_standard(rng) for _ in range(100_000)]

# Check mean and std
print(f"Mean: {np.mean(samples):.6f}")  # Should be ≈ 0
print(f"Std:  {np.std(samples):.6f}")   # Should be ≈ 1

# Histogram
plt.hist(samples, bins=50, density=True, alpha=0.7, label='Samples')

# Overlay theoretical N(0,1)
x = np.linspace(-4, 4, 100)
plt.plot(x, stats.norm.pdf(x), 'r-', label='N(0,1)')
plt.legend()
plt.show()

# Statistical test
ks_stat, p_value = stats.kstest(samples, 'norm')
print(f"KS test p-value: {p_value:.6f}")  # Should be > 0.05
```

If implemented correctly, you'll see:
```
Mean: 0.000234
Std:  1.000891
KS test p-value: 0.234567
```

The histogram overlaps the theoretical curve perfectly.

## Performance Analysis

### Operation Costs

For each normal value generated (amortized):

| Operation | Count per Call | Cycles Each | Total Cycles |
|-----------|----------------|-------------|--------------|
| RNG calls | ~2.7 (accounting for rejection) | 2-3 | ~7 |
| Multiply | 5 | 3-5 | ~20 |
| Add/Subtract | 4 | 1 | ~4 |
| Square root | 1 | ~20 | ~20 |
| Natural log | 1 | ~25 | ~25 |
| Comparison | ~1.3 | 1 | ~2 |
| **Total** | | | **~78 cycles** |

With the spare value optimization:
- Half the calls return cached value immediately (~2 cycles)
- Half the calls do full computation (~78 cycles)
- **Average: ~40 cycles per normal value**

### Comparison to Box-Muller

Box-Muller (without caching):

| Operation | Cycles |
|-----------|--------|
| 2 RNG calls | ~6 |
| Natural log | ~25 |
| cos | ~40 |
| sin | ~40 |
| Multiply | ~15 |
| **Total** | **~126 cycles** |

Marsaglia Polar is **~3× faster** than Box-Muller!

### Comparison to Ziggurat

The **Ziggurat algorithm** is even faster (~10-15 cycles per value), but:
- Much more complex to implement (200+ lines)
- Requires lookup tables (128+ entries)
- Harder to verify correctness
- Difficult to ensure identical implementation across languages

For our benchmark, Marsaglia Polar is the **sweet spot** of simplicity and performance.

## Common Pitfalls

### ❌ Forgetting the Spare

Without caching the second value:

```c
// BAD: Wasteful implementation
double normal_polar_next_bad(xorshift128_t *rng) {
    for (;;) {
        double u = 2.0 * xorshift128_next_f64(rng) - 1.0;
        double v = 2.0 * xorshift128_next_f64(rng) - 1.0;
        double s = u*u + v*v;
        if (s > 0.0 && s < 1.0) {
            double m = sqrt((-2.0 * log(s)) / s);
            return u * m;  // Discard v * m!
        }
    }
}
```

This **throws away** half the work! Always cache the spare.

### ❌ Wrong Rejection Condition

```c
// BAD: Missing s > 0 check
if (s < 1.0) {  // What if s == 0?
    double m = sqrt((-2.0 * log(s)) / s);  // Division by zero!
    ...
}
```

Must check `s > 0.0 && s < 1.0` to avoid:
- Division by zero
- Logarithm of zero (undefined)

### ❌ Using s <= 1.0

```c
// BAD: Accepting points on the boundary
if (s > 0.0 && s <= 1.0) {  // Wrong!
    ...
}
```

Points exactly on the circle (s = 1.0) should be rejected. The algorithm requires s < 1.0 strictly.

### ❌ Non-Thread-Safe Spare

In multi-threaded code:

```c
// BAD: Global state
static int has_spare = 0;
static double spare = 0.0;

double normal_polar_next(xorshift128_t *rng) {
    if (has_spare) {  // Race condition!
        has_spare = 0;
        return spare;
    }
    ...
}
```

Two threads might both see `has_spare = 1`, both return `spare`, both set `has_spare = 0`. This breaks the algorithm!

**Solution**: Use thread-local storage or pass state explicitly (as we do).

## Exercises

### Exercise 1: Implement Marsaglia Polar in Python

Write a complete implementation:

```python
import random
import math

class NormalPolar:
    def __init__(self):
        self.has_spare = False
        self.spare = 0.0

    def next_standard(self, rng):
        # Your code here
        pass

# Test it
rng = XorShift128(seed=1)
norm = NormalPolar()
samples = [norm.next_standard(rng) for _ in range(10)]
print(samples)
```

Verify:
1. Mean of 100,000 samples is near 0
2. Standard deviation is near 1
3. Values range roughly from -3 to +3 (99.7% rule)

### Exercise 2: Rejection Rate

Modify the implementation to count rejections:

```python
rejections = 0
acceptances = 0

# Inside the loop
if s >= 1.0 or s <= 0.0:
    rejections += 1
else:
    acceptances += 1
    # ... rest of acceptance logic

# After generating 100,000 normals (50,000 pairs)
print(f"Rejection rate: {rejections / (rejections + acceptances):.2%}")
```

What rejection rate do you observe? It should be around 21-22%.

### Exercise 3: Compare to Box-Muller

Implement basic Box-Muller (without rejection sampling):

```python
def box_muller(rng):
    u1 = rng.next_f64()
    u2 = rng.next_f64()
    z1 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    z2 = math.sqrt(-2 * math.log(u1)) * math.sin(2 * math.pi * u2)
    return z1, z2
```

Compare:
1. Do both produce the same distribution? (histogram)
2. Which is faster? (time 1 million calls)

### Exercise 4: Visualize Rejection Sampling

Plot the accepted and rejected points:

```python
import matplotlib.pyplot as plt

accepted_x, accepted_y = [], []
rejected_x, rejected_y = [], []

rng = XorShift128(seed=1)
for _ in range(1000):
    u = 2.0 * rng.next_f64() - 1.0
    v = 2.0 * rng.next_f64() - 1.0
    s = u*u + v*v
    if 0.0 < s < 1.0:
        accepted_x.append(u)
        accepted_y.append(v)
    else:
        rejected_x.append(u)
        rejected_y.append(v)

plt.scatter(accepted_x, accepted_y, c='green', s=1, label='Accepted')
plt.scatter(rejected_x, rejected_y, c='red', s=1, label='Rejected')
circle = plt.Circle((0, 0), 1, fill=False, color='blue')
plt.gca().add_patch(circle)
plt.axis('equal')
plt.legend()
plt.show()
```

You should see green points inside the circle, red points outside.

### Exercise 5: Spare Value Impact

Measure the performance difference with and without spare caching:

```python
import time

# With spare
rng1 = XorShift128(seed=1)
norm1 = NormalPolar()  # Has spare caching
start = time.time()
for _ in range(1_000_000):
    norm1.next_standard(rng1)
with_spare = time.time() - start

# Without spare (modify NormalPolar to always recompute)
rng2 = XorShift128(seed=1)
norm2 = NormalPolarNoSpare()
start = time.time()
for _ in range(1_000_000):
    norm2.next_standard(rng2)
without_spare = time.time() - start

print(f"With spare:    {with_spare:.3f}s")
print(f"Without spare: {without_spare:.3f}s")
print(f"Speedup:       {without_spare / with_spare:.2f}x")
```

Expected speedup: ~1.8-2.0×

## Advanced Topics

### Why Does Marsaglia Polar Work?

The mathematical proof:

1. **Uniform disk sampling**: Points (u, v) uniformly distributed inside unit circle
2. **Polar coordinates**: Convert to (r, θ) where r² = s, θ = arctan(v/u)
3. **Independence**: r and θ are independent
4. **Transformation**: The mapping (u, v) → (u*m, v*m) transforms uniform disk to bivariate normal

The key insight: Points uniformly distributed on a disk, when scaled by the right function, become normally distributed on each axis.

### Connection to Box-Muller

Marsaglia Polar is Box-Muller in disguise:

**Box-Muller**:
```
z₁ = √(-2 ln U₁) * cos(2π U₂)
z₂ = √(-2 ln U₁) * sin(2π U₂)
```

**Marsaglia Polar** (after acceptance):
```
m = √(-2 ln(s) / s)
z₁ = u * m
z₂ = v * m
```

Since u/√s = cos(θ) and v/√s = sin(θ) (polar coordinates), we have:
```
z₁ = u * m = (√s * cos θ) * (√(-2 ln s) / √s) = √(-2 ln s) * cos θ
z₂ = v * m = (√s * sin θ) * (√(-2 ln s) / √s) = √(-2 ln s) * sin θ
```

If we let s = U₁ (both are uniform in [0, 1)), this is exactly Box-Muller! Marsaglia Polar avoids computing θ explicitly by using rejection sampling.

### Alternative: Ziggurat Algorithm

The Ziggurat algorithm divides the normal PDF into horizontal slices:

```
     |     ___
     |   _|   |_
     |  |  ___  |
     | _|_|   |_|_
     ||___|   |___|
     +--------------> x
```

Most samples are drawn from the rectangular core (fast). Rare samples fall in tail regions (slower). On average: ~10-15 cycles per sample.

**Why we don't use it**:
- Complex implementation (100+ lines)
- Requires lookup tables (language-specific initialization)
- Harder to verify identical behavior across languages
- Overkill for our benchmark (normal generation is only ~30% of runtime)

## Practical Usage in Our Benchmark

From `c/ou_bench.c:223-228`:

```c
// Initialize normal sampler
normal_polar_t norm;
normal_polar_init(&norm);

// Generate N-1 scaled normal random numbers
for (size_t i = 0; i < n - 1; i++) {
    gn[i] = diff * normal_polar_next(&norm, &rng);
}
```

Where `diff = sigma * sqrt(dt)` (from Chapter 1). This generates:
```
gn[i] ~ N(0, sigma² * dt)
```

These are the random "kicks" applied in the OU simulation.

## Summary

Normal distribution sampling in our benchmark:

1. **Algorithm**: Marsaglia Polar Method
   - Rejection sampling inside unit circle
   - Transforms uniform to normal via logarithm and square root
   - Avoids expensive trigonometric functions

2. **Key optimizations**:
   - Spare value caching (2× faster)
   - Simple operations (no trig)
   - Inline functions (no call overhead)

3. **Properties**:
   - Exact normal distribution (not approximate)
   - ~21% rejection rate
   - ~40 cycles per value (amortized)
   - Identical across all five languages

4. **Integration**:
   - Uses XorShift128 for uniform input
   - Produces standard normals N(0, 1)
   - Scaled by σ√(dt) for OU process

This provides the **random noise** component of the Ornstein-Uhlenbeck process.

---

**Previous**: [Chapter 2: Random Number Generation Deep Dive](02-random-numbers.md)
**Next**: [Chapter 4: C Implementation - The Baseline](04-c-implementation.md)

## References

- [Marsaglia Polar Method (Wikipedia)](https://en.wikipedia.org/wiki/Marsaglia_polar_method)
- Marsaglia, G.; Bray, T. A. (1964). "A Convenient Method for Generating Normal Variables"
- [Box-Muller Transform](https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform)
- [Normal Distribution (Wikipedia)](https://en.wikipedia.org/wiki/Normal_distribution)
- [Ziggurat Algorithm](https://en.wikipedia.org/wiki/Ziggurat_algorithm)
- Marsaglia, G.; Tsang, W. W. (2000). "The Ziggurat Method for Generating Random Variables"
