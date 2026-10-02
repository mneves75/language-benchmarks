# Benchmark modernization and run record — 2026-10-02

Version **1.4.0** reviews all six implementations, both shell entry points,
the comparison helper, and the full documentation set. Numerical behavior is
preserved; CLI errors are now strict and consistent. Source and artifact hashes
are recorded in [metadata.json](results/2026-10-02/metadata.json).

## Environment and scope

| Item | Observed value |
|---|---|
| Hardware | MacBook Pro, Apple M5 Pro, 64 GB RAM, 18 cores reported |
| OS | macOS 27.2, build 26B5091g, arm64 |
| Power | AC power |
| C compiler | Apple clang 21.0.0, clang-2100.3.34.2 |
| Rust / Cargo | rustc 1.99.0 (b940084d7); cargo 1.99.0 (5f94df478) |
| Zig | 0.16.0 |
| Swift | Apple Swift 6.4, swiftlang-6.4.0.34.1 |
| Xcode selected | Xcode-beta 27.2, build 27B5028f |
| Bun | 1.4.2 |
| V | 0.5.2, 7647ce1, official macOS arm64 release |
| Python | 3.14.8 |
| Baseline Git revision | ef3c53038ca83a4769bac08efd3420d2c5ad8154 |

Hardware metadata came from `system_profiler SPHardwareDataType -json`, selecting
only model/chip/memory/core fields. `sysctl` access was restricted. No thermal
telemetry or exclusive CPU reservation was available. Other host activity was
not controlled; process-level variability is visible below.

V was downloaded into `.scratch/toolchains/`; V module and temporary paths stayed
inside the repository. No host toolchain was installed or changed. The existing
Swift CLI build is not an Xcode project. Xcode-beta MCP documentation access
required opening/approving a project, so the installed documentation, Apple
documentation, and actual CLI compiler were used instead.

## Findings and changes

| Finding | Resolution and evidence |
|---|---|
| Silent partial-number conversion and unknown arguments | All languages enforce the same decimal grammar, ranges, modes, and options; 291 E2E checks |
| Rust/Swift aborting on malformed input | Normal nonzero exits with stderr diagnostics |
| TypeScript rounded wide seeds before reduction | Parse with BigInt, then reduce; u64 maximum matches the reference |
| C byte-count overflow / failure cleanup | Count and multiplication checks, owned allocations freed on failure |
| Infallible Rust reservation | Fallible reservation with explicit allocation errors |
| Zig 0.15 API usage fails on installed 0.16 | Migrate argument/I/O APIs and use monotonic `.awake` timestamps |
| Unequal floating-point compiler policies | Remove C/V fast-math and disable C/V FMA contraction; use Swift `-O` |
| TypeScript timing-array growth | Fixed Float64Array allocated before measured runs |
| Swift global array mutation overhead | Local state and closure-scoped buffer access; runtime checks retained |
| Per-sample normal dispatch | Pair fills in Rust/Zig/Swift/TypeScript; retain measured scalar choice in C/V |
| V broad unsafe blocks | Only guarded noise-buffer stores remain unchecked; native sanitizer checks pass |
| Runner depends on current directory and mixes status with JSON | Root-relative paths, shared build script, clean JSONL on stdout |
| Zig positional writer overwrote earlier records in a redirected file | Failing redirection regression added; use `writerStreaming` to preserve stdout offset |
| Comparison silently overwrites duplicates or compares unlike inputs | Validate records/configuration/checksums and fail before printing a comparison |
| Stale five-language guidance and unsupported performance claims | Refresh all guides, add V chapter, preserve historical records explicitly |

## Decisions and rejected alternatives

1. **Preserve the workload.** Keep the PRNG, polar transform, seed/sample order,
   `dt=1/n`, scalar recurrence, stored path, and ordered checksum. Exact OU
   transitions, Ziggurat sampling, parallel paths, or reassociated reductions
   could be faster but would answer a different benchmark question.
2. **Measure each language's loop choice.** Paired filling substantially helped
   Swift and improved the observed TypeScript median. C and V paired-fill
   candidates regressed generation, so their final implementation keeps scalar
   cached sampling. Zig's pair helper is inline; Rust uses safe fixed-size chunks.
3. **Keep checks where practical.** Swift `-O` with scoped buffers was selected
   over `-Ounchecked`. V's ordinary generated array setters added work in a trial
   fill; only stores whose indices are proven by the fixed-size loop use narrow
   unsafe blocks. Whole-loop unchecked access was rejected. Zig ReleaseFast
   remains the benchmark configuration, with ReleaseSafe tested separately.
