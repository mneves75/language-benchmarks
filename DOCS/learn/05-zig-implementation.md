# Chapter 5: Zig - Modern Systems Programming

## What Is Zig?

Zig is a **modern systems programming language** created by Andrew Kelley in 2016. It aims to be a better alternative to C for systems programming.

Think of Zig as **"C with training wheels"** - it gives you the same low-level control and performance as C, but with modern safety features that prevent common mistakes.

### The Zig Philosophy

Three core principles drive Zig's design:

1. **No hidden control flow**: If it looks simple, it is simple. No exceptions, no implicit allocations, no operator overloading.
2. **Explicit is better than implicit**: Make behavior clear at the call site.
3. **Compile-time execution**: Run code at compile time whenever possible.

### Why Zig Matters

In our benchmark, Zig achieves **3.82 ms median** - only 3% slower than C (3.70 ms). This is remarkable because:

- ✓ No undefined behavior (many C gotchas are compile errors in Zig)
- ✓ Explicit error handling (no unchecked returns)
- ✓ Memory safety features (bounds checking in debug mode)
- ✓ Modern tooling (built-in build system, testing, formatting)

Yet it's **as fast as C** because:
- No runtime overhead (unlike Go or Java)
- No garbage collector
- Same LLVM backend as Clang
- Direct memory control

Think of it as "C with better ergonomics" - you get C's performance with Rust-like safety, but simpler syntax.

## Key Zig Features

### 1. Explicit Error Handling

In C, errors are implicit:
```c
// Did malloc fail? You must remember to check!
double *arr = malloc(n * sizeof(double));
if (arr == NULL) { /* handle error */ }
```

In Zig, errors are part of the type system:
```zig
// ! in return type means "may return an error"
fn parseArgs(allocator: std.mem.Allocator) !Args {
    const argv = try std.process.argsAlloc(allocator);
    // 'try' propagates errors up the call stack
    return out;
}
```

The `!` makes errors **visible** in the function signature. You can't forget to handle them - the compiler enforces it.

### 2. Wrapping Arithmetic

Integer overflow in C is **undefined behavior**:
```c
uint32_t a = 4000000000;
uint32_t b = 1000000000;
uint32_t c = a + b;  // Undefined behavior! Might wrap, might trap, compiler can do anything
```

Zig makes overflow behavior **explicit**:
```zig
const a: u32 = 4000000000;
const b: u32 = 1000000000;

const c = a + b;      // Compile error: "operation caused overflow"
const d = a +% b;     // Wrapping add (OK, wraps to 704967296)
const e = a +| b;     // Saturating add (4294967295, max u32)
```

For our RNG, we want wrapping (modular arithmetic), so we use `+%` and `*%`:
```zig
self.s +%= 0x9E37_79B9;  // Explicit wrapping add
z = (z ^ (z >> 16)) *% 0x85EB_CA6B;  // Explicit wrapping multiply
```

This makes the intent clear and prevents surprises.

### 3. No Hidden Allocations

In Zig, **all allocations are explicit**. There are no hidden heap allocations.

C example (hidden allocation):
```c
// Looks innocent, but malloc happens inside!
char *str = strdup("hello");
```

Zig requires explicit allocator:
```zig
const allocator = std.heap.page_allocator;
var gn = try allocator.alloc(f64, n - 1);  // Explicit allocation
defer allocator.free(gn);  // Explicit deallocation
```

This makes it **obvious** where memory is being allocated, helping prevent leaks.

### 4. Comptime (Compile-Time Execution)

Zig can run code at **compile time**. This is used extensively in the standard library.

Example:
```zig
const n = comptime fibonacci(10);  // Computed at compile time!
```

The compiler executes `fibonacci(10)` during compilation and embeds the result. No runtime cost!

In our benchmark, we don't use `comptime` extensively, but it's powerful for:
- Generic programming (type parameters)
- Code generation
- Compile-time validation

### 5. Const by Default

In Zig, variables are **immutable by default**:
```zig
const x = 5;  // Immutable
var y = 10;   // Mutable
```

This is the opposite of C, where everything is mutable by default. Immutability:
- ✓ Prevents accidental modification
- ✓ Makes code easier to reason about
- ✓ Enables compiler optimizations

### 6. Switch Must Be Exhaustive

