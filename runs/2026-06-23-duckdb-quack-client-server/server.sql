-- server.sql — boot a DuckDB quack server with seed tables, then serve.
-- Run with:  duckdb -init server.sql   (DuckDB v1.5.3 CLI on PATH)
--
-- quack is an autoloadable core extension; INSTALL fetches it from the network once.
INSTALL quack;
LOAD quack;

-- Seed data (in-memory server).
CREATE TABLE hello (msg VARCHAR);
INSERT INTO hello VALUES ('world'), ('duck');

CREATE TABLE big AS SELECT i AS k, i * 2 AS v FROM range(1000000) t(i);

CREATE TABLE t (id INTEGER, who VARCHAR);        -- append target for DML matrix + concurrency
CREATE TABLE upd_probe (id INTEGER, val INTEGER);
INSERT INTO upd_probe VALUES (1, 1);
CREATE TABLE tx_probe (id INTEGER);              -- ROLLBACK propagation probe

-- Serve on loopback with a shared token. Blocks; Ctrl-C to stop.
CALL quack_serve('quack:localhost', token := 'super_secret');
