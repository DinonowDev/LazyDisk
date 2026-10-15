#!/usr/bin/env python3
"""Compare LazyDisk benchmark JSON with DaisyDisk JSON (from benchmark-daisydisk-auto)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def score_ratio(lazy: float, daisy: float, lower_is_better: bool = True) -> float:
    if daisy <= 0 or lazy <= 0:
        return 0.0
    ratio = lazy / daisy
    if lower_is_better:
        if ratio <= 1.0:
            return min(10.0, 10.0 / ratio * 0.85 + 1.5)
        return max(0.0, 10.0 - (ratio - 1.0) * 4.0)
    return 0.0


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: benchmark-compare.py <lazydisk.json> <daisydisk.json>", file=sys.stderr)
        return 2

    lazy_path = Path(sys.argv[1])
    daisy_path = Path(sys.argv[2])
    lazy = load(lazy_path)
    daisy = load(daisy_path)

    metrics = [
        ("gated_ready", "gatedReadySeconds", True),
        ("nav_total", "navigationTotalSeconds", True),
        ("nav_median", "navigationMedianSeconds", True),
    ]

    print(f"LazyDisk:  {lazy_path}")
    print(f"DaisyDisk: {daisy_path}")
    print(f"scanRoot lazy={lazy.get('scanRoot')} daisy={daisy.get('scanRoot')}")
    print()

    scores: list[float] = []
    for label, key, lower in metrics:
        lv = float(lazy.get(key, 0) or 0)
        dv = float(daisy.get(key, 0) or 0)
        s = score_ratio(lv, dv, lower_is_better=lower)
        scores.append(s)
        winner = "LazyDisk" if lv < dv else "DaisyDisk" if dv < lv else "tie"
        print(f"{label:12}  LazyDisk {lv:8.3f}s   DaisyDisk {dv:8.3f}s   → {winner}   score {s:.1f}/10")

    if scores:
        avg = sum(scores) / len(scores)
        print()
        print(f"Average comparative score (higher = LazyDisk closer/faster): {avg:.1f}/10")

    report_script = Path(__file__).resolve().parent / "benchmark-report.py"
    if report_script.is_file():
        out_dir = lazy_path.parent
        base = f"report-compare-{lazy_path.stem}"
        subprocess.run(
            [
                sys.executable,
                str(report_script),
                str(lazy_path),
                "--daisy-json",
                str(daisy_path),
                "--out-dir",
                str(out_dir),
                "--basename",
                base,
            ],
            check=False,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
