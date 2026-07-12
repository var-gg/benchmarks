#!/usr/bin/env python3
"""Firsthand: test CSS anchor positioning support across Chromium/Firefox/WebKit
via Playwright, and screenshot the Chromium render. Evidence for the essay."""
import json, sys
from pathlib import Path
from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
DEMO = (HERE / "demo.html").resolve().as_uri()

PROPS = {
    "anchor-name": "anchor-name: --x",
    "position-anchor": "position-anchor: --x",
    "anchor()": "top: anchor(bottom)",
    "position-area": "position-area: top",
    "anchor-size()": "width: anchor-size(width)",
    "@position-try(try-fallbacks)": "position-try-fallbacks: --y",
    "position-visibility": "position-visibility: anchors-visible",
}

JS = "(props) => Object.fromEntries(Object.entries(props).map(([k,v]) => [k, CSS.supports(v)]))"

def run():
    out = {}
    with sync_playwright() as p:
        for name, launcher in (("chromium", p.chromium), ("firefox", p.firefox), ("webkit", p.webkit)):
            try:
                b = launcher.launch(headless=True)
                ver = b.version
                pg = b.new_page(viewport={"width": 900, "height": 640})
                pg.goto(DEMO)
                pg.wait_for_timeout(500)
                supports = pg.evaluate(JS, PROPS)
                footer = pg.inner_text("#support")
                if name == "chromium":
                    pg.screenshot(path=str(HERE / "render-chromium.png"))
                out[name] = {"version": ver, "supports": supports, "footer": footer}
                b.close()
            except Exception as e:
                out[name] = {"error": repr(e)}
    (HERE / "probe-result.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print("wrote probe-result.json")

if __name__ == "__main__":
    run()
