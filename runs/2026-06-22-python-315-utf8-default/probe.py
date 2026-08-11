# -*- coding: utf-8 -*-
"""Driver for the Python 3.15 UTF-8-default (PEP 686) encoding probe.

Runs `_probe_inner.py` under two pinned interpreters (an old 3.14.x line and a
new 3.15.x line) and merges their reports, plus a small opt-out toggle matrix,
into probe-result.json.

    python probe.py --old <py3.14/python.exe> --new <py3.15/python.exe> \
                    --old-label 3.14.6 --new-label 3.15.0b2 > probe-result.json

The report is deterministic for a given (interpreter build, OS ANSI codepage).
It is meaningful only on Windows with a non-UTF-8 ANSI codepage (the essay used
CP949 / Korean). On a UTF-8 locale both interpreters already default to UTF-8
and the contrast disappears — that is itself the point.
"""
import sys, os, json, subprocess, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
INNER = os.path.join(HERE, "_probe_inner.py")


def _clean_env():
    env = dict(os.environ)
    # Read the *default* contract: strip any inherited explicit override.
    env.pop("PYTHONUTF8", None)
    env.pop("PYTHONIOENCODING", None)
    return env


def run_inner(exe):
    out = subprocess.run([exe, INNER], capture_output=True, env=_clean_env(), timeout=180)
    if out.returncode != 0:
        sys.stderr.write(out.stderr.decode("utf-8", "replace"))
        raise SystemExit("inner probe failed under %s (rc=%d)" % (exe, out.returncode))
    return json.loads(out.stdout.decode("utf-8"))


def run_toggle(exe, extra_env=None, extra_args=None):
    env = _clean_env()
    if extra_env:
        env.update(extra_env)
    args = [exe] + (extra_args or []) + [
        "-c",
        "import sys,locale,json;"
        "print(json.dumps({'utf8_mode':sys.flags.utf8_mode,"
        "'getpreferredencoding':locale.getpreferredencoding(False)}))",
    ]
    out = subprocess.run(args, capture_output=True, env=env, timeout=60)
    return json.loads(out.stdout.decode("utf-8", "replace"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True, help="path to the 3.14.x python executable")
    ap.add_argument("--new", required=True, help="path to the 3.15.x python executable")
    ap.add_argument("--old-label", default="old")
    ap.add_argument("--new-label", default="new")
    args = ap.parse_args()

    report = {
        "generated_by": "probe.py",
        "note": ("Default text-encoding contract + deterministic encoding experiments "
                 "under two pinned CPython builds on Windows. Meaningful only on a "
                 "non-UTF-8 ANSI codepage (essay used CP949)."),
        "host_ansi_codepage_hint": None,
        "interpreters": {
            args.old_label: run_inner(args.old),
            args.new_label: run_inner(args.new),
        },
        "toggle": {
            # 3.15 opting back OUT via env var / -X flag restores the old default.
            "new_PYTHONUTF8_0": run_toggle(args.new, extra_env={"PYTHONUTF8": "0"}),
            "new_X_utf8_0": run_toggle(args.new, extra_args=["-X", "utf8=0"]),
            # 3.14 opting IN previews the 3.15 default.
            "old_PYTHONUTF8_1": run_toggle(args.old, extra_env={"PYTHONUTF8": "1"}),
        },
    }
    try:
        import ctypes
        report["host_ansi_codepage_hint"] = ctypes.windll.kernel32.GetACP()
    except Exception:  # noqa: BLE001 - non-Windows / no ctypes
        pass

    # Emit as UTF-8 bytes: the report contains characters (e.g. U+00AF) that a
    # cp949 stdout cannot encode — the same failure mode this probe documents.
    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    sys.stdout.buffer.write(payload.encode("utf-8"))


if __name__ == "__main__":
    main()
