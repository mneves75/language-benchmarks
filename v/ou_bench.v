/*
  Unified OU benchmark (V)

  Algorithms intentionally match TS/Rust/Zig/C in this repo:
  - PRNG: xorshift128 (u32) seeded via splitmix32
  - Uniform: 53-bit double from two u32 draws
  - Normal: Marsaglia polar method with cached spare
  - OU: Euler update with precomputed a,b and diffusion coefficient

  Build (maximum optimization):
    v -prod -cstrict -cc gcc -skip-unused -cflags '-O3 -ffast-math -march=native -fno-math-errno -fno-trapping-math' ou_bench.v

  Run:
    ./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1
*/

import time
import math
import os

struct Splitmix32 {
mut:
	s u32
}

@[inline]
fn (mut sm Splitmix32) next() u32 {
	sm.s = sm.s + u32(0x9E3779B9)
	mut z := sm.s
	z = (z ^ (z >> 16)) * u32(0x85EBCA6B)
	z = (z ^ (z >> 13)) * u32(0xC2B2AE35)
	z = z ^ (z >> 16)
	return z
}

struct Xorshift128 {
mut:
	x u32
	y u32
	z u32
	w u32
}

fn xorshift128_new(seed u32) Xorshift128 {
	mut sm := Splitmix32{s: seed}
	mut rng := Xorshift128{
		x: sm.next()
		y: sm.next()
		z: sm.next()
		w: sm.next()
	}
	if (rng.x | rng.y | rng.z | rng.w) == u32(0) {
		rng.w = u32(1)
	}
	return rng
}

@[inline]
fn (mut rng Xorshift128) next_u32() u32 {
	t := rng.x ^ (rng.x << 11)
	rng.x = rng.y
	rng.y = rng.z
	rng.z = rng.w
	rng.w = rng.w ^ (rng.w >> 19) ^ t ^ (t >> 8)
	return rng.w
}

@[inline]
fn (mut rng Xorshift128) next_f64() f64 {
	a := rng.next_u32()
	b := rng.next_u32()
	u := (u64(a >> 5) << 26) | u64(b >> 6)
	return f64(u) * (1.0 / 9007199254740992.0)
}

struct NormalPolar {
mut:
	has_spare bool
	spare     f64
}

@[inline]
fn (mut n NormalPolar) next(mut rng Xorshift128) f64 {
	if n.has_spare {
		n.has_spare = false
		return n.spare
	}
	for {
		u := 2.0 * rng.next_f64() - 1.0
		v := 2.0 * rng.next_f64() - 1.0
		s := u * u + v * v
		if s > 0.0 && s < 1.0 {
			m := math.sqrt((-2.0 * math.log(s)) / s)
			n.spare = v * m
			n.has_spare = true
			return u * m
		}
	}
	return 0.0 // unreachable
}

enum Mode {
	full
	gn
	ou
}

enum Output {
	text
	json
}

struct Args {
	n      int
	runs   int
	warmup int
	seed   u32
	mode   Mode
	output Output
}

fn parse_args() Args {
	mut n := 500000
	mut runs := 1000
	mut warmup := 5
	mut seed := u32(1)
	mut mode := Mode.full
	mut output := Output.text

	for arg in os.args[1..] {
		if arg.starts_with('--n=') {
			n = arg.substr(4, arg.len).int()
			if n < 2 {
				eprintln('--n must be >= 2')
				exit(1)
			}
		} else if arg.starts_with('--runs=') {
			runs = arg.substr(7, arg.len).int()
			if runs < 1 {
				eprintln('--runs must be >= 1')
				exit(1)
			}
		} else if arg.starts_with('--warmup=') {
			warmup = arg.substr(9, arg.len).int()
			if warmup < 0 {
				eprintln('--warmup must be >= 0')
				exit(1)
			}
		} else if arg.starts_with('--seed=') {
			seed = u32(arg.substr(7, arg.len).u64())
		} else if arg.starts_with('--mode=') {
			mode_str := arg.substr(7, arg.len)
			mode = match mode_str {
				'full' { Mode.full }
				'gn' { Mode.gn }
				'ou' { Mode.ou }
				else {
					eprintln('--mode must be full|gn|ou')
					exit(1)
				}
			}
		} else if arg.starts_with('--output=') {
			output_str := arg.substr(9, arg.len)
			output = match output_str {
				'text' { Output.text }
				'json' { Output.json }
				else {
					eprintln('--output must be text|json')
					exit(1)
				}
			}
		}
	}

	return Args{
		n: n
		runs: runs
		warmup: warmup
		seed: seed
		mode: mode
		output: output
	}
}

fn median(mut times []f64) f64 {
	times.sort()
	if times.len % 2 == 1 {
		return times[times.len / 2]
	} else {
		return (times[times.len / 2 - 1] + times[times.len / 2]) / 2.0
	}
}

