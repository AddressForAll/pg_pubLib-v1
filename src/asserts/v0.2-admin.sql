-- Optional admin checks, after pubLib03-admin.sql (requires adminpack).
\set ON_ERROR_STOP on
BEGIN;
CREATE SCHEMA publib_v02_admin_test;
CREATE TABLE publib_v02_admin_test.sample (id integer, label text);
DO $test$
BEGIN
  ASSERT rel_columns('sample','publib_v02_admin_test') = ARRAY['id','label'], 'catalog columns';
  ASSERT pg_relation_lines('publib_v02_admin_test.sample') = 0, 'dynamic query';
  ASSERT (SELECT provolatile='s' AND proparallel='r' FROM pg_proc WHERE oid='rel_columns(text,text)'::regprocedure), 'catalog attributes';
  ASSERT (SELECT proparallel='u' FROM pg_proc WHERE oid='pg_relation_lines(text)'::regprocedure), 'dynamic SQL exception';
  ASSERT EXISTS (SELECT 1 FROM doc_UDF_show('public','to_integer') WHERE name='to_integer'), 'documentation query';
END
$test$;
ALTER TABLE publib_v02_admin_test.sample ADD COLUMN extra boolean;
DO $test$
BEGIN
  ASSERT rel_columns('sample','publib_v02_admin_test') = ARRAY['id','label','extra'], 'catalog changes visible';
END
$test$;
ROLLBACK;
