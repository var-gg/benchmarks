#!/usr/bin/env bash
#
# Reproduce the Astro 7 (Rust compiler / agent-native) firsthand checks.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-09-astro-7-rust-agent-native
#     ./run.sh
#
# What it does: scaffolds a minimal astro@7.0.6 project in ./work, drops the
# fixtures/ files, and runs four deterministic checks:
#   A1  JSX whitespace collapse in .astro output
#   A2  unterminated <p> -> hard CompilerError (build fails, exit 1)
#   B   background dev server lifecycle (start/status/stop, lockfile)
#   C   GFM markdown (table/strikethrough/footnote/task-list) built-in, no plugins
# Writes probe-result.json. Compare it against results.json.
#
# NOTE: this is a compiler-behavior / capability check, not a timing benchmark.
# Build times are machine-dependent and intentionally NOT part of the evidence.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_ASTRO="7.0.6"
WORK="$HERE/work"

echo "==> Scaffolding minimal astro@${EXPECTED_ASTRO} project in ./work"
rm -rf "$WORK"
mkdir -p "$WORK/src/pages"
cd "$WORK"

cat > package.json <<EOF
{
  "name": "astro-7-firsthand-repro",
  "type": "module",
  "version": "0.0.0",
  "private": true,
  "scripts": { "build": "astro build" },
  "dependencies": { "astro": "${EXPECTED_ASTRO}" }
}
EOF
cat > astro.config.mjs <<'EOF'
import { defineConfig } from 'astro/config';
export default defineConfig({});
EOF

echo "==> npm install (pins astro ${EXPECTED_ASTRO}; ~35s, 196 pkgs)"
npm install --no-audit --no-fund --loglevel=error
ASTRO_VER=$(node -e "console.log(require('./node_modules/astro/package.json').version)")
echo "    installed astro ${ASTRO_VER}"

# JSON emit helpers (no jq dependency)
j() { printf '%s' "$1" | python -c "import json,sys;print(json.dumps(sys.stdin.read()))" 2>/dev/null || printf '"%s"' "$1"; }

# ---- EXP A1 + C: build the good fixtures together ----
cp "$HERE/fixtures/index.astro" src/pages/index.astro
cp "$HERE/fixtures/post.md"     src/pages/post.md
echo "==> BUILD 1 (A1 whitespace + C markdown)"
npx astro build >/dev/null 2>&1
A1_HTML=$(grep -o '<p id="ws">.*</p>' dist/index.html | head -1)
A1_COLLAPSED=$([ "$A1_HTML" = '<p id="ws"><span>Hello</span><span>World</span></p>' ] && echo true || echo false)
POST=dist/post/index.html
C_TABLE=$(grep -c '<table' "$POST"); C_DEL=$(grep -c '<del' "$POST")
C_FN=$(grep -c 'footnote-ref\|data-footnote' "$POST"); C_TASK=$(grep -c 'type="checkbox"' "$POST")

# ---- EXP A2: unterminated tag must FAIL the build ----
cp "$HERE/fixtures/broken.astro" src/pages/broken.astro
echo "==> BUILD 2 (A2 broken tag — expect failure)"
A2_OUT=$(npx astro build 2>&1); A2_CODE=$?
A2_ERR=$(printf '%s' "$A2_OUT" | grep -oiE "Expected corresponding JSX closing tag for 'p'" | head -1)
A2_ROLLDOWN=$(printf '%s' "$A2_OUT" | grep -c 'rolldown')
rm -f src/pages/broken.astro

# ---- EXP B: background dev server lifecycle ----
echo "==> EXP B (background dev server)"
B_START=$(npx astro dev --background 2>&1 | head -1)
sleep 2
B_STATUS=$(npx astro dev status 2>&1 | head -1)
B_LOCK=$([ -f .astro/dev.json ] && echo true || echo false)
npx astro dev stop >/dev/null 2>&1
B_STOP2=$(npx astro dev stop 2>&1 | head -1); B_STOP2_CODE=$?

cd "$HERE"
cat > probe-result.json <<EOF
{
  "astro_version": "${ASTRO_VER}",
  "exp_A1_whitespace_collapse": {
    "output_p": ${A1_HTML:+$(j "$A1_HTML")},
    "collapsed_no_space": ${A1_COLLAPSED}
  },
  "exp_A2_unterminated_tag": {
    "build_exit_code": ${A2_CODE},
    "compiler_error_matched": $([ -n "$A2_ERR" ] && echo true || echo false),
    "via_rolldown": $([ "$A2_ROLLDOWN" -gt 0 ] && echo true || echo false)
  },
  "exp_B_background_dev_server": {
    "start_reports_pid": $(printf '%s' "$B_START" | grep -qiE 'pid' && echo true || echo false),
    "status_reports_background": $(printf '%s' "$B_STATUS" | grep -qiE 'background' && echo true || echo false),
    "lockfile_present": ${B_LOCK},
    "stop_when_not_running_exit0": $([ "$B_STOP2_CODE" -eq 0 ] && echo true || echo false)
  },
  "exp_C_gfm_builtin_no_plugins": {
    "table": $([ "$C_TABLE" -gt 0 ] && echo true || echo false),
    "strikethrough_del": $([ "$C_DEL" -gt 0 ] && echo true || echo false),
    "footnote": $([ "$C_FN" -gt 0 ] && echo true || echo false),
    "task_checkbox": $([ "$C_TASK" -gt 0 ] && echo true || echo false)
  }
}
EOF

echo
echo "==> Wrote probe-result.json:"
cat probe-result.json
echo
echo "    Compare against results.json. All boolean checks should be true"
echo "    except exp_A2 which asserts build FAILURE (exit 1) is the correct behavior."
