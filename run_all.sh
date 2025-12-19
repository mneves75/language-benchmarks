#!/usr/bin/env bash
set -euo pipefail

N="${1:-500000}"
RUNS="${2:-1000}"
WARMUP="${3:-5}"
SEED="${4:-1}"
MODE="${5:-full}"
OUTPUT="${6:-text}"

echo "=== Building all benchmarks ==="
echo

echo "Building Rust..."
( cd rust && RUSTFLAGS="-C target-cpu=native" cargo build --release --quiet )

echo "Building C..."
( cd c && cc -Ofast -march=native -fno-math-errno -fno-trapping-math -std=c11 ou_bench.c -lm -o ou_bench_c )

echo "Building Zig..."
( cd zig && zig build-exe ou_bench.zig -O ReleaseFast -mcpu=native -fstrip -femit-bin=ou_bench 2>/dev/null )

echo "Building Swift..."
( cd swift && swiftc -Ounchecked -whole-module-optimization ou_bench.swift -o ou_bench_swift )

echo
echo "=== Running benchmarks ==="
echo "n=$N runs=$RUNS warmup=$WARMUP seed=$SEED"
if [[ "$MODE" != "full" || "$OUTPUT" != "text" ]]; then
  echo "mode=$MODE output=$OUTPUT"
fi
echo

echo "[TypeScript/Bun]"
( cd ts && bun run ou_bench.ts --n="$N" --runs="$RUNS" --warmup="$WARMUP" --seed="$SEED" --mode="$MODE" --output="$OUTPUT" )
echo

echo "[Rust]"
( cd rust && ./target/release/ou_bench_unified --n="$N" --runs="$RUNS" --warmup="$WARMUP" --seed="$SEED" --mode="$MODE" --output="$OUTPUT" )
echo

echo "[C]"
( cd c && ./ou_bench_c --n="$N" --runs="$RUNS" --warmup="$WARMUP" --seed="$SEED" --mode="$MODE" --output="$OUTPUT" )
echo

echo "[Zig]"
( cd zig && ./ou_bench --n="$N" --runs="$RUNS" --warmup="$WARMUP" --seed="$SEED" --mode="$MODE" --output="$OUTPUT" )

echo "[Swift]"
( cd swift && ./ou_bench_swift --n="$N" --runs="$RUNS" --warmup="$WARMUP" --seed="$SEED" --mode="$MODE" --output="$OUTPUT" )
echo
