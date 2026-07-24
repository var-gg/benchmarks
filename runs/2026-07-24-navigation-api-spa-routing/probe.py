"""
probe.py — firsthand check of the Navigation API across Chromium / Firefox / WebKit.

The Navigation API reached Baseline "newly available" in January 2026, and the pitch
is that it fixes what the History API could never do: see every navigation, read the
whole history stack, and intercept navigations from one place. This probe measures
that instead of quoting it.

Experiments
  1 surface      — which parts of the API each engine actually exposes
  2 observability— for 10 navigation triggers, does `popstate`/`hashchange` fire?
                   does `navigate` fire? (the headline table)
  3 stack        — what each API can tell you about the session history
  4 intercept    — does a navigate+intercept() router actually render, and which
                   triggers report canIntercept=false (cross-origin, hash, download)

Everything runs against two throwaway localhost origins (same-origin A, cross-origin B)
so cross-origin behavior is real, not simulated. Output: probe-result.json.

Usage:  python probe.py [--engines chromium,firefox,webkit] [--out probe-result.json]
"""
from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent

# Each trigger: (name, argument, what it represents to a router author)
TRIGGERS = [
    ("pushState",       None, "programmatic history.pushState (what every SPA router calls)"),
    ("replaceState",    None, "programmatic history.replaceState"),
    ("hash",            None, "fragment navigation (location.hash = '#frag')"),
    ("back",            None, "user pressed Back across documents (traverse)"),
    ("back_after_push", None, "user pressed Back within one document (the case popstate was designed for)"),
    ("nav_navigate",    None, "navigation.navigate() — the new programmatic API"),
    ("anchor_click",    None, "user clicked a same-origin <a>"),
    ("form_get",        None, "a GET form was submitted"),
    ("location_assign", None, "location.assign() to a same-origin URL"),
    ("crossorigin",     "B",  "user clicked a CROSS-ORIGIN link"),
    ("download",        None, "user clicked a <a download> link"),
]


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):  # keep stdout readable
        pass


def serve(directory: Path) -> tuple[ThreadingHTTPServer, int]:
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(directory)))
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd, httpd.server_address[1]


