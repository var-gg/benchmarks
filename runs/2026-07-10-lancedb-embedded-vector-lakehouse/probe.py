#!/usr/bin/env python3
"""Firsthand harness for the LanceDB 0.34.0 essay.

Reproduces the deterministic behaviors the post claims, with NO Docker, NO GPU,
NO network, NO LLM — a local embedded library over local files only:

  EXP B  exact top-k is deterministic, and `_distance` is *squared* L2 (a gotcha)
  EXP D  versioning / time-travel (checkout an old version, then latest)
  EXP E  IVF_PQ ANN trades recall for speed; nprobes/refine_factor tune it back
  EXP F  full-text (BM25) search with zero embeddings

Writes probe-result.json. Compare it against the committed results.json.

Pinned subject: lancedb==0.34.0 (see requirements.txt). API surface used here is
the 0.34.0 one: create_index('col', config=IvfPq(...)) and create_index(config=FTS()).
Earlier create_fts_index / metric= kwargs were deprecated by 0.34.
"""
import json
import shutil
import tempfile
from pathlib import Path

import numpy as np
import pyarrow as pa
import lancedb
from lancedb.index import IvfPq, FTS

HERE = Path(__file__).parent
OUT = HERE / "probe-result.json"


def exp_b_exact_topk(db):
    """Fixed 2D vectors → exact L2 order is deterministic; _distance is squared."""
    rows = [
        {"id": 0, "vector": [1.0, 0.0]},
        {"id": 1, "vector": [0.0, 1.0]},
        {"id": 2, "vector": [0.9, 0.1]},
        {"id": 3, "vector": [-1.0, 0.0]},
    ]
    t = db.create_table("exp_b", data=rows, mode="overwrite")
    res = t.search([1.0, 0.0]).metric("l2").limit(4).to_list()
    pairs = [(r["id"], round(float(r["_distance"]), 4)) for r in res]
    order = [p[0] for p in pairs]
    # run three times to confirm determinism
    same = True
    for _ in range(2):
        order2 = [r["id"] for r in t.search([1.0, 0.0]).metric("l2").limit(4).to_list()]
        same = same and (order2 == order)
    return {
        "pairs_id_squared_l2": pairs,
        "order": order,
        "distance_is_squared_l2": abs(pairs[1][1] - 0.02) < 1e-6,  # 0.01+0.01, not 0.14
        "deterministic_3x": same,
    }


def exp_d_versioning(db):
    """create → add → version bumps; checkout old and latest."""
    rows = [{"id": i, "vector": [float(i), 0.0]} for i in range(4)]
    t = db.create_table("exp_d", data=rows, mode="overwrite")
    v_after_create = t.version
    t.add([{"id": 4, "vector": [4.0, 0.0]}])
    v_after_add = t.version
    n_versions = len(t.list_versions())
    t.checkout(1)
    n_at_v1 = t.count_rows()
    t.checkout_latest()
    n_latest = t.count_rows()
    return {
        "version_after_create": v_after_create,
        "version_after_add": v_after_add,
        "n_versions": n_versions,
        "rows_at_v1": n_at_v1,
        "rows_latest": n_latest,
        "time_travel_works": n_at_v1 == 4 and n_latest == 5,
    }


def exp_e_ann_vs_exact(db, n=50000, d=32, seed=42, k=10):
    """IVF_PQ recall vs exact brute force; tune with nprobes/refine_factor."""
    rng = np.random.default_rng(seed)
    data = rng.standard_normal((n, d)).astype(np.float32)
    q = data[0].copy()  # a real point so ground truth is well-defined
    # exact ground truth (brute force L2)
    d2 = ((data - q) ** 2).sum(axis=1)
    truth = set(np.argsort(d2)[:k].tolist())

    tbl = pa.table({
        "id": pa.array(range(n)),
        "vector": pa.FixedSizeListArray.from_arrays(pa.array(data.reshape(-1)), d),
    })
    t = db.create_table("exp_e", data=tbl, mode="overwrite")
    t.create_index("vector", config=IvfPq(num_partitions=64, num_sub_vectors=8))

    def recall(**kw):
        res = t.search(q).limit(k)
        for key, val in kw.items():
            res = getattr(res, key)(val)
        got = {r["id"] for r in res.to_list()}
        return len(got & truth) / k

    default = recall()
    tuned = recall(nprobes=64, refine_factor=10)
    return {
        "n": n, "d": d, "seed": seed, "k": k,
        "recall_default_nprobes": round(default, 3),
        "recall_nprobes64_refine10": round(tuned, 3),
        "ann_trades_recall_for_speed": default < 1.0,
        "tuning_recovers_recall": tuned >= default,
    }


def exp_f_fts(db):
    """BM25 full-text search, no embeddings at all."""
    docs = [
        {"id": 0, "text": "the quick brown fox"},
        {"id": 1, "text": "a lazy dog sleeps"},
        {"id": 2, "text": "rain in spain"},
        {"id": 3, "text": "the fox and the hound"},
    ]
    t = db.create_table("exp_f", data=docs, mode="overwrite")
    t.create_index("text", config=FTS())
    fox = [(r["id"], round(float(r["_score"]), 4)) for r in t.search("fox", query_type="fts").limit(5).to_list()]
    lazy = [r["id"] for r in t.search("lazy", query_type="fts").limit(5).to_list()]
    return {
        "fox_id_score": fox,
        "fox_ids": [p[0] for p in fox],
        "lazy_ids": lazy,
        "fts_zero_embeddings": True,
    }


def main():
    workdir = Path(tempfile.mkdtemp(prefix="lancedb-probe-"))
    try:
        db = lancedb.connect(str(workdir))
        out = {
            "lancedb_version": lancedb.__version__,
            "connection_type": type(db).__name__,  # embedded, no daemon
            "exp_b_exact_topk": exp_b_exact_topk(db),
            "exp_d_versioning": exp_d_versioning(db),
            "exp_e_ann_vs_exact": exp_e_ann_vs_exact(db),
            "exp_f_fts": exp_f_fts(db),
        }
        OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
        print("wrote", OUT.name)
        print(json.dumps(out, ensure_ascii=False, indent=2))
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
