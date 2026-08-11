# -*- coding: utf-8 -*-
# Runs UNDER each target interpreter (CPython 3.14.x or 3.15.x, Windows amd64).
# Reports that interpreter's DEFAULT text-encoding contract and the outcome of
# several deterministic encoding experiments from the var.gg essay.
#
# All output is emitted as UTF-8 *bytes* via sys.stdout.buffer, so the very
# encoding difference under test cannot corrupt the report itself.
import sys, os, json, subprocess, tempfile
import locale

result = {}
result["version"] = sys.version.split()[0]
result["utf8_mode"] = getattr(sys.flags, "utf8_mode", None)
result["getpreferredencoding"] = locale.getpreferredencoding(False)
result["stdout_encoding"] = sys.stdout.encoding
result["getfilesystemencoding"] = sys.getfilesystemencoding()

# EXP2 — same source text, default open() (no encoding=), on-disk bytes.
with tempfile.TemporaryDirectory() as td:
    p = os.path.join(td, "exp2.txt")
    with open(p, "w") as f:                       # default text encoding
        f.write("한글 데이터: 매출 1234원")  # "한글 데이터: 매출 1234원"
    data = open(p, "rb").read()
    result["exp2_write_default"] = {"n_bytes": len(data), "hex": data.hex(" ")}


def read_default(td, name, raw):
    """Write fixed bytes, read back with the DEFAULT text encoding. Records
    whether the read raised, and if not, exactly what string it produced."""
    p = os.path.join(td, name)
    with open(p, "wb") as f:
        f.write(raw)
    try:
        with open(p) as f:                        # default text encoding
            return {"ok": True, "text": f.read()}
    except UnicodeDecodeError as e:
        return {"ok": False, "error": "%s: %s" % (type(e).__name__, e)}

# EXP9 / S2 — silent divergence: the SAME on-disk bytes decode without error
# to DIFFERENT strings depending on the default text encoding.
with tempfile.TemporaryDirectory() as td:
    # '짱'.encode('cp949')  == b'\xc2\xaf'  (also valid UTF-8 -> U+00AF '¯')
    result["s2_bytes_c2af"] = read_default(td, "a.bin", b"\xc2\xaf")
    # '문서'.encode('utf-8') == b'\xeb\xac\xb8\xec\x84\x9c' (also valid CP949)
    result["s2_bytes_munseo"] = read_default(td, "b.bin", b"\xeb\xac\xb8\xec\x84\x9c")

# EXP7 — subprocess(text=True) capturing a child that emits fixed CP949 bytes.
# The parent's reader decodes with the default text encoding:
#   3.14 (cp949) -> decodes fine, stdout returned intact.
#   3.15 (utf-8) -> the reader THREAD raises UnicodeDecodeError on the cp949
#                   bytes; the traceback lands on the PARENT's stderr and
#                   subprocess.run returns stdout=None (rc still 0). The captured
#                   output is silently lost, not raised to the caller.
# Child source is pure ASCII (hex literal) so it is encoding-neutral. The bytes
# c7d1 b1db bbf3 c5c2 are '한글상태' in CP949.
child = ("import sys;sys.stdout.buffer.write("
         "bytes.fromhex('c7d1b1dbbbf3c5c2'));sys.stdout.buffer.flush()")
exp7 = {}
# The decode failure happens in subprocess's daemon reader THREAD, whose default
# excepthook writes the traceback to the parent's sys.stderr — not to the child's
# captured pipe. Redirect sys.stderr to capture it deterministically. run()'s
# communicate() joins the reader thread before returning, so by return time the
# traceback (if any) is already written.
import io as _io, contextlib as _ctx
_cap = _io.StringIO()
try:
    with _ctx.redirect_stderr(_cap):
        cp = subprocess.run([sys.executable, "-c", child],
                            capture_output=True, text=True, timeout=60)
    parent_stderr = _cap.getvalue()
    exp7 = {
        "raised_to_caller": False,
        "returncode": cp.returncode,
        "stdout_repr": repr(cp.stdout),
        "stdout_lost": (cp.stdout is None),        # None (not '') == reader thread died
        "reader_thread_decode_error": ("UnicodeDecodeError" in parent_stderr),
        "reader_thread_error_line": next(
            (ln.strip() for ln in parent_stderr.splitlines() if "Error" in ln), None),
    }
except UnicodeDecodeError as e:
    exp7 = {"raised_to_caller": True, "error": "%s: %s" % (type(e).__name__, e)}
except Exception as e:  # noqa: BLE001 - report any failure faithfully
    exp7 = {"raised_to_caller": True, "error": "%s: %s" % (type(e).__name__, e)}
result["exp7_subprocess_text"] = exp7

sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))
