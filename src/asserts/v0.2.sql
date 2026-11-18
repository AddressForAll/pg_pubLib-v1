-- Regression checks for the v0.2 migration. Install core modules first.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
BEGIN
  ASSERT round(2.56::float,1) = 2.6, 'round overload';
  ASSERT iif(true, 1, 2) = 1, 'polymorphic iif';
  ASSERT array_last(ARRAY[1,2,3]) = 3, 'polymorphic array_last';
  ASSERT array_distinct_sort(ARRAY[3,1,3]) = ARRAY[1,3], 'polymorphic sorting';
  ASSERT to_integer('a12b') = 12, 'string conversion';
  ASSERT to_integer('abc') IS NULL, 'empty conversion';
  ASSERT to_integer(NULL) IS NULL, 'null conversion';
  ASSERT str_urldecode('hello%20world') = 'hello world', 'URL decoding';
  ASSERT substring_occurs('banana','na') = 2, 'substring count';
  ASSERT jsonb_objslice(ARRAY['a','b'], '{"a":1,"b":2}'::jsonb) = '{"a":1,"b":2}'::jsonb, 'JSON slice';
  ASSERT jsonb_objslice('$.a'::jsonpath, '{"a":1}'::jsonb, 'x') = '{"x":1}'::jsonb, 'JSON path';
  ASSERT jsonb_summable_merge('{"a":2}'::jsonb, '{"a":3,"b":1}'::jsonb) = '{"a":5,"b":1}'::jsonb, 'JSON merge';
  ASSERT jsonb_summable_merge(ARRAY['{"a":2}'::jsonb,'{"a":3}'::jsonb]) = '{"a":5}'::jsonb, 'PL/pgSQL merge';
  ASSERT jsonb_array_to_text_array('["b","a","b"]'::jsonb,true) = ARRAY['a','b'], 'sorted JSON array';
  ASSERT jsonb_array_to_text_array(NULL::jsonb,false) IS NULL, 'null JSON array';
  ASSERT (SELECT array_agg_cat(x) FROM (VALUES (ARRAY[1,2]), (ARRAY[3])) t(x)) = ARRAY[1,2,3], 'compatible array aggregate';
  ASSERT (SELECT jsonb_summable_aggmerge(x) FROM (VALUES ('{"a":2}'::jsonb), ('{"a":3}'::jsonb)) t(x)) = '{"a":5}'::jsonb, 'JSON aggregate';
  ASSERT (SELECT jsonb_summable_aggmerge(x) FROM (SELECT NULL::jsonb x WHERE false) t) = 'null'::jsonb, 'empty JSON aggregate';
  ASSERT str_geouri_decode('geo:-23.5,-46.6') = ARRAY[-23.5,-46.6,NULL,NULL]::float[], 'GeoURI';
  ASSERT (SELECT count(*) FROM varbit_generate_tree(2::smallint)) = 7, 'atomic recursive CTE';
  ASSERT (SELECT prosqlbody IS NOT NULL FROM pg_proc WHERE oid='to_integer(text)'::regprocedure), 'SQL-standard body';
  ASSERT (SELECT prosqlbody IS NULL FROM pg_proc WHERE oid='array_last(anyarray)'::regprocedure), 'polymorphic exception';
  ASSERT (SELECT proparallel='r' AND provolatile='v' FROM pg_proc WHERE oid='public.array_sample(anyarray,integer)'::regprocedure), 'random sampling classification';
  ASSERT (SELECT proparallel='u' FROM pg_proc WHERE oid='array_distinct_sort(anyarray,boolean)'::regprocedure), 'generic operator exception';
  ASSERT (SELECT proparallel='u' FROM pg_proc WHERE oid='jsonb_array_to_text_array(jsonb,boolean)'::regprocedure), 'unsafe callee propagation';
END
$test$;

-- A SAFE parsed body must not directly depend on a RESTRICTED/UNSAFE function.
DO $test$
BEGIN
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_depend d
    JOIN pg_proc p ON d.classid='pg_proc'::regclass AND d.objid=p.oid
    JOIN pg_proc q ON d.refclassid='pg_proc'::regclass AND d.refobjid=q.oid
    JOIN pg_namespace n ON p.pronamespace=n.oid
    WHERE n.nspname='public' AND p.prosqlbody IS NOT NULL
      AND p.proparallel='s' AND q.proparallel <> 's'
  ), 'SAFE function depends on a non-SAFE function';
END
$test$;

-- Compare serial and parallel execution on a real relation (temporary tables
-- cannot be scanned by parallel workers). All objects are rolled back.
CREATE SCHEMA publib_v02_test;
CREATE TABLE publib_v02_test.input AS SELECT generate_series(1,100000) AS i;
ALTER TABLE publib_v02_test.input SET (parallel_workers=2);
ANALYZE publib_v02_test.input;
SET LOCAL min_parallel_table_scan_size=0;
SET LOCAL parallel_setup_cost=0;
SET LOCAL parallel_tuple_cost=0;
DO $test$
DECLARE serial_result bigint; parallel_result bigint; plan json;
BEGIN
  PERFORM set_config('max_parallel_workers_per_gather','0',true);
  SELECT sum(to_integer(i::text)) INTO serial_result FROM publib_v02_test.input;
  PERFORM set_config('max_parallel_workers_per_gather','2',true);
  SELECT sum(to_integer(i::text)) INTO parallel_result FROM publib_v02_test.input;
  ASSERT serial_result = 5000050000 AND parallel_result = serial_result, 'serial/parallel results';
  EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) SELECT sum(to_integer(i::text)) FROM publib_v02_test.input' INTO plan;
  ASSERT plan::text LIKE '%Gather%', 'parallel plan';
END
$test$;

-- Reinstalling the modules must preserve objects depending on aggregates.
CREATE VIEW publib_v02_test.aggregate_dependency AS
  SELECT array_agg_cat(ARRAY[i]) AS a FROM publib_v02_test.input WHERE i <= 3;
\ir ../pubLib01-array.sql
\ir ../pubLib04-aggregate.sql
DO $test$
BEGIN
  ASSERT (SELECT a FROM publib_v02_test.aggregate_dependency) = ARRAY[1,2,3], 'aggregate dependent view preserved';
END
$test$;
ROLLBACK;
