#!/usr/bin/env python3
"""
Firsthand probe for DBOS Transact (Python, 2.27.0) durable execution — the kill test.

DBOS is a durable-execution LIBRARY: pip install dbos, decorate functions, and it
checkpoints workflow/step progress into a database (SQLite by default, zero config).
This probe deliberately hard-kills the process mid-workflow (os._exit) and then
relaunches to observe what recovery actually replays, using an append-only side-effect
ledger file as ground truth of "this code really ran (again)".

Modes (each invoked as its own process by run.sh):
  run             baseline: fresh 5-step workflow to completion
  crash-during    step 3 hard-crashes the process ON ITS FIRST ATTEMPT (mid-step)
  crash-between   process hard-crashes AFTER step 3 completes, BEFORE step 4 starts
  resume          relaunch with the same pinned app version; wait for auto-recovery
  status          print workflow status + recorded steps without waiting
  inspect         dump the DBOS SQLite system db (tables, workflow_status, operation_outputs)
  overhead        durability tax: time N no-op steps in a workflow vs plain calls

Environment:
  DBOS_DEMO_WORK  working dir for sqlite + ledger (default: alongside this file)
  APP_VERSION     pin the DBOS application version (recovery only picks up matching versions)
  CRASH_MODE      internal: none | during | between
  N_STEPS         overhead mode: number of no-op steps (default 200)

Deterministic by construction: fixed workflow id, fixed step count, no RNG.
Exit codes 42/43 are the deliberate crashes.
"""
import os, sys, json, time, sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.abspath(os.environ.get("DBOS_DEMO_WORK", HERE))
DB = os.path.join(WORK, "dbos-firsthand.sqlite")
LEDGER = os.path.join(WORK, "ledger.txt")
CRASH_FLAG = os.path.join(WORK, "crashed.flag")
CRASH_MODE = os.environ.get("CRASH_MODE", "none")
WFID = "kill-test-1"

os.makedirs(WORK, exist_ok=True)


