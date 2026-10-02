// Unified OU benchmark (Swift)
//
// Algorithms intentionally match all six implementations in this repository:
// - PRNG: xorshift128 (u32) seeded via splitmix32
// - Uniform: 53-bit double from two u32 draws
// - Normal: Marsaglia polar method with cached spare
// - OU: Euler update with precomputed a,b and diffusion coefficient
//
// Build:
// swiftc -O -whole-module-optimization ou_bench.swift -o ou_bench_swift
//
// Run:
// ./ou_bench_swift --n=500000 --runs=1000 --warmup=5 --seed=1

import Dispatch
import Foundation

enum Mode: String {
  case full
  case gn
  case ou
}

enum Output: String {
  case text
  case json
}

struct Args {
  var n: Int = 500_000
  var runs: Int = 1000
  var warmup: Int = 5
  var seed: UInt32 = 1
  var mode: Mode = .full
  var output: Output = .text
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
  exit(1)
}

func decimal(_ value: String, maximum: UInt64) -> UInt64 {
  guard !value.isEmpty, value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
    let number = UInt64(value), number <= maximum
  else {
    fail("expected decimal integer in range")
  }
  return number
}

func parseArgs(_ argv: [String]) -> Args {
  var args = Args()
  for raw in argv {
    let parts = raw.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { fail("expected --key=value") }
    let key = String(parts[0])
    let value = String(parts[1])
    switch key {
    case "--n":
      args.n = Int(decimal(value, maximum: 2_147_483_647))
      guard args.n >= 2 else { fail("--n must be >= 2") }
    case "--runs":
      args.runs = Int(decimal(value, maximum: 2_147_483_647))
      guard args.runs >= 1 else { fail("--runs must be >= 1") }
    case "--warmup":
      args.warmup = Int(decimal(value, maximum: 2_147_483_647))
    case "--seed":
      args.seed = UInt32(truncatingIfNeeded: decimal(value, maximum: UInt64.max))
    case "--mode":
      guard let mode = Mode(rawValue: value) else { fail("--mode must be full|gn|ou") }
      args.mode = mode
    case "--output":
      guard let output = Output(rawValue: value) else { fail("--output must be text|json") }
      args.output = output
    default:
      fail("unknown option")
    }
  }
  return args
}

struct SplitMix32 {
  var s: UInt32

  mutating func next() -> UInt32 {
    s = s &+ 0x9E37_79B9
    var z = s
    z = (z ^ (z >> 16)) &* 0x85EB_CA6B
    z = (z ^ (z >> 13)) &* 0xC2B2_AE35
    return z ^ (z >> 16)
  }
}

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

struct NormalPolar {
  var hasSpare: Bool = false
  var spare: Double = 0.0

  mutating func fill(
    _ buffer: UnsafeMutableBufferPointer<Double>, diff: Double, rng: inout XorShift128
  ) {
    var i = 0
    if hasSpare && !buffer.isEmpty {
      buffer[i] = diff * spare
      i += 1
      hasSpare = false
    }
    while i + 1 < buffer.count {
      buffer[i] = diff * nextStandard(rng: &rng)
      buffer[i + 1] = diff * spare
      hasSpare = false
      i += 2
    }
    if i < buffer.count { buffer[i] = diff * nextStandard(rng: &rng) }
  }

  mutating func nextStandard(rng: inout XorShift128) -> Double {
    if hasSpare {
      hasSpare = false
      return spare
    }
    while true {
      let u = 2.0 * rng.nextF64() - 1.0
      let v = 2.0 * rng.nextF64() - 1.0
      let s = u * u + v * v
      if s > 0.0 && s < 1.0 {
        let m = sqrt((-2.0 * log(s)) / s)
        spare = v * m
        hasSpare = true
        return u * m
      }
    }
  }
}

@inline(__always) func nowNs() -> UInt64 {
  return DispatchTime.now().uptimeNanoseconds
}

