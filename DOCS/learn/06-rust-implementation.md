# Chapter 6: Rust - Safety and Performance

## What Is Rust?

Rust is a **systems programming language** focused on safety, speed, and concurrency. Created by Mozilla Research in 2010, it has become one of the most loved languages according to Stack Overflow surveys.

**The Rust Promise**: "Fearless concurrency and memory safety without garbage collection"

Think of Rust as **"C++ done right"** - you get the performance of C/C++ with compile-time guarantees that prevent:
- Null pointer dereferences
- Use-after-free bugs
- Data races
- Buffer overflows

### Benchmark Results

In our benchmark, Rust achieves **3.85 ms median** - only 4% slower than C (3.70 ms).

| Language | Median (ms) | vs C | Safety |
|----------|-------------|------|---------|
| C        | 3.70        | baseline | Manual |
| Zig      | 3.82        | +3%  | Debug mode only |
| **Rust** | **3.84**    | **+4%** | **Compile-time guaranteed** |

Rust proves you can have **both** safety and performance.

## The Ownership System

Rust's signature feature is **ownership** - a set of rules the compiler enforces at compile time.

### The Three Rules

1. **Each value has an owner**
2. **Only one owner at a time**
3. **When owner goes out of scope, value is dropped**

Example:
```rust
{
    let s = String::from("hello");  // s owns the String
    // s is valid here
}  // s goes out of scope, String is dropped (freed)
```

No manual `free()` needed! The compiler inserts cleanup code automatically.

### Move Semantics

```rust
let s1 = String::from("hello");
let s2 = s1;  // s1's ownership moves to s2
println!("{}", s1);  // ERROR: s1 no longer valid!
```

After the move, `s1` is invalid. This prevents use-after-free bugs:

```c
// C: Use-after-free bug!
char *s1 = malloc(100);
char *s2 = s1;
free(s2);
printf("%s", s1);  // Undefined behavior!
```

Rust catches this at **compile time**.

### Borrowing

You can **borrow** a value without taking ownership:

```rust
fn calculate_length(s: &String) -> usize {
    s.len()  // Borrow s, don't own it
}  // s goes out of scope, but nothing is dropped

let s = String::from("hello");
let len = calculate_length(&s);  // Borrow s
println!("{}", s);  // s is still valid!
```

The `&` means "borrow" - a reference without ownership.

### Mutable vs Immutable Borrows

```rust
let mut s = String::from("hello");

let r1 = &s;        // Immutable borrow
let r2 = &s;        // Another immutable borrow (OK)
let r3 = &mut s;    // ERROR: Can't have mutable borrow while immutable borrows exist

println!("{} {}", r1, r2);
```

**Rules**:
- Multiple immutable borrows: ✓ OK
- One mutable borrow: ✓ OK
- Mutable + immutable: ✗ ERROR

This prevents data races at compile time!

## The Rust Implementation

Our Rust implementation is `rust/src/main.rs` (421 lines). Let's examine key patterns.

### Structs with Copy vs Clone

From `rust/src/main.rs:5-18`:

```rust
#[derive(Clone, Copy)]
struct SplitMix32 {
    s: u32,
}

impl SplitMix32 {
    #[inline(always)]
    fn next_u32(&mut self) -> u32 {
        self.s = self.s.wrapping_add(0x9E37_79B9);
        let mut z = self.s;
        z = (z ^ (z >> 16)).wrapping_mul(0x85EB_CA6B);
        z = (z ^ (z >> 13)).wrapping_mul(0xC2B2_AE35);
        z ^ (z >> 16)
    }
}
```

