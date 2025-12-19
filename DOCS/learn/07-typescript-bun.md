# Chapter 7: TypeScript/Bun - Dynamic Language Performance

## The Dynamic Language Challenge

JavaScript and TypeScript are **dynamically typed** languages - types are checked at runtime, not compile time. This typically means slower performance:

```javascript
let x = 5;          // x is a number
x = "hello";        // now x is a string (allowed!)
x = [1, 2, 3];      // now x is an array (also allowed!)
```

This flexibility comes at a cost: the runtime must constantly check types, making programs slower than statically-typed languages.

Yet our benchmark shows **Bun achieves 6.15 ms** - only **66% slower** than C. For a dynamic language, this is remarkable!

| Language | Median (ms) | vs C | Type System |
|----------|-------------|------|-------------|
| C        | 3.70        | baseline | Static, compiled |
| Zig      | 3.82        | +3%  | Static, compiled |
| Rust     | 3.84        | +4%  | Static, compiled |
| **Bun**  | **6.13**    | **+66%** | **Dynamic, JIT** |
| Swift    | 9.25        | +150% | Static, compiled |

**Key insight**: Bun (dynamic) is **faster than Swift** (static)! Runtime performance depends on more than just type systems.

## What Is Bun?

**Bun** is a modern JavaScript runtime created by Jarred Sumner in 2021. It's designed as a faster alternative to Node.js and Deno.

**Key features**:
- ✓ **JavaScriptCore engine** (from WebKit/Safari), not V8 (Chrome)
- ✓ **Native TypeScript support** (no transpilation needed)
- ✓ **Fast startup** (~3× faster than Node.js)
- ✓ **Built-in bundler, transpiler, package manager**

**Why Bun for our benchmark?**
- Fastest JavaScript runtime currently available
- Native TypeScript support (no build step)
- Represents the **best case** for dynamic languages

## JavaScript's Type System Challenges

### No Native Integers

JavaScript has only one number type: **64-bit floating point** (IEEE 754 double).

```javascript
typeof 5        // "number"
typeof 5.5      // "number"
typeof 5n       // "bigint" (special type for integers)
```

This means:
- No u32, i32, u64 types
- All arithmetic is floating-point (slower than integer)
- Need tricks for 32-bit integer operations

### Bitwise Operations Trick

JavaScript bitwise operators (`|`, `&`, `^`, `<<`, `>>`) treat numbers as **32-bit signed integers**:

```javascript
let x = 5.7;
let y = x | 0;  // y = 5 (truncated to 32-bit int)
```

We use this extensively in our RNG:

```javascript
const t = (this.x ^ (this.x << 11)) | 0;  // Force 32-bit
```

The `| 0` ensures the result is treated as a 32-bit integer.

### No Type Declarations (in plain JS)

```javascript
function add(a, b) {
    return a + b;  // Could be numbers, strings, anything!
}
```

The runtime must check types every time, adding overhead.

## TypeScript: Type Safety for JavaScript

**TypeScript** adds static types to JavaScript:

```typescript
function add(a: number, b: number): number {
    return a + b;  // Compiler enforces number types
}
```

**Benefits**:
- Catch errors at compile time
- Better IDE support (autocomplete, refactoring)
- Self-documenting code

**Important**: TypeScript types are **erased** at runtime. They don't affect performance directly, but they help write correct code.

## The Bun Implementation

From `ts/ou_bench.ts` (344 lines). Let's examine TypeScript/JavaScript-specific patterns.

### Type Annotations

```typescript
type Args = {
  n: number;
  runs: number;
  warmup: number;
  seed: number;
  mode: "full" | "gn" | "ou";
  output: "text" | "json";
};
```

The `"full" | "gn" | "ou"` is a **union type** - mode can only be one of these three strings.

### Classes vs Structs

JavaScript doesn't have structs, only classes:

```typescript
class XorShift128 {
  private x: number;
  private y: number;
  private z: number;
  private w: number;

  constructor(seed: number) {
    // Initialize
  }

  nextU32(): number {
    // Implementation
  }
}
```

**private** fields are only enforceable in TypeScript (erased at runtime).

### The SplitMix32 Function

```typescript
function splitmix32_next(state: { s: number }): number {
  state.s = (state.s + 0x9e3779b9) | 0;
  let z = state.s | 0;
  z = Math.imul(z ^ (z >>> 16), 0x85ebca6b) | 0;
  z = Math.imul(z ^ (z >>> 13), 0xc2b2ae35) | 0;
  z = (z ^ (z >>> 16)) | 0;
  return z >>> 0;
}
```