Zig's `switch` statement requires all cases to be handled:
```zig
switch (args.mode) {
    .full => { /* ... */ },
    .gn => { /* ... */ },
    .ou => { /* ... */ },
    // No default needed - all cases covered!
}
```

If you add a new enum variant, the compiler will error on all switches that don't handle it. This prevents bugs!

## The Zig Implementation Walkthrough

Our Zig implementation is 397 lines (`zig/ou_bench.zig`). Let's examine the key differences from C.

### Imports and Standard Library

From `zig/ou_bench.zig:15`:

```zig
const std = @import("std");
```

This is the entire import! Zig's standard library is accessed through `std.*`:

```zig
std.mem.Allocator         // Memory allocator interface
std.process.argsAlloc()   // Parse command-line arguments
std.time.nanoTimestamp()  // High-resolution timer
std.mem.sort()            // Sorting algorithm
std.fs.File.stdout()      // Standard output
```

Unlike C, no separate `#include` directives needed. Everything is namespaced.

### Data Structures with Defaults

From `zig/ou_bench.zig:17-24`:

```zig
const Args = struct {
    n: usize = 500_000,
    runs: usize = 1000,
    warmup: usize = 5,
    seed: u32 = 1,
    mode: Mode = .full,
    output: Output = .text,
};
```

Zig structs can have **default values**. This is cleaner than C:

C requires manual initialization:
```c
args_t a;
a.n = 500000;  // Must set each field
a.runs = 1000;
// ...
```

Zig allows:
```zig
var out = Args{};  // All fields get defaults!
```

### Enums as Types

From `zig/ou_bench.zig:26-27`:

```zig
const Mode = enum { full, gn, ou };
const Output = enum { text, json };
```

Zig enums are **first-class types**. You use them with `.variant` syntax:

```zig
out.mode = .full;  // Not Mode.full, just .full!
```

The compiler infers the type from context. This is concise yet type-safe.

### Error Handling in Argument Parsing

From `zig/ou_bench.zig:29-68`:

```zig
fn parseArgs(allocator: std.mem.Allocator) !Args {
    var out = Args{};
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    // ...

    if (std.mem.startsWith(u8, a, "--n=")) {
        const v = try std.fmt.parseInt(usize, a[4..], 10);
        if (v < 2) return error.InvalidN;
        out.n = v;
    }

    // ...

    return out;
}
```

Notice `!Args` in the return type. This means "returns Args or an error."

**Error propagation**:
```zig
const argv = try std.process.argsAlloc(allocator);
```

The `try` keyword:
1. If function succeeds → unwrap the result
2. If function fails → return the error to caller

This is syntactic sugar for:
```zig
const argv = std.process.argsAlloc(allocator) catch |err| return err;
```

**Custom errors**:
```zig
if (v < 2) return error.InvalidN;
```

Zig allows returning custom error values. These are part of an implicit error set.

### Defer for Resource Cleanup

```zig
const argv = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, argv);
```

`defer` executes code at the end of the current scope, no matter how it's exited:

```zig
{
    var resource = acquire();
    defer release(resource);  // Always executed when scope ends

    if (error) return;  // defer still runs!
    // ...
}  // defer runs here too
```

This is like C++'s RAII but explicit. No risk of forgetting cleanup!

In our implementation:
```zig
var gn = try allocator.alloc(f64, n - 1);
defer allocator.free(gn);  // Freed when function ends
```

### RNG Implementation

From `zig/ou_bench.zig:70-117`:

```zig
const SplitMix32 = struct {
    s: u32,

    inline fn next(self: *SplitMix32) u32 {
        self.s +%= 0x9E37_79B9;
        var z: u32 = self.s;
        z = (z ^ (z >> 16)) *% 0x85EB_CA6B;
        z = (z ^ (z >> 13)) *% 0xC2B2_AE35;
        return z ^ (z >> 16);
    }
};
```

**Key differences from C**:

