/**
 * System's Public library (commom for many scripts)
 * Module: admin functions. Fragment.
 *
 * Complementing adminpack and https://www.postgresql.org/docs/current/functions-admin.html
 */

CREATE extension IF NOT EXISTS adminpack;  -- for pg_file_write

CREATE or replace FUNCTION pg_relation_lines(p_tablename text)
RETURNS bigint LANGUAGE 'plpgsql' AS $f$
  DECLARE
    lines bigint;
  BEGIN
      EXECUTE 'SELECT COUNT(*) FROM '|| $1 INTO lines;
      RETURN lines;
  END
$f$;
COMMENT ON FUNCTION pg_relation_lines
  IS 'run COUNT(*), a complement for pg_relation_size() function.'
;

-- -- -- -- -- --
-- FILE functions

CREATE or replace FUNCTION volat_file_write(
  file text,
  fcontent text,
  msg text DEFAULT 'Ok',
  append boolean DEFAULT false
) RETURNS text AS $f$
  SELECT pg_catalog.pg_file_unlink(file);
  -- solves de PostgreSQL problem of the "LAZY COALESCE", as https://stackoverflow.com/a/42405837/287948
  SELECT msg ||'. Content bytes '|| CASE WHEN append THEN 'appended:' ELSE 'writed:' END
         ||  pg_catalog.pg_file_write(file,fcontent,append)::text
         || E'\nSee '|| file
$f$ language SQL volatile;
COMMENT ON FUNCTION volat_file_write
  IS 'Do lazy coalesce. To use in a "only write when null" condiction of COALESCE(x,volat_file_write()).'
;

CREATE or replace FUNCTION pg_tablestruct_dump_totext(
  p_tabname text, p_ignore text[] DEFAULT NULL, p_add text[] DEFAULT NULL
) RETURNS text[]  AS $f$
  SELECT array_agg(col||' '||datatype) || COALESCE(p_add,array[]::text[])
  FROM (
    SELECT -- attrelid::regclass AS tbl,
           attname            AS col
         , atttypid::regtype  AS datatype
    FROM   pg_attribute
    WHERE  attrelid = p_tabname::regclass  -- table name, optionally schema-qualified
    AND    attnum > 0
    AND    NOT attisdropped
    AND    ( p_ignore IS null OR NOT(attname=ANY(p_ignore)) )
    ORDER  BY attnum
  ) t
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION pg_tablestruct_dump_totext
  IS 'Extraxcts column descriptors of a table. Used in ingest.fdw_generate_getclone() function. Optional adds to the end.'
;

CREATE or replace FUNCTION jsonb_pg_stat_file(
  f text,   -- filename with absolute path
  add_md5 boolean DEFAULT false,
  -- add_filename  boolean DEFAULT true,
  missing_ok boolean DEFAULT false
) RETURNS JSONb AS $f$
  -- = indest.get_file_meta(). Falta emitir erro quando file not found!
  -- usar (j->'size')::bigint+1 como pg_read(size)!  para poder usar missing nele.
  SELECT j
         || jsonb_build_object( 'file',f )
         || CASE WHEN add_md5 THEN jsonb_build_object( 'hash_md5', md5(pg_read_binary_file(f)) ) ELSE '{}'::jsonb END
  FROM to_jsonb( pg_stat_file(f,missing_ok) ) t(j)
  WHERE j IS NOT NULL
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_pg_stat_file
  IS 'Convert pg_stat_file() information in JSONb, adding option to include MD5 digest and filename.'
;

-- -- -- -- -- -- -- -- -- -- --
-- Helper functions: avoid.

CREATE or replace FUNCTION iIF(
    condition boolean,       -- IF condition
    true_result anyelement,  -- THEN
    false_result anyelement  -- ELSE
    -- See https://stackoverflow.com/a/53750984/287948
) RETURNS anyelement AS $f$
  SELECT CASE WHEN condition THEN true_result ELSE false_result END
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION iif
  IS 'Immediate IF. Sintax sugar for the most frequent CASE-WHEN. Avoid with text, need explicit cast.'
;
