# Benchmark Run Record

## Environment
- Date/time (local): 2025-12-19
- Hostname: 192.168.0.19
- OS version: macOS 26.3 (Build 25D5087f)
- CPU model: Mac16,8
- RAM: 51539607552 bytes
- Power state (AC/battery): unknown
- Thermal state (if known): unknown
- Background load notes: none recorded

## Toolchain Versions
- C compiler (clang/gcc + version): Apple clang 17.0.0 (clang-1700.6.3.2)
- Zig version: 0.15.2
- Rust version: rustc 1.92.0 (ded5c06cf 2025-12-08) (Homebrew)
- Bun version: 1.3.5
- Swift version: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)

## Command
- Command line (exact): ./run_all.sh
- Parameters: n=500000, runs=1000, warmup=5, seed=1, mode=full, output=text

## Results
- Raw output:

```
=== Building all benchmarks ===

Building Rust...
Building C...
Building Zig...
Building Swift...

=== Running benchmarks ===
n=500000 runs=1000 warmup=5 seed=1

[TypeScript/Bun]
== OU benchmark (TypeScript/Bun, unified algorithms) ==
n=500000 runs=1000 warmup=5 seed=1
total_s=6.154940
avg_ms=6.154940 median_ms=6.127333 min_ms=5.767834 max_ms=18.321375
breakdown_s gen_normals=4.964520 simulate=0.923680 checksum=0.266740
checksum=609886.10196144308

[Rust]
== OU benchmark (Rust, unified algorithms) ==
n=500000 runs=1000 warmup=5 seed=1
total_s=3.849924
avg_ms=3.849924 median_ms=3.838334 min_ms=3.588625 max_ms=5.794250
breakdown_s gen_normals=2.713513 simulate=0.853216 checksum=0.283195
checksum=609886.10196144308429211

[C]
== OU benchmark (C, unified algorithms) ==
n=500000 runs=1000 warmup=5 seed=1
total_s=3.705480
avg_ms=3.705480 median_ms=3.698000 min_ms=3.444000 max_ms=5.075000
breakdown_s gen_normals=2.840233 simulate=0.621669 checksum=0.243578
checksum=609886.10196144308

[Zig]
== OU benchmark (Zig, unified algorithms) ==
n=500000 runs=1000 warmup=5 seed=1
total_s=3.824517
avg_ms=3.824517 median_ms=3.821000 min_ms=3.567000 max_ms=5.081000
breakdown_s gen_normals=2.733136 simulate=0.850004 checksum=0.241377
checksum=609886.10196144310000000
[Swift]
== OU benchmark (Swift, unified algorithms) ==
n=500000 runs=1000 warmup=5 seed=1
total_s=9.249255
avg_ms=9.249255 median_ms=9.254813 min_ms=8.819916 max_ms=9.954542
breakdown_s gen_normals=8.049033 simulate=0.929598 checksum=0.270624
checksum=609886.10196144308
```

## Notes
- Observed anomalies or variance: none noted
- Comparison target (if any): none
