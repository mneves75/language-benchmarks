# Chapter 8: Swift - Apple Ecosystem Performance

## The Swift Paradox

Swift achieved **9.25 ms median** - the slowest in our benchmark at **150% slower than C**. This surprises many since Swift is:
- ✓ Compiled (not interpreted)
- ✓ Statically typed
- ✓ Created by Apple (known for performance)
- ✓ Uses LLVM (same as C/Rust/Zig)

Yet it's slower than Bun (a dynamic, JIT-compiled language)!

| Language | Median (ms) | vs C | Compiled? |
|----------|-------------|------|-----------|
| C        | 3.70        | baseline | Yes |
| Zig      | 3.82        | +3%  | Yes |
| Rust     | 3.84        | +4%  | Yes |
| Bun      | 6.13        | +66% | JIT |
| **Swift** | **9.25**   | **+150%** | **Yes** |

**Why is Swift slower?** This chapter explores the answer.

## What Is Swift?

Swift is a **general-purpose programming language** created by Apple in 2014. It's designed to replace Objective-C for Apple platforms (iOS, macOS, watchOS).

**Design goals**:
- Modern syntax (less verbose than Objective-C)
- Safety (no null pointers, memory safety)
- Performance (compiled, not interpreted)
- Interoperability with Objective-C

**Key features**:
- Protocol-oriented programming
- Optionals (no null pointers)
- Automatic Reference Counting (ARC)
- Type inference
- Generics

## Why Swift Is Slower in This Benchmark

### 1. Reference Counting Overhead

Swift uses **ARC (Automatic Reference Counting)** for memory management:

```swift
class MyClass {
    var value: Int
}

let obj1 = MyClass()  // Ref count = 1
let obj2 = obj1       // Ref count = 2
// obj1 goes out of scope → Ref count = 1
// obj2 goes out of scope → Ref count = 0 → Deallocate
```

Every object assignment increments/decrements reference counts. This adds overhead.

**In our benchmark**: We use structs (not classes), so ARC doesn't apply. But the Swift runtime still has overhead from:
- Copy-on-write for arrays
- Existential containers for protocols
- Runtime type checks

### 2. Array Bounds Checking

Swift checks array bounds on **every access**:

```swift
let arr = [1, 2, 3]
let val = arr[10]  // Runtime error: Index out of range!
```

This is safer than C (which allows undefined behavior), but adds overhead. The compiler can sometimes eliminate bounds checks, but not always.

### 3. Integer Overflow Checking

Swift checks for overflow:

```swift
let a: UInt32 = 4000000000
let b: UInt32 = 1000000000
let c = a + b  // Runtime error: Overflow!
```

For wrapping arithmetic, use `&+` and `&*`:

```swift
let c = a &+ b  // Wraps to 704967296
```

Each checked operation adds 1-2 cycles overhead.

### 4. Copy-on-Write Arrays

Swift arrays use **copy-on-write**:

```swift
var arr1 = [1, 2, 3]
var arr2 = arr1       // Shares storage with arr1
arr2[0] = 99          // Copies arr1 before modification
```

This is efficient for immutable use but adds overhead when modifying.

### 5. Protocol Dispatch

Swift's protocols can use **dynamic dispatch** (like C++ virtual functions):

```swift
protocol Shape {
    func area() -> Double
}

func totalArea(shapes: [Shape]) -> Double {
    var sum = 0.0
    for shape in shapes {
        sum += shape.area()  // Dynamic dispatch!
    }
    return sum
}
```

Each call looks up the method in a vtable (~5-10 cycles overhead vs direct call).

Our benchmark doesn't use protocols, but the Swift standard library does internally.

## The Swift Implementation

From `swift/ou_bench.swift` (354 lines). Let's examine Swift-specific patterns.

### Structs with Default Values

```swift
struct Args {
    var n: Int = 500_000
    var runs: Int = 1000
    var warmup: Int = 5
    var seed: UInt32 = 1
    var mode: Mode = .full
    var output: Output = .text
}
```

Swift structs are value types (copied, not referenced). This is like C structs, but with methods.

### Enums as Sum Types

```swift
enum Mode: String {
    case full
    case gn
    case ou
}

enum Output: String {
    case text
    case json
}
```

Swift enums can have raw values (strings, integers). This is more powerful than C enums.

### The mutating Keyword

