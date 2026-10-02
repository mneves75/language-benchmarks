# Learning the six-language OU benchmark

This tutorial explains the shared workload and its implementations in C, Zig,
Rust, TypeScript/Bun, Swift, and V. Read it beside the source. The
[root README](../../README.md) owns current CLI limits and build commands.

| Topic | Chapter |
|---|---|
| Scope and pipeline | [Introduction](00-introduction.md) |
| Mean reversion and Euler approximation | [OU process](01-ou-process.md) |
| Integer and uniform streams | [Random numbers](02-random-numbers.md) |
| Rejection sampling and paired fills | [Normal distribution](03-normal-distribution.md) |
| Explicit memory and unsigned arithmetic | [C](04-c-implementation.md) |
| Allocators, errors, and build modes | [Zig](05-zig-implementation.md) |
| Ownership, slices, and release profiles | [Rust](06-rust-implementation.md) |
| Integer semantics and typed arrays | [TypeScript/Bun](07-typescript-bun.md) |
| Value types and buffer lifetimes | [Swift](08-swift-implementation.md) |
| C backend and runtime configuration | [V](11-v-implementation.md) |
| Measurement and interpretation | [Methodology](09-benchmarking-methodology.md) |
| Practice with acceptance criteria | [Exercises](10-exercises-projects.md) |

Read the first four chapters, choose a familiar language and a new one, then
study methodology before comparing timings. Prerequisites are loops, functions,
command-line basics, algebra, and elementary probability.

Explain each stage in your own words, trace a small input, and run the real CLI
checks. You will learn why an optimization must preserve sample order and why a
checksum alone cannot prove numerical correctness.

Historical timings in [the 2025 record](../Run-Record-2025-12-19.md) describe one
configuration. Current modernization evidence belongs in
[the 2026 record](../Run-Record-2026-10-02.md). Hardware, compiler, flags, math
library, runtime, and input all affect results.

This learning benchmark does not certify PRNG quality, memory safety, scientific
validity, or general application performance. Alternative PRNGs, exact OU
transitions, GPU implementations, and SIMD across paths are separate workloads.
