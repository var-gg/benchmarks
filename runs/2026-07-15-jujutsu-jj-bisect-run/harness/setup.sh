#!/usr/bin/env bash
#
# Reproduce the jj (Jujutsu) 0.43.0 firsthand demo: build a linear history with a
# planted off-by-one bug in mean(), then let `jj bisect run` binary-search for the
# first bad commit automatically. Also exercises `jj file search` and shows git
# colocation (plain `git log` sees the jj commits).
#
# Usage:
#   JJ=/path/to/jj.exe  ./setup.sh /short/path/workdir
#
# NOTE: on Windows use a SHORT working path — jj's index segment filenames are
# ~128 chars and a long parent path overflows MAX_PATH (260).
#
set -euo pipefail
JJ="${JJ:?set JJ to the jj binary (pinned v0.43.0)}"
WORK="${1:?usage: setup.sh <short-work-dir>}"

export JJ_CONFIG="$WORK/jjconfig.toml"
mkdir -p "$WORK"
cat > "$JJ_CONFIG" <<'TOML'
[user]
name = "var.gg demo"
email = "demo@var.gg"
[ui]
color = "never"
paginate = "never"
TOML

DEMO="$WORK/demo"; rm -rf "$DEMO"; mkdir -p "$DEMO"; cd "$DEMO"
"$JJ" git init --colocate

# c1: correct mean()
cat > stats.py <<'PY'
def mean(xs):
    return sum(xs) / len(xs)
PY
"$JJ" bookmark create base -r @
"$JJ" commit -m "feat: add mean()"
# c2: unrelated total()
printf '\ndef total(xs):\n    return sum(xs)\n' >> stats.py
"$JJ" commit -m "feat: add total()"
# c3: unrelated median()
printf '\ndef median(xs):\n    s = sorted(xs)\n    return s[len(s)//2]\n' >> stats.py
"$JJ" commit -m "feat: add median()"
# c4: PLANT THE BUG in mean() (off-by-one: divide by len-1)
python - <<'PY'
src=open("stats.py").read()
src=src.replace("    return sum(xs) / len(xs)",
                "    # off-by-one: divides by len-1\n    return sum(xs) / (len(xs) - 1)")
open("stats.py","w").write(src)
PY
"$JJ" commit -m "refactor: tweak mean() internals"
# c5: unrelated variance()
printf '\ndef variance(xs):\n    m = mean(xs)\n    return sum((x-m)**2 for x in xs) / len(xs)\n' >> stats.py
"$JJ" commit -m "feat: add variance()"
# c6: unrelated docstring
python - <<'PY'
src=open("stats.py").read(); open("stats.py","w").write('"""tiny stats lib."""\n'+src)
PY
"$JJ" commit -m "docs: module docstring"
# c7: unrelated minmax()
printf '\ndef minmax(xs):\n    return (min(xs), max(xs))\n' >> stats.py
"$JJ" commit -m "feat: add minmax()"

# put the working copy on the last real commit
"$JJ" edit "$("$JJ" log -r '@-' --no-graph -T 'change_id.shortest(8)')"

echo "=== history ==="
"$JJ" log -r 'base::@' --no-graph -T 'change_id.shortest(4) ++ "  " ++ description.first_line() ++ "\n"'

echo "=== jj bisect run (the test: mean([2,4,6]) must equal 4) ==="
"$JJ" bisect run --range 'base..@' -- \
  python -B -c "import stats,sys; sys.exit(0 if stats.mean([2.0,4.0,6.0])==4.0 else 1)"

echo "=== jj file search: variance exists at @ but NOT at the median commit (searches the tree of any revision, no checkout) ==="
"$JJ" file search --pattern 'variance' || true
"$JJ" file search --pattern 'variance' -r 'base+2' || true   # before variance was added

echo "=== git colocation: plain git sees the same commits ==="
git log --oneline -3
