#!/usr/bin/env python3
"""Deterministic behavioral experiments for SQLite ALTER COLUMN NOT NULL / CHECK.

All experiments are on small in-memory / temp databases, no timing, so they
reproduce byte-for-byte on any machine. Timing / large-table experiments from
the original 2026-06-25 run (3M/5M rows) are hardware-specific and are NOT
re-measured here -- see results.json "not_measured".
"""
import json
import subprocess
import tempfile
from pathlib import Path

BIN = Path(__file__).parent / "bin"


def exe_for(v: str) -> Path:
    """Locate the pinned binary run.sh laid down (sqlite3-<ver>[.exe])."""
    for cand in (BIN / f"sqlite3-{v}.exe", BIN / f"sqlite3-{v}"):
        if cand.exists():
            return cand
    raise FileNotFoundError(f"missing bin/sqlite3-{v}[.exe] -- run ./run.sh first")


V352 = exe_for("3.52.0")
V351 = exe_for("3.51.0")


def sql(exe, statements, db=":memory:"):
    p = subprocess.run([str(exe), db], input=statements,
                       capture_output=True, text=True, timeout=30)
    return p.returncode, (p.stdout or "").strip(), (p.stderr or "").strip()


def exp_atomic_rejection():
    """SET NOT NULL on a column that has a NULL row is rejected atomically:
    the offending row survives and the schema is unchanged."""
    script = """
CREATE TABLE t(id INTEGER PRIMARY KEY, email TEXT);
INSERT INTO t VALUES (1,'a@x'),(2,NULL),(3,'c@x');
ALTER TABLE t ALTER COLUMN email SET NOT NULL;
SELECT '--after--';
SELECT count(*) FROM t WHERE email IS NULL;
SELECT sql FROM sqlite_master WHERE name='t';
"""
    rc, out, err = sql(V352, script)
    rejected = rc != 0 or "constraint failed" in err.lower()
    null_rows_kept = "\n1" in ("\n" + out) or out.strip().endswith("1")
    schema_unchanged = "NOT NULL" not in out  # ALTER did not apply
    return {
        "rejected": rejected,
        "stderr": err[:120],
        "null_row_survived": null_rows_kept,
        "schema_unchanged": schema_unchanged,
    }


def exp_rollback():
    """DDL inside a transaction can be rolled back."""
    script = """
CREATE TABLE t(id INTEGER PRIMARY KEY, email TEXT);
BEGIN;
ALTER TABLE t ALTER COLUMN email SET NOT NULL;
ROLLBACK;
SELECT sql FROM sqlite_master WHERE name='t';
"""
    rc, out, err = sql(V352, script)
    return {"rc": rc, "reverted": "NOT NULL" not in out, "schema": out}


def exp_backward_compat():
    """A NOT NULL added via 3.52 ALTER is enforced by 3.51 (no ALTER grammar).
    Proves it is an ordinary NOT NULL constraint, not a new on-disk format."""
    with tempfile.TemporaryDirectory() as d:
        db = str(Path(d) / "bc.db")
        rc1, _, e1 = sql(V352,
            "CREATE TABLE t(id INTEGER PRIMARY KEY, email TEXT);"
            "ALTER TABLE t ALTER COLUMN email SET NOT NULL;", db=db)
        # 3.51 reads schema + rejects a NULL insert
        rc2, out2, e2 = sql(V351,
            "SELECT sql FROM sqlite_master WHERE name='t';"
            "INSERT INTO t VALUES (1, NULL);", db=db)
        rc3, out3, _ = sql(V351, "PRAGMA integrity_check;", db=db)
    return {
        "created_by_352": rc1 == 0,
        "351_sees_not_null": "NOT NULL" in out2,
        "351_rejects_null_insert": rc2 != 0 and "not null" in (e2.lower()),
        "351_reject_stderr": e2[:120],
        "integrity_ok": out3.strip() == "ok",
    }


def exp_limits():
    """What ALTER COLUMN still refuses (syntax errors) on 3.52 -- the honest
    boundary vs Postgres."""
    cases = {
        "SET DEFAULT":   "ALTER TABLE t ALTER COLUMN age SET DEFAULT 0;",
        "SET DATA TYPE": "ALTER TABLE t ALTER COLUMN age SET DATA TYPE REAL;",
        "ADD UNIQUE":    "ALTER TABLE t ADD CONSTRAINT u UNIQUE(age);",
        "ADD PRIMARY KEY": "ALTER TABLE t ADD CONSTRAINT pk PRIMARY KEY(age);",
        "ADD FOREIGN KEY": "ALTER TABLE t ADD CONSTRAINT fk FOREIGN KEY(age) REFERENCES t(id);",
    }
    base = "CREATE TABLE t(id INTEGER PRIMARY KEY, age INTEGER);\n"
    res = {}
    for name, ddl in cases.items():
        rc, out, err = sql(V352, base + ddl)
        res[name] = {"rejected": rc != 0, "syntax_error": "syntax error" in err.lower(),
                     "stderr": err[:100]}
    return res


def main():
    out = {
        "atomic_rejection_exp2": exp_atomic_rejection(),
        "rollback_exp6": exp_rollback(),
        "backward_compat_exp8": exp_backward_compat(),
        "limits_exp10": exp_limits(),
    }
    print(json.dumps(out, indent=2))
    return out


if __name__ == "__main__":
    main()
