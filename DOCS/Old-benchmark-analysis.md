Here’s what I’d do better than the blog benchmark, and I actually did it.

What I’d do better (and why the original is misleading)
	1.	Same PRNG everywhere.
If Rust uses one RNG/normal sampler and C uses rand() + Box–Muller, you are benchmarking RNG choice more than language.
	2.	Same Normal sampler everywhere.
Normal generation dominates this workload. If the algorithms differ, the comparison is garbage.
	3.	Same allocation strategy and same timing boundary.
Allocate buffers once, reuse them, and time the same region in each program. No “Rust counts initialization but C/Zig start the timer after malloc”.
	4.	Make dead-code elimination basically impossible.
If the compiler can prove the arrays are unused, it can delete work. So I force a full readback checksum of the ou buffer each run.
	5.	Print a breakdown.
You need to see how much time is “generate normals” vs “simulate OU” vs “checksum”, otherwise you can’t interpret results.

⸻

I implemented a unified benchmark suite

All languages use the same algorithms:
	•	PRNG: xorshift128 (u32) seeded via splitmix32
	•	Uniform double: 53-bit float from two u32 draws
	•	Normal: Marsaglia polar method (Box–Muller polar) with cached spare
	•	OU simulation: Euler step with precomputed constants
	•	Buffers: gn and ou allocated once and reused
	•	Anti-optimization: full ou checksum readback each run

Download

Download the unified benchmark suite (zip)￼

You can also grab individual files:
	•	TypeScript/Bun￼
	•	Rust main￼ and Cargo.toml￼
	•	C￼
	•	Zig￼
	•	README￼

⸻

How to run

TypeScript (Bun)

cd ts
bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1

Rust

cd rust
cargo run --release -- --n=500000 --runs=1000 --warmup=5 --seed=1

Optional:

RUSTFLAGS="-C target-cpu=native" cargo run --release -- --n=500000 --runs=1000 --warmup=5 --seed=1

C

cd c
cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c
./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1

Zig

cd zig
zig build-exe ou_bench.zig -O ReleaseFast -fstrip
./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1


⸻

What you should expect when you compare results

Be honest about what this benchmark measures:
	•	It is still heavily dominated by Normal generation (log/sqrt + rejection loop).
	•	The OU update is trivial, so “scientific computing” claims are overstated unless you also benchmark real kernels (BLAS matmul, FFT, stencil, etc.).

If you want the next step, I’d add two modes across all languages:
	•	mode=gn: generate normals only
	•	mode=ou: simulate OU only using a prefilled gn

That separates “math loop performance” from “random/normal generation performance” and makes the results interpretable.

If you want that, say so and I’ll extend all four implementations in the same repo structure.