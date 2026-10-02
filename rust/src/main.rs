use std::env;
use std::time::Instant;

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

#[derive(Clone, Copy)]
struct XorShift128 {
    x: u32,
    y: u32,
    z: u32,
    w: u32,
}

impl XorShift128 {
    fn new(seed: u32) -> Self {
        let mut sm = SplitMix32 { s: seed };
        let x = sm.next_u32();
        let y = sm.next_u32();
        let z = sm.next_u32();
        let mut w = sm.next_u32();

        if (x | y | z | w) == 0 {
            w = 1;
        }

        Self { x, y, z, w }
    }

    #[inline(always)]
    fn next_u32(&mut self) -> u32 {
        // Marsaglia xorshift128 (32-bit)
        let t = self.x ^ (self.x << 11);
        self.x = self.y;
        self.y = self.z;
        self.z = self.w;
        self.w = self.w ^ (self.w >> 19) ^ t ^ (t >> 8);
        self.w
    }

    #[inline(always)]
    fn next_f64(&mut self) -> f64 {
        // 53-bit uniform in [0,1) from two u32 draws.
        let a = self.next_u32();
        let b = self.next_u32();
        let u: u64 = ((a >> 5) as u64) << 26 | ((b >> 6) as u64);
        (u as f64) * (1.0 / 9007199254740992.0) // 2^53
    }
}

#[derive(Clone, Copy)]
struct NormalPolar {
    has_spare: bool,
    spare: f64,
}

impl NormalPolar {
    fn new() -> Self {
        Self {
            has_spare: false,
            spare: 0.0,
        }
    }

    fn fill(&mut self, buffer: &mut [f64], diff: f64, rng: &mut XorShift128) {
        let mut rest = buffer;
        if self.has_spare && !rest.is_empty() {
            rest[0] = diff * self.spare;
            self.has_spare = false;
            rest = &mut rest[1..];
        }
        let (pairs, tail) = rest.as_chunks_mut::<2>();
        for pair in pairs {
            pair[0] = diff * self.next_standard(rng);
            pair[1] = diff * self.spare;
            self.has_spare = false;
        }
        if let Some(last) = tail.first_mut() {
            *last = diff * self.next_standard(rng);
        }
    }

    #[inline(always)]
    fn next_standard(&mut self, rng: &mut XorShift128) -> f64 {
        if self.has_spare {
            self.has_spare = false;
            return self.spare;
        }

        loop {
            let u = 2.0 * rng.next_f64() - 1.0;
            let v = 2.0 * rng.next_f64() - 1.0;
            let s = u * u + v * v;
            if s > 0.0 && s < 1.0 {
                let m = (-2.0 * s.ln() / s).sqrt();
                self.spare = v * m;
                self.has_spare = true;
                return u * m;
            }
        }
    }
}

#[derive(Debug, Clone, Copy)]
struct Args {
    n: usize,
    runs: usize,
    warmup: usize,
    seed: u32,
    mode: Mode,
    output: Output,
}

#[derive(Debug, Clone, Copy)]
enum Mode {
    Full,
    Gn,
    Ou,
}

#[derive(Debug, Clone, Copy)]
enum Output {
    Text,
    Json,
}

fn decimal(value: &str, maximum: u64) -> Result<u64, String> {
    if value.is_empty() || !value.bytes().all(|c| c.is_ascii_digit()) {
        return Err("expected decimal digits".into());
    }
    let number = value.parse::<u64>().map_err(|_| "integer out of range")?;
    if number > maximum {
        return Err("integer out of range".into());
    }
    Ok(number)
}

