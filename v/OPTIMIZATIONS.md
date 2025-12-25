# V Implementation Optimizations

This V implementation is heavily optimized to achieve C-level performance while remaining idiomatic V code.

## Key Optimizations

### 1. Function Inlining
All hot-path functions are marked with `@[inline]` attribute:
- `Splitmix32.next()` - PRNG seeding
- `Xorshift128.next_u32()` - 32-bit random number generation
- `Xorshift128.next_f64()` - Uniform double generation
- `NormalPolar.next()` - Gaussian random number generation

These functions are called millions of times per benchmark run. Inlining eliminates function call overhead and enables better compiler optimizations.

### 2. Unsafe Blocks for Zero-Overhead Array Access
All performance-critical loops use `unsafe` blocks to eliminate bounds checking:
- Normal number generation loops
- OU simulation loops
- Checksum accumulation loops

V's arrays normally include bounds checking. Using `unsafe` blocks removes this overhead, matching C's raw pointer performance.

### 3. Aggressive Compiler Flags

**V Compiler Flags:**
- `-prod` - Production mode with all optimizations enabled
- `-cstrict` - Strict C backend mode for better optimization opportunities
- `-skip-unused` - Eliminate dead code
- `-cc gcc` - Use GCC as the C compiler backend

**C Compiler Flags (passed through):**
- `-O3` - Maximum optimization level
- `-ffast-math` - Aggressive floating-point optimizations
- `-march=native` - Use all CPU instructions available on the build machine
- `-fno-math-errno` - Don't set errno for math functions
- `-fno-trapping-math` - Assume no floating-point exceptions

### 4. Algorithm Fidelity
The implementation uses **identical algorithms** to C/Rust/Zig:
- xorshift128 PRNG with splitmix32 seeding
- 53-bit uniform distribution from two u32 draws
- Marsaglia polar method with cached spare value
- Euler-Maruyama OU simulation with precomputed coefficients

### 5. Memory Efficiency
- Single allocation of `gn` and `ou` arrays
- Arrays reused across all benchmark runs
- No allocations in the timed region
- Monotonic clock timing to avoid syscall overhead

## Expected Performance

With these optimizations, the V implementation should achieve performance within **5-15% of C**, making it competitive with Rust and Zig. V compiles to C, so the generated code should be nearly identical to hand-written C with proper optimization flags.

## Why V Can Match C Performance

1. **Compiles to C** - V generates C code, which is then compiled with the same aggressive flags
2. **No Runtime Overhead** - V has no garbage collector or runtime
3. **Zero-Cost Abstractions** - V's syntax compiles to direct C equivalents
4. **Unsafe Blocks** - Allow bypassing safety checks in hot paths
5. **Inline Hints** - Help the C compiler make better optimization decisions

## Verification

To verify the optimization quality:
1. Build with the provided flags
2. Compare the benchmark results with C/Rust/Zig
3. Optionally inspect the generated C code in the V cache directory
4. Use `perf` or similar tools to profile hot spots

## Trade-offs

- **Unsafe blocks** - We sacrifice bounds checking for performance (acceptable in a benchmark)
- **Aggressive math flags** - `-ffast-math` may affect numerical precision slightly
- **Architecture-specific** - `-march=native` means the binary only works on the build CPU

These are the same trade-offs made by the C, Rust, and Zig implementations for a fair comparison.