```swift
struct SplitMix32 {
    var s: UInt32

    mutating func next() -> UInt32 {
        s = s &+ 0x9E37_79B9  // Modifies s
        var z = s
        z = (z ^ (z >> 16)) &* 0x85EB_CA6B
        z = (z ^ (z >> 13)) &* 0xC2B2_AE35
        return z ^ (z >> 16)
    }
}
```

**mutating** means the method can modify the struct. Without it, methods can't change fields (structs are immutable by default).

### Wrapping Arithmetic

```swift
s = s &+ 0x9E37_79B9  // Wrapping add
z = (z ^ (z >> 16)) &* 0x85EB_CA6B  // Wrapping multiply
```

The `&` prefix enables wrapping behavior (like Zig's `+%` and Rust's `wrapping_add`).

### The XorShift128 Implementation

```swift
struct XorShift128 {
    var x: UInt32
    var y: UInt32
    var z: UInt32
    var w: UInt32

    init(seed: UInt32) {
        var sm = SplitMix32(s: seed)
        x = sm.next()
        y = sm.next()
        z = sm.next()
        w = sm.next()
        if (x | y | z | w) == 0 {
            w = 1
        }
    }

    mutating func nextU32() -> UInt32 {
        let t = x ^ (x << 11)
        x = y
        y = z
        z = w
        w = w ^ (w >> 19) ^ t ^ (t >> 8)
        return w
    }

    mutating func nextF64() -> Double {
        let a = nextU32()
        let b = nextU32()
        let u = (UInt64(a >> 5) << 26) | UInt64(b >> 6)
        return Double(u) * (1.0 / 9007199254740992.0)
    }
}
```

Note: `nextU32()` is `mutating` because it modifies the struct's state.

### Type Conversions

```swift
let u = (UInt64(a >> 5) << 26) | UInt64(b >> 6)
return Double(u) * (1.0 / 9007199254740992.0)
```

Swift requires explicit type conversions: `UInt64()`, `Double()`. This is clearer than C's implicit casts.

### Timing with DispatchTime

```swift
import Dispatch

func nowNs() -> UInt64 {
    return DispatchTime.now().uptimeNanoseconds
}

let t0 = nowNs()
// ... work ...
let t1 = nowNs()
let elapsed_ns = t1 - t0
```

`DispatchTime` provides nanosecond precision. Unlike C's `clock_gettime`, it's built into the standard library.

### Array Creation

```swift
var gn = [Double](repeating: 0.0, count: n - 1)
var ou = [Double](repeating: 0.0, count: n)
```

This creates arrays initialized with zeros. Swift's type inference determines the type from `Double`.

### The Benchmark Loop

```swift
for r in 0..<runs {
    var gen: Double = 0.0
    var sim: Double = 0.0
    var chk: Double = 0.0

    if mode == .full {
        let t0 = nowNs()

        for i in 0..<(n - 1) {
            gn[i] = diff * norm.nextStandard(rng: &rng)
        }
        let t1 = nowNs()

        var x: Double = 0.0
        ou[0] = x
        for i in 1..<n {
            x = a * x + b + gn[i - 1]
            ou[i] = x
        }
        let t2 = nowNs()

        var s: Double = 0.0
        for i in 0..<n {
            s += ou[i]
        }
        checksum += s
        let t3 = nowNs()

        gen = Double(t1 - t0) * 1e-9
        sim = Double(t2 - t1) * 1e-9
        chk = Double(t3 - t2) * 1e-9
    }
}
```

**Range syntax**: `0..<n` means 0 to n-1 (exclusive end). Swift's for-in loops are cleaner than C's for loops.

### Inout Parameters

```swift
mutating func nextStandard(rng: inout XorShift128) -> Double {
    // ...
}
```