fn main() {
	args := parse_args()

	t_param := 1.0
	theta := 1.0
	mu := 0.0
	sigma := 0.1

	n := args.n

	dt := t_param / f64(n)
	a := 1.0 - theta * dt
	b := theta * mu * dt
	diff := sigma * math.sqrt(dt)

	mut gn := []f64{len: n - 1}
	mut ou := []f64{len: n}

	// Pre-fill gn for MODE_OU
	if args.mode == .ou {
		mut rng_prefill := xorshift128_new(args.seed)
		mut norm_prefill := NormalPolar{}
		unsafe {
			for i in 0 .. n - 1 {
				gn[i] = diff * norm_prefill.next(mut rng_prefill)
			}
		}
	}

	// Warmup
	{
		mut rng := xorshift128_new(args.seed)
		mut norm := NormalPolar{}

		for _ in 0 .. args.warmup {
			mut s := 0.0
			match args.mode {
				.full {
					unsafe {
						for i in 0 .. n - 1 {
							gn[i] = diff * norm.next(mut rng)
						}
						mut x := 0.0
						ou[0] = x
						for i in 1 .. n {
							x = a * x + b + gn[i - 1]
							ou[i] = x
						}
						for i in 0 .. n {
							s += ou[i]
						}
					}
				}
				.gn {
					unsafe {
						for i in 0 .. n - 1 {
							gn[i] = diff * norm.next(mut rng)
						}
						for i in 0 .. n - 1 {
							s += gn[i]
						}
					}
				}
				.ou {
					unsafe {
						mut x := 0.0
						ou[0] = x
						for i in 1 .. n {
							x = a * x + b + gn[i - 1]
							ou[i] = x
						}
						for i in 0 .. n {
							s += ou[i]
						}
					}
				}
			}
			if s == 123456789.0 {
				println('impossible')
			}
		}
	}

	// Timed runs
	mut rng := xorshift128_new(args.seed)
	mut norm := NormalPolar{}

	mut total_s := 0.0
	mut total_gen_s := 0.0
	mut total_sim_s := 0.0
	mut total_chk_s := 0.0

	mut min_s := 1e300
	mut max_s := 0.0
	mut run_times := []f64{len: args.runs}

	mut checksum := 0.0

	for r in 0 .. args.runs {
		mut gen := 0.0
		mut sim := 0.0
		mut chk := 0.0
		mut run := 0.0

		match args.mode {
			.full {
				t0 := time.sys_mono_now()
				unsafe {
					for i in 0 .. n - 1 {
						gn[i] = diff * norm.next(mut rng)
					}
				}
				t1 := time.sys_mono_now()

				unsafe {
					mut x := 0.0
					ou[0] = x
					for i in 1 .. n {
						x = a * x + b + gn[i - 1]
						ou[i] = x
					}
				}
				t2 := time.sys_mono_now()

				mut s := 0.0
				unsafe {
					for i in 0 .. n {
						s += ou[i]
					}
				}
				checksum += s
				t3 := time.sys_mono_now()

				gen = f64(t1 - t0) * 1e-9
				sim = f64(t2 - t1) * 1e-9
				chk = f64(t3 - t2) * 1e-9
				run = f64(t3 - t0) * 1e-9
			}
			.gn {
				t0 := time.sys_mono_now()
				unsafe {
					for i in 0 .. n - 1 {
						gn[i] = diff * norm.next(mut rng)
					}
				}
				t1 := time.sys_mono_now()

				mut s := 0.0
				unsafe {
					for i in 0 .. n - 1 {
						s += gn[i]
					}
				}
				checksum += s
				t2 := time.sys_mono_now()

				gen = f64(t1 - t0) * 1e-9
				sim = 0.0
				chk = f64(t2 - t1) * 1e-9
				run = f64(t2 - t0) * 1e-9
			}
			.ou {
				t0 := time.sys_mono_now()
				unsafe {
					mut x := 0.0
					ou[0] = x
					for i in 1 .. n {
						x = a * x + b + gn[i - 1]
						ou[i] = x
					}
				}
				t1 := time.sys_mono_now()

				mut s := 0.0
				unsafe {
					for i in 0 .. n {
						s += ou[i]
					}
				}
				checksum += s
				t2 := time.sys_mono_now()

				gen = 0.0
				sim = f64(t1 - t0) * 1e-9
				chk = f64(t2 - t1) * 1e-9
				run = f64(t2 - t0) * 1e-9
			}
		}

		total_gen_s += gen
		total_sim_s += sim
		total_chk_s += chk
		total_s += run
		run_times[r] = run

		if run < min_s {
			min_s = run
		}
		if run > max_s {
			max_s = run
		}
	}

	// Calculate statistics
	median_s := median(mut run_times)
	avg_ms := (total_s / f64(args.runs)) * 1000.0
	median_ms := median_s * 1000.0
	min_ms := min_s * 1000.0
	max_ms := max_s * 1000.0

	mode_str := match args.mode {
		.full { 'full' }
		.gn { 'gn' }
		.ou { 'ou' }
	}

	if args.output == .json {
		println('{"language":"V","mode":"${mode_str}","n":${args.n},"runs":${args.runs},"warmup":${args.warmup},"seed":${args.seed},"total_s":${total_s:.6f},"avg_ms":${avg_ms:.6f},"median_ms":${median_ms:.6f},"min_ms":${min_ms:.6f},"max_ms":${max_ms:.6f},"breakdown_s":{"gen_normals":${total_gen_s:.6f},"simulate":${total_sim_s:.6f},"checksum":${total_chk_s:.6f}},"checksum":${checksum:.17g}}')
	} else {
		println('== OU benchmark (V, unified algorithms) ==')
		println('n=${args.n} runs=${args.runs} warmup=${args.warmup} seed=${args.seed}')
		println('total_s=${total_s:.6f}')
		println('avg_ms=${avg_ms:.6f} median_ms=${median_ms:.6f} min_ms=${min_ms:.6f} max_ms=${max_ms:.6f}')
		println('breakdown_s gen_normals=${total_gen_s:.6f} simulate=${total_sim_s:.6f} checksum=${total_chk_s:.6f}')
		println('checksum=${checksum:.17g}')
	}
}
