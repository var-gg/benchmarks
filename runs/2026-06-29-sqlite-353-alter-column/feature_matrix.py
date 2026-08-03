#!/usr/bin/env python3
"""Version bisect: which SQLite build first accepts ALTER TABLE ... ALTER COLUMN.

Runs the four ALTER COLUMN operations against 6 pinned sqlite3.exe builds on an
in-memory database and records OK/ERR per (version, feature). Deterministic:
no network, no data, no timing -- purely "does this build accept this DDL".

Each feature is set up so preconditions are satisfied on a *supporting* build,
so a non-zero exit == the grammar is absent (older builds emit "syntax error").
"""
import json
import subprocess
import sys
from pathlib import Path

BIN = Path(__file__).parent / "bin"
VERSIONS = ["3.48.0", "3.49.0", "3.50.0", "3.51.0", "3.52.0", "3.53.0"]


def exe_for(v: str) -> Path:
    """Locate the pinned binary run.sh laid down (sqlite3-<ver>[.exe])."""
    for cand in (BIN / f"sqlite3-{v}.exe", BIN / f"sqlite3-{v}"):
        if cand.exists():
            return cand
    raise FileNotFoundError(f"missing bin/sqlite3-{v}[.exe] -- run ./run.sh first")

# (setup schema, DDL under test) -- setup succeeds everywhere; DDL only on 3.52+
FEATURES = {
    "SET NOT NULL": (
        "CREATE TABLE t(id INTEGER PRIMARY KEY, age INTEGER);",
        "ALTER TABLE t ALTER COLUMN age SET NOT NULL;",
    ),
    "DROP NOT NULL": (
        "CREATE TABLE t(id INTEGER PRIMARY KEY, email TEXT NOT NULL);",
        "ALTER TABLE t ALTER COLUMN email DROP NOT NULL;",
    ),
    "ADD CHECK": (
        "CREATE TABLE t(id INTEGER PRIMARY KEY, age INTEGER);",
        "ALTER TABLE t ADD CONSTRAINT age_nonneg CHECK(age >= 0);",
    ),
    "DROP CONSTRAINT": (
        "CREATE TABLE t(id INTEGER PRIMARY KEY, age INTEGER, CONSTRAINT age_ck CHECK(age >= 0));",
        "ALTER TABLE t DROP CONSTRAINT age_ck;",
    ),
}


def run_sql(exe: Path, sql: str):
    p = subprocess.run(
        [str(exe), ":memory:"],
        input=sql, capture_output=True, text=True, timeout=30,
    )
    return p.returncode, (p.stderr or "").strip()


def main():
    detail = {}
    for v in VERSIONS:
        exe = exe_for(v)
        row = {}
        for name, (setup, ddl) in FEATURES.items():
            rc, err = run_sql(exe, setup + "\n" + ddl)
            row[name] = {
                "ok": rc == 0,
                "syntax_error": "syntax error" in err.lower(),
                "stderr": err[:160],
            }
        detail[v] = row

    grid = {v: {f: ("OK" if detail[v][f]["ok"] else "ERR") for f in FEATURES} for v in VERSIONS}
    out = {"grid": grid, "detail": detail, "features": list(FEATURES)}
    print(json.dumps(out, indent=2))
    return out


if __name__ == "__main__":
    main()
