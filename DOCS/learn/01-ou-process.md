# Chapter 1: The Ornstein-Uhlenbeck Process Explained Simply

## The Rubber Band in Water Analogy

Imagine you have a small bead attached to a rubber band, and you drop it into a glass of water. What happens?

1. The **rubber band pulls** the bead back toward the center
2. The **water molecules randomly jostle** the bead around
3. The bead settles into a **random dance** around the center point

This is essentially what an Ornstein-Uhlenbeck (OU) process models. It's a mathematical way to describe things that:
- Are pulled toward a central value (mean reversion)
- Experience random fluctuations (noise)
- Have memory of their past position

## Real-World Examples

### 1. Stock Prices (Finance)

Stock prices don't just wander randomly forever. They tend to:
- Revert to fundamental values (the rubber band)
- Experience random market shocks (the water jostling)

### 2. Temperature (Physics)

A heated object cooling down:
- Pulls toward room temperature (mean reversion)
- Has random molecular motion (noise)

### 3. Heart Rate (Biology)

Your heart rate when exercising:
- Returns to resting rate when you stop (mean reversion)
- Has slight variations beat-to-beat (noise)

## The Mathematical Formula (Don't Panic!)

The OU process is defined by this differential equation:

```
dX(t) = θ(μ - X(t))dt + σdW(t)
```

Let's break this down piece by piece, using our bead analogy:

### X(t) - Current Position

This is where the bead is **right now** at time `t`. In our code, this is the value we're tracking.

### θ(μ - X(t))dt - The Rubber Band Pull

- **μ (mu)**: Where the center is (where the rubber band is attached)
- **X(t)**: Where the bead currently is
- **(μ - X(t))**: How far the bead is from center
- **θ (theta)**: How strong the rubber band is
- **dt**: A tiny step in time

So `θ(μ - X(t))dt` means: **pull toward center proportional to distance**

If the bead is far from center → strong pull
If the bead is near center → weak pull

### σdW(t) - The Random Jostling

- **σ (sigma)**: How violent the water is (volatility)
- **dW(t)**: Random kick from water molecules (Brownian motion)

This adds **randomness** to the movement.

## The Discrete Version (What We Actually Code)

Computers can't handle infinitely small time steps (dt → 0). We need a **discrete approximation**. This is called the **Euler-Maruyama method**:

```
X(t + dt) = X(t) + θ(μ - X(t))dt + σ√(dt) * N(0,1)
```

In plain English:
```
Next position = Current position + pull toward center + random kick
```

Let's see this in our C code (`c/ou_bench.c:181-190`):

```c
const double T = 1.0;        // Total time
const double theta = 1.0;    // Rubber band strength
const double mu = 0.0;       // Center point
const double sigma = 0.1;    // Noise level

const double dt = T / (double)n;           // Time step
const double a = 1.0 - theta * dt;         // Pull coefficient
const double b = theta * mu * dt;          // Center pull
const double diff = sigma * sqrt(dt);      // Noise scaling
```

Then in the simulation loop (`c/ou_bench.c:278-283`):

```c
double x = 0.0;
ou[0] = x;
for (size_t i = 1; i < n; i++) {
    x = a * x + b + gn[i - 1];  // gn[i-1] is random noise
    ou[i] = x;
}
```

This is equivalent to:
```
x_new = a * x_old + b + random_noise
```

Where:
- `a` = 1 - θ·dt (decay factor)
- `b` = θ·μ·dt (pull toward μ)
- `random_noise` = σ·√(dt)·N(0,1) (scaled random normal)

## Step-by-Step Example

Let's simulate 5 steps by hand (using made-up random numbers):

**Setup**:
- θ = 1.0, μ = 0.0, σ = 0.1
- dt = 0.2
- a = 1 - 1.0×0.2 = 0.8
- b = 1.0×0.0×0.2 = 0.0
- diff = 0.1×√0.2 ≈ 0.0447

**Simulation** (starting at X₀ = 0):

| Step | Current X | Random N(0,1) | Noise = diff×N | New X = 0.8×X + noise |
|------|-----------|---------------|----------------|------------------------|
| 0    | 0.0       | -             | -              | 0.0                    |
| 1    | 0.0       | +1.2          | +0.054         | 0.0 + 0.054 = 0.054    |
| 2    | 0.054     | -0.8          | -0.036         | 0.043 - 0.036 = 0.007  |
| 3    | 0.007     | +0.3          | +0.013         | 0.006 + 0.013 = 0.019  |
| 4    | 0.019     | -1.5          | -0.067         | 0.015 - 0.067 = -0.052 |
| 5    | -0.052    | +0.5          | +0.022         | -0.042 + 0.022 = -0.020|

