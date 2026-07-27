#!/usr/bin/env python3
"""Generate the synthetic, type-CLEAN codebase used for Experiment B (speed).

2000 modules, ~35 lines each -> ~70k lines, all fully annotated and correct so
every checker has to do the full analysis but finds nothing. Uniform + shallow
by design (see results.json 'real_world_heavy_generics' caveat).

  python gen_codebase.py out_dir 2000
"""
import sys
from pathlib import Path

TEMPLATE = '''\
from __future__ import annotations
from dataclasses import dataclass


@dataclass
class Rec{i}:
    a: int
    b: str
    c: float


def make{i}(a: int, b: str) -> Rec{i}:
    return Rec{i}(a=a, b=b, c=float(a))


def total{i}(items: list[Rec{i}]) -> float:
    acc: float = 0.0
    for it in items:
        acc += it.c + len(it.b)
    return acc


def label{i}(r: Rec{i}) -> str:
    return f"{{r.a}}:{{r.b}}:{{r.c:.1f}}"


def run{i}() -> float:
    recs: list[Rec{i}] = [make{i}(k, str(k)) for k in range(10)]
    _ = [label{i}(r) for r in recs]
    return total{i}(recs)
'''


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "synthetic")
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    out.mkdir(parents=True, exist_ok=True)
    lines = 0
    for i in range(n):
        text = TEMPLATE.format(i=i)
        (out / f"mod{i:05d}.py").write_text(text, encoding="utf-8")
        lines += text.count("\n")
    (out / "__init__.py").write_text("", encoding="utf-8")
    print(f"wrote {n} modules, ~{lines} lines to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