1. **Wrapping arithmetic**: `+%` and `*%` instead of `+` and `*`
2. **inline fn**: Inline hint (like C's `static inline`)
3. **Methods**: Functions inside structs act like methods
4. **self parameter**: Explicit (like Python), not implicit (like C++)

**Calling convention**:
```zig
var sm = SplitMix32{ .s = seed };
const val = sm.next();  // Calls next with &sm as self
```

Zig automatically passes `&sm` as the `self` parameter.

### Type Conversions with @as

From `zig/ou_bench.zig:114-115`:

```zig
const u: u64 = (@as(u64, a >> 5) << 26) | @as(u64, b >> 6);
return @as(f64, @floatFromInt(u)) * (1.0 / 9007199254740992.0);
```

Zig requires **explicit type conversions** using builtins:

- `@as(T, value)`: Cast to type T
- `@floatFromInt(value)`: Convert integer to float
- `@intCast(value)`: Convert integer to different size
- `@intFromFloat(value)`: Convert float to integer

This prevents accidental truncation or overflow:

```c
// C: Silent truncation!
uint64_t big = 1234567890123456789;
uint32_t small = big;  // Oops, data loss
```

```zig
// Zig: Compiler error!
const big: u64 = 1234567890123456789;
const small: u32 = big;  // ERROR: type mismatch

// Must be explicit:
const small: u32 = @intCast(big);  // OK, intent is clear
```

###While Loops vs For Loops

Zig uses `while` for iteration:

```zig
var i: usize = 0;
while (i < n - 1) : (i += 1) {
    gn[i] = diff * norm.next(&rng);
}
```

This is equivalent to C's `for`:
```c
for (size_t i = 0; i < n - 1; i++) {
    gn[i] = diff * norm_polar_next(&norm, &rng);
}
```

The `: (i += 1)` part is the "continue expression" - executed at the end of each iteration.

**Why while instead of for?** Zig's philosophy: fewer constructs, more consistency. `while` can do everything `for` can:

```zig
// Infinite loop
while (true) { ... }

// Condition only
while (condition) { ... }

// With continue expression (like for)
while (condition) : (post) { ... }

// For-each (over slices)
for (slice) |item| { ... }
```

### The and/or Keywords

From `zig/ou_bench.zig:132`:

```zig
if (s > 0.0 and s < 1.0) {
    // ...
}
```

Zig uses **words** instead of symbols for logical operators:

| C | Zig |
|---|-----|
| `&&` | `and` |
| `||` | `or` |
| `!` | (same, or `not` in some contexts) |

This improves readability and avoids confusion with bitwise operators (`&`, `|`).

### Builtins vs Library Functions

From `zig/ou_bench.zig:133`:

```zig
const m = @sqrt((-2.0 * @log(s)) / s);
```

Math functions are **builtins** in Zig, prefixed with `@`:

- `@sqrt(x)`: Square root
- `@log(x)`: Natural logarithm
- `@sin(x)`, `@cos(x)`: Trigonometric functions
- `@exp(x)`: Exponential

These compile directly to LLVM intrinsics (often single CPU instructions), potentially faster than calling `libm`.

### Timing with i128

From `zig/ou_bench.zig:142-144`:

```zig
inline fn nowNs() i128 {
    return std.time.nanoTimestamp();
}
```

Zig's `std.time.nanoTimestamp()` returns `i128` (128-bit signed integer) for nanoseconds since epoch.

**Why 128 bits?** To represent timestamps far in the future:
```
2^63 nanoseconds ≈ 292 years
2^127 nanoseconds ≈ way more than universe's age
```

We convert to `f64` for calculations:
```zig
gen = @as(f64, @floatFromInt(t1 - t0)) * 1e-9;
```

### Switch with Enum Inference

From `zig/ou_bench.zig:258-337`:

```zig
switch (args.mode) {
    .full => {
        const t0 = nowNs();
        // ... generate normals ...
        const t1 = nowNs();
        // ... simulate OU ...
        const t2 = nowNs();
        // ... checksum ...
        const t3 = nowNs();

        gen = @as(f64, @floatFromInt(t1 - t0)) * 1e-9;
        sim = @as(f64, @floatFromInt(t2 - t1)) * 1e-9;
        chk = @as(f64, @floatFromInt(t3 - t2)) * 1e-9;
        run = @as(f64, @floatFromInt(t3 - t0)) * 1e-9;
    },
    .gn => {
        // ... similar ...
    },
    .ou => {
        // ... similar ...
    },
}
```

Notice `.full`, `.gn`, `.ou` - no need to write `Mode.full`! Zig infers the type from `args.mode`.

**Exhaustiveness**: If we add a fourth mode, the compiler will error here, forcing us to handle it. No silent bugs!

### Sorting with Comparison Function

From `zig/ou_bench.zig:350`:

```zig
std.mem.sort(f64, run_times, {}, std.sort.asc(f64));
```

Zig's sort is generic:
- **Type**: `f64` (what we're sorting)
- **Slice**: `run_times` (the data)
- **Context**: `{}` (empty, we don't need it)
- **Comparator**: `std.sort.asc(f64)` (ascending order)

This is similar to C's `qsort`, but type-safe (no `void*` casts needed).

### Print Formatting

From `zig/ou_bench.zig:369-387`:

```zig
try stdout.print(
    "{{\"language\":\"Zig\",\"mode\":\"{s}\",\"n\":{},\"runs\":{},\"warmup\":{},\"seed\":{},\"total_s\":{d:.6},\"avg_ms\":{d:.6},\"median_ms\":{d:.6},\"min_ms\":{d:.6},\"max_ms\":{d:.6},\"breakdown_s\":{{\"gen_normals\":{d:.6},\"simulate\":{d:.6},\"checksum\":{d:.6}}},\"checksum\":{d:.17}}}\n",
    .{
        mode_str,
        args.n,
        args.runs,
        args.warmup,
        args.seed,
        total_s,
        avg_ms,
        median_ms,
        min_ms,
        max_ms,
        total_gen_s,
        total_sim_s,
        total_chk_s,
        checksum,
    },
);
```

Zig's format strings:

- `{s}`: String
- `{}`: Default formatting (uses type)
- `{d:.6}`: Decimal with 6 digits precision
- `{d:.17}`: Decimal with 17 digits precision

Arguments are passed as a tuple `.{ arg1, arg2, ... }`.

**Error handling**: `print` can fail (disk full, broken pipe), so it returns `!void`. We use `try` to propagate errors.

## Build System and Compilation

From the header comment (`zig/ou_bench.zig:10`):

```bash
zig build-exe ou_bench.zig -O ReleaseFast -fstrip -femit-bin=ou_bench
```

### Zig Build Flags

**`-O ReleaseFast`**: Maximum optimization for speed
- Equivalent to C's `-O3`
- Disables safety checks (bounds checking, integer overflow)
- Enables aggressive optimizations

Other optimization modes:
- `-O Debug`: No optimization, all safety checks
- `-O ReleaseSafe`: Optimized but keeps safety checks
- `-O ReleaseSmall`: Optimize for size

**`-fstrip`**: Strip debug information
- Reduces binary size
- Removes symbol table
- Not needed for production

**`-femit-bin=ou_bench`**: Output filename
- Without this, output would be `ou_bench.zig.o` or similar

### No Build Files Needed!

For simple projects, Zig doesn't need a build file. The compiler handles everything:

```bash
zig build-exe myproject.zig
```

For complex projects, create `build.zig` (Zig code, not YAML/JSON):

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "ou_bench",
        .root_source_file = "ou_bench.zig",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    b.installArtifact(exe);
}
```

Then run:
```bash
zig build
```

This is more flexible than Makefiles and more type-safe.

### Cross-Compilation

Zig excels at **cross-compilation**. Want to build for Windows from Linux?

```bash
zig build-exe ou_bench.zig -target x86_64-windows
```

For macOS ARM64 from Linux x86_64?

```bash
zig build-exe ou_bench.zig -target aarch64-macos
```

No toolchain setup needed! Zig bundles everything.

## Performance Analysis

### Benchmark Results

| Language | Median (ms) | vs C | Notes |
|----------|-------------|------|-------|
| C | 3.70 | baseline | Raw speed |
| **Zig** | **3.82** | **+3%** | Virtually identical |
| Rust | 3.84 | +4% | Also competitive |

Zig is within **3%** of C. For practical purposes, this is **equivalent performance**.

### Why Is Zig So Fast?

1. **Same compiler backend**: Zig uses LLVM, same as Clang
2. **No runtime**: No garbage collector, no runtime system
3. **Manual memory management**: Like C, explicit control
4. **Zero-cost abstractions**: Features compile away

The 3% difference is likely:
- Slightly different code generation
- Different allocation patterns
- Minor LLVM version differences

### Debug vs Release Performance

Run with safety checks enabled:
```bash
zig build-exe ou_bench.zig -O ReleaseSafe
./ou_bench
```

Expected: ~5-10% slower than ReleaseFast due to:
- Bounds checking on array access
- Integer overflow detection
- Stack overflow detection

This is **worth it during development** to catch bugs early!

### Safety Checks Caught

In debug mode (`-O Debug`), Zig catches:

**Out-of-bounds access**:
```zig
const arr = [_]u32{1, 2, 3};
const val = arr[10];  // Panic: index out of bounds!
```

**Integer overflow**:
```zig
const a: u8 = 250;
const b: u8 = 10;
const c = a + b;  // Panic: overflow!
```

**Null pointer dereference** (if using optionals):
```zig
const ptr: ?*u32 = null;
const val = ptr.?.*;  // Panic: unwrap null!
```

These would be **undefined behavior** in C, potentially causing silent corruption. Zig catches them immediately.

## Memory Safety Features

### No Use-After-Free (in Safe Mode)

Zig doesn't prevent use-after-free by default (you can still `free` manually), but it provides tools:

**Allocator interface**:
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();  // Detects leaks!
const allocator = gpa.allocator();

var arr = try allocator.alloc(u32, 100);
defer allocator.free(arr);

// If you forget 'defer', gpa.deinit() will report the leak
```

**Arena allocator** (for scoped allocations):
```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();  // Frees everything at once
const allocator = arena.allocator();

var arr1 = try allocator.alloc(u32, 100);  // No individual free needed
var arr2 = try allocator.alloc(u32, 200);  // No individual free needed
// arena.deinit() frees all at once
```

### Optional Types (Preventing Null Errors)

Zig has **optional types** for nullable pointers:

```zig
const maybe_ptr: ?*u32 = null;  // Optional pointer

if (maybe_ptr) |ptr| {
    // ptr is *u32 here, guaranteed non-null
    const val = ptr.*;
} else {
    // Handle null case
}
```

The `?T` syntax means "T or null". You must unwrap before use:

```zig
const val = maybe_ptr.?;  // Unwrap (panics if null)
const val = maybe_ptr orelse default;  // Unwrap or use default
```

This prevents null pointer dereferences at compile time!

### Comptime Bounds Checking

For compile-time known arrays:
```zig
const arr = [_]u32{1, 2, 3};
const val = arr[5];  // Compile error: index 5 out of bounds!
```

The compiler **proves** this is wrong and rejects it. No runtime needed!

## Common Zig Idioms

### Error Handling Patterns

**Propagate with try**:
```zig
fn foo() !void {
    try bar();  // If bar fails, return its error
}
```

**Handle with catch**:
```zig
const result = bar() catch |err| {
    std.debug.print("Error: {}\n", .{err});
    return;
};
```

**Provide default**:
```zig
const value = try_something() catch 42;
```

**Ignore errors** (rarely used):
```zig
try_something() catch {};
```

### Resource Management with Defer

**Pattern**: Acquire resource, immediately defer cleanup:
```zig
var file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();  // Always closes, even on error return

var data = try allocator.alloc(u8, 1024);
defer allocator.free(data);  // Always frees
```

### Const vs Var

**Const** for immutable (default choice):
```zig
const x = 5;
const name = "Alice";
const arr = [_]u32{1, 2, 3};
```

**Var** for mutable (only when needed):
```zig
var counter: usize = 0;
counter += 1;  // OK

var rng = XorShift128.init(seed);
```

## Exercises

### Exercise 1: Add ReleaseSafe Build

Compile with safety checks:
```bash
zig build-exe ou_bench.zig -O ReleaseSafe -femit-bin=ou_bench_safe
./ou_bench_safe --runs=100
```

Questions:
1. How much slower is ReleaseSafe vs ReleaseFast?
2. Add an out-of-bounds access bug - does it catch it?
3. Add an integer overflow bug - does it catch it?

### Exercise 2: Implement Standard Deviation

Add standard deviation calculation to the statistics:

```zig
// After computing median
var variance: f64 = 0.0;
var i: usize = 0;
while (i < args.runs) : (i += 1) {
    const diff = run_times[i] - avg_ms;
    variance += diff * diff;
}
variance /= @as(f64, @floatFromInt(args.runs));
const stddev_ms = @sqrt(variance);

try stdout.print("stddev_ms={d:.6}\n", .{stddev_ms});
```

Compile and test.

### Exercise 3: Custom Error Set

Define a custom error set:

```zig
const BenchmarkError = error{
    InvalidN,
    InvalidRuns,
    InvalidWarmup,
    AllocationFailed,
};

fn parseArgs(allocator: std.mem.Allocator) BenchmarkError!Args {
    // ...
    if (v < 2) return BenchmarkError.InvalidN;
    // ...
}
```

This makes error types explicit and documented.

### Exercise 4: Use Arena Allocator

Replace page allocator with arena:

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();  // Frees everything
const allocator = arena.allocator();
```

Remove individual `defer allocator.free(...)` calls. Everything is freed by `arena.deinit()`.

### Exercise 5: Benchmark Zig vs C

Compare identical runs:

```bash
# Build both
cd c && cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
cd ../zig && zig build-exe ou_bench.zig -O ReleaseFast -fstrip

# Run same parameters
cd ../c && ./ou_bench_c --runs=1000 --seed=42 > c_results.txt
cd ../zig && ./ou_bench --runs=1000 --seed=42 > zig_results.txt

# Compare
diff c_results.txt zig_results.txt
```

Questions:
1. Are checksums identical?
2. Is median within 5% for both?
3. Which has lower variance?

## Advanced Topics

### Comptime for Generic Programming

Zig uses `comptime` for generics:

```zig
fn GenericStack(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,

        pub fn push(self: *@This(), item: T) !void {
            // ...
        }
    };
}

const IntStack = GenericStack(i32);
const FloatStack = GenericStack(f64);
```

The `comptime T: type` parameter is evaluated at compile time, generating specialized code for each type.

This is similar to C++ templates but:
- ✓ Simpler syntax
- ✓ Better error messages
- ✓ No template metaprogramming complexity

### Inline Assembly

Zig supports inline assembly for performance-critical code:

```zig
fn rdtsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high)
    );
    return (@as(u64, high) << 32) | low;
}
```

This reads the CPU cycle counter directly.

### Packed Structs

For bit-level control:

```zig
const Flags = packed struct {
    a: bool,
    b: bool,
    c: u6,
};

