-- client.sql — probe a running quack server (see server.sql) for the capability matrix.
-- Run in a SECOND DuckDB process:  duckdb -init client.sql
-- Compare each result against results.json.
INSTALL quack;
LOAD quack;

-- 2. AUTH — valid token attaches; wrong token / no secret fail with distinct errors.
--    (Uncomment the wrong-token / no-secret variants one at a time to observe the errors.)
CREATE SECRET (TYPE quack, TOKEN 'super_secret');
ATTACH 'quack:localhost' AS remote;
-- wrong token   -> Invalid Input Error: Authentication failed
-- no SECRET     -> Invalid Input Error: Could not find a Quack authentication token

-- 1. BASIC ROUND-TRIP (read)
SELECT 'roundtrip_hello' AS probe, count(*) AS n FROM remote.hello;        -- expect 2
SELECT 'roundtrip_big'   AS probe, count(*) AS n FROM remote.big;          -- expect 1000000

-- 3. REMOTE WRITE SURFACE — append + DDL succeed; direct UPDATE/DELETE fail.
INSERT INTO remote.t VALUES (1,'alice'),(2,'bob'),(3,'carol');            -- pass
CREATE TABLE remote.t2 AS SELECT 42 AS x;                                  -- pass
DROP TABLE remote.t2;                                                      -- pass
-- UPDATE remote.t SET who='X' WHERE id=1;   -- Binder Error: Can only update base table
-- DELETE FROM remote.t WHERE id=1;          -- Binder Error: Can only delete from base table
-- PRAGMA database_list;                      -- Not implemented Error: InMemory not implemented yet

-- 3b. UPDATE/DELETE server-side workaround via remote.query(...)
SELECT * FROM remote.query('UPDATE upd_probe SET val=999 WHERE id=1 RETURNING *');  -- (1,999)
SELECT 'upd_readback' AS probe, val FROM remote.upd_probe WHERE id=1;               -- 999

-- 3c. TRANSACTION ROLLBACK NOT PROPAGATED — inserted row survives ROLLBACK.
SELECT 'tx_before' AS probe, count(*) AS n FROM remote.tx_probe;          -- 0
BEGIN; INSERT INTO remote.tx_probe VALUES (1); ROLLBACK;
SELECT 'tx_after_rollback' AS probe, count(*) AS n FROM remote.tx_probe;  -- 1 (bug #173)

-- 6. SERVER FAILURE — kill the server process, then re-run any remote.* query:
--    IO Error: Could not connect to server error for HTTP POST to 'http://localhost:9494/quack'
