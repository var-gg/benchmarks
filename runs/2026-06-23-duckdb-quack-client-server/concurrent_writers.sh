#!/usr/bin/env bash
# concurrent_writers.sh — Section 4: two separate processes append 5000 rows each.
# Requires a running server (server.sql) with an empty-ish remote.t.
# Expect final total = preexisting + 10000, no row loss / lockout.
set -euo pipefail

writer() {
  local who="$1" lo="$2" hi="$3"
  duckdb <<SQL
INSTALL quack; LOAD quack;
CREATE SECRET (TYPE quack, TOKEN 'super_secret');
ATTACH 'quack:localhost' AS remote;
INSERT INTO remote.t SELECT i, '${who}' FROM range(${lo}, ${hi}) t(i);
SQL
}

writer A 100000 105000 &
writer B 200000 205000 &
wait

duckdb <<'SQL'
INSTALL quack; LOAD quack;
CREATE SECRET (TYPE quack, TOKEN 'super_secret');
ATTACH 'quack:localhost' AS remote;
SELECT who, count(*) FROM remote.t GROUP BY who ORDER BY who;   -- A 5000, B 5000, (+preexisting)
SELECT count(*) AS total FROM remote.t;
SQL
