# Chapter 0: Introduction - Understanding Language Benchmarks

## What You'll Learn

Welcome! This tutorial will teach you everything you need to know about performance benchmarking across different programming languages. By the end, you'll understand:

- What benchmarks are and why they matter
- How different programming languages handle the same task
- The math and algorithms behind our specific benchmark
- How to write performance-critical code in 5 different languages
- How to measure performance fairly and accurately

## What Is This Project?

This is a **multi-language benchmark** that compares how fast different programming languages can solve the same mathematical problem. Think of it like a race where five runners (C, Zig, Rust, TypeScript (Bun runtime), and Swift) all run the exact same course using the exact same technique - we're testing who's naturally faster, not who has better running shoes or knows shortcuts.

### The Five Languages We Compare

1. **C** - The grandfather of systems programming (created 1972)
2. **Zig** - Modern systems language focused on simplicity (2016)
3. **Rust** - Memory-safe systems language (2015)
4. **TypeScript (Bun runtime)** - JavaScript with types, running on a fast runtime (2012/2022)
5. **Swift** - Apple's modern language (2014)

### The Problem We're Solving

We're simulating something called an **Ornstein-Uhlenbeck process** - imagine modeling how a particle moves in water when it's being pulled toward a center point but also gets randomly jostled around. Don't worry if that sounds complex - we'll explain everything step by step.

## Why Benchmarks Matter

### Real-World Analogy

Imagine you're buying a car. The dealer says "This car is fast!" But how fast? Is it faster than other cars in the same price range? Does it handle curves well or just go fast in a straight line?

Benchmarks are like standardized tests for programming languages:
- They measure specific capabilities
- They use identical conditions for fair comparison
- They help you choose the right tool for your job

### What Makes a Good Benchmark?

A good benchmark is like a good scientific experiment. It must be:

1. **Fair** - Every language solves the exact same problem
2. **Reproducible** - Run it again, get similar results
3. **Realistic** - Tests something that matters in real applications
4. **Measurable** - Clear, quantitative results
5. **Transparent** - Code is open for review

Our benchmark satisfies all five criteria.

## The Current Results

Here's what we found (on MacBook Pro M4 Pro, 48GB RAM):

| Language | Average Time | Median Time | What This Means |
|----------|-------------|-------------|-----------------|
| C        | 3.71 ms     | 3.70 ms     | Baseline: raw speed |
| Zig      | 3.82 ms     | 3.82 ms     | Nearly C performance with safety |
| Rust     | 3.85 ms     | 3.84 ms     | Safe as Zig, competitive speed |
| TypeScript (Bun runtime) | 6.15 ms     | 6.13 ms     | Dynamic language, 65% slower |
| Swift    | 9.25 ms     | 9.25 ms     | Easiest to write, slowest here |

**Key Insight**: C is fastest, but Zig and Rust are within 3-5% while offering memory safety. Bun (JavaScript) is surprisingly competitive for a dynamic language. Swift is slower for this specific workload.

## What Makes Our Benchmark Special?

### 1. Algorithmic Parity

Every language uses **exactly the same algorithms**:
- Same random number generator (XorShift128)
- Same normal distribution sampler (Marsaglia polar method)
- Same numerical simulation (Euler method)

This is like making sure all five runners wear identical shoes and run the same distance.

### 2. Fair Measurement

We only measure the actual computation:
- Memory allocation happens **before** timing
- Argument parsing happens **before** timing
- JIT warmup (for Bun) happens **before** timing
- We use median, not average, to avoid outliers

### 3. Prevents Compiler Tricks

Compilers are smart and try to optimize away unnecessary work. We prevent this by:
- Computing a checksum of all results
- Printing the checksum so the compiler can't prove it's unused
- This forces all calculations to actually happen

See this code pattern in `c/ou_bench.c:286-288`:

```c
double s = 0.0;
for (size_t i = 0; i < n; i++) s += ou[i];
checksum += s;
```

Without this, a clever compiler might say "Hey, nobody uses these values!" and skip the entire simulation.

## How to Read This Tutorial

### For Complete Beginners

Start with Chapter 1 (The OU Process Explained) and read sequentially. Don't skip the exercises! Learning by doing is essential.