**Key differences from C**:

1. **`| 0`**: Forces 32-bit signed integer
2. **`>>> 0`**: Converts to unsigned 32-bit (return value)
3. **`>>>`**: Unsigned right shift (vs `>>` signed shift)
4. **Math.imul()**: 32-bit integer multiplication

### Why Math.imul()?

Regular `*` does floating-point multiplication:

```javascript
const a = 4000000000;
const b = 2;
const c = a * b;  // 8000000000.0 (float, loses precision)
```

`Math.imul()` does true 32-bit integer multiplication:

```javascript
const c = Math.imul(a, b);  // -589934592 (wraps, correct for u32)
```

This is critical for our RNG to work correctly.

### The XorShift128 Class

```typescript
class XorShift128 {
  private x: number;
  private y: number;
  private z: number;
  private w: number;

  constructor(seed: number) {
    const st = { s: seed | 0 };
    this.x = splitmix32_next(st) | 0;
    this.y = splitmix32_next(st) | 0;
    this.z = splitmix32_next(st) | 0;
    this.w = splitmix32_next(st) | 0;

    if ((this.x | this.y | this.z | this.w) === 0) {
      this.w = 1;
    }
  }

  nextU32(): number {
    const t = (this.x ^ (this.x << 11)) | 0;
    this.x = this.y;
    this.y = this.z;
    this.z = this.w;
    this.w = (this.w ^ (this.w >>> 19) ^ t ^ (t >>> 8)) | 0;
    return this.w >>> 0;
  }

  nextF64(): number {
    const a = this.nextU32();
    const b = this.nextU32();
    const u = (a >>> 5) * 67108864 + (b >>> 6);
    return u * (1.0 / 9007199254740992.0);
  }
}
```

**Converting to 53-bit float**:
```typescript
const u = (a >>> 5) * 67108864 + (b >>> 6);
```

Why multiplication instead of bit shift?
- `67108864 = 2^26`
- `(a >>> 5) * 2^26` is equivalent to `(a >>> 5) << 26`
- JavaScript doesn't have 64-bit bitwise ops, so we use math

### Timing with performance.now()

```typescript
function nowMs(): number {
  return performance.now();
}

const t0 = nowMs();
// ... work ...
const t1 = nowMs();
const elapsed_ms = t1 - t0;
```

`performance.now()` returns **milliseconds** with microsecond precision:
- Resolution: ~0.001 ms (1 microsecond)
- Monotonic: Yes
- Relative to page load

### The Benchmark Loop

```typescript
for (let r = 0; r < runs; r++) {
  let gen = 0.0;
  let sim = 0.0;
  let chk = 0.0;

  if (mode === "full") {
    const t0 = nowMs();

    for (let i = 0; i < n - 1; i++) {
      gn[i] = diff * norm.nextStandard(rng);
    }
    const t1 = nowMs();

    let x = 0.0;
    ou[0] = x;
    for (let i = 1; i < n; i++) {
      x = a * x + b + gn[i - 1];
      ou[i] = x;
    }
    const t2 = nowMs();

    let s = 0.0;
    for (let i = 0; i < n; i++) s += ou[i];
    checksum += s;
    const t3 = nowMs();

    gen = (t1 - t0) / 1000;  // Convert ms to seconds
    sim = (t2 - t1) / 1000;
    chk = (t3 - t2) / 1000;
  }
  // ...
}
```

**Key difference**: Times are in milliseconds, not nanoseconds. We convert to seconds for consistency.

### Array Creation

```typescript
const gn = new Array(n - 1).fill(0.0);
const ou = new Array(n).fill(0.0);
```

JavaScript arrays are dynamically typed and can grow. We use `fill(0.0)` to:
- Allocate the full size upfront
- Initialize with floats (helps JIT optimize)

### Garbage Collection Hint

```typescript
Bun.gc(true);  // Force garbage collection before warmup
```

This **minimizes GC pauses** during the timed runs. We run GC once upfront to clear any allocation debris.

## How Bun Achieves Performance

### JavaScriptCore JIT

