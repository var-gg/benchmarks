#!/usr/bin/env python3
"""
probe.py - firsthand check of the MCP 2026-07-28 spec's "goes stateless" claim,
verified against the protocol's OWN machine-readable schema.json (not a press summary).

It compares two published schemas:
  - 2025-11-25  (previous stable protocol revision)
  - draft       (the 2026-07-28 release candidate snapshot)

and asserts, symbol by symbol, that the JSON-RPC types the changelog says were
REMOVED are gone and the ones it says were ADDED are present. Deterministic:
schema $defs membership, no timing, no model interpretation.

Usage:
    python probe.py                 # uses committed schema-*.json snapshots
    python probe.py --fetch         # re-fetch both schemas from github raw first

Output: probe-result.json
"""
import argparse
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OLD_FILE = os.path.join(HERE, "schema-2025-11-25.json")
NEW_FILE = os.path.join(HERE, "schema-draft.json")

RAW = "https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema"
OLD_URL = f"{RAW}/2025-11-25/schema.json"
NEW_URL = f"{RAW}/draft/schema.json"

# Each assertion ties a changelog claim to a concrete schema $defs symbol.
# ("symbol", "expected_in_old", "expected_in_new", "changelog claim")
ASSERTIONS = [
    # --- statelessness: handshake + session removed ---
    ("InitializeRequest",        True,  False, "initialize handshake removed (SEP-2575)"),
    ("InitializedNotification",  True,  False, "notifications/initialized removed (SEP-2575)"),
    ("PingRequest",              True,  False, "ping removed (SEP-2575)"),
    ("SetLevelRequest",          True,  False, "logging/setLevel removed; logLevel now per-request _meta"),
    ("SubscribeRequest",         True,  False, "resources/subscribe replaced by subscriptions/listen"),
    ("UnsubscribeRequest",       True,  False, "resources/unsubscribe replaced by subscriptions/listen"),
    ("RootsListChangedNotification", True, False, "notifications/roots/list_changed removed"),
    ("ServerRequest",            True,  False, "server-initiated requests replaced by MRTR (SEP-2322)"),
    # --- Tasks moved out of core into an extension ---
    ("CreateTaskResult",         True,  False, "Tasks moved to io.modelcontextprotocol/tasks extension (SEP-2663)"),
    ("ListTasksRequest",         True,  False, "tasks/list removed; Tasks now an extension"),
    ("GetTaskRequest",           True,  False, "core task RPCs moved to extension"),
    ("Task",                     True,  False, "core Task type moved to extension"),
    # --- new stateless machinery added ---
    ("DiscoverRequest",          False, True,  "server/discover added for up-front version negotiation (SEP-2575)"),
    ("DiscoverResult",           False, True,  "server/discover result added (SEP-2575)"),
    ("CacheableResult",          False, True,  "ttlMs/cacheScope cacheability added (SEP-2549)"),
    ("SubscriptionsListenRequest", False, True, "single subscriptions/listen stream added (SEP-2575)"),
    ("InputRequiredResult",      False, True,  "Multi Round-Trip Requests result added (SEP-2322)"),
    ("ResultType",               False, True,  "required resultType field added (SEP-2322)"),
    ("UnsupportedProtocolVersionError", False, True, "version-mismatch error added (SEP-2575)"),
    ("HeaderMismatchError",      False, True,  "Mcp-Method/Mcp-Name header enforcement error (SEP-2243)"),
]


def load(path, url, do_fetch):
    if do_fetch or not os.path.exists(path):
        print(f"==> fetching {url}", file=sys.stderr)
        with urllib.request.urlopen(url, timeout=30) as r:
            data = r.read().decode("utf-8")
        with open(path, "w", encoding="utf-8") as f:
            f.write(data)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fetch", action="store_true", help="re-fetch schemas before probing")
    args = ap.parse_args()

    old = load(OLD_FILE, OLD_URL, args.fetch)
    new = load(NEW_FILE, NEW_URL, args.fetch)
    o = set(old["$defs"].keys())
    n = set(new["$defs"].keys())

    checks = []
    passed = 0
    for sym, in_old, in_new, claim in ASSERTIONS:
        got_old = sym in o
        got_new = sym in n
        ok = (got_old == in_old) and (got_new == in_new)
        passed += ok
        checks.append({
            "symbol": sym,
            "claim": claim,
            "expected": {"in_2025_11_25": in_old, "in_draft": in_new},
            "observed": {"in_2025_11_25": got_old, "in_draft": got_new},
            "pass": ok,
        })

    result = {
        "probe": "mcp-2026-07-28-schema-statelessness",
        "measured_at": "2026-07-27",
        "note": "Draft schema is a snapshot of the 2026-07-28 release candidate. The 'draft' path is mutable; re-fetching later pulls whatever is current. Committed schema-draft.json is the 2026-07-27 snapshot.",
        "compared": {
            "old": "2025-11-25",
            "new": "draft (2026-07-28 RC)",
            "old_defs_count": len(o),
            "new_defs_count": len(n),
        },
        "assertions_total": len(ASSERTIONS),
        "assertions_passed": passed,
        "all_passed": passed == len(ASSERTIONS),
        "checks": checks,
        "removed_defs": sorted(o - n),
        "added_defs": sorted(n - o),
    }
    with open(os.path.join(HERE, "probe-result.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"==> {passed}/{len(ASSERTIONS)} assertions passed. Wrote probe-result.json", file=sys.stderr)
    return 0 if passed == len(ASSERTIONS) else 1


if __name__ == "__main__":
    sys.exit(main())
