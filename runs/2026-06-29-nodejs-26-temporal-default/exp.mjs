// Node.js 26 — Temporal (default global) vs legacy Date: behavior probe.
//
// Pure stdlib, no network, no deps. Every check below is a DETERMINISTIC
// language-behavior observation on a given Node build — so this harness
// reproduces the support/behavior matrix the var.gg post claims firsthand.
//
// Run with TZ pinned so the two local-parse observations are reproducible:
//     TZ=Asia/Seoul node exp.mjs
//
// Emits probe-result.json. Compare against the committed results.json.

import { writeFileSync } from "node:fs";
import process from "node:process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const out = {};

// --- environment (self-reported by the running binary) ----------------------
out.environment = {
  node: process.versions.node,
  v8: process.versions.v8,
  undici: process.versions.undici,
  uv: process.versions.uv,
  modules: process.versions.modules, // NODE_MODULE_VERSION
  tz: process.env.TZ ?? "(unset)",
};

// --- 0) Temporal exposed as a global WITHOUT any flag -----------------------
out.temporal_global = typeof globalThis.Temporal !== "undefined";

// --- 1) month index: Date is 0-based, Temporal is 1-based -------------------
{
  const d = new Date(2026, 6, 29); // month arg 6 -> July, not June
  out.month_indexing = {
    date_month_arg_6_is: d.toLocaleString("en-US", { month: "long" }), // "July"
    date_getMonth: d.getMonth(), // 6
    temporal_month_field: Temporal.PlainDate.from({ year: 2026, month: 7, day: 29 }).toString(), // 2026-07-29
  };
}

// --- 2) mutability: Date.setMonth mutates; PlainDate.add is immutable -------
{
  const d = new Date(2026, 6, 29); // 2026-07-29 local
  const before = d.toLocaleDateString("en-CA"); // local YYYY-MM-DD
  d.setMonth(d.getMonth() + 1); // mutates in place -> August
  const after = d.toLocaleDateString("en-CA");

  const pd = Temporal.PlainDate.from("2026-07-29");
  const pd2 = pd.add({ months: 1 }); // returns a NEW value
  out.mutability = {
    date_mutates_in_place: before !== after,
    date_before: before, // 2026-07-29
    date_after: after,   // 2026-08-29
    plaindate_original_preserved: pd.toString() === "2026-07-29",
    plaindate_add_returns_new: pd2.toString(), // 2026-08-29
  };
}

// --- 3) DST arithmetic: America/New_York spring-forward 2026-03-08 ----------
{
  const start = Temporal.ZonedDateTime.from("2026-03-07T12:00-05:00[America/New_York]");
  const plusCalendarDay = start.add({ days: 1 });   // wall clock preserved
  const plusPhysical24h = start.add({ hours: 24 }); // absolute 24h -> overshoots by 1h

  // Legacy Date does pure millisecond math -> DST-unaware, matches physical 24h.
  const legacy = new Date(start.epochMilliseconds + 24 * 60 * 60 * 1000);
  const legacyLocalHourNY = Number(
    new Intl.DateTimeFormat("en-US", {
      timeZone: "America/New_York", hour: "2-digit", hour12: false,
    }).format(legacy),
  );

  out.dst = {
    start: start.toString(),
    plus_calendar_day_hour: plusCalendarDay.hour, // 12 (wall clock kept)
    plus_physical_24h_hour: plusPhysical24h.hour,  // 13 (DST absorbed the extra hour)
    legacy_date_plus_24h_ny_hour: legacyLocalHourNY, // 13 (ms math == physical, calendar-blind)
    calendar_and_physical_diverge: plusCalendarDay.hour !== plusPhysical24h.hour,
  };
}

// --- 4) month-end + 1 month: silent overflow vs constrain vs reject ---------
{
  const d = new Date(2026, 0, 31); // Jan 31 local
  d.setMonth(d.getMonth() + 1);    // Feb has no 31 -> rolls into March
  const dateResult = d.toLocaleDateString("en-CA"); // YYYY-MM-DD, e.g. 2026-03-03

  const constrain = Temporal.PlainDate.from("2026-01-31").add({ months: 1 }); // -> 2026-02-28
  let rejectResult;
  try {
    Temporal.PlainDate.from("2026-01-31", { overflow: "reject" }).add(
      { months: 1 },
      { overflow: "reject" },
    );
    rejectResult = "no error";
  } catch (e) {
    rejectResult = e.constructor.name; // RangeError
  }

  out.month_end_overflow = {
    date_setMonth_rolls_over_to: dateResult,          // 2026-03-03 (skips Feb)
    temporal_constrain_clamps_to: constrain.toString(), // 2026-02-28
    temporal_reject_throws: rejectResult,             // RangeError
  };
}

// --- 5) string parsing: ISO(UTC) vs slash(local) vs Temporal(no tz) ---------
{
  const iso = new Date("2026-06-29");    // ISO date-only -> UTC midnight
  const slash = new Date("2026/06/29");  // non-ISO -> LOCAL midnight
  out.parsing = {
    iso_dash_is_utc_midnight: iso.toISOString(),        // 2026-06-29T00:00:00.000Z
    slash_local_epoch_differs: slash.getTime() !== iso.getTime(),
    slash_utc_string: slash.toISOString(),               // offset by local tz
    temporal_plaindate_has_no_tz:
      Temporal.PlainDate.from("2026-06-29").toString(),  // 2026-06-29, timezone-free by design
  };
}

// --- 6) the four Temporal types are distinct -------------------------------
{
  const names = ["Instant", "PlainDate", "PlainDateTime", "ZonedDateTime"];
  out.types_present = Object.fromEntries(
    names.map((n) => [n, typeof Temporal[n] === "function"]),
  );
}

// --- 7) V8 14.6 bonus: Map.getOrInsert / Iterator.concat -------------------
{
  const m = new Map();
  const goi = typeof m.getOrInsert === "function" && m.getOrInsert("k", 1) === 1;
  const goic =
    typeof m.getOrInsertComputed === "function" &&
    m.getOrInsertComputed("k2", () => 2) === 2;
  const iterConcat = typeof Iterator.concat === "function";
  out.v8_146 = {
    map_getOrInsert: goi,
    map_getOrInsertComputed: goic,
    iterator_concat: iterConcat,
  };
}

// --- 8) removals in Node 26 -------------------------------------------------
{
  const http = require("node:http");
  const writeHeaderGone =
    http.ServerResponse.prototype.writeHeader === undefined;
  let streamWrap;
  try {
    require("_stream_wrap");
    streamWrap = "still present";
  } catch (e) {
    streamWrap = e.code; // MODULE_NOT_FOUND
  }
  out.removals = {
    http_writeHeader_removed: writeHeaderGone,
    _stream_wrap_removed: streamWrap === "MODULE_NOT_FOUND",
    _stream_wrap_error_code: streamWrap,
  };
}

writeFileSync(
  new URL("./probe-result.json", import.meta.url),
  JSON.stringify(out, null, 2) + "\n",
);
console.log(JSON.stringify(out, null, 2));