### For Experienced Developers

You can jump to specific language chapters (4-8) if you want to see how a particular language approaches the problem. But we recommend reading Chapters 1-3 first to understand the algorithms.

### For Mathematics Students

Chapters 1-3 will show you how mathematical concepts translate to running code. Pay special attention to Chapter 3 (Normal Distribution Sampling).

## Prerequisites

**Minimal**:
- Basic programming experience in any language
- Understanding of loops and functions
- Willingness to learn

**Helpful** (but not required):
- Understanding of probability
- Experience with compiled languages
- Basic command line usage

## Learning Philosophy: The Feynman Technique

This tutorial uses the **Feynman Technique** - named after physicist Richard Feynman:

1. **Learn**: Read and understand a concept
2. **Teach**: Explain it simply, as if to a child
3. **Identify Gaps**: Find what you don't understand
4. **Simplify**: Refine your explanation

We'll explain complex topics using:
- Simple analogies
- Visual descriptions
- Step-by-step breakdowns
- Working code you can run

### Example of Feynman Technique

**Complex**: "The XorShift128 PRNG implements a maximal-length linear-feedback shift register with period 2^128-1"

**Feynman-Style**: "Imagine shuffling a deck of cards. XorShift128 is like a magical shuffle that can produce 340 undecillion different arrangements before repeating - that's a 3 followed by 38 zeros. It's fast because it only uses simple bit operations (shift, XOR) instead of complex math."

## What You'll Build

By the end of this tutorial, you'll:

1. Understand the OU process mathematically and intuitively
2. Implement a random number generator from scratch
3. Understand how to generate normally-distributed random numbers
4. Write the same benchmark in at least one language
5. Know how to measure performance accurately
6. Understand the tradeoffs between different languages

## Chapter Overview

**Chapter 1: The Ornstein-Uhlenbeck Process**
- What it models (with real-world examples)
- The mathematics (explained simply)
- Why it's a good benchmark

**Chapter 2: Random Number Generation**
- Why we need our own RNG
- How XorShift128 works
- Why determinism matters

**Chapter 3: Normal Distribution Sampling**
- What "normally distributed" means
- The Marsaglia polar method
- Why it's better than alternatives

**Chapter 4-8: Language Implementations**
- Deep dive into each language
- Line-by-line code explanations
- Language-specific optimizations

**Chapter 9: Benchmarking Methodology**
- How to measure accurately
- Statistical concepts (median, variance)
- Avoiding common pitfalls

**Chapter 10: Exercises and Projects**
- Hands-on coding challenges
- Extension ideas
- Performance experiments

## Getting Started

First, clone the repository and try running the benchmarks:

```bash
git clone https://github.com/mneves75/language-benchmarks.git
cd language-benchmarks
./run_all.sh
```

You should see output showing timing results for each language. This is what we'll be building and understanding!

## Questions to Consider

As you read each chapter, ask yourself:

1. **Why?** - Why did we choose this approach?
2. **What if?** - What would happen if we changed this?
3. **How?** - How does this actually work at the bit level?
4. **When?** - When would I use this in my own code?

## A Note on Difficulty

This tutorial covers advanced topics, but we explain everything from first principles. Some chapters will be challenging - that's okay! Learning happens when we're slightly uncomfortable.

If you get stuck:
1. Re-read the section slowly
2. Try the code examples
3. Search for additional resources
4. Move on and come back later
5. The "aha!" moment will come

## Ready to Begin?

Let's start with Chapter 1, where we'll understand the problem we're solving: the Ornstein-Uhlenbeck process. We'll explain it so clearly that you could teach it to someone else - that's how you know you truly understand.

---

**Next**: [Chapter 1: The Ornstein-Uhlenbeck Process Explained Simply](01-ou-process.md)

## References

- [The Feynman Technique](https://www.scotthyoung.com/blog/2024/03/26/5-keys-feynman-technique/)
- [Technical Documentation Best Practices](https://www.archbee.com/blog/technical-documentation-best-practices)
- [How to Understand Complex Coding Concepts Using the Feynman Technique](https://www.freecodecamp.org/news/how-to-understand-complex-coding-concepts-better-using-the-feynman-technique/)
