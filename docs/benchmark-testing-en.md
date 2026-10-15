# Benchmark & performance testing

English · [فارسی](benchmark-testing-fa.md)

This guide walks through measuring LazyDisk performance (headless + native), generating **Markdown/PDF** reports, and comparing with **DaisyDisk** on the same Mac using the automated DaisyDisk script only.

## What you need

| Tool | Purpose |
|------|---------|
| Xcode / Swift 5.9+, macOS 13+ | `swift build`, `swift test` |
| Python 3 | `benchmark-report.py`, `benchmark-compare.py`, `benchmark-daisydisk-auto.py` |
| [pandoc](https://pandoc.org/) + [BasicTeX](https://www.tug.org/mactex/morepackages.html) | PDF reports (optional; `.md` always generated) |
| DaisyDisk (for comparison) | `/Applications/DaisyDisk.app` |

Install PDF tooling once:

```bash
brew install pandoc basictex
eval "$(/usr/libexec/path_helper)"   # or restart Terminal
which pdflatex
```

## Recommended workflow (end to end)

From the repository root:

```bash
cd /path/to/LazyDisk

# 1) Pick the same folder LazyDisk and DaisyDisk will scan (start with home — faster)
export LAZYDISK_BENCHMARK_ROOT="$HOME"
export LAZYDISK_BENCHMARK_NAV_STEPS=20

# 2) LazyDisk benchmark (native + headless) — can take many minutes on large trees
./Scripts/benchmark-native-scan.sh "$HOME/Library"

# 3) One-time permissions for DaisyDisk automation
./Scripts/benchmark-daisydisk-auto.sh --check

# 4) DaisyDisk benchmark (opens DaisyDisk, rescan, navigation clicks)
./Scripts/benchmark-daisydisk-auto.sh
# optional explicit root: ./Scripts/benchmark-daisydisk-auto.sh "$HOME"
```

When finished, open:

- `benchmark-results/latest-report.md` — LazyDisk-only summary  
- `benchmark-results/report-compare-auto-*.md` (and `.pdf` if pandoc works) — LazyDisk vs DaisyDisk  

All artifacts live in `benchmark-results/` (gitignored).

### Two different paths in `benchmark-native-scan.sh`

| Setting | Meaning |
|---------|---------|
| **First argument** (e.g. `$HOME/Library`) | **Phase A** — native `LazyDiskFS` sizing benchmark on that folder |
| **`LAZYDISK_BENCHMARK_ROOT`** (e.g. `$HOME`) | **Phase B** — headless gated-ready + navigation on that scan root |

For a fair DaisyDisk comparison, set `LAZYDISK_BENCHMARK_ROOT` to the folder you open in DaisyDisk (often `$HOME`). Phase A can stay on `$HOME/Library` for a quicker native sample.

## What gets measured

### Phase A — Native child sizing (`LazyDiskFS`)

- Runs `NativeScanBenchmarkTests` with `getattrlistbulk`-style walks.
- Controlled by `LDFS_BENCHMARK=1`, `LDFS_BENCHMARK_PATH`, and `BENCHMARK_RUNS` (Phase A uses default **2** runs inside the script).

### Phase B — Gated ready + navigation (headless, no SwiftUI)

Simulates the core app pipeline via `VolumeScanBenchmark`:

1. **`list_volume_root`** — list entries at scan root  
2. **`volume_tree_scan`** — deep directory index (usually ~95% of `gatedReadySeconds` on large trees)  
3. **`chart_child_map`** — sunburst child map  
4. **`prefetch_display_depth`** — display-depth prefetch (ring-style depth)  
5. **Navigation harness** — `LAZYDISK_BENCHMARK_NAV_STEPS` folder listings from `DirectorySizeIndex` (no subtree re-walk)

| Variable | Default | Meaning |
|----------|---------|---------|
| `LAZYDISK_BENCHMARK_ROOT` | `/System/Volumes/Data` | Headless scan root (`scanRoot` in JSON) |
| `LAZYDISK_BENCHMARK_NAV_STEPS` | `20` | Drill-down steps after scan |
| `LAZYDISK_BENCHMARK` | set by script | Enables `VolumeScanBenchmarkTests/testVolumeScanBenchmarkReport` |

**Note:** Headless `gatedReadySeconds` does **not** include SwiftUI, app cache, splash animations, or Admin Helper. Real app “time until interactive” may be slightly higher.

### Phase C — DaisyDisk (automated)

Run separately via `benchmark-daisydisk-auto.sh` after Phase B. See [DaisyDisk automation](#daisydisk-automation) below.

## Output files

### LazyDisk (`benchmark-native-scan.sh`)

| File | Description |
|------|-------------|
| `lazydisk-<timestamp>.json` | Raw metrics |
| `latest-lazydisk.json` | Symlink/copy of latest LazyDisk run |
| `report-<timestamp>.md` / `.pdf` | LazyDisk report |
| `latest-report.md` / `latest-report.pdf` | Latest LazyDisk report |

### DaisyDisk (`benchmark-daisydisk-auto.sh`)

| File | Description |
|------|-------------|
| `daisydisk-auto-<timestamp>.json` | Automated DaisyDisk metrics |
| `latest-daisydisk.json` | Latest DaisyDisk run |
| `report-compare-auto-<timestamp>.md` / `.pdf` | Combined comparison report |

### Key JSON fields (both products)

| Field | Meaning |
|-------|---------|
| `scanRoot` | Folder that was scanned |
| `gatedReadySeconds` | Time until “ready” (LazyDisk: full headless pipeline; DaisyDisk: CPU-idle heuristic after rescan) |
| `navigationSteps` | Number of drill-down steps measured |
| `navigationTotalSeconds` | Sum of navigation step times |
| `navigationMedianSeconds` | Median step time (LazyDisk always; DaisyDisk when clicks succeed) |
| `phases[]` | LazyDisk only — per-phase timings |

## DaisyDisk automation

DaisyDisk has no public CLI. `Scripts/benchmark-daisydisk-auto.py` drives the app through **Accessibility** and **Automation**.

### One-time permissions

macOS cannot grant these programmatically.

```bash
./Scripts/benchmark-daisydisk-auto.sh --check
```

Repeat until you see **`Preflight passed`**.

1. **System Settings → Privacy & Security → Accessibility** — enable **Terminal** or **Cursor** (whichever runs the script).  
2. If prompted: **Automation** — allow that app to control **DaisyDisk**.  
3. DaisyDisk installed at `/Applications/DaisyDisk.app`.

If Accessibility is missing, the script opens Privacy settings.

### What the script does

1. Reads `scanRoot` from `benchmark-results/latest-lazydisk.json` (or from an optional path argument).  
2. Quits **LazyDisk** if running.  
3. `open -a DaisyDisk <scanRoot>`.  
4. **Action → Rescan Current Folder** (falls back to other “Rescan …” menu items if the label differs by version).  
5. Waits until DaisyDisk-related processes stay below **~8% CPU** for **8 consecutive samples** (0.5s apart), after at least **8s** of scan — max wait **2 hours**.  
6. Performs **`LAZYDISK_BENCHMARK_NAV_STEPS`** double-clicks at a fixed point on the chart (~58% width, ~52% height of the main window).  
7. Writes JSON, runs `benchmark-compare.py`, and `benchmark-report.py` with `--daisy-json`.

### Limits (read before trusting numbers)

| Topic | Detail |
|-------|--------|
| Scan “ready” | CPU heuristic ≠ DaisyDisk’s internal progress; can finish early or late vs what you feel in the UI. |
| Navigation | Fixed chart clicks ≠ LazyDisk’s “largest child” path in the headless harness. |
| Admin rescan | Do not use **Quick Rescan as Administrator** in the menu manually during a run; the script uses **Rescan Current Folder**. |
| Duration | Home folder scans often take **several minutes**; full Data volume can take **hours**. |

### Fair comparison checklist

- Same Mac, same disk, low background I/O (pause heavy downloads, VMs, Time Machine if possible).  
- Same **`scanRoot`** in both JSON files.  
- Comparable permissions (Full Disk Access / protected folders affect both apps differently).  
- Fresh rescan in DaisyDisk (script triggers rescan; don’t rely on an old map only).  
- Same **`LAZYDISK_BENCHMARK_NAV_STEPS`** for both sides.

## Regenerate reports

LazyDisk only:

```bash
python3 Scripts/benchmark-report.py benchmark-results/latest-lazydisk.json \
  --out-dir benchmark-results \
  --basename my-report
```

With DaisyDisk JSON:

```bash
python3 Scripts/benchmark-report.py benchmark-results/latest-lazydisk.json \
  --daisy-json benchmark-results/latest-daisydisk.json \
  --out-dir benchmark-results \
  --basename my-report
```

Terminal-only compare (also triggers a report via `benchmark-report.py`):

```bash
python3 Scripts/benchmark-compare.py \
  benchmark-results/latest-lazydisk.json \
  benchmark-results/latest-daisydisk.json
```

### Comparison score (/10)

`benchmark-compare.py` scores **gated ready**, **nav total**, and **nav median** (lower time is better). If either side has `0` in a metric, that row scores **0** — fix empty DaisyDisk runs by re-running `benchmark-daisydisk-auto.sh`. Higher average score means LazyDisk is closer to or faster than DaisyDisk on those metrics.

## Interpreting LazyDisk results

- **`volume_tree_scan`** usually dominates `gatedReadySeconds`.  
- **Navigation** totals under ~0.1s for 20 steps (warm index) suggest good post-scan drill-down in the harness.  
- **`volumeTreeFilesScanned`** and **`indexedPathCount`** help explain why two machines differ.

Rough sanity check: files per second ≈ `volumeTreeFilesScanned / volume_tree_scan` phase seconds.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| `No BENCHMARK_JSON line` after Phase B | Run from repo root; check `swift test --filter VolumeScanBenchmarkTests` with `LAZYDISK_BENCHMARK=1` and same `LAZYDISK_BENCHMARK_ROOT`. |
| Phase B very slow | Use `$HOME` instead of full `/System/Volumes/Data` for first runs. |
| `Preflight` Accessibility MISSING | Enable Terminal/Cursor in Accessibility; run outside restricted sandboxes; re-run `--check`. |
| `Can't get menu item "Rescan"` | Update repo — script uses **Rescan Current Folder** and fallbacks. |
| DaisyDisk compare scores all 0 | `gatedReadySeconds` or nav times are 0 in `latest-daisydisk.json` — re-run auto benchmark. |
| PDF missing | Install pandoc + basictex; `.md` is still valid. |
| Password dialog during DaisyDisk scan | Cancel admin quick rescan; use normal **Rescan Current Folder** via the script. |

## Related scripts

| Script | Role |
|--------|------|
| `Scripts/benchmark-native-scan.sh` | Phase A + B, JSON, LazyDisk MD/PDF |
| `Scripts/benchmark-daisydisk-auto.sh` | Phase C — DaisyDisk + compare MD/PDF |
| `Scripts/benchmark-report.py` | JSON → Markdown/PDF |
| `Scripts/benchmark-compare.py` | Terminal comparison + report |

## Unit tests (CI-style)

```bash
swift test
```

Benchmark tests are **skipped** without env flags:

```bash
LDFS_BENCHMARK=1 swift test --filter NativeScanBenchmarkTests
LAZYDISK_BENCHMARK=1 LAZYDISK_BENCHMARK_ROOT="$HOME" swift test --filter VolumeScanBenchmarkTests
```

`VolumeScanBenchmarkTests/testNavigationHarnessOnTempTree` always runs on a small temp tree.

## App development

```bash
./Scripts/dev.sh
swift test
```

See `README.md` and `CONTRIBUTING.md` for general workflow.