fn parse_args() -> Result<Args, String> {
    let mut out = Args {
        n: 500_000,
        runs: 1000,
        warmup: 5,
        seed: 1,
        mode: Mode::Full,
        output: Output::Text,
    };
    for arg in env::args().skip(1) {
        let (key, value) = arg.split_once('=').ok_or("expected --key=value")?;
        match key {
            "--n" | "--runs" | "--warmup" => {
                let number = decimal(value, i32::MAX as u64)? as usize;
                match key {
                    "--n" if number >= 2 => out.n = number,
                    "--runs" if number >= 1 => out.runs = number,
                    "--warmup" => out.warmup = number,
                    _ => return Err("n must be >= 2 and runs must be >= 1".into()),
                }
            }
            "--seed" => out.seed = decimal(value, u64::MAX)? as u32,
            "--mode" => {
                out.mode = match value {
                    "full" => Mode::Full,
                    "gn" => Mode::Gn,
                    "ou" => Mode::Ou,
                    _ => return Err("--mode must be full|gn|ou".into()),
                }
            }
            "--output" => {
                out.output = match value {
                    "text" => Output::Text,
                    "json" => Output::Json,
                    _ => return Err("--output must be text|json".into()),
                }
            }
            _ => return Err("unknown option".into()),
        }
    }
    Ok(out)
}

fn buffer(len: usize) -> Result<Vec<f64>, String> {
    let mut values = Vec::new();
    values
        .try_reserve_exact(len)
        .map_err(|error| format!("allocation failed: {error}"))?;
    values.resize(len, 0.0);
    Ok(values)
}

