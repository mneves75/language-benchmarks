// Unified OU benchmark (Zig)
//
// Algorithms intentionally match TS/Rust/C in this repo:
// - PRNG: xorshift128 (u32) seeded via splitmix32
// - Uniform: 53-bit double from two u32 draws
// - Normal: Marsaglia polar method with cached spare
// - OU: Euler update with precomputed a,b and diffusion coefficient
//
// Build:
//   zig build-exe ou_bench.zig -O ReleaseFast -fstrip
//
// Run:
//   ./ou_bench --n=500000 --runs=1000 --warmup=5 --seed=1

const std = @import("std");

const Args = struct {
    n: usize = 500_000,
    runs: usize = 1000,
    warmup: usize = 5,
    seed: u32 = 1,
};

fn parseArgs(allocator: std.mem.Allocator) !Args {
    var out = Args{};
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (!std.mem.startsWith(u8, a, "--")) continue;

        if (std.mem.startsWith(u8, a, "--n=")) {
            const v = try std.fmt.parseInt(usize, a[4..], 10);
            if (v < 2) return error.InvalidN;
            out.n = v;
        } else if (std.mem.startsWith(u8, a, "--runs=")) {
            const v = try std.fmt.parseInt(usize, a[7..], 10);
            if (v < 1) return error.InvalidRuns;
            out.runs = v;
        } else if (std.mem.startsWith(u8, a, "--warmup=")) {
            const v = try std.fmt.parseInt(usize, a[9..], 10);
            out.warmup = v;
        } else if (std.mem.startsWith(u8, a, "--seed=")) {
            const v = try std.fmt.parseInt(u64, a[7..], 10);
            out.seed = @as(u32, @intCast(v & 0xFFFF_FFFF));
        }
    }

    return out;
}

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

const XorShift128 = struct {
    x: u32,
    y: u32,
    z: u32,
    w: u32,

    fn init(seed: u32) XorShift128 {
        var sm = SplitMix32{ .s = seed };
        var r = XorShift128{
            .x = sm.next(),
            .y = sm.next(),
            .z = sm.next(),
            .w = sm.next(),
        };
        if ((r.x | r.y | r.z | r.w) == 0) {
            r.w = 1;
        }
        return r;
    }

    inline fn nextU32(self: *XorShift128) u32 {
        const t: u32 = self.x ^ (self.x << 11);
        self.x = self.y;
        self.y = self.z;
        self.z = self.w;
        self.w = self.w ^ (self.w >> 19) ^ t ^ (t >> 8);
        return self.w;
    }

    inline fn nextF64(self: *XorShift128) f64 {
        const a: u32 = self.nextU32();
        const b: u32 = self.nextU32();
        const u: u64 = (@as(u64, a >> 5) << 26) | @as(u64, b >> 6);
        return @as(f64, @floatFromInt(u)) * (1.0 / 9007199254740992.0);
    }
};

const NormalPolar = struct {
    has_spare: bool = false,
    spare: f64 = 0.0,

    inline fn next(self: *NormalPolar, rng: *XorShift128) f64 {
        if (self.has_spare) {
            self.has_spare = false;
            return self.spare;
        }
        while (true) {
            const u = 2.0 * rng.nextF64() - 1.0;
            const v = 2.0 * rng.nextF64() - 1.0;
            const s = u * u + v * v;
            if (s > 0.0 and s < 1.0) {
                const m = @sqrt((-2.0 * @log(s)) / s);
                self.spare = v * m;
                self.has_spare = true;
                return u * m;
            }
        }
    }
};