comptime {
    assert(@sizeOf(Flags) == 1);  // Only 1 byte!
}
```

Packed structs have no padding, useful for:
- Binary protocols
- Hardware registers
- Bit flags

### Async/Await (Experimental)

Zig has async/await for concurrent programming:

```zig
fn fetchUrl(url: []const u8) ![]const u8 {
    suspend {
        // Network request
    }
    resume;
    return data;
}

const data = await fetchUrl("https://example.com");
```

Currently experimental, not stable yet.

## Zig vs C vs Rust

| Feature | C | Zig | Rust |
|---------|---|-----|------|
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Safety** | ⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Simplicity** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Learning curve** | Moderate | Low | High |
| **Compile time** | Fast | Fast | Slow |
| **Ecosystem** | Huge | Growing | Large |

**Choose C** when:
- Legacy codebase
- Maximum portability
- Embedded systems with no Zig support

**Choose Zig** when:
- New systems project
- Want safety without complexity
- Need cross-compilation

**Choose Rust** when:
- Maximum safety required
- Multithreading is core feature
- Can afford longer compile times

## Summary

Zig achieves **near-C performance** (3% slower) while providing:

1. **Explicit error handling**: Errors in type signatures, enforced by compiler
2. **Memory safety features**: Debug-mode bounds checking, leak detection
3. **No hidden control flow**: What you see is what you get
4. **Modern tooling**: Built-in build system, cross-compilation, testing
5. **Explicit semantics**: Wrapping arithmetic, type conversions, allocations

Key language features:
- `try` / `catch` for error handling
- `defer` for resource cleanup
- `comptime` for compile-time execution
- `@builtin` functions for low-level operations
- `inline` for performance hints

Zig occupies a sweet spot: **simpler than Rust, safer than C, as fast as both**.

---

**Previous**: [Chapter 4: C Implementation - The Baseline](04-c-implementation.md)
**Next**: [Chapter 6: Rust - Safety and Performance](06-rust-implementation.md)

## References

- [Zig Official Website](https://ziglang.org/)
- [Zig Documentation](https://ziglang.org/documentation/master/)
- [Zig Learn](https://ziglearn.org/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)
- [Why Zig When There is Already C++, D, and Rust?](https://ziglang.org/learn/why_zig_rust_d_cpp/)
- [Zig Language Reference](https://ziglang.org/documentation/master/#Zig-Language-Reference)
