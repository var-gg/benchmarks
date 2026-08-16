-- Planner-advice probe, PostgreSQL 19 Beta 1.
-- pg_plan_advice = LOADable library (EXPLAIN (PLAN_ADVICE)); pg_stash_advice = contrib extension.
-- Reconstructed from firsthand-benchmark.md. See results.json -> plan_advice_library_and_extension.

\echo '== both .so files exist under the lib dir (run from shell): =='
\echo '   ls /usr/lib/postgresql/19/lib/pg_plan_advice.so /usr/lib/postgresql/19/lib/pg_stash_advice.so'

-- Small skewed join so the planner has a real shape to describe.
DROP TABLE IF EXISTS join_fact;
DROP TABLE IF EXISTS dim;
CREATE TABLE dim  (id int primary key, region text);
CREATE TABLE join_fact (id int primary key, dim_id int, v int);
INSERT INTO dim SELECT g, CASE WHEN g=1 THEN 'kr' ELSE 'xx' END FROM generate_series(1,1000) g;
INSERT INTO join_fact SELECT g, 1 + (g % 1000), g FROM generate_series(1,200000) g;
CREATE INDEX ON join_fact(dim_id);
ANALYZE dim; ANALYZE join_fact;

\echo '== load the library and read generated advice =='
-- NOTE: EXPLAIN (ADVICE) is WRONG -> "unrecognized EXPLAIN option". Correct option: PLAN_ADVICE.
LOAD 'pg_plan_advice';
EXPLAIN (PLAN_ADVICE)
  SELECT f.* FROM join_fact f JOIN dim d ON d.id=f.dim_id WHERE d.region='kr';
-- Expect a "Generated Plan Advice:" block, e.g.
--   JOIN_ORDER(d f) / NESTED_LOOP_PLAIN(f) / SEQ_SCAN(d) / BITMAP_HEAP_SCAN(f) / NO_GATHER(f d)

\echo '== feed advice back; expect "Supplied Plan Advice: JOIN_ORDER(d f) /* matched */" =='
SET pg_plan_advice.advice = 'JOIN_ORDER(d f)';
EXPLAIN (PLAN_ADVICE)
  SELECT f.* FROM join_fact f JOIN dim d ON d.id=f.dim_id WHERE d.region='kr';
RESET pg_plan_advice.advice;

\echo '== pg_stash_advice: the automatic-apply half (separate contrib extension) =='
CREATE EXTENSION IF NOT EXISTS pg_stash_advice;
SELECT pg_create_advice_stash('demo');
SELECT pg_set_stashed_advice('demo', 12345, 'JOIN_ORDER(d f)');
SELECT * FROM pg_get_advice_stash_contents('demo');   -- expect: demo|12345|JOIN_ORDER(d f)
SELECT * FROM pg_get_advice_stashes();                 -- expect: demo | 1
SELECT pg_drop_advice_stash('demo');
