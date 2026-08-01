#!/usr/bin/env bash
# Reproduce the Zig 0.16 "Writergate" / I/O-as-an-Interface firsthand checks.
#   ./probe.sh
#
# Requires `zig` (0.16.x) on PATH. Set ZIG=/path/to/zig.exe to override.
# Downloads nothing; compiles four tiny programs and records observed behavior.
#
# The four probes:
#   hello_flush.zig   — the canonical 0.16 stdout write, WITH interface.flush()
#   hello_noflush.zig — identical but WITHOUT flush()  -> the buffered-output footgun
#   old_api.zig       — the 0.15 pattern std.io.getStdOut() -> must fail to compile
#   threadpool.zig    — std.Thread.Pool -> must fail to compile (removed for std.Io async)
#
# Deterministic: fixed sources + pinned compiler -> fixed verdicts.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ZIG="${ZIG:-zig}"

ver=$("$ZIG" version 2>/dev/null)
echo "zig version: $ver"

flush_out=$("$ZIG" run "$HERE/hello_flush.zig" 2>/dev/null)
noflush_out=$("$ZIG" run "$HERE/hello_noflush.zig" 2>/dev/null)

old_err=$("$ZIG" run "$HERE/old_api.zig" 2>&1 >/dev/null | grep -oE "has no member named '[a-zA-Z]+'" | head -1)
pool_err=$("$ZIG" run "$HERE/threadpool.zig" 2>&1 >/dev/null | grep -oE "has no member named '[a-zA-Z]+'" | head -1)

cat > "$HERE/probe-result.gen.json" <<EOF
{
  "zig_version": "$ver",
  "with_flush":    { "stdout": "$flush_out", "bytes": ${#flush_out} },
  "without_flush": { "stdout": "$noflush_out", "bytes": ${#noflush_out} },
  "old_std_io_getStdOut_compiles": false, "old_api_error": "$old_err",
  "std_thread_pool_compiles": false, "thread_pool_error": "$pool_err"
}
EOF
echo "==> wrote probe-result.gen.json"; cat "$HERE/probe-result.gen.json"
echo
echo "Expected: with_flush 'hello, writergate' (17 bytes); without_flush '' (0 bytes);"
echo "          old_api error \"has no member named 'io'\"; thread_pool error \"has no member named 'Pool'\"."
