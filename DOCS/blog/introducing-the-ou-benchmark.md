# One stochastic workload, six language implementations

The OU benchmark implements one numerical pipeline in C, Zig, Rust,
TypeScript/Bun, Swift, and V. It is a small, inspectable way to study numerical
code and measurement, with a shared algorithm and command-line contract.

The Ornstein–Uhlenbeck process models a value pulled toward a mean while receiving
random kicks. A spring subject to disturbances is a useful analogy. The benchmark
uses an Euler approximation, not an exact transition of the continuous process.

## The shared recipe

Every implementation expands a seed with SplitMix32, advances xorshift128,
combines two words into a 53-bit uniform, and uses Marsaglia polar to generate
normal pairs. Scaled noise drives the recurrence:

```text
dt = 1/n
a = 1 - dt
diff = 0.1 * sqrt(dt)
X[0] = 0
X[i] = (a * X[i-1] + 0) + diff * Z[i-1]
```

`n` counts stored points. There are `n-1` updates and the final time is
`(n-1)/n`. Matching those details matters as much as matching the formula.

Rust, Zig, TypeScript, and Swift fill normal pairs while preserving the
original order, including spares across odd-length fills. C and V retain scalar
cached sampling after paired-fill candidates slowed generation in matched-policy
experiments. Both structures implement the same stream.

Zig explicitly inlines its fill helper. V limits unchecked access to normal-buffer
stores in loops bounded by the buffer length; other accesses retain
ordinary checks. These choices come from concrete artifact inspection and
measurement, not from assuming every language benefits from the same loop shape.

## What gets timed

| Mode | Work inside timing |
|---|---|
| `full` | Normal generation, simulation, ordered path checksum |
| `gn` | Normal generation and ordered noise checksum |
| `ou` | Simulation and checksum over prefilled noise |

Allocation, parsing, warmup, output, and sorting timing samples are excluded.
Warmup uses separate state; timed generation restarts from the seed and then
continues across runs.

The checksum makes output observable and detects some regressions. Independent
numeric reference tests and negative controls provide stronger correctness
evidence. Small rounding differences need investigation; they do not justify
changing the integer stream or time step.

## Try a small run

From the repository root:

```bash
./run_all.sh 1000 3 1 42 full json
```

The runner builds and runs all six implementations and emits six JSON Lines
records on stdout. Build messages go to stderr. The
[root README](../../README.md) defines prerequisites, exact build flags, CLI
limits, and verification commands.

The CLI accepts decimal integers and rejects malformed or unknown arguments.
Seeds are parsed exactly through the unsigned 64-bit range before reduction to
the effective 32-bit seed.

## Compare configurations, not slogans

Strict optimized builds avoid default fast-math and Swift unchecked mode.
That helps preserve the numerical contract, but it does not make runtime safety
checks or compiler behavior identical across languages.

A runtime or language name cannot explain a timing gap by itself. Attribute a
gap to garbage collection, ARC, bounds checks, or dispatch only after a profile
or controlled experiment. Native CPU builds and changing math libraries also
limit transferability.

Historical results remain in [the 2025 run record](../Run-Record-2025-12-19.md).
Modernization measurements and their limits belong in
[the 2026 record](../Run-Record-2026-10-02.md). Neither establishes a universal
language ranking or a promised speedup.

## Learn by tracing

The [learning guide](../learn/README.md) explains the math, integer arithmetic,
normal pairs, language choices, and measurement boundaries. Start with a tiny
path, trace its seed and samples, then verify a real CLI result before measuring.

Changing to exact OU transitions, another generator, SIMD across independent
paths, or GPU execution can be valuable. Each is a different workload and should
be labeled and validated as such.