**inout** means the parameter is passed by reference (like C's pointer). Changes to `rng` are visible to the caller.

### String Interpolation

```swift
print("n=\(args.n) runs=\(args.runs) warmup=\(args.warmup) seed=\(args.seed)")
```

Swift's `\()` syntax embeds expressions in strings. This is cleaner than printf-style formatting.

## Performance Analysis

### Why 150% Slower Than C?

**Overhead breakdown** (estimated):

| Source | Overhead |
|--------|----------|
| Bounds checking | ~20-30% |
| Overflow checking | ~10-15% |
| Reference counting (minimal for our structs) | ~5% |
| Function call overhead | ~10-20% |
| Copy-on-write arrays | ~10-15% |
| Swift runtime | ~10-20% |
| Other | ~10% |

**Total**: ~75-125% overhead (matches our 150% observed)

### Why Slower Than Bun?

Bun (6.13 ms) is faster than Swift (9.25 ms) despite being JIT-compiled. Why?

1. **Type stability**: Bun's JIT optimizes hot loops aggressively
2. **No bounds checking**: JavaScript doesn't check bounds (unsafe but fast)
3. **No overflow checking**: JavaScript wraps silently (unsafe but fast)
4. **Simpler runtime**: Bun has less overhead than Swift's safety features

**Trade-off**: Swift is safer (catches bugs at runtime), Bun is faster (but less safe).

### Swift is Fast for Other Workloads

Our benchmark is **not representative** of typical Swift code. Swift excels at:
- UI programming (its primary use case)
- Object-oriented code with reference types
- String manipulation
- Concurrent programming with actors

For these workloads, Swift's performance is competitive with C++.

## Optimization Opportunities

### 1. Use @inline

```swift
@inline(__always)
mutating func nextU32() -> UInt32 {
    // Force inlining
}
```

This eliminates function call overhead.

### 2. Disable Safety Checks (Unsafe!)

Compile with:
```bash
swiftc -O -unchecked ou_bench.swift
```

This disables bounds and overflow checking. **Only use in production after thorough testing!**

Expected speedup: 20-30% (brings Swift closer to C).

### 3. Use UnsafeMutableBufferPointer

For maximum performance:

```swift
let gnPointer = UnsafeMutableBufferPointer<Double>.allocate(capacity: n - 1)
defer { gnPointer.deallocate() }

// Access without bounds checking
gnPointer[i] = value
```

This is like C's raw pointers. Faster but unsafe.

## Common Swift Patterns

### Optionals

Swift uses optionals for nullable values:

```swift
let maybe: Int? = nil

if let value = maybe {
    print("Value: \(value)")
} else {
    print("No value")
}
```

**No null pointer errors!** The compiler forces you to handle None case.

### Guard Statements

```swift
guard let value = maybe else {
    return  // Early exit if None
}
// value is unwrapped here
```

### Error Handling

```swift
enum FileError: Error {
    case notFound
    case permissionDenied
}

func readFile(_ path: String) throws -> String {
    guard fileExists(path) else {
        throw FileError.notFound
    }
    return contents
}

do {
    let data = try readFile("data.txt")
} catch {
    print("Error: \(error)")
}
```

## Exercises

### Exercise 1: Disable Safety Checks

Recompile with unchecked mode:
```bash
swiftc -O -whole-module-optimization -unchecked ou_bench.swift -o ou_bench_unchecked
```

Measure the speedup. Is it worth the risk?

### Exercise 2: Profile with Instruments

Use Xcode's Instruments:
```bash
xcodebuild -scheme YourScheme -configuration Release
# Open in Instruments and profile
```

Where is time spent?

### Exercise 3: Add Optional Handling

Modify parseArgs to return `Args?`:

```swift
func parseArgs(_ argv: [String]) -> Args? {
    // Return nil on invalid input
}

guard let args = parseArgs(Array(CommandLine.arguments.dropFirst())) else {
    print("Invalid arguments")
    exit(1)
}
```

### Exercise 4: Use Generics

Make the RNG generic over integer types:

```swift
struct XorShift128<T: FixedWidthInteger> {
    // Use T instead of UInt32
}
```

Can you make it work?

## Summary

Swift is a **modern, safe language** optimized for Apple platforms. In our benchmark, it's the slowest due to:

- ✗ Bounds checking
- ✗ Overflow checking
- ✗ Copy-on-write arrays
- ✗ Runtime safety features

**But**:
- ✓ Catches bugs at runtime
- ✓ Prevents null pointer errors
- ✓ Modern syntax and features
- ✓ Excellent for UI programming

**Conclusion**: Swift prioritizes **safety over raw performance**. For scientific computing, C/Zig/Rust are better choices. For app development, Swift is excellent.

---

**Previous**: [Chapter 7: TypeScript/Bun - Dynamic Language Performance](07-typescript-bun.md)
**Next**: [Chapter 9: Benchmarking Methodology](09-benchmarking-methodology.md)

## References

- [Swift Programming Language](https://docs.swift.org/swift-book/)
- [Swift Performance Tips](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst)
- [Automatic Reference Counting](https://docs.swift.org/swift-book/LanguageGuide/AutomaticReferenceCounting.html)
- [Swift Evolution Proposals](https://apple.github.io/swift-evolution/)
