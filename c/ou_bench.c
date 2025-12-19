/*
  Unified OU benchmark (C)

  Algorithms intentionally match TS/Rust/Zig in this repo:
  - PRNG: xorshift128 (u32) seeded via splitmix32
  - Uniform: 53-bit double from two u32 draws
  - Normal: Marsaglia polar method with cached spare
  - OU: Euler update with precomputed a,b and diffusion coefficient

  Build:
    cc -O3 -march=native -std=c11 ou_bench.c -lm -o ou_bench_c

  Run:
    ./ou_bench_c --n=500000 --runs=1000 --warmup=5 --seed=1
*/

#define _POSIX_C_SOURCE 199309L
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

typedef struct {
    uint32_t s;
} splitmix32_t;

static inline uint32_t splitmix32_next(splitmix32_t *st) {
    st->s += 0x9E3779B9u;
    uint32_t z = st->s;
    z = (z ^ (z >> 16)) * 0x85EBCA6Bu;
    z = (z ^ (z >> 13)) * 0xC2B2AE35u;
    z = z ^ (z >> 16);
    return z;
}

typedef struct {
    uint32_t x, y, z, w;
} xorshift128_t;

static inline xorshift128_t xorshift128_new(uint32_t seed) {
    splitmix32_t sm = { seed };
    xorshift128_t rng;
    rng.x = splitmix32_next(&sm);
    rng.y = splitmix32_next(&sm);
    rng.z = splitmix32_next(&sm);
    rng.w = splitmix32_next(&sm);
    if ((rng.x | rng.y | rng.z | rng.w) == 0u) {
        rng.w = 1u;
    }
    return rng;
}

static inline uint32_t xorshift128_next_u32(xorshift128_t *rng) {
    // Marsaglia xorshift128 (32-bit)
    uint32_t t = rng->x ^ (rng->x << 11);
    rng->x = rng->y;
    rng->y = rng->z;
    rng->z = rng->w;
    rng->w = rng->w ^ (rng->w >> 19) ^ t ^ (t >> 8);
    return rng->w;
}

static inline double xorshift128_next_f64(xorshift128_t *rng) {
    // 53-bit uniform in [0,1) from two u32 draws.
    uint32_t a = xorshift128_next_u32(rng);
    uint32_t b = xorshift128_next_u32(rng);
    uint64_t u = ((uint64_t)(a >> 5) << 26) | (uint64_t)(b >> 6);
    return (double)u * (1.0 / 9007199254740992.0); // 2^53
}

typedef struct {
    int has_spare;
    double spare;
} normal_polar_t;

static inline void normal_polar_init(normal_polar_t *n) {
    n->has_spare = 0;
    n->spare = 0.0;
}

static inline double normal_polar_next(normal_polar_t *n, xorshift128_t *rng) {
    if (n->has_spare) {
        n->has_spare = 0;
        return n->spare;
    }
    for (;;) {
        double u = 2.0 * xorshift128_next_f64(rng) - 1.0;
        double v = 2.0 * xorshift128_next_f64(rng) - 1.0;
        double s = u*u + v*v;
        if (s > 0.0 && s < 1.0) {
            double m = sqrt((-2.0 * log(s)) / s);
            n->spare = v * m;
            n->has_spare = 1;
            return u * m;
        }
    }
}

static inline uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

typedef struct {
    size_t n;
    size_t runs;
    size_t warmup;
    uint32_t seed;
} args_t;

static args_t parse_args(int argc, char **argv) {
    args_t a;
    a.n = 500000;
    a.runs = 1000;
    a.warmup = 5;
    a.seed = 1;

    for (int i = 1; i < argc; i++) {
        const char *s = argv[i];
        if (strncmp(s, "--n=", 4) == 0) {
            long long v = atoll(s + 4);
            if (v < 2) { fprintf(stderr, "--n must be >= 2\n"); exit(1); }
            a.n = (size_t)v;
        } else if (strncmp(s, "--runs=", 7) == 0) {
            long long v = atoll(s + 7);
            if (v < 1) { fprintf(stderr, "--runs must be >= 1\n"); exit(1); }
            a.runs = (size_t)v;
        } else if (strncmp(s, "--warmup=", 9) == 0) {
            long long v = atoll(s + 9);
            if (v < 0) { fprintf(stderr, "--warmup must be >= 0\n"); exit(1); }
            a.warmup = (size_t)v;
        } else if (strncmp(s, "--seed=", 7) == 0) {
            unsigned long long v = strtoull(s + 7, NULL, 10);
            a.seed = (uint32_t)(v & 0xFFFFFFFFu);
        }
    }

    return a;
}

