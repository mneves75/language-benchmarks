/*
  Unified OU benchmark (Bun / TypeScript)

  Algorithms intentionally match the Rust/Zig/C versions in this repo:
  - PRNG: xorshift128 (u32) seeded with splitmix32
  - Uniform: 53-bit double from two u32 draws
  - Normal: Marsaglia polar method with cached spare
  - OU: Euler update with precomputed a,b and diffusion coefficient

  Run:
    bun run ou_bench.ts --n=500000 --runs=1000 --warmup=5 --seed=1
*/

type Args = {
  n: number;
  runs: number;
  warmup: number;
  seed: number;
  mode: "full" | "gn" | "ou";
  output: "text" | "json";
};

function parseArgs(argv: string[]): Args {
  // Defaults match the blog's parameters.
  const args: Args = { n: 500_000, runs: 1000, warmup: 5, seed: 1, mode: "full", output: "text" };

  for (const raw of argv) {
    if (!raw.startsWith("--")) continue;
    const eq = raw.indexOf("=");
    const key = eq >= 0 ? raw.slice(2, eq) : raw.slice(2);
    const val = eq >= 0 ? raw.slice(eq + 1) : "";
    const num = val.length ? Number(val) : NaN;

    switch (key) {
      case "n":
        if (!Number.isFinite(num) || num < 2) throw new Error("--n must be >= 2");
        args.n = Math.floor(num);
        break;
      case "runs":
        if (!Number.isFinite(num) || num < 1) throw new Error("--runs must be >= 1");
        args.runs = Math.floor(num);
        break;
      case "warmup":
        if (!Number.isFinite(num) || num < 0) throw new Error("--warmup must be >= 0");
        args.warmup = Math.floor(num);
        break;
      case "seed":
        if (!Number.isFinite(num) || num < 0) throw new Error("--seed must be >= 0");
        args.seed = Math.floor(num) >>> 0; // keep in u32 range
        break;
      case "mode":
        if (val !== "full" && val !== "gn" && val !== "ou") {
          throw new Error("--mode must be full|gn|ou");
        }
        args.mode = val;
        break;
      case "output":
        if (val !== "text" && val !== "json") {
          throw new Error("--output must be text|json");
        }
        args.output = val;
        break;
      default:
        // ignore unknown args
        break;
    }
  }
  return args;
}

// ---- PRNG: splitmix32 seeding + xorshift128 ----

function splitmix32_next(state: { s: number }): number {
  // All arithmetic is 32-bit.
  state.s = (state.s + 0x9e3779b9) | 0;
  let z = state.s | 0;
  z = Math.imul(z ^ (z >>> 16), 0x85ebca6b) | 0;
  z = Math.imul(z ^ (z >>> 13), 0xc2b2ae35) | 0;
  z = (z ^ (z >>> 16)) | 0;
  return z >>> 0;
}

class XorShift128 {
  private x: number;
  private y: number;
  private z: number;
  private w: number;

  constructor(seed: number) {
    // seed via splitmix32 into 4 non-zero-ish states
    const st = { s: seed | 0 };
    this.x = splitmix32_next(st) | 0;
    this.y = splitmix32_next(st) | 0;
    this.z = splitmix32_next(st) | 0;
    this.w = splitmix32_next(st) | 0;

    // Avoid the all-zero state (extremely unlikely, but possible).
    if ((this.x | this.y | this.z | this.w) === 0) {
      this.w = 1;
    }
  }

  nextU32(): number {
    // Marsaglia xorshift128 (returns u32)
    const t = (this.x ^ (this.x << 11)) | 0;
    this.x = this.y;
    this.y = this.z;
    this.z = this.w;
    this.w = (this.w ^ (this.w >>> 19) ^ t ^ (t >>> 8)) | 0;
    return this.w >>> 0;
  }

  nextF64(): number {
    // 53-bit uniform in [0,1) from two u32 draws (exact in JS number range)
    const a = this.nextU32();
    const b = this.nextU32();
    const u = (a >>> 5) * 67108864 + (b >>> 6); // (a>>5)<<26 + (b>>6)
    return u * (1.0 / 9007199254740992.0); // 2^53
  }
}

// ---- Normal: Marsaglia polar with cached spare ----

class NormalPolar {
  private hasSpare = false;
  private spare = 0.0;

  nextStandard(rng: XorShift128): number {
    if (this.hasSpare) {
      this.hasSpare = false;
      return this.spare;
    }
    while (true) {
      const u = 2.0 * rng.nextF64() - 1.0;
      const v = 2.0 * rng.nextF64() - 1.0;
      const s = u * u + v * v;
      if (s > 0.0 && s < 1.0) {
        const m = Math.sqrt((-2.0 * Math.log(s)) / s);
        this.spare = v * m;
        this.hasSpare = true;
        return u * m;
      }
    }
  }
}

// ---- Benchmark core ----

function nowMs(): number {
  // Bun supports performance.now()
  return performance.now();
}

