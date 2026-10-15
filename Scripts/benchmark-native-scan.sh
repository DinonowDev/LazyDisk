#!/bin/bash
# LazyDisk performance benchmark: native sizing, gated-ready simulation, 20-folder navigation.
# Optional DaisyDisk comparison: ./Scripts/benchmark-daisydisk-auto.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE_TARGET="${1:-$HOME/Library}"
BENCHMARK_ROOT="${LAZYDISK_BENCHMARK_ROOT:-/System/Volumes/Data}"
RUNS="${BENCHMARK_RUNS:-1}"
NAV_STEPS="${LAZYDISK_BENCHMARK_NAV_STEPS:-20}"
OUT_DIR="${ROOT}/benchmark-results"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="${OUT_DIR}/lazydisk-${STAMP}.json"
LATEST_JSON="${OUT_DIR}/latest-lazydisk.json"
REPORT_BASE="report-${STAMP}"
OUT_MD="${OUT_DIR}/${REPORT_BASE}.md"
OUT_PDF="${OUT_DIR}/${REPORT_BASE}.pdf"
LATEST_MD="${OUT_DIR}/latest-report.md"
LATEST_PDF="${OUT_DIR}/latest-report.pdf"

mkdir -p "$OUT_DIR"

echo "═══════════════════════════════════════════════════════════════"
echo " LazyDisk performance benchmark"
echo "═══════════════════════════════════════════════════════════════"
echo "  native path:     $NATIVE_TARGET"
echo "  volume root:     $BENCHMARK_ROOT"
echo "  navigation steps: $NAV_STEPS"
  echo "  results:         $OUT_JSON"
  echo "  report:          $OUT_MD (+ PDF if pandoc installed)"
echo ""

cd "$ROOT"

echo "→ Building release…"
swift build -c release 2>/dev/null

echo ""
echo "── Phase A: native child sizing (LazyDiskFS) ──"
export LDFS_BENCHMARK=1
export LDFS_BENCHMARK_PATH="$NATIVE_TARGET"
export BENCHMARK_RUNS="${BENCHMARK_RUNS:-2}"
swift test --filter NativeScanBenchmarkTests 2>&1 | tail -n 25

echo ""
echo "── Phase B: gated ready + ${NAV_STEPS}× navigation (headless) ──"
export LAZYDISK_BENCHMARK=1
export LAZYDISK_BENCHMARK_ROOT="$BENCHMARK_ROOT"
export LAZYDISK_BENCHMARK_NAV_STEPS="$NAV_STEPS"

PHASE_B_LOG="$(mktemp)"
set +e
swift test --filter VolumeScanBenchmarkTests/testVolumeScanBenchmarkReport 2>&1 | tee "$PHASE_B_LOG"
TEST_EXIT=$?
set -e

BENCHMARK_LINE="$(grep '^BENCHMARK_JSON=' "$PHASE_B_LOG" | tail -n 1 || true)"
rm -f "$PHASE_B_LOG"

if [[ -n "$BENCHMARK_LINE" ]]; then
  JSON_PAYLOAD="${BENCHMARK_LINE#BENCHMARK_JSON=}"
  echo "$JSON_PAYLOAD" > "$OUT_JSON"
  cp "$OUT_JSON" "$LATEST_JSON"
  echo ""
  echo "── Saved machine-readable report ──"
  echo "  $OUT_JSON"
  DAISY_JSON=""
  for candidate in "$OUT_DIR"/daisydisk-*.json "$OUT_DIR"/latest-daisydisk.json; do
    if [[ -f "$candidate" ]]; then
      DAISY_JSON="$candidate"
      break
    fi
  done

  if command -v python3 >/dev/null 2>&1; then
    REPORT_ARGS=(python3 "$ROOT/Scripts/benchmark-report.py" "$OUT_JSON" --out-dir "$OUT_DIR" --basename "$REPORT_BASE")
    if [[ -n "$DAISY_JSON" ]]; then
      REPORT_ARGS+=(--daisy-json "$DAISY_JSON")
    fi
    "${REPORT_ARGS[@]}" || true
    cp -f "$OUT_MD" "$LATEST_MD" 2>/dev/null || true
    cp -f "$OUT_PDF" "$LATEST_PDF" 2>/dev/null || true

    python3 - <<'PY' "$OUT_JSON"
import json, sys
path = sys.argv[1]
with open(path) as f:
    r = json.load(f)
print(f"  gated_ready:      {r['gatedReadySeconds']:.3f}s")
print(f"  nav_total ({r['navigationSteps']}): {r['navigationTotalSeconds']:.3f}s")
print(f"  nav_median:       {r['navigationMedianSeconds']:.3f}s")
print(f"  nav_p95:          {r['navigationP95Seconds']:.3f}s")
for p in r.get("phases", []):
    d = f" ({p['detail']})" if p.get("detail") else ""
    print(f"    - {p['name']}: {p['seconds']:.3f}s{d}")
PY
    echo ""
    echo "── Reports ──"
    echo "  $OUT_MD"
    [[ -f "$OUT_PDF" ]] && echo "  $OUT_PDF"
  fi
else
  echo "⚠ No BENCHMARK_JSON line captured (test skipped or failed)."
fi

echo ""
echo "── Phase C: DaisyDisk (automated, same scan root) ──"
echo "  ./Scripts/benchmark-daisydisk-auto.sh --check   # once: Accessibility"
echo "  ./Scripts/benchmark-daisydisk-auto.sh         # or: ./Scripts/benchmark-daisydisk-auto.sh \"$BENCHMARK_ROOT\""

exit "${TEST_EXIT:-0}"
