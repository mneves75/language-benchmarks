#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 baseline.jsonl candidate.jsonl" >&2
  exit 1
fi

python3 - "$1" "$2" <<'PY'
import json
import sys

baseline_path, candidate_path = sys.argv[1], sys.argv[2]


def load(path):
    data = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            key = f"{obj.get('language')}|{obj.get('mode')}"
            data[key] = obj
    return data


def pct(new, old):
    if old == 0:
        return None
    return (new - old) / old * 100.0


baseline = load(baseline_path)
candidate = load(candidate_path)
keys = sorted(set(baseline.keys()) | set(candidate.keys()))

for key in keys:
    if key not in baseline:
        print(f"{key}: missing in baseline")
        continue
    if key not in candidate:
        print(f"{key}: missing in candidate")
        continue

    old = baseline[key]
    new = candidate[key]
    print(key)
    for field in ("avg_ms", "median_ms", "min_ms", "max_ms"):
        if field not in old or field not in new:
            continue
        o = old[field]
        n = new[field]
        delta = pct(n, o)
        if delta is None:
            print(f"  {field}: {o} -> {n}")
        else:
            print(f"  {field}: {o:.6f} -> {n:.6f} ({delta:+.2f}%)")
PY