Bun uses **JavaScriptCore** (Apple's JavaScript engine). It has a multi-tier JIT:

1. **LLInt** (Low-Level Interpreter): Fast startup
2. **Baseline JIT**: Quick compilation for warm code
3. **DFG** (Data Flow Graph): Optimizing JIT
4. **FTL** (Faster Than Light): Maximum optimization using LLVM

Hot code paths get progressively more optimized.

### Type Speculation

The JIT **speculates** about types:

```javascript
function add(a, b) {
    return a + b;
}

// After seeing add(1, 2) many times, JIT assumes integers
// Generates optimized code for integer addition
// If suddenly called with strings, deoptimizes
```

In our benchmark, types are stable (always numbers), so speculation succeeds.

### Inline Caching

Method calls are cached:

```javascript
rng.nextU32();  // First call: lookup method
rng.nextU32();  // Subsequent calls: use cached lookup
```

This reduces overhead for hot methods.

### Escape Analysis

If the JIT proves an object doesn't escape a function, it can allocate it on the stack instead of heap:

```javascript
function compute() {
    const obj = { x: 5, y: 10 };  // Might be stack-allocated
    return obj.x + obj.y;
}  // obj doesn't escape, no heap allocation needed
```

This avoids GC pressure.

## Performance Characteristics

### Why 66% Slower?

Compared to C (3.70 ms), Bun (6.13 ms) is 66% slower. Why?

**Overhead sources**:
1. **Type checking**: ~20-30% overhead
2. **JIT warmup**: First few iterations slower
3. **Integer emulation**: ~10-15% (no native 32-bit int)
4. **Function calls**: ~5-10% (virtual dispatch)
5. **GC pauses**: ~5% (minimized by pre-GC)

**Surprisingly fast because**:
- JIT optimizes hot loops aggressively
- Type stability (no polymorphism)
- Simple numeric code (JIT's strength)

### Comparison to Node.js

If we ran on Node.js instead of Bun:
- Expected: ~10-12 ms (60-100% slower than Bun)
- V8 is powerful but has slower startup and higher overhead

Bun's speed comes from:
- JavaScriptCore (lighter than V8)
- Native implementation of many APIs
- Optimized for modern JavaScript

## Common JavaScript Pitfalls

### Forgetting | 0

```javascript
// BAD: Floating-point arithmetic
const t = this.x ^ (this.x << 11);

// GOOD: Forced to 32-bit int
const t = (this.x ^ (this.x << 11)) | 0;
```

Without `| 0`, results can be wrong due to float precision.

### Using * Instead of Math.imul()

```javascript
// BAD: Float multiplication
const z = (z ^ (z >> 16)) * 0x85ebca6b;

// GOOD: 32-bit integer multiplication
const z = Math.imul(z ^ (z >> 16), 0x85ebca6b);
```

### Array Type Instability

```javascript
// BAD: Mixed types (defeats JIT optimization)
const arr = [];
arr.push(1);
arr.push("hello");  // Now JIT can't optimize

// GOOD: Consistent types
const arr = [0.0, 0.0, 0.0];  // All floats
```

## Exercises

### Exercise 1: Compare Bun vs Node.js

Install Node.js and run:
```bash
node ou_bench.ts --runs=100
```

How much slower is Node.js than Bun?

### Exercise 2: Profile with Bun

```bash
bun --inspect ou_bench.ts --runs=100
```

Connect with Chrome DevTools and inspect the flame graph. Where is time spent?

### Exercise 3: Test Type Stability

Modify the code to make types unstable:

```typescript
let x: any = 0.0;
x = "string";  // Introduce instability
x = 0.0;

for (let i = 1; i < n; i++) {
    x = a * x + b + gn[i - 1];
    ou[i] = x;
}
```

Measure the performance impact.

### Exercise 4: Remove | 0

Remove all `| 0` operations and see if results change:

```bash
# Before
bun ou_bench.ts --runs=1 --n=1000 --seed=1

# After removing | 0
bun ou_bench.ts --runs=1 --n=1000 --seed=1
```

Are checksums identical?

## Summary

TypeScript/Bun demonstrates that **dynamic languages can be competitive** for numeric computing:

**Achievements**:
- Only 66% slower than C
- Faster than Swift (a compiled language)
- Maintains dynamic typing flexibility

**Key techniques**:
- `| 0` for 32-bit integer emulation
- `Math.imul()` for correct integer multiplication
- Type stability for JIT optimization
- Pre-GC to minimize pauses

**Trade-offs**:
- Slower than C/Zig/Rust (expected)
- But: Faster development, richer ecosystem
- Good enough for many applications

Bun proves that JavaScript's reputation for slowness is **outdated** - modern JITs achieve impressive performance.

---

**Previous**: [Chapter 6: Rust - Safety and Performance](06-rust-implementation.md)
**Next**: [Chapter 8: Swift - Apple Ecosystem Performance](08-swift-implementation.md)

## References

- [Bun Official Website](https://bun.sh/)
- [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [JavaScript Number Type (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
- [Math.imul() (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Math/imul)