4. **Keep tooling small.** Standard-library Python drives real CLI processes.
   A separate benchmark framework per language would add dependencies and make
   boundaries harder to align. The framework literature informs methodology.

The lasting improvement is a checkable numerical/build contract and reproducible
evidence. It is more useful across future compiler changes than preserving a
particular ranking or adding speculative abstractions.

## Matched-policy measurements

Protocol: `n=500000`, `runs=200`, `warmup=20`, `seed=1`; five fresh-process
baseline/candidate pairs for each of `full`, `gn`, `ou`. Pair order alternated;
language order rotated. Final V scalar pairs were rerun after rejecting V pair
filling; final Zig pairs were rerun after its stdout fix. No builds or heavy test
suites ran concurrently with these measurements.

The baseline was rebuilt from the revision above using the **same strict compiler
policy** as the candidate. Its original scalar kernels remain intact. Zig needed
an [API-only compatibility patch](results/2026-10-02/baseline-zig-0.16.patch)
to build on 0.16. Baseline V retains its old broad unsafe blocks. These comparisons
therefore describe the combined source changes, not an isolated pair-fill effect.
They do not compare the candidate with the old README's fast-math/unchecked ranking.

All 90 paired checksums agreed within `1e-10` absolute/relative tolerance.
[Final raw data](results/2026-10-02/paired.jsonl) contains 180 records and artifact
SHA-256 values. [Initial experiment](results/2026-10-02/paired-first.jsonl) and
[rejected V paired candidate](results/2026-10-02/paired-before-v-scalar.jsonl)
are retained separately so unfavorable observations remain inspectable.

Numbers below are medians of the five process medians, in milliseconds. Delta
is `(candidate / baseline - 1) * 100`; negative means lower elapsed time.
The range is the candidate's five process medians, **not a confidence interval**.

### Full pipeline

| Language | Baseline | Candidate | Delta | Candidate range |
|---|---:|---:|---:|---:|
| C | 4.2405 | 4.1525 | -2.1% | 4.0455–5.1700 |
| Rust | 4.7918 | 4.6268 | -3.4% | 4.5316–4.8927 |
| Zig | 5.8949 | 4.8146 | -18.3% | 4.5275–5.6455 |
| Swift | 8.4068 | 4.0996 | -51.2% | 3.9835–5.1602 |
| V | 4.0152 | 3.9652 | -1.2% | 3.8920–4.1562 |
| TypeScript/Bun | 6.7128 | 6.1531 | -8.3% | 5.6325–17.7327 |

### Normal generation and checksum

| Language | Baseline | Candidate | Delta | Candidate range |
|---|---:|---:|---:|---:|
| C | 2.9565 | 3.1120 | +5.3% | 2.8710–3.1695 |
| Rust | 3.2281 | 3.2981 | +2.2% | 3.0790–3.5464 |
| Zig | 3.0209 | 3.1677 | +4.9% | 2.8629–3.3540 |
| Swift | 7.1758 | 2.9556 | -58.8% | 2.7541–3.6758 |
| V | 2.9545 | 2.8672 | -3.0% | 2.8021–3.0042 |
| TypeScript/Bun | 5.6218 | 5.0942 | -9.4% | 4.6563–5.4324 |

### OU simulation and checksum

| Language | Baseline | Candidate | Delta | Candidate range |
|---|---:|---:|---:|---:|
| C | 1.6700 | 1.5390 | -7.8% | 1.4665–1.6575 |
| Rust | 1.7263 | 1.7287 | +0.1% | 1.6491–1.9099 |
| Zig | 1.5097 | 1.5218 | +0.8% | 1.5103–1.5422 |
| Swift | 1.5482 | 1.4667 | -5.3% | 1.3310–1.6305 |
| V | 1.1594 | 1.1522 | -0.6% | 1.1469–1.1802 |
| TypeScript/Bun | 1.3792 | 1.3273 | -3.8% | 1.2341–1.7940 |

Swift's improvement is the clearest observation. Smaller gaps are mixed across
modes; TypeScript has a large full-mode outlier. No statistical significance or
universal speedup is claimed. The C kernel remains scalar even though unrelated
host/compiler-layout effects still produce different observations between builds.

## Verification

The pre-change E2E matrix produced **105 failures**: 82 across C/Rust/Swift/TS,
17 in V, and 6 in the API-adapted Zig baseline. Unmodified Zig also failed to
compile on 0.16. The tests existed and ran before implementation changes.

Final commands and results:

| Command / check | Result |
|---|---|
| `V="$PWD/.scratch/toolchains/v/v" bash build.sh` | All five native builds succeed; Bun available |
| `python3 tests/check.py --skip-build --scripts` | 291 passed, 0 failed |
| Native safety matrix, `--bin-dir .scratch/safe --languages c zig swift v rust` | 240 passed, 0 failed; final V and Zig separately rerun, 48/48 each |
| PRNG mutation control: change C shift 11 to 10 in a scratch copy | 21 numeric cases fail; 27 interface cases pass; expected exit 1 |
| `cargo fmt --manifest-path rust/Cargo.toml --check` | PASS |
| `cargo clippy --manifest-path rust/Cargo.toml --locked --all-targets -- -D warnings` | PASS |
| `cargo test --manifest-path rust/Cargo.toml --locked` | PASS, zero unit tests; behavioral coverage is E2E |
| `zig fmt --check zig/ou_bench.zig` | PASS |
| `xcrun swift-format lint --strict swift/ou_bench.swift` | PASS |
| `v fmt -verify v/ou_bench.v` | PASS |
| `shellcheck build.sh run_all.sh DOCS/scripts/compare_runs.sh` and `bash -n` | PASS |
| `git diff --check` | PASS |
| Archived Zig compatibility patch applied to a fresh baseline source, then `cmp` against the measured baseline source | PASS; blank context lines normalized for the staged whitespace gate |

Safety builds use C and V `-O1 -g -fsanitize=address,undefined
-fno-omit-frame-pointer -ffp-contract=off` (V also links the sanitizers), Zig
ReleaseSafe, Swift `-Onone -swift-version 6`, and Rust debug. The independent
Standards review also checked Swift's scoped pointer lifetimes and V's local
index proofs; sanitizer success does not prove absence of every memory error.

The default-size full run is recorded in
[default-full.jsonl](results/2026-10-02/default-full.jsonl):

```bash
V="$PWD/.scratch/toolchains/v/v" ./run_all.sh 500000 1000 5 1 full json
```

## Independent code review

The requested Matt Pocock `code-review` workflow used separate fresh Standards
and Spec contexts against baseline `ef3c530`, including new task files. The
user's request and frozen acceptance supplied the spec. The `autoreview` helper
refused report paths inside the repository before executing a review, so fresh
read-only review agents supplied the documented fallback. No outside-repository
report was written.

### Standards

**Zero actionable findings.** The reviewer inspected all six implementations,
scripts, E2E oracle, documentation, and metadata. Scoped Swift pointer lifetimes,
V store bounds, and cached-spare handling were checked. Cross-language
duplication and mode dispatch serve the parity and timing contract.

The reviewer independently ran `python3 tests/check.py --skip-build --scripts`
with **291 passed, 0 failed**, checked additional CLI boundaries, verified source
and artifact hashes, and recalculated the measurement tables. Rebuilds, safety
builds, and performance experiments were not repeated in this review.

### Spec

**Zero actionable findings.** The reviewer checked the frozen acceptance,
numerical contract, documentation, version, output behavior, and measurement
claims. `python3 -B tests/check.py --skip-build` passed **288 checks** across all
six languages. All 18 published measurement rows were recalculated; the 180 raw
records form 90 matched pairs with compatible configurations and checksums.
Source/artifact hashes and relative documentation links also passed.

This pass did not independently establish historical red-test chronology,
measurement scheduling, host contention, external-document currency, rebuilds,
safety builds, or script E2E behavior.

Total findings: **Standards 0; Spec 0**.

## Independent acceptance verification

The requested `mneves-verify` ran in a fresh context with a different model.
It rebuilt copied inputs under `.scratch/verify-build/`, preserving the measured
artifacts, and derived its own scalar oracle from the public numerical chapters.
It did not inspect implementation or test source for behavioral judgments.

```text
Verdict: PASS
Builder: GPT-6.1 Sol / shell, compiler, web, patch / main implementation context
Verifier: GPT-6 Astra / shell, compiler, independent scalar oracle, real CLI / fresh acceptance context
Different model required: yes
Different model used: yes
Criterion 1 — Six implementations build/run: PASS — Independent scratch rebuild exited 0; all six ran on the recorded toolchains.
Criterion 2 — Numerical parity, modes, seeds, warmup and output: PASS — 516/516 independent probes on measured artifacts and 516/516 on fresh builds, including 288 numeric cases per set.
Criterion 3 — Local, reproducible optimization claims: PASS — All 18 summaries recalculated; improvements, regressions and outliers match the records; 90 checksum pairs match.
Criterion 4 — CLI rejection and overflow: PASS — 210 invalid-input probes per artifact set returned nonzero, stderr diagnostics and empty stdout.
Criterion 5 — CLI coverage and controls: PASS — Fresh-build repository E2E 291/291; independent script probes 11/11; wrong-PRNG and wrong-time-grid controls detected; formatting, Clippy, Cargo test, shellcheck and diff gates passed.
Criterion 6 — Reproducible evidence: PASS — 180 measurement records, parameters, timing consistency, 13 source hashes and six measured artifact hashes validated; final stability check passed.
Criterion 7 — Documentation/version/changelog: PASS — README, VERSION, changelog and fresh Cargo compilation identify 1.4.0; historical rankings are labeled.
Remaining uncertainty: Finite probes do not prove exhaustive correctness. Historical timing conditions cannot be reconstructed from records. Sanitizer/ReleaseSafe runs were not independently repeated. Source reviews and Git delivery are separate gates.
```