fn benchmark() -> Result<(), String> {
    let args = parse_args()?;

    let t = 1.0_f64;
    let theta = 1.0_f64;
    let mu = 0.0_f64;
    let sigma = 0.1_f64;

    let n = args.n;

    let dt = t / (n as f64);
    let a = 1.0 - theta * dt;
    let b = theta * mu * dt;
    let diff = sigma * dt.sqrt();

    let mut gn = buffer(n - 1)?;
    let mut ou = buffer(n)?;

    if let Mode::Ou = args.mode {
        let mut rng_prefill = XorShift128::new(args.seed);
        let mut norm_prefill = NormalPolar::new();
        norm_prefill.fill(&mut gn, diff, &mut rng_prefill);
    }

    // Warmup
    {
        let mut rng = XorShift128::new(args.seed);
        let mut norm = NormalPolar::new();
        for _ in 0..args.warmup {
            let mut s = 0.0_f64;
            match args.mode {
                Mode::Full => {
                    norm.fill(&mut gn, diff, &mut rng);

                    let mut x = 0.0_f64;
                    ou[0] = x;
                    for (slot, increment) in ou[1..].iter_mut().zip(&gn) {
                        x = a * x + b + increment;
                        *slot = x;
                    }

                    for v in std::hint::black_box(&ou) {
                        s += *v;
                    }
                }
                Mode::Gn => {
                    norm.fill(&mut gn, diff, &mut rng);
                    for v in std::hint::black_box(&gn) {
                        s += *v;
                    }
                }
                Mode::Ou => {
                    let mut x = 0.0_f64;
                    ou[0] = x;
                    for (slot, increment) in ou[1..].iter_mut().zip(&gn) {
                        x = a * x + b + increment;
                        *slot = x;
                    }

                    for v in std::hint::black_box(&ou) {
                        s += *v;
                    }
                }
            }
            if s == 123456789.0 {
                eprintln!("impossible");
            }
        }
    }

    // Timed runs
    let mut rng = XorShift128::new(args.seed);
    let mut norm = NormalPolar::new();

    let mut total_s = 0.0_f64;
    let mut total_gen_s = 0.0_f64;
    let mut total_sim_s = 0.0_f64;
    let mut total_chk_s = 0.0_f64;

    let mut min_s = f64::INFINITY;
    let mut max_s = 0.0_f64;
    let mut run_times = buffer(args.runs)?;

    let mut checksum = 0.0_f64;

    for time in &mut run_times {
        let (generation, sim, chk, run);
        match args.mode {
            Mode::Full => {
                let t0 = Instant::now();
                norm.fill(&mut gn, diff, &mut rng);
                let t1 = Instant::now();

                let mut x = 0.0_f64;
                ou[0] = x;
                for (slot, increment) in ou[1..].iter_mut().zip(&gn) {
                    x = a * x + b + increment;
                    *slot = x;
                }
                let t2 = Instant::now();

                let mut s = 0.0_f64;
                for v in std::hint::black_box(&ou) {
                    s += *v;
                }
                checksum += s;
                let t3 = Instant::now();

                generation = t1.duration_since(t0).as_secs_f64();
                sim = t2.duration_since(t1).as_secs_f64();
                chk = t3.duration_since(t2).as_secs_f64();
                run = t3.duration_since(t0).as_secs_f64();
            }
            Mode::Gn => {
                let t0 = Instant::now();
                norm.fill(&mut gn, diff, &mut rng);
                let t1 = Instant::now();

                let mut s = 0.0_f64;
                for v in std::hint::black_box(&gn) {
                    s += *v;
                }
                checksum += s;
                let t2 = Instant::now();

                generation = t1.duration_since(t0).as_secs_f64();
                sim = 0.0_f64;
                chk = t2.duration_since(t1).as_secs_f64();
                run = t2.duration_since(t0).as_secs_f64();
            }
            Mode::Ou => {
                let t0 = Instant::now();
                let mut x = 0.0_f64;
                ou[0] = x;
                for (slot, increment) in ou[1..].iter_mut().zip(&gn) {
                    x = a * x + b + increment;
                    *slot = x;
                }
                let t1 = Instant::now();

                let mut s = 0.0_f64;
                for v in std::hint::black_box(&ou) {
                    s += *v;
                }
                checksum += s;
                let t2 = Instant::now();

                generation = 0.0_f64;
                sim = t1.duration_since(t0).as_secs_f64();
                chk = t2.duration_since(t1).as_secs_f64();
                run = t2.duration_since(t0).as_secs_f64();
            }
        }

        total_gen_s += generation;
        total_sim_s += sim;
        total_chk_s += chk;
        total_s += run;
        *time = run;

        if run < min_s {
            min_s = run;
        }
        if run > max_s {
            max_s = run;
        }
    }

    run_times.sort_unstable_by(f64::total_cmp);
    let median_s = if args.runs % 2 == 1 {
        run_times[args.runs / 2]
    } else {
        (run_times[args.runs / 2 - 1] + run_times[args.runs / 2]) / 2.0
    };

    let avg_ms = (total_s / args.runs as f64) * 1000.0;
    let median_ms = median_s * 1000.0;
    let min_ms = min_s * 1000.0;
    let max_ms = max_s * 1000.0;

    let mode_str = match args.mode {
        Mode::Full => "full",
        Mode::Gn => "gn",
        Mode::Ou => "ou",
    };

    match args.output {
        Output::Json => {
            println!(
                r#"{{"language":"Rust","mode":"{}","n":{},"runs":{},"warmup":{},"seed":{},"total_s":{:.6},"avg_ms":{:.6},"median_ms":{:.6},"min_ms":{:.6},"max_ms":{:.6},"breakdown_s":{{"gen_normals":{:.6},"simulate":{:.6},"checksum":{:.6}}},"checksum":{:.17}}}"#,
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
                checksum
            );
        }
        Output::Text => {
            println!("== OU benchmark (Rust, unified algorithms) ==");
            println!(
                "n={} runs={} warmup={} seed={}",
                args.n, args.runs, args.warmup, args.seed
            );
            println!("total_s={:.6}", total_s);
            println!(
                "avg_ms={:.6} median_ms={:.6} min_ms={:.6} max_ms={:.6}",
                avg_ms, median_ms, min_ms, max_ms
            );
            println!(
                "breakdown_s gen_normals={:.6} simulate={:.6} checksum={:.6}",
                total_gen_s, total_sim_s, total_chk_s
            );
            println!("checksum={:.17}", checksum);
        }
    }
    Ok(())
}

fn main() -> std::process::ExitCode {
    match benchmark() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error}");
            std::process::ExitCode::FAILURE
        }
    }
}