int main(int argc, char **argv) {
    args_t args = parse_args(argc, argv);

    const double T = 1.0;
    const double theta = 1.0;
    const double mu = 0.0;
    const double sigma = 0.1;

    const size_t n = args.n;

    const double dt = T / (double)n;
    const double a = 1.0 - theta * dt;
    const double b = theta * mu * dt;
    const double diff = sigma * sqrt(dt);

    double *gn = (double*)malloc((n - 1) * sizeof(double));
    double *ou = (double*)malloc(n * sizeof(double));
    if (!gn || !ou) {
        fprintf(stderr, "allocation failed\n");
        return 1;
    }

    // Warmup
    {
        xorshift128_t rng = xorshift128_new(args.seed);
        normal_polar_t norm;
        normal_polar_init(&norm);

        for (size_t r = 0; r < args.warmup; r++) {
            for (size_t i = 0; i < n - 1; i++) {
                gn[i] = diff * normal_polar_next(&norm, &rng);
            }
            double x = 0.0;
            ou[0] = x;
            for (size_t i = 1; i < n; i++) {
                x = a * x + b + gn[i - 1];
                ou[i] = x;
            }
            double s = 0.0;
            for (size_t i = 0; i < n; i++) s += ou[i];
            if (s == 123456789.0) printf("impossible\n");
        }
    }

    // Timed runs
    xorshift128_t rng = xorshift128_new(args.seed);
    normal_polar_t norm;
    normal_polar_init(&norm);

    double total_s = 0.0;
    double total_gen_s = 0.0;
    double total_sim_s = 0.0;
    double total_chk_s = 0.0;

    double min_s = 1e300;
    double max_s = 0.0;
    double *run_times = (double*)malloc(args.runs * sizeof(double));
    if (!run_times) {
        fprintf(stderr, "allocation failed\n");
        return 1;
    }

    double checksum = 0.0;

    for (size_t r = 0; r < args.runs; r++) {
        uint64_t t0 = now_ns();

        for (size_t i = 0; i < n - 1; i++) {
            gn[i] = diff * normal_polar_next(&norm, &rng);
        }
        uint64_t t1 = now_ns();

        double x = 0.0;
        ou[0] = x;
        for (size_t i = 1; i < n; i++) {
            x = a * x + b + gn[i - 1];
            ou[i] = x;
        }
        uint64_t t2 = now_ns();

        double s = 0.0;
        for (size_t i = 0; i < n; i++) s += ou[i];
        checksum += s;
        uint64_t t3 = now_ns();

        double gen = (double)(t1 - t0) * 1e-9;
        double sim = (double)(t2 - t1) * 1e-9;
        double chk = (double)(t3 - t2) * 1e-9;
        double run = (double)(t3 - t0) * 1e-9;

        total_gen_s += gen;
        total_sim_s += sim;
        total_chk_s += chk;
        total_s += run;
        run_times[r] = run;

        if (run < min_s) min_s = run;
        if (run > max_s) max_s = run;
    }

    // Sort run_times for median
    for (size_t i = 0; i < args.runs - 1; i++) {
        for (size_t j = i + 1; j < args.runs; j++) {
            if (run_times[j] < run_times[i]) {
                double tmp = run_times[i];
                run_times[i] = run_times[j];
                run_times[j] = tmp;
            }
        }
    }
    double median_s = (args.runs % 2 == 1)
        ? run_times[args.runs / 2]
        : (run_times[args.runs / 2 - 1] + run_times[args.runs / 2]) / 2.0;

    double avg_ms = (total_s / (double)args.runs) * 1000.0;
    double median_ms = median_s * 1000.0;
    double min_ms = min_s * 1000.0;
    double max_ms = max_s * 1000.0;

    printf("== OU benchmark (C, unified algorithms) ==\n");
    printf("n=%zu runs=%zu warmup=%zu seed=%u\n", args.n, args.runs, args.warmup, args.seed);
    printf("total_s=%.6f\n", total_s);
    printf("avg_ms=%.6f median_ms=%.6f min_ms=%.6f max_ms=%.6f\n", avg_ms, median_ms, min_ms, max_ms);
    printf("breakdown_s gen_normals=%.6f simulate=%.6f checksum=%.6f\n", total_gen_s, total_sim_s, total_chk_s);
    printf("checksum=%.17g\n", checksum);

    free(gn);
    free(ou);
    free(run_times);
    return 0;
}