The fresh-build E2E command was
`python3 tests/check.py --skip-build --bin-dir .scratch/verify-build/.scratch/bin --scripts`.
Independent probes also covered file-redirection and outside-root runner usage,
comparison success and invalid records, decimal grammar, wide seeds, and warmup
0 versus 11. Detailed local logs remain in the ignored verification directory.
No product defects were found, so no correction/reverification round was needed.

## Reproduce the experiment

Use [build.sh](../build.sh) for current compiler commands. Materialize baseline
sources from `git show ef3c530:<path>` in a scratch directory, apply the linked
Zig compatibility patch there, and compile with the same flags. In particular,
baseline C/V must disable fast-math and contraction and baseline Swift must use
`-O`, even though the historical runner used other settings.

For each language and mode, run five fresh-process pairs; reverse order on odd
repetitions. Rotate language order between repetitions. Each process receives:

```text
--n=500000 --runs=200 --warmup=20 --seed=1 --mode=<full|gn|ou> --output=json
```

Preserve each JSON object with its revision label, repetition, and binary/source
hash, as in the raw records. Check paired checksums before calculating deltas.
For the comparison helper, extract one repetition into two flat JSONL files:

```python
import json
from pathlib import Path
rows = [json.loads(line) for line in Path("DOCS/results/2026-10-02/paired.jsonl").read_text().splitlines()]
for revision in ("baseline", "candidate"):
    records = [row["result"] for row in rows if row["revision"] == revision and row["repetition"] == 1]
    Path(f".scratch/{revision}.jsonl").write_text("".join(json.dumps(record) + "\n" for record in records))
```

Then run `./DOCS/scripts/compare_runs.sh .scratch/baseline.jsonl .scratch/candidate.jsonl`.

## Primary guidance consulted

- [Clang floating-point options](https://clang.llvm.org/docs/UsersManual.html#controlling-floating-point-behavior): fast-math and contraction alter numerical assumptions; this supports the explicit build policy.
- [Zig 0.16 release notes](https://ziglang.org/download/0.16.0/release-notes.html): process and I/O migration; local standard-library source confirmed `.awake` clock semantics.
- [Rust slice APIs](https://doc.rust-lang.org/std/primitive.slice.html#method.as_chunks_mut) and [Nicholas Nethercote's bounds-check guidance](https://nnethercote.github.io/perf-book/bounds-checks.html): use safe fixed-size chunks and iterators before unchecked indexing.
- [Swift Array](https://developer.apple.com/documentation/swift/array) and installed Xcode `Swift-InlineArray-Span.md`: review ownership and lifetime choices. Compile-time-sized InlineArray does not fit runtime `n`.
- [Bun binary-data documentation](https://bun.com/docs/runtime/binary-data): typed numeric buffers.
- [V documentation](https://github.com/vlang/v/blob/0.5.2/doc/docs.md) and generated C: inspect backend flags, array access, and runtime configuration rather than infer them from language labels.
- [Google Benchmark guide](https://google.github.io/benchmark/user_guide.html): fresh repetitions, interleaving, and optimizer observability.
- [Brendan Gregg's Active Benchmarking](https://www.brendangregg.com/activebenchmarking.html): inspect the actual workload and configuration before interpreting numbers. This run does not claim his full system-profiling methodology was executed.

## Limits

Only this macOS arm64 machine and the listed compilers were executed. Linux,
Windows, x86, Rust's declared minimum version, other Swift/Xcode versions, and
future toolchains remain unverified. Bun executes TypeScript but does not supply
a TypeScript typecheck; no standalone TypeScript compiler gate was installed.
No profiler-based attribution, confidence interval, thermal control, exhaustive
input proof, or cryptographic/scientific PRNG certification is claimed.

The historical tracked `v/ou_bench` binary remains unchanged and unused. The
current source-built artifacts live under `.scratch/bin/`.
