#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
if (( $# > 6 )); then
  echo "usage: $0 [n] [runs] [warmup] [seed] [mode] [output]" >&2
  exit 1
fi

N="${1:-500000}"
RUNS="${2:-1000}"
WARMUP="${3:-5}"
SEED="${4:-1}"
MODE="${5:-full}"
OUTPUT="${6:-text}"

if [[ "${BENCH_SKIP_BUILD:-0}" != "1" ]]; then
  bash "$ROOT/build.sh"
fi

args=("--n=$N" "--runs=$RUNS" "--warmup=$WARMUP" "--seed=$SEED" "--mode=$MODE" "--output=$OUTPUT")
"${BUN:-bun}" run "$ROOT/ts/ou_bench.ts" "${args[@]}"
for language in rust c zig swift v; do
  "$ROOT/.scratch/bin/$language" "${args[@]}"
done