Notice how the value **fluctuates around zero** (μ = 0). This is mean reversion in action!

## Why This Makes a Good Benchmark

### 1. Computationally Representative

The OU simulation requires:
- **Floating-point arithmetic** (multiplication, addition)
- **Array access** (memory bandwidth)
- **Tight loops** (branch prediction, cache usage)
- **Random number generation** (bit operations)

This mixture is similar to many real-world applications: scientific computing, finance, simulations.

### 2. Can't Be Over-Optimized

Some benchmarks are trivial and compilers optimize them to nothing. The OU process is complex enough that:
- Compilers can't eliminate the work
- It's not so complex that only one language can handle it
- Different languages can use the same algorithm

### 3. Mathematically Well-Defined

There's a single correct algorithm (Euler-Maruyama). We're not comparing apples to oranges.

### 4. Scales Linearly

Want a longer benchmark? Increase `n` (number of points). The work scales proportionally, making it easy to test different problem sizes.

## The Parameters We Use

In our benchmark, we use these values (found in all implementations):

```c
const double T = 1.0;        // Simulate 1 time unit
const double theta = 1.0;    // Moderate mean reversion
const double mu = 0.0;       // Revert to zero
const double sigma = 0.1;    // Low noise level
```

With default `n = 500,000`:
```c
const double dt = T / (double)n;  // dt = 1/500000 = 0.000002
```

This means we're simulating 1 time unit divided into 500,000 tiny steps.

## Visualizing the Process

If we were to plot the OU process, it would look like:

```
 X
 ^
 |     /\    /\/\
 |    /  \  /    \    /\
 |___/____\/_______\__/__\___> time
 |        \/         \/
 |
```

The process:
- Fluctuates around μ = 0 (the horizontal line)
- Has random ups and downs
- Never drifts infinitely far from zero (mean reversion)

Compare this to pure random walk (no mean reversion):

```
 X
 ^              /\
 |            /    \
 |          /        \    /\
 |        /            \/    \
 |______/                      \___> time
```

A random walk can drift arbitrarily far, while OU is "tethered" to μ.

## The Three Stages of Our Benchmark

Looking at `c/ou_bench.c:271-294`, each benchmark run has three stages:

### Stage 1: Generate Normal Random Numbers (gen_normals)

```c
for (size_t i = 0; i < n - 1; i++) {
    gn[i] = diff * normal_polar_next(&norm, &rng);
}
```

This generates 499,999 random normally-distributed numbers. This is the random "jostling" we'll apply at each step.

**Time**: ~70% of total (RNG is expensive!)

### Stage 2: Simulate OU Process (simulate)

```c
double x = 0.0;
ou[0] = x;
for (size_t i = 1; i < n; i++) {
    x = a * x + b + gn[i - 1];
    ou[i] = x;
}
```

Apply the discrete OU formula 500,000 times.

**Time**: ~20% of total (just arithmetic)

### Stage 3: Checksum (checksum)

```c
double s = 0.0;
for (size_t i = 0; i < n; i++) s += ou[i];
checksum += s;
```

Sum all values to prevent compiler optimizations from eliminating the work.

**Time**: ~10% of total (memory access)

## Understanding Mean Reversion Intuitively

### Without Mean Reversion (Random Walk)

Imagine flipping a coin:
- Heads: +1
- Tails: -1

After 1000 flips, you might be at +50, -30, +200, anywhere. No tendency to return to zero.

### With Mean Reversion (OU Process)

Now imagine a coin where:
- If you're above 0: more likely to flip Tails (pull down)
- If you're below 0: more likely to flip Heads (pull up)
- The further you are, the stronger the pull

After 1000 flips, you'll be **near zero** most of the time.

## Why θ (Theta) Matters

**θ controls mean reversion speed**:

- **θ = 0**: No mean reversion (pure random walk)
- **θ = 0.5**: Slow return to center
- **θ = 1.0**: Moderate return (our choice)
- **θ = 5.0**: Rapid return to center

In our code, θ = 1.0 means the process returns to μ at a moderate rate.

## Why σ (Sigma) Matters

**σ controls volatility**:

- **σ = 0**: No randomness (deterministic decay to μ)
- **σ = 0.01**: Tiny fluctuations
- **σ = 0.1**: Small fluctuations (our choice)
- **σ = 1.0**: Large fluctuations

