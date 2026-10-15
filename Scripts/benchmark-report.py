#!/usr/bin/env python3
"""Generate Markdown + PDF reports from LazyDisk benchmark JSON."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def fmt_seconds(value: float) -> str:
    return f"{value:.3f}s"


def score_ratio(lazy: float, daisy: float) -> float:
    if daisy <= 0 or lazy <= 0:
        return 0.0
    ratio = lazy / daisy
    if ratio <= 1.0:
        return min(10.0, 10.0 / ratio * 0.85 + 1.5)
    return max(0.0, 10.0 - (ratio - 1.0) * 4.0)


def build_markdown(lazy: dict[str, Any], daisy: dict[str, Any] | None) -> str:
    recorded = lazy.get("recordedAt", datetime.now(timezone.utc).isoformat())
    scan_root = lazy.get("scanRoot", "—")
    lines: list[str] = [
        "# LazyDisk performance benchmark",
        "",
        f"- **Recorded:** {recorded}",
        f"- **Scan root:** `{scan_root}`",
        f"- **Indexed paths:** {lazy.get('indexedPathCount', 0):,}",
        f"- **Files scanned (volume tree):** {lazy.get('volumeTreeFilesScanned', 0):,}",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|--------|------:|",
        f"| Gated ready (Daisy parity: splash chart + map, no full walk / prefetch) | **{fmt_seconds(float(lazy.get('daisyParityReadySeconds', lazy.get('gatedReadySeconds', 0))))}** |",
        f"| Navigation steps | {lazy.get('navigationSteps', 0)} |",
        f"| Navigation total | {fmt_seconds(float(lazy.get('navigationTotalSeconds', 0)))} |",
        f"| Navigation median | {fmt_seconds(float(lazy.get('navigationMedianSeconds', 0)))} |",
        f"| Navigation p95 | {fmt_seconds(float(lazy.get('navigationP95Seconds', 0)))} |",
        "",
        "## Phases",
        "",
        "| Phase | Time | Detail |",
        "|-------|-----:|--------|",
    ]

    for phase in lazy.get("phases", []):
        name = phase.get("name", "")
        seconds = fmt_seconds(float(phase.get("seconds", 0)))
        detail = phase.get("detail") or ""
        lines.append(f"| `{name}` | {seconds} | {detail} |")

    nav = lazy.get("navigation") or []
    if nav:
        lines.extend(
            [
                "",
                "## Navigation drill-down",
                "",
                "| # | Folder | Children | Time |",
                "|--:|--------|----------|-----:|",
            ]
        )
        for step in nav:
            lines.append(
                f"| {step.get('index', '')} | `{step.get('name', '')}` | "
                f"{step.get('childCount', 0)} | {fmt_seconds(float(step.get('seconds', 0)))} |"
            )

    notes = lazy.get("notes") or []
    if notes:
        lines.extend(["", "## Notes", ""])
        for note in notes:
            lines.append(f"- {note}")

    if daisy:
        lines.extend(
            [
                "",
                "## Comparison vs DaisyDisk",
                "",
                f"- **DaisyDisk scan root:** `{daisy.get('scanRoot', '—')}`",
                "",
                "| Metric | LazyDisk | DaisyDisk | Faster | Score /10 |",
                "|--------|---------:|----------:|--------|----------:|",
            ]
        )
        metrics = [
            ("Gated ready", "gatedReadySeconds"),
            ("Nav total", "navigationTotalSeconds"),
            ("Nav median", "navigationMedianSeconds"),
        ]
        scores: list[float] = []
        for label, key in metrics:
            lv = float(lazy.get(key, 0) or 0)
            dv = float(daisy.get(key, 0) or 0)
            s = score_ratio(lv, dv)
            scores.append(s)
            faster = "LazyDisk" if lv < dv else "DaisyDisk" if dv < lv else "tie"
            lines.append(
                f"| {label} | {fmt_seconds(lv)} | {fmt_seconds(dv)} | {faster} | {s:.1f} |"
            )
        if scores:
            lines.append("")
            lines.append(f"**Average comparative score:** {sum(scores) / len(scores):.1f} / 10")
        daisy_notes = daisy.get("notes")
        if daisy_notes:
            lines.extend(["", f"*DaisyDisk notes:* {daisy_notes}"])

    lines.extend(
        [
            "",
            "---",
            "",
            "*Headless benchmark (`VolumeScanBenchmark`): volume tree scan, chart map, "
            "display-depth prefetch, then indexed folder listings. "
            "DaisyDisk numbers from `benchmark-daisydisk-auto` on the same machine.*",
            "",
        ]
    )
    return "\n".join(lines)


def write_pdf(md_path: Path, pdf_path: Path) -> str | None:
    pandoc = shutil.which("pandoc")
    if not pandoc:
        return "pandoc not found (install: brew install pandoc basictex)"

    engines = ["pdflatex", "xelatex", "lualatex", "tectonic"]
    for engine in engines:
        if shutil.which(engine):
            result = subprocess.run(
                [
                    pandoc,
                    str(md_path),
                    "-o",
                    str(pdf_path),
                    f"--pdf-engine={engine}",
                    "-V",
                    "geometry:margin=2.2cm",
                    "-V",
                    "fontsize=11pt",
                ],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and pdf_path.is_file():
                return None
    # HTML → print via wkhtmltopdf if present
    wk = shutil.which("wkhtmltopdf")
    if wk:
        html_path = md_path.with_suffix(".html")
        subprocess.run([pandoc, str(md_path), "-o", str(html_path)], check=True)
        result = subprocess.run([wk, str(html_path), str(pdf_path)], capture_output=True, text=True)
        html_path.unlink(missing_ok=True)
        if result.returncode == 0 and pdf_path.is_file():
            return None

    return "PDF export failed (install basictex or wkhtmltopdf)"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Markdown/PDF benchmark report")
    parser.add_argument("lazydisk_json", type=Path, help="LazyDisk benchmark JSON")
    parser.add_argument(
        "--daisy-json",
        type=Path,
        default=None,
        help="Optional DaisyDisk JSON (e.g. latest-daisydisk.json)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Output directory (default: same as JSON parent)",
    )
    parser.add_argument("--basename", type=str, default=None, help="Report file basename without extension")
    args = parser.parse_args()

    if not args.lazydisk_json.is_file():
        print(f"Missing JSON: {args.lazydisk_json}", file=sys.stderr)
        return 1

    lazy = load_json(args.lazydisk_json)
    daisy = load_json(args.daisy_json) if args.daisy_json and args.daisy_json.is_file() else None

    out_dir = args.out_dir or args.lazydisk_json.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    base = args.basename or args.lazydisk_json.stem.replace("lazydisk-", "report-")
    if base == args.lazydisk_json.stem:
        base = f"report-{args.lazydisk_json.stem}"

    md_path = out_dir / f"{base}.md"
    pdf_path = out_dir / f"{base}.pdf"

    md_path.write_text(build_markdown(lazy, daisy), encoding="utf-8")
    print(f"Wrote {md_path}")

    pdf_error = write_pdf(md_path, pdf_path)
    if pdf_error:
        print(f"PDF: {pdf_error}", file=sys.stderr)
        print(f"  Markdown report is still available: {md_path}")
        return 0

    print(f"Wrote {pdf_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