inline fn nowNs() i128 {
    return std.time.nanoTimestamp();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try parseArgs(allocator);

    const T: f64 = 1.0;
    const theta: f64 = 1.0;
    const mu: f64 = 0.0;
    const sigma: f64 = 0.1;

    const n = args.n;

    const dt: f64 = T / @as(f64, @floatFromInt(n));
    const a: f64 = 1.0 - theta * dt;
    const b: f64 = theta * mu * dt;
    const diff: f64 = sigma * @sqrt(dt);

    var gn = try allocator.alloc(f64, n - 1);
    defer allocator.free(gn);
    var ou = try allocator.alloc(f64, n);
    defer allocator.free(ou);

    // Warmup
    {
        var rng = XorShift128.init(args.seed);
        var norm = NormalPolar{};
        var r: usize = 0;
        while (r < args.warmup) : (r += 1) {
            var i: usize = 0;
            while (i < n - 1) : (i += 1) {
                gn[i] = diff * norm.next(&rng);
            }

            var x: f64 = 0.0;
            ou[0] = x;
            i = 1;
            while (i < n) : (i += 1) {
                x = a * x + b + gn[i - 1];
                ou[i] = x;
            }

            var s: f64 = 0.0;
            i = 0;
            while (i < n) : (i += 1) {
                s += ou[i];
            }
            if (s == 123456789.0) {
                std.debug.print("impossible\n", .{});
            }
        }
    }

    // Timed runs
    var rng = XorShift128.init(args.seed);
    var norm = NormalPolar{};

    var total_s: f64 = 0.0;
    var total_gen_s: f64 = 0.0;
    var total_sim_s: f64 = 0.0;
    var total_chk_s: f64 = 0.0;

    var min_s: f64 = 1e300;
    var max_s: f64 = 0.0;
    var run_times = try allocator.alloc(f64, args.runs);
    defer allocator.free(run_times);

    var checksum: f64 = 0.0;

    var r: usize = 0;
    while (r < args.runs) : (r += 1) {
        const t0 = nowNs();

        var i: usize = 0;
        while (i < n - 1) : (i += 1) {
            gn[i] = diff * norm.next(&rng);
        }
        const t1 = nowNs();

        var x: f64 = 0.0;
        ou[0] = x;
        i = 1;
        while (i < n) : (i += 1) {
            x = a * x + b + gn[i - 1];
            ou[i] = x;
        }
        const t2 = nowNs();

        var s: f64 = 0.0;
        i = 0;
        while (i < n) : (i += 1) {
            s += ou[i];
        }
        checksum += s;
        const t3 = nowNs();

        const gen = @as(f64, @floatFromInt(t1 - t0)) * 1e-9;
        const sim = @as(f64, @floatFromInt(t2 - t1)) * 1e-9;
        const chk = @as(f64, @floatFromInt(t3 - t2)) * 1e-9;
        const run = @as(f64, @floatFromInt(t3 - t0)) * 1e-9;

        total_gen_s += gen;
        total_sim_s += sim;
        total_chk_s += chk;
        total_s += run;
        run_times[r] = run;

        if (run < min_s) min_s = run;
        if (run > max_s) max_s = run;
    }

    // Sort run_times for median
    std.mem.sort(f64, run_times, {}, std.sort.asc(f64));
    const median_s = if (args.runs % 2 == 1)
        run_times[args.runs / 2]
    else
        (run_times[args.runs / 2 - 1] + run_times[args.runs / 2]) / 2.0;

    const avg_ms = (total_s / @as(f64, @floatFromInt(args.runs))) * 1000.0;
    const median_ms = median_s * 1000.0;
    const min_ms = min_s * 1000.0;
    const max_ms = max_s * 1000.0;

    std.debug.print("== OU benchmark (Zig, unified algorithms) ==\n", .{});
    std.debug.print("n={} runs={} warmup={} seed={}\n", .{ args.n, args.runs, args.warmup, args.seed });
    std.debug.print("total_s={d:.6}\n", .{ total_s });
    std.debug.print("avg_ms={d:.6} median_ms={d:.6} min_ms={d:.6} max_ms={d:.6}\n", .{ avg_ms, median_ms, min_ms, max_ms });
    std.debug.print("breakdown_s gen_normals={d:.6} simulate={d:.6} checksum={d:.6}\n", .{ total_gen_s, total_sim_s, total_chk_s });
    std.debug.print("checksum={d:.17}\n", .{ checksum });
}
