#!/usr/bin/env python3
"""
Firsthand probe for Polars' new streaming engine (Polars 1.42.1).

NOTE (freshness correction vs the original in-session docstring): the new streaming
engine is NOT the default and was not "stabilized in 1.41" — it is opt-in via
collect(engine="streaming") and still evolving (tracking issue pola-rs/polars#20947).
This comment is the only edit vs the harness as executed; all code is verbatim.

Each measurement runs as its own `python probe.py <mode>` subprocess so peak memory is
isolated per engine. On Windows we read the true peak working set (psutil peak_wset);
elsewhere we fall back to peak RSS sampled by the parent.

Modes:
  gen                       generate the synthetic Parquet dataset (idempotent)
  measure <engine>          run the group-by query with engine in {streaming,in-memory}, print JSON
  pandas                    run the same group-by via pandas (loads all rows), print JSON
  limits                    probe which ops the streaming engine runs vs falls back / errors, print JSON
  equal                     assert streaming and in-memory produce identical results, print JSON

The query and data are deterministic (fixed seed), so results reproduce on a pinned Polars.
"""
import os, sys, json, time

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.environ.get("POLARS_DEMO_DATA", os.path.join(HERE, "..", "..", "..", "..", "..",
                                                        "..", "tmp", "firsthand-polars", "big.parquet"))
DATA = os.path.abspath(DATA)

N_ROWS = int(os.environ.get("POLARS_DEMO_ROWS", "30000000"))   # 30M rows
N_GROUPS = 2000
SEED = 42


def peak_mem_mb():
    """Peak working set (MB). Windows: psutil peak_wset (true peak). Else: current RSS."""
    import psutil
    p = psutil.Process()
    mi = p.memory_info()
    val = getattr(mi, "peak_wset", None)
    if val is None:
        val = mi.rss
    return round(val / (1024 * 1024), 1)


def gen():
    import polars as pl
    if os.path.exists(DATA):
        sz = round(os.path.getsize(DATA) / (1024 * 1024), 1)
        print(json.dumps({"mode": "gen", "status": "exists", "path": DATA, "size_mb": sz}))
        return
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    # Deterministic synthetic data: an int64 key (2000 groups), a category, a float value.
    # Built as a lazy range so generation itself does not materialize N_ROWS in Python.
    lf = (
        pl.select(pl.int_range(0, N_ROWS, dtype=pl.Int64).alias("id"))
        .lazy()
        .with_columns(
            (pl.col("id") % N_GROUPS).alias("key"),
            (pl.col("id") % 7).alias("cat"),
            # value: cheap deterministic pseudo-random-ish float, fully reproducible
            (((pl.col("id") * 2654435761) % 1000003) / 1000.0).alias("val"),
        )
    )
    lf.sink_parquet(DATA)   # streaming write — never materializes all rows at once
    sz = round(os.path.getsize(DATA) / (1024 * 1024), 1)
    print(json.dumps({"mode": "gen", "status": "created", "path": DATA,
                      "rows": N_ROWS, "groups": N_GROUPS, "size_mb": sz}))


def _query(pl):
    return (
        pl.scan_parquet(DATA)
        .group_by("key")
        .agg(
            pl.len().alias("n"),
            pl.col("val").sum().alias("val_sum"),
            pl.col("val").mean().alias("val_mean"),
            pl.col("val").max().alias("val_max"),
        )
        .sort("key")
    )


def measure(engine):
    import polars as pl
    t0 = time.perf_counter()
    res = _query(pl).collect(engine=engine)
    dt = round(time.perf_counter() - t0, 2)
    print(json.dumps({
        "mode": "measure", "engine": engine,
        "rows_out": res.height, "seconds": dt, "peak_mem_mb": peak_mem_mb(),
        "checksum": round(float(res["val_sum"].sum()), 3),
    }))


def pandas_run():
    import pandas as pd
    t0 = time.perf_counter()
    df = pd.read_parquet(DATA)   # pandas must load the whole thing into RAM
    g = df.groupby("key")["val"].agg(["size", "sum", "mean", "max"]).reset_index().sort_values("key")
    dt = round(time.perf_counter() - t0, 2)
    print(json.dumps({
        "mode": "pandas", "rows_out": int(g.shape[0]), "seconds": dt,
        "peak_mem_mb": peak_mem_mb(), "checksum": round(float(g["sum"].sum()), 3),
    }))


def equal():
    import polars as pl
    a = _query(pl).collect(engine="streaming")
    b = _query(pl).collect(engine="in-memory")
    print(json.dumps({"mode": "equal", "streaming_equals_in_memory": a.equals(b),
                      "rows_out": a.height}))


OPS = {
    # baseline: partial-aggregate group-by — the streaming engine's sweet spot
    "group_by_sum": lambda pl: pl.scan_parquet(DATA).group_by("key").agg(pl.col("val").sum()),
    # large-left / small-right equi-join then aggregate
    "equi_join": lambda pl: (
        pl.scan_parquet(DATA).join(
            pl.LazyFrame({"key": list(range(N_GROUPS)),
                          "label": ["g" + str(i) for i in range(N_GROUPS)]}),
            on="key", how="inner").group_by("label").agg(pl.col("val").mean())),
    # window / over expression (a classic streaming stressor — needs per-group state)
    "window_over": lambda pl: pl.scan_parquet(DATA).select(
        pl.col("val"), pl.col("val").mean().over("key").alias("grp_mean")),
    # cumulative sum over the whole frame (inherently sequential, whole-column state)
    "cum_sum": lambda pl: pl.scan_parquet(DATA).select(pl.col("val").cum_sum().alias("c")),
    # rank within a group
    "rank_over": lambda pl: pl.scan_parquet(DATA).select(pl.col("val").rank().over("key").alias("r")),
    # sort the entire large frame (bounded-memory sort is the hard case)
    "full_sort": lambda pl: pl.scan_parquet(DATA).sort("val"),
}


def limits():
    """Probe every op under engine='streaming'. Record: ran (+ rows), or raised (+ error head)."""
    import polars as pl
    out = []
    for name, build in OPS.items():
        rec = {"op": name}
        try:
            df = build(pl).collect(engine="streaming")
            rec["result"] = "ran"
            rec["rows_out"] = df.height
        except Exception as e:
            rec["result"] = "raised"
            rec["error_type"] = type(e).__name__
            rec["error_head"] = " ".join(str(e).split())[:180]
        out.append(rec)
    print(json.dumps({"mode": "limits", "polars": pl.__version__, "probes": out}))


def measop(name, engine):
    """Measure peak memory + time for one named op under one engine (own process)."""
    import polars as pl
    build = OPS[name]
    t0 = time.perf_counter()
    df = build(pl).collect(engine=engine)
    dt = round(time.perf_counter() - t0, 2)
    print(json.dumps({"mode": "measop", "op": name, "engine": engine,
                      "rows_out": df.height, "seconds": dt, "peak_mem_mb": peak_mem_mb()}))


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "gen"
    if mode == "gen":
        gen()
    elif mode == "measure":
        measure(sys.argv[2])
    elif mode == "pandas":
        pandas_run()
    elif mode == "equal":
        equal()
    elif mode == "limits":
        limits()
    elif mode == "measop":
        measop(sys.argv[2], sys.argv[3])
    else:
        print(json.dumps({"error": "unknown mode", "mode": mode}))
        sys.exit(2)