func main() {
  let args = parseArgs(Array(CommandLine.arguments.dropFirst()))

  let t = 1.0
  let theta = 1.0
  let mu = 0.0
  let sigma = 0.1

  let n = args.n

  let dt = t / Double(n)
  let a = 1.0 - theta * dt
  let b = theta * mu * dt
  let diff = sigma * sqrt(dt)

  var gn = [Double](repeating: 0.0, count: n - 1)
  var ou = [Double](repeating: 0.0, count: n)

  // Pointers remain inside these closures; both arrays have fixed, validated sizes.
  gn.withUnsafeMutableBufferPointer { gn in
    ou.withUnsafeMutableBufferPointer { ou in

      if args.mode == .ou {
        var rngPrefill = XorShift128(seed: args.seed)
        var normPrefill = NormalPolar()
        normPrefill.fill(gn, diff: diff, rng: &rngPrefill)
      }

      // Warmup
      var rngWarm = XorShift128(seed: args.seed)
      var normWarm = NormalPolar()
      if args.warmup > 0 {
        for _ in 0..<args.warmup {
          var s = 0.0
          switch args.mode {
          case .full:
            normWarm.fill(gn, diff: diff, rng: &rngWarm)
            var x = 0.0
            ou[0] = x
            if n > 1 {
              for i in 1..<n {
                x = a * x + b + gn[i - 1]
                ou[i] = x
              }
            }
            for i in 0..<n { s += ou[i] }
          case .gn:
            normWarm.fill(gn, diff: diff, rng: &rngWarm)
            for i in 0..<(n - 1) { s += gn[i] }
          case .ou:
            var x = 0.0
            ou[0] = x
            if n > 1 {
              for i in 1..<n {
                x = a * x + b + gn[i - 1]
                ou[i] = x
              }
            }
            for i in 0..<n { s += ou[i] }
          }
          if s == 123456789.0 {
            print("impossible")
          }
        }
      }

      // Timed runs
      var rng = XorShift128(seed: args.seed)
      var norm = NormalPolar()

      var totalS = 0.0
      var totalGenS = 0.0
      var totalSimS = 0.0
      var totalChkS = 0.0

      var minS = Double.greatestFiniteMagnitude
      var maxS = 0.0
      var runTimes = [Double](repeating: 0.0, count: args.runs)

      var checksum = 0.0

      for r in 0..<args.runs {
        var gen = 0.0
        var sim = 0.0
        var chk = 0.0
        var run = 0.0

        switch args.mode {
        case .full:
          let t0 = nowNs()
          norm.fill(gn, diff: diff, rng: &rng)
          let t1 = nowNs()

          var x = 0.0
          ou[0] = x
          if n > 1 {
            for i in 1..<n {
              x = a * x + b + gn[i - 1]
              ou[i] = x
            }
          }
          let t2 = nowNs()

          var s = 0.0
          for i in 0..<n { s += ou[i] }
          checksum += s
          let t3 = nowNs()

          gen = Double(t1 - t0) * 1e-9
          sim = Double(t2 - t1) * 1e-9
          chk = Double(t3 - t2) * 1e-9
          run = Double(t3 - t0) * 1e-9
        case .gn:
          let t0 = nowNs()
          norm.fill(gn, diff: diff, rng: &rng)
          let t1 = nowNs()

          var s = 0.0
          for i in 0..<(n - 1) { s += gn[i] }
          checksum += s
          let t2 = nowNs()

          gen = Double(t1 - t0) * 1e-9
          sim = 0.0
          chk = Double(t2 - t1) * 1e-9
          run = Double(t2 - t0) * 1e-9
        case .ou:
          let t0 = nowNs()
          var x = 0.0
          ou[0] = x
          if n > 1 {
            for i in 1..<n {
              x = a * x + b + gn[i - 1]
              ou[i] = x
            }
          }
          let t1 = nowNs()

          var s = 0.0
          for i in 0..<n { s += ou[i] }
          checksum += s
          let t2 = nowNs()

          gen = 0.0
          sim = Double(t1 - t0) * 1e-9
          chk = Double(t2 - t1) * 1e-9
          run = Double(t2 - t0) * 1e-9
        }

        totalGenS += gen
        totalSimS += sim
        totalChkS += chk
        totalS += run
        runTimes[r] = run

        if run < minS { minS = run }
        if run > maxS { maxS = run }
      }

      runTimes.sort()
      let medianS: Double
      if args.runs % 2 == 1 {
        medianS = runTimes[args.runs / 2]
      } else {
        medianS = (runTimes[args.runs / 2 - 1] + runTimes[args.runs / 2]) / 2.0
      }

      let avgMs = (totalS / Double(args.runs)) * 1000.0
      let medianMs = medianS * 1000.0
      let minMs = minS * 1000.0
      let maxMs = maxS * 1000.0

      func fmt6(_ v: Double) -> String {
        return String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), v)
      }

      func fmt17(_ v: Double) -> String {
        return String(format: "%.17g", locale: Locale(identifier: "en_US_POSIX"), v)
      }

      if args.output == .json {
        let json =
          "{" + "\"language\":\"Swift\"," + "\"mode\":\"\(args.mode.rawValue)\","
          + "\"n\":\(args.n)," + "\"runs\":\(args.runs)," + "\"warmup\":\(args.warmup),"
          + "\"seed\":\(args.seed)," + "\"total_s\":\(fmt6(totalS))," + "\"avg_ms\":\(fmt6(avgMs)),"
          + "\"median_ms\":\(fmt6(medianMs))," + "\"min_ms\":\(fmt6(minMs)),"
          + "\"max_ms\":\(fmt6(maxMs)),"
          + "\"breakdown_s\":{\"gen_normals\":\(fmt6(totalGenS)),\"simulate\":\(fmt6(totalSimS)),\"checksum\":\(fmt6(totalChkS))},"
          + "\"checksum\":\(fmt17(checksum))" + "}"
        print(json)
      } else {
        print("== OU benchmark (Swift, unified algorithms) ==")
        print("n=\(args.n) runs=\(args.runs) warmup=\(args.warmup) seed=\(args.seed)")
        print("total_s=\(fmt6(totalS))")
        print(
          "avg_ms=\(fmt6(avgMs)) median_ms=\(fmt6(medianMs)) min_ms=\(fmt6(minMs)) max_ms=\(fmt6(maxMs))"
        )
        print(
          "breakdown_s gen_normals=\(fmt6(totalGenS)) simulate=\(fmt6(totalSimS)) checksum=\(fmt6(totalChkS))"
        )
        print("checksum=\(fmt17(checksum))")
      }

    }
  }
}

main()