def run_engine(pw, engine: str, origin_a: str, origin_b: str) -> dict:
    out: dict = {"engine": engine}
    browser = getattr(pw, engine).launch()
    out["version"] = browser.version
    ctx = browser.new_context(accept_downloads=True)
    page = ctx.new_page()
    page.on("download", lambda d: None)  # accept and discard
    page.on("dialog", lambda d: d.dismiss())

    base = f"{origin_a}/demo.html"

    # ---------- EXP 1: feature surface ----------
    page.goto(base, wait_until="load")
    out["surface"] = page.evaluate("__surface()")

    # ---------- EXP 2 + 4: observability / canIntercept, one trigger per fresh page ----------
    rows = []
    for name, arg, meaning in TRIGGERS:
        row = {"trigger": name, "meaning": meaning}
        try:
            page.goto(base, wait_until="load")
            page.evaluate("__clearLog()")
            argv = origin_b + "/demo.html" if arg == "B" else None
            kind = page.evaluate("([n,a]) => __trigger(n,a)", [name, argv])
            row["dispatch"] = kind
            if kind == "unsupported":
                row["skipped"] = "navigation object not available in this engine"
                rows.append(row)
                continue
            page.wait_for_timeout(700)  # let cross-document loads settle

            # After a cross-document navigation the log lives in the origin's
            # sessionStorage; come back to the harness page to read it.
            if not page.url.startswith(origin_a) or "demo.html" not in page.url:
                page.goto(base, wait_until="load")
            entries = page.evaluate("__readLog()")
            row["log"] = entries
            row["popstate"] = sum(1 for e in entries if e.get("event") == "popstate")
            row["hashchange"] = sum(1 for e in entries if e.get("event") == "hashchange")
            navs = [e for e in entries if e.get("event") == "navigate"]
            row["navigate"] = len(navs)
            row["history_api_saw_it"] = bool(row["popstate"] or row["hashchange"])
            row["navigation_api_saw_it"] = bool(navs)
            if navs:
                first = navs[0]
                row["navigationType"] = first.get("navigationType")
                row["canIntercept"] = first.get("canIntercept")
                row["hashChange"] = first.get("hashChange")
                row["downloadRequest"] = first.get("downloadRequest")
                row["hasFormData"] = first.get("hasFormData")
        except Exception as exc:  # one bad trigger must not kill the engine run
            row["error"] = f"{type(exc).__name__}: {exc}"[:200]
        rows.append(row)
    out["triggers"] = rows

    # ---------- EXP 3: what can you learn about the history stack? ----------
    # A FRESH context, so history.length reflects only these three pushes instead of
    # accumulating every navigation the trigger sweep just performed.
    ctx3 = browser.new_context()
    page3 = ctx3.new_page()
    page3.goto(base, wait_until="load")
    page3.evaluate("""() => {
        history.pushState({}, '', '/demo.html?a=1');
        history.pushState({}, '', '/demo.html?b=2');
        history.pushState({}, '', '/demo.html?c=3');
    }""")
    out["stack_after_3_pushes"] = page3.evaluate("__stack()")
    ctx3.close()

    # ---------- EXP 4b: does an intercept()-only router actually render? ----------
    spa = {"supported": bool(out["surface"].get("navigation_object"))}
    if spa["supported"]:
        page.goto(f"{base}?mode=spa", wait_until="load")
        page.evaluate("__clearLog()")
        before = page.evaluate("() => document.getElementById('outlet').textContent")
        page.evaluate("() => document.getElementById('link-samedoc').click()")
        page.wait_for_timeout(600)
        spa["outlet_before"] = before
        spa["outlet_after"] = page.evaluate("() => document.getElementById('outlet').textContent")
        spa["url_after"] = page.url.replace(origin_a, "")
        log = page.evaluate("__readLog()")
        spa["handler_ran"] = any(e.get("event") == "intercept.handler-ran" for e in log)
        spa["full_page_reload_avoided"] = spa["outlet_after"] != before and spa["handler_ran"]
    out["spa_intercept"] = spa

    ctx.close()
    browser.close()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--engines", default="chromium,firefox,webkit")
    ap.add_argument("--out", default=str(HERE / "probe-result.json"))
    args = ap.parse_args()

    srv_dir = HERE / "_serve"
    srv_dir.mkdir(exist_ok=True)
    (srv_dir / "demo.html").write_text((HERE / "demo.html").read_text(encoding="utf-8"), encoding="utf-8")
    (srv_dir / "blob.txt").write_text("download probe payload\n", encoding="utf-8")

    srv_a, port_a = serve(srv_dir)
    srv_b, port_b = serve(srv_dir)
    origin_a, origin_b = f"http://127.0.0.1:{port_a}", f"http://localhost:{port_b}"
    print(f"[probe] same-origin A={origin_a}  cross-origin B={origin_b}")

    result = {
        "measured_at": time.strftime("%Y-%m-%d"),
        "origins": {"same_origin": origin_a, "cross_origin": origin_b,
                    "note": "127.0.0.1 vs localhost on different ports = genuinely different origins"},
        "engines": [],
    }
    for engine in args.engines.split(","):
        engine = engine.strip()
        if not engine:
            continue
        print(f"[probe] === {engine} ===")
        try:
            r = run_engine(sync_playwright().start() if False else PW, engine, origin_a, origin_b)
        except Exception as exc:
            r = {"engine": engine, "error": f"{type(exc).__name__}: {exc}"[:300]}
        nav_ok = r.get("surface", {}).get("navigation_object")
        print(f"[probe] {engine} {r.get('version','?')} navigation={nav_ok}")
        result["engines"].append(r)

    srv_a.shutdown()
    srv_b.shutdown()
    Path(args.out).write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[probe] wrote {args.out}")
    return 0


if __name__ == "__main__":
    with sync_playwright() as PW:
        sys.exit(main())
