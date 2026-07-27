#!/usr/bin/env python3
"""Time each checker over a target dir, cold then warm, median of N.

  python bench_run.py <target_dir> [--runs 3]

'cold' clears each tool's own cache first (.mypy_cache etc.); 'warm' is an
immediate re-run. Emits a small summary table — NOT per-iteration raw arrays
(the repo size gate forbids raw dumps; results.json keeps the medians).
"""
import argparse
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

# Commands assume the four tools are on PATH / resolvable (see run.sh).
TOOLS = {
    "ty":      ["ty", "check"],
    "pyrefly": ["pyrefly", "check"],
    "mypy":    ["mypy"],
    "pyright": ["npx", "pyright"],
}


def clear_caches(target: Path) -> None:
    for c in (".mypy_cache", ".pyrefly_cache", "__pycache__"):
        shutil.rmtree(target / c, ignore_errors=True)
        shutil.rmtree(Path.cwd() / c, ignore_errors=True)


def timed(cmd: list[str], target: Path) -> float:
    t0 = time.perf_counter()
    subprocess.run(cmd + [str(target)], capture_output=True)
    return time.perf_counter() - t0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", type=Path)
    ap.add_argument("--runs", type=int, default=3)
    args = ap.parse_args()

    print(f"{'tool':10} {'cold':>8} {'warm':>8}")
    for name, cmd in TOOLS.items():
        if shutil.which(cmd[0]) is None:
            print(f"{name:10} {'(missing)':>8}")
            continue
        clear_caches(args.target)
        cold = timed(cmd, args.target)              # first run, no cache
        warm = statistics.median(timed(cmd, args.target) for _ in range(args.runs))
        print(f"{name:10} {cold:8.2f} {warm:8.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
