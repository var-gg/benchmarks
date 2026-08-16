-- GUC-default probe, PostgreSQL 19 Beta 1: parallel autovacuum + async I/O.
-- Reconstructed from firsthand-benchmark.md. See results.json -> guc_defaults.

\echo '== parallel autovacuum: opt-in, default 0 =='
SHOW autovacuum_max_parallel_workers;      -- expect 0 (off by default)

\echo '== async I/O defaults =='
SHOW io_method;                            -- expect worker (default)
SHOW io_max_concurrency;                   -- expect 64
SELECT name, setting, context
  FROM pg_settings
 WHERE name IN ('io_method','io_max_concurrency','autovacuum_max_parallel_workers')
 ORDER BY name;
-- io_method / io_max_concurrency have context = postmaster (restart to change).
-- AIO itself landed in PG18; 19beta1 confirms the default worker mode here.