We use σ = 0.1 for modest noise that doesn't overwhelm the mean reversion.

## Mathematical Deep Dive (Optional)

### The Continuous Time Limit

As dt → 0, the Euler-Maruyama approximation converges to the true OU process. Our dt = 0.000002 is small enough for high accuracy.

### Stationary Distribution

In the long run (t → ∞), an OU process with θ > 0 reaches a **stationary distribution**:

```
X ~ N(μ, σ²/(2θ))
```

For our parameters (μ=0, σ=0.1, θ=1):
```
X ~ N(0, 0.01/2) = N(0, 0.005)
```

This means the process eventually fluctuates around 0 with standard deviation ≈ 0.071.

### Autocorrelation

OU processes have **exponentially decaying correlation**:

```
Cor(X(t), X(t+s)) = exp(-θs)
```

This means:
- Nearby times are correlated
- Distant times are nearly independent
- The correlation decays at rate θ

## Code Verification

Let's verify our code matches the mathematics. Looking at the update formula:

**Mathematical**:
```
X_{i+1} = X_i + θ(μ - X_i)dt + σ√(dt)·N(0,1)
        = X_i(1 - θdt) + θμdt + σ√(dt)·N(0,1)
```

**Code** (`c/ou_bench.c:281`):
```c
x = a * x + b + gn[i - 1]
```

Where:
- `a` = 1 - θdt ✓
- `b` = θμdt ✓
- `gn[i-1]` = σ√(dt)·N(0,1) ✓

Perfect match!

## Exercise 1: Modify Parameters

Try changing the parameters and observe the behavior:

1. **Increase θ to 5.0**
   - What happens to the trajectory?
   - Does it stay closer to μ?

2. **Increase σ to 0.5**
   - Does the process become more "noisy"?
   - How does this affect runtime?

3. **Change μ to 1.0**
   - Does the process fluctuate around 1 instead of 0?

## Exercise 2: Plot the Process

Write a program to:
1. Run the OU simulation with n=1000
2. Save the trajectory to a file
3. Plot it using your favorite tool (Python matplotlib, gnuplot, Excel)

You should see mean reversion in action!

## Exercise 3: Implement in Python

Implement the OU process in Python to verify your understanding:

```python
import numpy as np

def ou_process(n, T, theta, mu, sigma, seed):
    np.random.seed(seed)
    dt = T / n
    a = 1.0 - theta * dt
    b = theta * mu * dt
    diff = sigma * np.sqrt(dt)

    x = np.zeros(n)
    x[0] = 0.0

    for i in range(1, n):
        noise = np.random.normal(0, 1)
        x[i] = a * x[i-1] + b + diff * noise

    return x

# Test it
trajectory = ou_process(500000, 1.0, 1.0, 0.0, 0.1, 1)
print(f"Final value: {trajectory[-1]}")
print(f"Mean: {np.mean(trajectory)}")
print(f"Std: {np.std(trajectory)}")
```

Expected output should show mean ≈ 0 and std ≈ 0.07.

## Common Misconceptions

### ❌ "OU is just random noise"

No! OU has **structure** (mean reversion). Pure noise is unpredictable in all directions.

### ❌ "Higher θ always gives smaller values"

No! θ controls the **rate** of return to μ, not the size of fluctuations. σ controls size.

### ❌ "The checksum stage is optional"

No! Without it, compilers might optimize away the entire simulation. The checksum forces actual computation.

## Summary

The Ornstein-Uhlenbeck process models:
1. **Mean reversion**: Pull toward central value μ
2. **Random fluctuation**: Noise with volatility σ
3. **Memory**: Current value depends on past (not pure random walk)

Our implementation uses:
- **Euler-Maruyama**: Discrete approximation
- **500,000 steps**: High accuracy
- **Three stages**: Generate noise, simulate, checksum

This provides a realistic, non-trivial benchmark for comparing programming languages.

---

**Previous**: [Chapter 0: Introduction](00-introduction.md)
**Next**: [Chapter 2: Random Number Generation Deep Dive](02-random-numbers.md)

## References

- [Ornstein-Uhlenbeck Process (Wikipedia)](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process)
- Uhlenbeck, G. E.; Ornstein, L. S. (1930). "On the Theory of the Brownian Motion"
- [Euler-Maruyama Method](https://en.wikipedia.org/wiki/Euler%E2%80%93Maruyama_method)
