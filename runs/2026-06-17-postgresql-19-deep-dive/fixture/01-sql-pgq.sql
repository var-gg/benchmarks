-- SQL/PGQ (property graph query) capability + limit probe, PostgreSQL 19 Beta 1.
-- Reconstructed from firsthand-benchmark.md. Expected outcomes are in results.json
-- (capabilities_verified: sql_pgq_fixed_length, sql_pgq_quantifier_limit).

\echo '== version =='
SELECT version();

DROP TABLE IF EXISTS knows;
DROP TABLE IF EXISTS person;

CREATE TABLE person (id int primary key, name text);
-- Edge table needs its OWN key, or CREATE PROPERTY GRAPH fails with
--   "no key specified and no suitable primary key exists"
CREATE TABLE knows (id int primary key, a int references person(id), b int references person(id));

INSERT INTO person VALUES (1,'Kim'),(2,'Lee'),(3,'Park');
INSERT INTO knows  VALUES (1, 1,2), (2, 2,3);   -- Kim->Lee, Lee->Park

CREATE PROPERTY GRAPH social
  VERTEX TABLES (person KEY (id))
  EDGE TABLES (knows KEY (id)
                     SOURCE KEY (a) REFERENCES person (id)
                     DESTINATION KEY (b) REFERENCES person (id));

\echo '== 1-hop: expect Kim|Lee, Lee|Park =='
SELECT * FROM GRAPH_TABLE (social
  MATCH (p1 IS person)-[IS knows]->(p2 IS person)
  COLUMNS (p1.name AS src, p2.name AS dst));

\echo '== fixed 2-hop (friend-of-friend): expect Kim|Park =='
SELECT * FROM GRAPH_TABLE (social
  MATCH (p1 IS person)-[IS knows]->(IS person)-[IS knows]->(p3 IS person)
  COLUMNS (p1.name AS src, p3.name AS dst));

\echo '== variable-length quantifier: EXPECT ERROR (element pattern quantifier is not supported) =='
SELECT * FROM GRAPH_TABLE (social
  MATCH (p1 IS person)-[IS knows]->{1,2}(p3 IS person)
  COLUMNS (p1.name AS src, p3.name AS dst));