**#[derive(Clone, Copy)]**: Automatically implements Copy trait
- **Copy**: Bitwise copy (like C's memcpy)
- **Clone**: Explicit copy via `.clone()`

Types that are Copy can be passed by value without moving ownership.

**Wrapping arithmetic**:
- `wrapping_add()`: Wraps on overflow (like Zig's `+%`)
- `wrapping_mul()`: Wraps on overflow (like Zig's `*%`)

This makes overflow behavior explicit.

### Traits and Implementations

```rust
impl SplitMix32 {
    fn next_u32(&mut self) -> u32 {
        // Implementation
    }
}
```

`impl` blocks add methods to types. The `&mut self` parameter:
- Borrows the instance mutably
- Allows modification
- Automatically returned to caller after method

### Option and Result Types

Rust has no null pointers. Instead, use `Option<T>`:

```rust
enum Option<T> {
    Some(T),
    None,
}

let maybe_value: Option<i32> = Some(42);
match maybe_value {
    Some(v) => println!("Value: {}", v),
    None => println!("No value"),
}
```

For errors, use `Result<T, E>`:

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}

fn parse_number(s: &str) -> Result<i32, ParseIntError> {
    s.parse()
}

let num = parse_number("42")?;  // ? propagates errors
```

The `?` operator:
- If Ok(value) → unwrap value
- If Err(e) → return Err(e)

This is like Zig's `try`.

### Cargo and Dependencies

Rust's package manager is **Cargo**. From `rust/Cargo.toml`:

```toml
[package]
name = "ou_bench_unified"
version = "0.1.0"
edition = "2021"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"
```

**Optimization settings**:
- `opt-level = 3`: Maximum optimization (like `-O3`)
- `lto = true`: Link-Time Optimization
- `codegen-units = 1`: Single codegen unit (slower compile, faster runtime)
- `panic = "abort"`: Abort on panic instead of unwinding (smaller binary)

Build:
```bash
cargo build --release
```

This creates `target/release/ou_bench_unified`.

### The main() Function

From `rust/src/main.rs`:

```rust
fn main() {
    let args = parse_args();

    let t: f64 = 1.0;
    let theta: f64 = 1.0;
    let mu: f64 = 0.0;
    let sigma: f64 = 0.1;

    let n = args.n;
    let dt: f64 = t / (n as f64);
    let a: f64 = 1.0 - theta * dt;
    let b: f64 = theta * mu * dt;
    let diff: f64 = sigma * dt.sqrt();

    let mut gn = vec![0.0_f64; n - 1];
    let mut ou = vec![0.0_f64; n];

    // ... warmup and timed runs
}
```

**vec!** macro creates a vector (growable array):
```rust
let mut gn = vec![0.0_f64; n - 1];  // n-1 zeros
```

This is heap-allocated, like C's `malloc`.

**Type conversions**:
```rust
let dt = t / (n as f64);  // Cast n to f64
```

`as` is Rust's cast operator (like Zig's `@as`).

### Timing with Instant

From `rust/src/main.rs`:

```rust
use std::time::Instant;

let t0 = Instant::now();
// ... work ...
let t1 = Instant::now();

let elapsed = (t1 - t0).as_secs_f64();  // Duration in seconds
```

`Instant` is Rust's high-resolution timer:
- Monotonic (doesn't go backward)
- Platform-independent
- Sub-millisecond precision

### Pattern Matching with Match

```rust
let mode_str = match args.mode {
    Mode::Full => "full",
    Mode::Gn => "gn",
    Mode::Ou => "ou",
};
```

`match` is like switch but:
- Must be exhaustive (all cases covered)
- Returns a value
- Supports pattern matching

### The ? Operator for Error Propagation

```rust
fn parse_args() -> Args {
    let args: Vec<String> = std::env::args().collect();
    // Parse arguments
}
```

If a function can fail, return `Result`:

```rust
fn parse_number(s: &str) -> Result<i32, std::num::ParseIntError> {
    let num = s.parse()?;  // Propagate error if parse fails
    Ok(num)
}
```

The `?` unwraps Ok or returns Err.

## Zero-Cost Abstractions

Rust's motto: **"Zero-cost abstractions"** - high-level features compile to the same code as hand-written low-level code.

### Iterator Example

```rust
// High-level
let sum: i32 = (0..1000).map(|x| x * 2).filter(|x| x % 3 == 0).sum();

// Compiles to the same code as:
let mut sum: i32 = 0;
for x in 0..1000 {
    let doubled = x * 2;
    if doubled % 3 == 0 {
        sum += doubled;
    }
}
```

The high-level iterator code:
- ✓ More readable
- ✓ Same performance
- ✓ Harder to make mistakes

This is zero-cost abstraction.

### Inlining

```rust
#[inline(always)]
fn next_u32(&mut self) -> u32 {
    // ...
}
```

`#[inline(always)]` forces inlining, eliminating function call overhead.

## Memory Safety Guarantees

### No Null Pointer Dereferences

```rust
let maybe_ptr: Option<&i32> = Some(&42);

match maybe_ptr {
    Some(ptr) => println!("Value: {}", *ptr),
    None => println!("No value"),
}

// Can't do this:
// let value = *maybe_ptr;  // ERROR: Option is not a pointer
```

You must unwrap Option before use. Compiler enforces this.

### No Use-After-Free

```rust
let r;
{
    let x = 5;
    r = &x;  // ERROR: x doesn't live long enough
}  // x goes out of scope
println!("{}", r);  // Would be use-after-free
```

The borrow checker prevents this at compile time!

### No Data Races

```rust
use std::thread;

let mut data = vec![1, 2, 3];

thread::spawn(|| {
    data.push(4);  // ERROR: Can't move mutable reference to thread
});
```

Rust won't compile code with potential data races.

To share data between threads, use synchronization:

```rust
use std::sync::{Arc, Mutex};

let data = Arc::new(Mutex::new(vec![1, 2, 3]));
let data_clone = data.clone();

thread::spawn(move || {
    let mut d = data_clone.lock().unwrap();
    d.push(4);  // OK: Mutex ensures exclusive access
});
```

## Performance Characteristics

### Why Rust Is Fast

1. **No garbage collector**: Manual memory management (via ownership)
2. **Zero-cost abstractions**: High-level code compiles to low-level
3. **LLVM backend**: Same optimizer as C/Clang
4. **Aggressive inlining**: Compiler inlines aggressively

### Why 4% Slower Than C?

Possible reasons:
- Bounds checking in some cases
- Different code generation choices
- Slightly different memory layout

For practical purposes, **4% is negligible**. Rust's safety is worth it.

### Unsafe Rust

For ultimate performance, Rust has `unsafe` blocks:

```rust
unsafe {
    // Can dereference raw pointers
    // Can call unsafe functions
    // Still no undefined behavior if used correctly
}
```

Our benchmark doesn't need `unsafe` - safe Rust is fast enough!

## Exercises

### Exercise 1: Add Standard Deviation

Extend the statistics:

```rust
let mean = total_s / (args.runs as f64);
let variance: f64 = run_times.iter()
    .map(|&time| (time - mean).powi(2))
    .sum::<f64>() / (args.runs as f64);
let stddev = variance.sqrt();

println!("stddev={:.6}", stddev);
```

### Exercise 2: Use Iterator Methods

Replace manual loops with iterators:

```rust
// Manual loop
let mut sum = 0.0;
for i in 0..n {
    sum += ou[i];
}

// Iterator
let sum: f64 = ou.iter().sum();
```

Compare performance with `cargo bench`.

### Exercise 3: Add Error Handling

Make `parse_args` return `Result`:

```rust
fn parse_args() -> Result<Args, String> {
    // Return Err("message") on invalid input
    // Return Ok(args) on success
}

fn main() {
    let args = parse_args().unwrap_or_else(|err| {
        eprintln!("Error: {}", err);
        std::process::exit(1);
    });
}
```

### Exercise 4: Profile with cargo-flamegraph

Install flamegraph tool:
```bash
cargo install flamegraph
```

Generate profile:
```bash
cargo flamegraph --bin ou_bench_unified -- --runs=1000
```

This creates a flame graph showing where time is spent.

### Exercise 5: Compare Debug vs Release

```bash
# Debug build (has bounds checking)
cargo build
time ./target/debug/ou_bench_unified --runs=100

# Release build (optimized)
cargo build --release
time ./target/release/ou_bench_unified --runs=100
```

How much faster is release?

## Common Rust Patterns

### Builder Pattern

```rust
let args = ArgsBuilder::new()
    .n(500_000)
    .runs(1000)
    .warmup(5)
    .seed(1)
    .build();
```

### Error Handling Chain

```rust
let result = File::open("data.txt")
    .and_then(|file| read_to_string(file))
    .map(|content| content.len())
    .unwrap_or(0);
```

### Smart Pointers

```rust
Box<T>          // Heap allocation
Rc<T>           // Reference counting
Arc<T>          // Atomic reference counting (thread-safe)
RefCell<T>      // Interior mutability
```

## Rust Ecosystem

### Crates (Libraries)

- **serde**: Serialization/deserialization
- **tokio**: Async runtime
- **rayon**: Data parallelism
- **clap**: Command-line argument parsing

### Tools

- **cargo**: Package manager and build tool
- **rustfmt**: Code formatter
- **clippy**: Linter with 500+ lint checks
- **rust-analyzer**: LSP for IDE integration

## Rust vs C vs Zig Summary

| Aspect | C | Zig | Rust |
|--------|---|-----|------|
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Memory safety** | Manual | Debug mode | Compile-time guaranteed |
| **Learning curve** | Medium | Low | High |
| **Compile time** | Fast | Fast | Slow |
| **Error messages** | Cryptic | Clear | Very detailed |
| **Ecosystem** | Massive | Growing | Large |

**Choose Rust** when:
- Safety is critical (no room for bugs)
- Building concurrent systems
- Want modern tooling
- Can afford longer compile times

Our benchmark shows Rust achieves **C-like performance with compile-time safety**.

---

**Previous**: [Chapter 5: Zig - Modern Systems Programming](05-zig-implementation.md)
**Next**: [Chapter 7: TypeScript/Bun - Dynamic Language Performance](07-typescript-implementation.md)

## References

- [The Rust Programming Language](https://doc.rust-lang.org/book/)
- [Rust By Example](https://doc.rust-lang.org/rust-by-example/)
- [The Cargo Book](https://doc.rust-lang.org/cargo/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