def note(line: str) -> None:
    with open(LEDGER, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def read_ledger() -> list:
    if not os.path.exists(LEDGER):
        return []
    with open(LEDGER, encoding="utf-8") as f:
        return [l.rstrip("\n") for l in f if l.strip()]


def make_config():
    from dbos import DBOSConfig  # noqa
    cfg = {
        "name": "firsthand-dbos",
        "system_database_url": "sqlite:///" + DB.replace("\\", "/"),
        "run_admin_server": False,
        "console_log_level": "WARNING",
    }
    if os.environ.get("APP_VERSION"):
        cfg["application_version"] = os.environ["APP_VERSION"]
    return cfg


def build_app():
    """Register workflow + steps. Called by every mode that talks to DBOS."""
    from dbos import DBOS

    dbos = DBOS(config=make_config())

    @DBOS.step()
    def work_step(i: int) -> str:
        note(f"step{i} EXECUTED pid={os.getpid()}")
        if CRASH_MODE == "during" and i == 3 and not os.path.exists(CRASH_FLAG):
            open(CRASH_FLAG, "w").write("during")
            note(f"step3 KILLING PROCESS MID-STEP pid={os.getpid()}")
            os._exit(42)
        return f"result-{i}"

    @DBOS.workflow()
    def pipeline() -> str:
        outs = []
        for i in range(1, 6):
            outs.append(work_step(i))
            if CRASH_MODE == "between" and i == 3 and not os.path.exists(CRASH_FLAG):
                open(CRASH_FLAG, "w").write("between")
                note(f"KILLING PROCESS BETWEEN step3 AND step4 pid={os.getpid()}")
                os._exit(43)
        return ",".join(outs)

    return DBOS, pipeline


def wf_status(DBOS):
    for w in DBOS.list_workflows():
        if w.workflow_id == WFID:
            return w
    return None


def start(mode: str):
    from dbos import SetWorkflowID
    DBOS, pipeline = build_app()
    DBOS.launch()
    note(f"--- {mode} launch pid={os.getpid()} app_version={DBOS.application_version}")
    with SetWorkflowID(WFID):
        handle = DBOS.start_workflow(pipeline)
    result = handle.get_result()
    print(json.dumps({"mode": mode, "workflow_id": WFID, "result": result,
                      "app_version": DBOS.application_version,
                      "ledger": read_ledger()}, ensure_ascii=False, indent=1))
    DBOS.destroy()


def resume(wait_s: float = 30.0):
    DBOS, _pipeline = build_app()
    t0 = time.perf_counter()
    DBOS.launch()
    note(f"--- resume launch pid={os.getpid()} app_version={DBOS.application_version}")
    status = None
    deadline = time.time() + wait_s
    while time.time() < deadline:
        w = wf_status(DBOS)
        status = w.status if w else None
        if status == "SUCCESS":
            break
        time.sleep(0.25)
    dt = round(time.perf_counter() - t0, 2)
    steps = DBOS.list_workflow_steps(WFID)
    print(json.dumps({
        "mode": "resume", "workflow_id": WFID, "final_status": status,
        "seconds_from_launch_to_final": dt,
        "app_version": DBOS.application_version,
        "recorded_steps": [
            {"function_id": s["function_id"], "name": s["function_name"],
             "output": s["output"]} for s in steps
        ] if steps else [],
        "ledger": read_ledger(),
    }, ensure_ascii=False, indent=1))
    DBOS.destroy()


def inspect():
    con = sqlite3.connect(DB)
    cur = con.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = [r[0] for r in cur.fetchall()]
    out = {"mode": "inspect", "sqlite_file": DB,
           "size_kb": round(os.path.getsize(DB) / 1024, 1), "tables": tables}
    if "workflow_status" in tables:
        cur.execute("SELECT workflow_uuid, status, name, recovery_attempts, application_version FROM workflow_status")
        out["workflow_status"] = [
            {"workflow_id": r[0], "status": r[1], "name": r[2],
             "recovery_attempts": r[3], "application_version": r[4]} for r in cur.fetchall()]
    if "operation_outputs" in tables:
        cur.execute("SELECT workflow_uuid, function_id, function_name, output IS NOT NULL FROM operation_outputs ORDER BY function_id")
        out["operation_outputs"] = [
            {"workflow_id": r[0], "function_id": r[1], "function_name": r[2],
             "has_recorded_output": bool(r[3])} for r in cur.fetchall()]
    con.close()
    print(json.dumps(out, ensure_ascii=False, indent=1))


def overhead():
    from dbos import SetWorkflowID
    from dbos import DBOS as DBOS_cls  # local alias
    n = int(os.environ.get("N_STEPS", "200"))
    DBOS = DBOS_cls(config=make_config())

    @DBOS_cls.step()
    def noop(i: int) -> int:
        return i

    @DBOS_cls.workflow()
    def many_steps() -> int:
        acc = 0
        for i in range(n):
            acc += noop(i)
        return acc

    DBOS_cls.launch()
    t0 = time.perf_counter()
    with SetWorkflowID("overhead-1"):
        h = DBOS_cls.start_workflow(many_steps)
    r = h.get_result()
    dt = time.perf_counter() - t0

    def plain_noop(i):
        return i
    t1 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += plain_noop(i)
    dt_plain = time.perf_counter() - t1

    print(json.dumps({
        "mode": "overhead", "n_steps": n, "result_check": r == acc,
        "workflow_seconds": round(dt, 3),
        "plain_seconds": round(dt_plain, 6),
        "ms_per_step_durable": round(dt / n * 1000, 2),
        "note": "durable step cost = checkpoint write(s) to SQLite per step",
    }, ensure_ascii=False, indent=1))
    DBOS_cls.destroy()


def status_only():
    DBOS, _ = build_app()
    DBOS.launch()
    w = wf_status(DBOS)
    steps = DBOS.list_workflow_steps(WFID) if w else []
    print(json.dumps({
        "mode": "status", "workflow_id": WFID,
        "status": w.status if w else None,
        "app_version_of_process": DBOS.application_version,
        "app_version_of_workflow": w.app_version if w and hasattr(w, "app_version") else None,
        "recorded_step_count": len(steps) if steps else 0,
        "ledger": read_ledger(),
    }, ensure_ascii=False, indent=1))
    DBOS.destroy()


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    if mode == "run":
        start("run")
    elif mode == "crash-during":
        os.environ["CRASH_MODE"] = "during"; CRASH_MODE = "during"; start("crash-during")
    elif mode == "crash-between":
        os.environ["CRASH_MODE"] = "between"; CRASH_MODE = "between"; start("crash-between")
    elif mode == "resume":
        resume()
    elif mode == "status":
        status_only()
    elif mode == "inspect":
        inspect()
    elif mode == "overhead":
        overhead()
    else:
        print(json.dumps({"error": "unknown mode", "mode": mode})); sys.exit(2)
