#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
mkdir -p .scratch/bin .scratch/zig-cache .scratch/swift-cache .scratch/vmodules .scratch/vtmp

CC="${CC:-cc}"
V="${V:-v}"
for tool in "$CC" cargo zig swiftc "$V" "${BUN:-bun}"; do
  if ! command -v "$tool" >/dev/null; then
    echo "Missing tool: $tool (see README.md)" >&2
    exit 1
  fi
done

echo 'Building Rust, C, Zig, Swift, and V (strict floating point)...' >&2
RUSTFLAGS="${RUSTFLAGS:--C target-cpu=native}" cargo build --release --locked --manifest-path rust/Cargo.toml >&2
cp rust/target/release/ou_bench_unified .scratch/bin/rust
"$CC" -O3 -march=native -fno-fast-math -ffp-contract=off -std=c11 \
  -Wall -Wextra -Wconversion -Werror c/ou_bench.c -lm -o .scratch/bin/c
zig build-exe zig/ou_bench.zig -O "${ZIG_OPTIMIZE:-ReleaseFast}" -mcpu=native \
  --global-cache-dir "$ROOT/.scratch/zig-cache" -femit-bin=.scratch/bin/zig
swiftc -O -whole-module-optimization -swift-version 6 -warnings-as-errors \
  -module-cache-path .scratch/swift-cache swift/ou_bench.swift -o .scratch/bin/swift
VMODULES="${VMODULES:-$ROOT/.scratch/vmodules}" VTMP="${VTMP:-$ROOT/.scratch/vtmp}" \
  "$V" -prod -cc "$CC" -cflags '-O3 -march=native -fno-fast-math -ffp-contract=off' \
  -o .scratch/bin/v v/ou_bench.v
