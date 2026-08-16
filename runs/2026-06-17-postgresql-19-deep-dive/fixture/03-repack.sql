-- Core REPACK probe, PostgreSQL 19 Beta 1.
-- Reconstructed from firsthand-benchmark.md. See results.json -> repack_in_core,
-- repack_concurrently_wal_level.

\echo '== REPACK is a core command now (help text) =='
\h REPACK
-- Expect: REPACK [ ( option [, ...] ) ] [ table_and_columns [ USING INDEX [ index_name ] ] ]
--         option: VERBOSE | ANALYZE | CONCURRENTLY

\echo '== current wal_level (this run observed replica, NOT logical) =='
SHOW wal_level;

\echo '== simple REPACK on a small table =='
DROP TABLE IF EXISTS person CASCADE;
CREATE TABLE person (id int primary key, name text);
INSERT INTO person VALUES (1,'Kim'),(2,'Lee'),(3,'Park');
REPACK person;

\echo '== REPACK (CONCURRENTLY, VERBOSE) on 200k rows, no concurrent writer =='
DROP TABLE IF EXISTS join_fact;
CREATE TABLE join_fact (id int primary key, dim_id int, v int);
INSERT INTO join_fact SELECT g, 1 + (g % 1000), g FROM generate_series(1,200000) g;
REPACK (CONCURRENTLY, VERBOSE) join_fact;
-- Expect (observed): "repacking \"public.join_fact\" in physical order"
--   "found 0 removable, 200000 nonremovable row versions in 1082 pages"  -> REPACK
-- Succeeded under wal_level=replica with no concurrent writers. Under live concurrent
-- writes the slot/WAL cost of CONCURRENTLY is what surfaces (not driven in this run).
