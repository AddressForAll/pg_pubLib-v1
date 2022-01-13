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

-- -- -- -- -- -- -- -- -- -- -- --
-- Other system's helper functions

CREATE or replace FUNCTION rel_columns(
 p_relname text, p_schemaname text DEFAULT NULL
) RETURNS text[] AS $f$
   SELECT --attrelid::regclass AS tbl,  atttypid::regtype  AS datatype
        array_agg(attname::text ORDER  BY attnum)
   FROM   pg_attribute
   WHERE  attrelid = (CASE
             WHEN strpos($1, '.')>0 THEN $1
             WHEN $2 IS NULL THEN 'public.'||$1
             ELSE $2||'.'||$1
          END)::regclass
   AND    attnum > 0
   AND    NOT attisdropped
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION sql_parse_selectcols_simple(s text) RETURNS text AS $f$
   SELECT CASE
       WHEN $1 IS NULL OR p[1]='' OR array_length(p,1)>2 THEN NULL
       WHEN array_length(p,1)=1 THEN p[1]
       ELSE p[1] ||' AS '||p[2]
       END
   FROM (SELECT regexp_split_to_array(trim($1),'\s+') p) t
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION sql_parse_selectcols(selcols text[]) RETURNS text[] AS $f$
   SELECT array_agg( CASE
      WHEN $1 IS NULL OR p_as IS NULL OR array_length(p_as,1)=0 OR array_length(p_as,1)>2 THEN NULL
      WHEN array_length(p_as,1)=2 THEN p_as[1] ||' AS '||p_as[2]
      ELSE sql_parse_selectcols_simple(p_as[1])
      END )
   FROM (
     SELECT i,regexp_split_to_array(x, '\s+as\s+','i') p_as
     FROM UNNEST($1) WITH ORDINALITY t1(x,i)
   ) t2
$f$ LANGUAGE SQL;


CREATE or replace FUNCTION show_udfs(
  p_schema_name text DEFAULT NULL,
  p_name_like text DEFAULT '',
  p_name_notlike text DEFAULT ''
) RETURNS TABLE (
  schema_name text,
  name text,
  language text,
  arguments text,
  return_type text,
  definition text
) AS $f$
  SELECT
    pg_namespace.nspname::text,
    pg_proc.proname::text,
    pg_language.lanname::text,
    pg_get_function_arguments(pg_proc.oid)::text,
    pg_type.typname::text,
    CASE
      WHEN pg_language.lanname = 'internal' then pg_proc.prosrc::text
      ELSE pg_get_functiondef(pg_proc.oid)::text
    END
  FROM pg_proc
    LEFT JOIN pg_namespace on pg_proc.pronamespace = pg_namespace.oid
    LEFT JOIN pg_language on pg_proc.prolang = pg_language.oid
    LEFT JOIN pg_type on pg_type.oid = pg_proc.prorettype
  WHERE pg_namespace.nspname not in ('pg_catalog', 'information_schema')
        AND CASE WHEN p_schema_name IS NOT NULL THEN p_schema_name=pg_namespace.nspname::text ELSE true END
        AND CASE WHEN p_name_like>'' THEN pg_proc.proname::text iLIKE p_name_like ELSE true END
        AND CASE WHEN p_name_notlike>'' THEN NOT(pg_proc.proname::text iLIKE p_name_notlike) ELSE true END        
$f$ LANGUAGE SQL IMMUTABLE;
-- SELECT name, language, arguments, return_type FROM show_udfs('public','%geohas%','st_%');
