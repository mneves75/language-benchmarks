# Understanding Programming Language Performance: A Fair Comparison

**Date:** December 2025
**Reading Time:** 8 minutes
**Level:** Beginner-Friendly

---

## What is This Project About?

Welcome! This project is a **fair and scientific comparison** of how fast different programming languages can perform the same mathematical calculation. Think of it as a race where all runners follow the exact same route, use the same running technique, and start at the same time—that way, we know the results truly reflect each runner's speed, not differences in the course.

We're comparing five popular programming languages:
- **TypeScript** (running on Bun, a fast JavaScript runtime)
- **Rust** (a modern systems programming language)
- **Zig** (a new low-level language focused on performance)
- **C** (the classic, foundational language)
- **Swift** (Apple's modern language)

## What Problem Are We Solving?

Imagine you're a scientist studying how a stock price moves over time, or how a particle bounces around in water. These natural processes have a special property: they're **random, but with a tendency to return to an average value**.

This behavior is called an **Ornstein-Uhlenbeck (OU) process**, and it's used in:
- **Finance**: Modeling interest rates and stock volatility
- **Physics**: Describing particle movement in fluids
- **Biology**: Tracking population dynamics
- **Engineering**: Control systems and signal processing

### Breaking Down "Ornstein-Uhlenbeck Process"

Let's make this super simple:

1. **Random Movement**: Imagine a drunk person walking down a street. Each step is random—left or right, big or small.

2. **Mean Reversion**: But there's a twist! This person really wants to stay near their home (the "mean" or average position). The farther they wander away, the stronger the pull back home becomes.

3. **The OU Process**: This is exactly what an OU process does mathematically. It's random movement with a rubber band pulling it back to center.

**Real Example**: Your room temperature. It fluctuates randomly (door opens, sun comes in), but your heater/AC constantly pulls it back toward your target temperature (like 72°F).

## Why Do We Need a Benchmark?

When people argue about which programming language is "fastest," they often compare apples to oranges. One implementation might use a different algorithm, or skip important steps, making the comparison unfair.

Our benchmark is different because:

### ✅ **Identical Algorithms**
All five languages use:
- The **same random number generator** (xorshift128)
- The **same way to create random numbers** (Marsaglia polar method)
- The **same simulation formula** (Euler method)
- The **same mathematical operations**

### ✅ **Apples-to-Apples Comparison**
Think of it like comparing car speeds on the same track, same weather, same fuel. We're measuring pure language performance, not programmer cleverness.

### ✅ **Maximum Optimization**
Each language is compiled/run with the best possible performance settings:
- **Rust**: Native CPU instructions, link-time optimization
- **C**: Maximum optimization (`-O3`), fast math operations
- **Zig**: Release-fast mode, native CPU features
- **Swift**: Unchecked mode (maximum speed)
- **TypeScript**: Bun's ultra-fast JavaScript engine

## What Does the Benchmark Actually Do?

Here's the step-by-step process:

### Step 1: Generate Random Numbers
The program creates thousands of random numbers following a "normal distribution" (the famous bell curve). This simulates the random "kicks" that push our process around.

### Step 2: Simulate the OU Process
Using those random numbers, we calculate how our process evolves over time, step by step, always being pulled back toward the average value.

### Step 3: Calculate a Checksum
We add up all the values to get a single number. This prevents the compiler from being "lazy" and skipping calculations it thinks are unused.

### Step 4: Repeat and Time It
We do this entire process many times (default: 1,000 runs) and measure how long it takes. We also do "warmup" runs first to let the computer get ready (like warming up before a race).

## The Three Stages We Measure

Each run is split into three timed sections:

1. **`gen_normals`**: How fast can we generate random numbers?
2. **`simulate`**: How fast can we run the mathematical simulation?
3. **`checksum`**: How fast can we sum up all the results?

This breakdown helps us understand which part is fastest in each language.

## How to Run the Benchmark

### Run Everything at Once
The easiest way is to run all languages and compare:

```bash
./run_all.sh
```

This runs all five implementations with sensible defaults and shows you the results.

### Customize the Run
You can adjust the parameters:

```bash
./run_all.sh 1000000 500 10 42
```

This means:
- Simulate **1,000,000** steps
- Run **500** times
- Do **10** warmup runs
- Use seed **42** (for reproducible randomness)

### Run Individual Languages

**TypeScript (Bun):**
```bash
cd ts && bun run ou_bench.ts --n=500000 --runs=1000
```

**Rust:**
```bash
cd rust && cargo run --release -- --n=500000 --runs=1000
```

**C:**
```bash
cd c && cc -O3 -ffast-math -march=native ou_bench.c -lm -o ou_bench_c
./ou_bench_c --n=500000 --runs=1000
```

**Zig:**
```bash
cd zig && zig build-exe ou_bench.zig -O ReleaseFast -mcpu=native
./ou_bench --n=500000 --runs=1000
```

**Swift:**
```bash
cd swift && swiftc -Ounchecked -whole-module-optimization ou_bench.swift -o ou_bench_swift
./ou_bench_swift --n=500000 --runs=1000
```

## Understanding the Results

After running, you'll see output like:

```
Language: Rust
Average time per run: 12.34 ms
  - gen_normals: 5.67 ms
  - simulate: 4.23 ms
  - checksum: 2.44 ms
```

**What this tells you:**
- **Total time**: How long one complete simulation takes
- **Breakdown**: Which part (random numbers, simulation, or checksum) takes the most time
- **Comparison**: Run all languages to see which is fastest overall

### Important Note on Checksums

You might notice the final checksum number differs slightly between languages. This is **normal and expected**! Here's why:

- Different languages use different math libraries
- Aggressive optimization flags can reorder operations
- Floating-point math isn't perfectly precise

Small differences (in the 5th or 6th decimal place) don't mean the implementation is wrong—they're just natural variations in how computers do math.

## What Can You Learn From This?

### For Beginners:
1. **See Real Code**: Compare how the same algorithm looks in five different languages
2. **Understand Performance**: Learn what makes code fast or slow
3. **Learn Patterns**: See how random number generation and simulation work

### For Intermediate Developers:
1. **Language Characteristics**: Understand trade-offs between languages
2. **Optimization Techniques**: See how compiler flags affect performance
3. **Benchmarking Methods**: Learn how to create fair comparisons

### For Advanced Users:
1. **Low-Level Details**: Study how different languages optimize the same operations
2. **Compiler Insights**: See the impact of LTO, CPU-specific instructions, and math optimizations
3. **Scientific Computing**: Understand patterns used in real-world simulations

## The Fairness Factor

What makes this benchmark special:

| ✅ Fair | ❌ Unfair (other benchmarks) |
|---------|------------------------------|
| Same algorithm in all languages | Different algorithms per language |
| Maximum optimization for each | Inconsistent compiler flags |
| Same random seed | Different random sequences |
| Timed regions exclude setup | Include parsing and allocation |
| Identical mathematical operations | Shortcuts or approximations |

## Next Steps

Want to dive deeper?

1. **Read the Code**: Start with `ts/ou_bench.ts` (most readable) then compare others
2. **Modify Parameters**: Try different values of `n`, see how time scales
3. **Add Your Language**: Implement the same algorithm in your favorite language
4. **Study the Math**: Learn more about [Ornstein-Uhlenbeck processes](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process)
5. **Optimize Further**: Can you make any implementation faster while keeping it fair?

## Conclusion

This benchmark isn't about proving one language is "the best"—it's about understanding trade-offs and seeing how different languages approach the same problem. Each language has strengths:

- **C**: Raw speed, close to the metal
- **Rust**: Speed + safety, modern tooling
- **Zig**: Simplicity + control
- **Swift**: Apple ecosystem, modern syntax
- **TypeScript/Bun**: Familiar syntax, surprisingly fast

The "best" language depends on your project's needs: development speed, safety requirements, ecosystem, team expertise, and yes—raw performance.

**Happy benchmarking!** 🚀

---

## Resources

- **Project Repository**: [View on GitHub]
- **Original Inspiration**: [Scientific Computing Benchmark: Rust vs Zig vs C](https://rust-dd.com/post/crab-scientific-computing-benchmark-rust-crab-vs-zig-zap-vs-the-father-c-older_man)
- **OU Process Theory**: [Wikipedia Article](https://en.wikipedia.org/wiki/Ornstein%E2%80%93Uhlenbeck_process)
- **Questions?**: Open an issue in the repository

---

*This project is open source and welcomes contributions. If you find bugs, have suggestions, or want to add more languages, please contribute!*
