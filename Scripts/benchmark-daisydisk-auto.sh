#!/bin/bash
# Automated DaisyDisk benchmark (Accessibility + CPU heuristic). See docs/benchmark-testing-*.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f benchmark-results/latest-lazydisk.json ]]; then
  echo "Run LazyDisk benchmark first:"
  echo "  export LAZYDISK_BENCHMARK_ROOT=\"\$HOME\""
  echo "  ./Scripts/benchmark-native-scan.sh"
  exit 1
fi

if [[ "${1:-}" == "--check" || "${1:-}" == "-c" || "${1:-}" == "check" ]]; then
  exec python3 "$ROOT/Scripts/benchmark-daisydisk-auto.py" --check
fi

SCAN_ROOT="${1:-}"
if [[ -n "$SCAN_ROOT" ]]; then
  exec python3 "$ROOT/Scripts/benchmark-daisydisk-auto.py" "$SCAN_ROOT"
else
  exec python3 "$ROOT/Scripts/benchmark-daisydisk-auto.py"
fi
