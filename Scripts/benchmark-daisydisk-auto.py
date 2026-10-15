#!/usr/bin/env python3
"""
Automate DaisyDisk benchmark (scan ready + drill-down clicks) via macOS Accessibility.

Requires:
  - DaisyDisk.app in /Applications
  - System Settings → Privacy & Security → Accessibility → Terminal (or Cursor)
  - System Settings → Privacy & Security → Automation → allow Terminal to control DaisyDisk
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "benchmark-results"


def run_osascript(script: str) -> str:
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "osascript failed")
    return result.stdout.strip()


def accessibility_ok() -> bool:
    try:
        enabled = run_osascript(
            'tell application "System Events" to return UI elements enabled'
        )
        return enabled.lower() == "true"
    except Exception:
        return False


def open_accessibility_settings() -> None:
    for url in (
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        "x-apple.systempreferences:com.apple.preference.security",
    ):
        proc = subprocess.run(["open", url], check=False)
        if proc.returncode == 0:
            return


def daisy_disk_automation_ok() -> tuple[bool, str]:
    """Try a harmless AX query on DaisyDisk (needs Accessibility + often Automation)."""
    if not daisy_disk_installed():
        return False, "DaisyDisk not installed"
    subprocess.run(["open", "-a", "DaisyDisk"], check=False)
    time.sleep(1.5)
    result = subprocess.run(
        [
            "osascript",
            "-e",
            'tell application "DaisyDisk" to activate',
            "-e",
            'tell application "System Events" to tell process "DaisyDisk" to return name of window 1',
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "unknown").strip()
        return False, msg
    return True, result.stdout.strip()


def daisy_disk_installed() -> bool:
    return Path("/Applications/DaisyDisk.app").exists()


def quit_app(name: str) -> None:
    run_osascript(
        f'''
        tell application "{name}"
            try
                quit
            end try
        end tell
        '''
    )


def daisy_pids() -> list[int]:
    result = subprocess.run(
        ["pgrep", "-i", "daisydisk"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    return [int(line) for line in result.stdout.splitlines() if line.strip().isdigit()]


def total_cpu_percent(pids: list[int]) -> float:
    if not pids:
        return 0.0
    total = 0.0
    for pid in pids:
        proc = subprocess.run(
            ["ps", "-p", str(pid), "-o", "%cpu="],
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0:
            try:
                total += float(proc.stdout.strip())
            except ValueError:
                pass
    return total


def activate_rescan() -> None:
    """Action menu labels vary by DaisyDisk version (no plain "Rescan")."""
    run_osascript(
        '''
        tell application "DaisyDisk" to activate
        delay 0.5
        tell application "System Events" to tell process "DaisyDisk"
            set actionMenu to menu "Action" of menu bar item "Action" of menu bar 1
            set clickedRescan to false
            repeat with preferred in {"Rescan Current Folder", "Rescan", "Scan Again"}
                try
                    click menu item preferred of actionMenu
                    set clickedRescan to true
                    exit repeat
                end try
            end repeat
            if not clickedRescan then
                repeat with mi in menu items of actionMenu
                    try
                        set itemName to name of mi as text
                        if itemName starts with "Rescan " and itemName does not start with "Quick Rescan" then
                            click mi
                            set clickedRescan to true
                            exit repeat
                        end if
                    end try
                end repeat
            end if
            if not clickedRescan then
                error "No Rescan menu item found under Action"
            end if
        end tell
        '''
    )


def open_scan_root(scan_root: str) -> None:
    subprocess.run(["open", "-a", "DaisyDisk", scan_root], check=True)
    time.sleep(2.0)
    run_osascript('tell application "DaisyDisk" to activate')


def wait_until_scan_idle(
    min_active_seconds: float = 8.0,
    idle_threshold_cpu: float = 8.0,
    idle_samples_required: int = 8,
    sample_interval: float = 0.5,
    timeout_seconds: float = 7200.0,
) -> float:
    start = time.monotonic()
    idle_streak = 0
    while True:
        elapsed = time.monotonic() - start
        if elapsed > timeout_seconds:
            raise TimeoutError(f"DaisyDisk scan exceeded {timeout_seconds}s")

        cpu = total_cpu_percent(daisy_pids())
        if elapsed >= min_active_seconds and cpu < idle_threshold_cpu:
            idle_streak += 1
            if idle_streak >= idle_samples_required:
                return elapsed
        else:
            idle_streak = 0

        time.sleep(sample_interval)


def window_center_click(double: bool = True) -> None:
    """Double-click sunburst area (center-right of main window)."""
    second_click = (
        """
            delay 0.08
            click at {clickX, clickY}
        """
        if double
        else ""
    )
    run_osascript(
        f'''
        tell application "System Events" to tell process "DaisyDisk"
            tell window 1
                set {{x, y}} to position
                set {{w, h}} to size
            end tell
            set clickX to (x + (w * 0.58)) as integer
            set clickY to (y + (h * 0.52)) as integer
            set frontmost to true
            delay 0.05
            click at {{clickX, clickY}}
            {second_click}
        end tell
        '''
    )


def run_navigation(steps: int) -> tuple[list[dict], float]:
    records: list[dict] = []
    total = 0.0
    for index in range(1, steps + 1):
        step_start = time.monotonic()
        try:
            window_center_click(double=True)
        except Exception as exc:
            records.append(
                {
                    "index": index,
                    "seconds": 0.0,
                    "error": str(exc),
                }
            )
            break
        time.sleep(0.12)
        step_seconds = time.monotonic() - step_start
        total += step_seconds
        records.append({"index": index, "seconds": step_seconds})
    return records, total


def load_lazy_scan_root() -> str:
    lazy_path = OUT_DIR / "latest-lazydisk.json"
    if not lazy_path.is_file():
        raise FileNotFoundError(
            f"Missing {lazy_path}. Run ./Scripts/benchmark-native-scan.sh first."
        )
    with lazy_path.open(encoding="utf-8") as handle:
        return json.load(handle)["scanRoot"]


def write_daisy_json(
    scan_root: str,
    ready_seconds: float,
    nav_steps: int,
    nav_total: float,
    nav_records: list[dict],
    notes: str,
) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = OUT_DIR / f"daisydisk-auto-{stamp}.json"
    nav_times = [r["seconds"] for r in nav_records if "seconds" in r]
    nav_median = sorted(nav_times)[len(nav_times) // 2] if nav_times else 0.0
    payload = {
        "product": "DaisyDisk",
        "scanRoot": scan_root,
        "gatedReadySeconds": ready_seconds,
        "navigationSteps": len(nav_records),
        "navigationTotalSeconds": nav_total,
        "navigationMedianSeconds": nav_median,
        "recordedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "notes": notes,
        "automation": {
            "method": "Accessibility + CPU idle heuristic",
            "navigationClicks": nav_records,
        },
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    latest = OUT_DIR / "latest-daisydisk.json"
    latest.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    return path


def run_preflight() -> int:
    print("LazyDisk DaisyDisk automation preflight")
    ok_ax = accessibility_ok()
    print(f"  Accessibility (UI elements): {'OK' if ok_ax else 'MISSING'}")
    print(f"  DaisyDisk.app: {'OK' if daisy_disk_installed() else 'MISSING'}")
    if not ok_ax:
        print("\nOpening System Settings → Accessibility…")
        open_accessibility_settings()
        print("Enable Terminal or Cursor, then re-run:")
        print("  ./Scripts/benchmark-daisydisk-auto.sh --check")
        return 1
    if not daisy_disk_installed():
        return 1
    auto_ok, detail = daisy_disk_automation_ok()
    print(f"  DaisyDisk Automation/AX: {'OK' if auto_ok else 'FAILED'} ({detail})")
    if not auto_ok:
        print(
            "\nIf macOS asked for permission, allow this app to control DaisyDisk.\n"
            "Re-run: ./Scripts/benchmark-daisydisk-auto.sh --check"
        )
        return 1
    lazy = OUT_DIR / "latest-lazydisk.json"
    if lazy.is_file():
        print(f"  latest-lazydisk.json: OK ({json.load(lazy.open())['scanRoot']})")
    else:
        print("  latest-lazydisk.json: missing (run benchmark-native-scan.sh first)")
    print("\nPreflight passed. Run without --check to benchmark.")
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] in ("--check", "-c", "check"):
        return run_preflight()

    if not daisy_disk_installed():
        print("DaisyDisk not found at /Applications/DaisyDisk.app", file=sys.stderr)
        return 1

    if not accessibility_ok():
        print(
            "Enable Accessibility for this terminal:\n"
            "  System Settings → Privacy & Security → Accessibility\n"
            "  Add Terminal or Cursor and toggle ON.\n"
            "Also allow Automation for DaisyDisk if prompted.\n"
            "Run: ./Scripts/benchmark-daisydisk-auto.sh --check",
            file=sys.stderr,
        )
        open_accessibility_settings()
        return 1

    auto_ok, detail = daisy_disk_automation_ok()
    if not auto_ok:
        print(f"DaisyDisk automation check failed: {detail}", file=sys.stderr)
        return 1

    scan_root = (
        Path(sys.argv[1]).expanduser().resolve().as_posix()
        if len(sys.argv) > 1
        else load_lazy_scan_root()
    )
    nav_steps = int(
        __import__("os").environ.get("LAZYDISK_BENCHMARK_NAV_STEPS", "20")
    )

    print(f"Scan root: {scan_root}")
    print("Quitting LazyDisk if running…")
    quit_app("LazyDisk")

    print("Opening DaisyDisk…")
    open_scan_root(scan_root)

    print("Starting Rescan (Action → Rescan)…")
    ready_start = time.monotonic()
    activate_rescan()

    print("Waiting for scan to finish (CPU idle heuristic)…")
    try:
        ready_seconds = wait_until_scan_idle()
    except TimeoutError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(f"Gated ready: {ready_seconds:.2f}s")

    print(f"Navigation: {nav_steps} double-clicks on chart…")
    nav_records, nav_total = run_navigation(nav_steps)
    print(f"Navigation total: {nav_total:.3f}s")

    daisy_path = write_daisy_json(
        scan_root=scan_root,
        ready_seconds=ready_seconds,
        nav_steps=nav_steps,
        nav_total=nav_total,
        nav_records=nav_records,
        notes="automated via Scripts/benchmark-daisydisk-auto.py",
    )
    print(f"Wrote {daisy_path}")

    lazy_json = OUT_DIR / "latest-lazydisk.json"
    if lazy_json.is_file():
        subprocess.run(
            [sys.executable, str(ROOT / "Scripts/benchmark-compare.py"), str(lazy_json), str(daisy_path)],
            check=False,
        )
        stamp = daisy_path.stem.replace("daisydisk-auto-", "")
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "Scripts/benchmark-report.py"),
                str(lazy_json),
                "--daisy-json",
                str(daisy_path),
                "--out-dir",
                str(OUT_DIR),
                "--basename",
                f"report-compare-auto-{stamp}",
            ],
            check=False,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