function main(): void {
  const { n, runs, warmup, seed, mode, output } = parseArgs(process.argv.slice(2));

  const T = 1.0;
  const theta = 1.0;
  const mu = 0.0;
  const sigma = 0.1;

  const dt = T / n;
  const a = 1.0 - theta * dt;
  const b = theta * mu * dt;
  const diff = sigma * Math.sqrt(dt);

  const gn = new Float64Array(n - 1);
  const ou = new Float64Array(n);

  if (mode === "ou") {
    const rngPrefill = new XorShift128(seed);
    const normPrefill = new NormalPolar();
    for (let i = 0; i < n - 1; i++) {
      gn[i] = diff * normPrefill.nextStandard(rngPrefill);
    }
  }

  // Warmup (JIT + caches)
  {
    const rng = new XorShift128(seed);
    const norm = new NormalPolar();
    for (let r = 0; r < warmup; r++) {
      let s = 0.0;
      if (mode === "full") {
        for (let i = 0; i < n - 1; i++) {
          gn[i] = diff * norm.nextStandard(rng);
        }
        let x = 0.0;
        ou[0] = x;
        for (let i = 1; i < n; i++) {
          x = a * x + b + gn[i - 1];
          ou[i] = x;
        }
        for (let i = 0; i < n; i++) s += ou[i];
      } else if (mode === "gn") {
        for (let i = 0; i < n - 1; i++) {
          gn[i] = diff * norm.nextStandard(rng);
        }
        for (let i = 0; i < n - 1; i++) s += gn[i];
      } else {
        let x = 0.0;
        ou[0] = x;
        for (let i = 1; i < n; i++) {
          x = a * x + b + gn[i - 1];
          ou[i] = x;
        }
        for (let i = 0; i < n; i++) s += ou[i];
      }
      // prevent whole warmup from being dead
      if (s === 123456789.0) console.log("impossible");
    }
  }

  // Force GC before timed runs to reduce variance
  if (typeof Bun !== "undefined" && Bun.gc) {
    Bun.gc(true);
  }

  // Timed runs
  const rng = new XorShift128(seed);
  const norm = new NormalPolar();

  let totalMs = 0.0;
  let totalGenMs = 0.0;
  let totalSimMs = 0.0;
  let totalChkMs = 0.0;

  let minMs = Number.POSITIVE_INFINITY;
  let maxMs = 0.0;
  const runTimes: number[] = [];

  let checksum = 0.0;

  for (let r = 0; r < runs; r++) {
    let genMs = 0.0;
    let simMs = 0.0;
    let chkMs = 0.0;
    let runMs = 0.0;

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

      genMs = t1 - t0;
      simMs = t2 - t1;
      chkMs = t3 - t2;
      runMs = t3 - t0;
    } else if (mode === "gn") {
      const t0 = nowMs();
      for (let i = 0; i < n - 1; i++) {
        gn[i] = diff * norm.nextStandard(rng);
      }
      const t1 = nowMs();

      let s = 0.0;
      for (let i = 0; i < n - 1; i++) s += gn[i];
      checksum += s;
      const t2 = nowMs();

      genMs = t1 - t0;
      simMs = 0.0;
      chkMs = t2 - t1;
      runMs = t2 - t0;
    } else {
      const t0 = nowMs();
      let x = 0.0;
      ou[0] = x;
      for (let i = 1; i < n; i++) {
        x = a * x + b + gn[i - 1];
        ou[i] = x;
      }
      const t1 = nowMs();

      let s = 0.0;
      for (let i = 0; i < n; i++) s += ou[i];
      checksum += s;
      const t2 = nowMs();

      genMs = 0.0;
      simMs = t1 - t0;
      chkMs = t2 - t1;
      runMs = t2 - t0;
    }

    totalGenMs += genMs;
    totalSimMs += simMs;
    totalChkMs += chkMs;
    totalMs += runMs;
    runTimes.push(runMs);

    if (runMs < minMs) minMs = runMs;
    if (runMs > maxMs) maxMs = runMs;
  }

  const avgMs = totalMs / runs;
  runTimes.sort((a, b) => a - b);
  const medianMs = runs % 2 === 1
    ? runTimes[Math.floor(runs / 2)]
    : (runTimes[runs / 2 - 1] + runTimes[runs / 2]) / 2;

  if (output === "json") {
    const totalS = (totalMs / 1000).toFixed(6);
    const avgMsStr = avgMs.toFixed(6);
    const medianMsStr = medianMs.toFixed(6);
    const minMsStr = minMs.toFixed(6);
    const maxMsStr = maxMs.toFixed(6);
    const genS = (totalGenMs / 1000).toFixed(6);
    const simS = (totalSimMs / 1000).toFixed(6);
    const chkS = (totalChkMs / 1000).toFixed(6);
    const checksumStr = checksum.toPrecision(17);

    console.log(
      `{"language":"TypeScript/Bun","mode":"${mode}","n":${n},"runs":${runs},"warmup":${warmup},"seed":${seed},"total_s":${totalS},"avg_ms":${avgMsStr},"median_ms":${medianMsStr},"min_ms":${minMsStr},"max_ms":${maxMsStr},"breakdown_s":{"gen_normals":${genS},"simulate":${simS},"checksum":${chkS}},"checksum":${checksumStr}}`
    );
  } else {
    console.log("== OU benchmark (TypeScript/Bun, unified algorithms) ==");
    console.log(`n=${n} runs=${runs} warmup=${warmup} seed=${seed}`);
    console.log(`total_s=${(totalMs / 1000).toFixed(6)}`);
    console.log(`avg_ms=${avgMs.toFixed(6)} median_ms=${medianMs.toFixed(6)} min_ms=${minMs.toFixed(6)} max_ms=${maxMs.toFixed(6)}`);
    console.log(
      `breakdown_s gen_normals=${(totalGenMs / 1000).toFixed(6)} simulate=${(totalSimMs / 1000).toFixed(6)} checksum=${(totalChkMs / 1000).toFixed(6)}`
    );
    console.log(`checksum=${checksum.toPrecision(17)}`);
  }
}

main();
