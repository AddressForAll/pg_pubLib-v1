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

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Documentation helper functions (doc_ prefix)

CREATE or replace FUNCTION doc_UDF_show(
  p_schema_name text DEFAULT NULL,
  p_name_like text DEFAULT '',
  p_name_notlike text DEFAULT '',
  p_oid oid DEFAULT NULL
) RETURNS TABLE (
  oid oid,
  schema_name text,
  name text,
  language text,
  arguments text,
  return_type text,
  definition text,
  prokind text,
  comment text
) AS $f$
  SELECT
    pg_proc.oid,
    pg_namespace.nspname::text,
    pg_proc.proname::text,
    pg_language.lanname::text,
    pg_get_function_arguments(pg_proc.oid)::text,
    pg_type.typname::text,
    CASE
      WHEN pg_language.lanname = 'internal' then pg_proc.prosrc::text
      ELSE pg_get_functiondef(pg_proc.oid)::text
    END,
    CASE pg_proc.prokind
       WHEN 'a' THEN 'agg'
       WHEN 'w' THEN 'window'
       WHEN 'p' THEN 'proc'
       ELSE 'func'
    END,
    obj_description(pg_proc.oid)::text
  FROM pg_proc
    LEFT JOIN pg_namespace on pg_proc.pronamespace = pg_namespace.oid
    LEFT JOIN pg_language on pg_proc.prolang = pg_language.oid
    LEFT JOIN pg_type on pg_type.oid = pg_proc.prorettype
  WHERE pg_namespace.nspname not in ('pg_catalog', 'information_schema')
        AND CASE WHEN COALESCE(p_schema_name,'') >'' THEN p_schema_name=pg_namespace.nspname::text ELSE true END
        AND CASE WHEN COALESCE(p_name_like,'') >'' THEN
              CASE WHEN position('%' in p_name_like)>0 THEN pg_proc.proname::text iLIKE p_name_like ELSE pg_proc.proname::text ~ p_name_like END
            ELSE true END
        AND CASE WHEN COALESCE(p_name_notlike,'') >'' THEN NOT(pg_proc.proname::text iLIKE p_name_notlike) ELSE true END
        AND CASE WHEN p_oid IS NOT NULL THEN pg_proc.oid=p_oid ELSE true END
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION doc_UDF_show
  IS 'Show all information about an User Defined Function (UDF), by its OID, or listing all functions by LIKE filter.'
;
-- SELECT name, return_type, arguments FROM doc_UDF_show('public','%geohas%','st_%');
-- SELECT name, return_type, comment FROM doc_UDF_show('public','show_UDF');

CREATE or replace FUNCTION doc_UDF_show_simplified_signature(
  p_schema_name text DEFAULT NULL,
  p_name_like text DEFAULT '',
  p_name_notlike text DEFAULT ''
) RETURNS TABLE (
  oid text,
  schema_name information_schema.sql_identifier,
  name information_schema.sql_identifier,
  arguments_simplified information_schema.character_data[]
) AS $f$
  SELECT substring(routines.specific_name::text from '[^_]+$'),
         routines.specific_schema, routines.routine_name,
         array_agg(parameters.data_type ORDER BY parameters.ordinal_position) as simplified_signature
  FROM information_schema.routines
    LEFT JOIN information_schema.parameters ON routines.specific_name=parameters.specific_name
  WHERE
        CASE WHEN COALESCE(p_schema_name,'') >''   THEN p_schema_name=routines.specific_schema  ELSE true END
        AND CASE WHEN COALESCE(p_name_like,'') >'' THEN
              CASE WHEN position('%' in p_name_like)>0 THEN routines.routine_name::text iLIKE p_name_like ELSE routines.routine_name::text ~ p_name_like END
            ELSE true END
        AND CASE WHEN COALESCE(p_name_notlike,'') >'' THEN NOT(routines.routine_name iLIKE p_name_notlike) ELSE true END
  GROUP BY routines.specific_name, 2, 3
  ORDER BY routines.routine_name, routines.specific_name
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION doc_UDF_show_simplified_signature
  IS 'Show name and simplified argument list about an User Defined Function (UDF), by its name or listing all functions by LIKE filter. Useful for namespace analyses'
;
-- SELECT * FROM doc_UDF_show_simplified_signature('','%geohash%','st_%');


CREATE or replace FUNCTION doc_UDF_transparent_id(
  name_expression text,
  md5_digits int DEFAULT 6   -- good for ~5000 items or less. Not need more items in a limited-scope documentation.
) RETURNS text AS $f$
  SELECT substr( md5(lower(name_expression)), 1, md5_digits)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION doc_UDF_transparent_id(text,int)
  IS 'Offers a public eternal identifier for a function, important to JOINS in the documentation schema.'
;
-- SELECT doc_UDF_transparent_id( 'public.doc_UDF_show(text,text,text,OID)' ); -- eternally '875377'

CREATE or replace FUNCTION doc_UDF_transparent_id(
  schema_name text,
  name text,
  arguments_simplified text[],
  md5_digits int DEFAULT 6   -- good for ~5000 items or less. Not need more items in a limited-scope documentation.
) RETURNS text AS $f$
  SELECT doc_UDF_transparent_id( schema_name||'.'||name||'('||array_to_string(arguments_simplified,',')||')', md5_digits)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION doc_UDF_transparent_id(text,text,text[],int)
  IS 'Prepare the standard parameters for doc_UDF_transparent_id().'
;
-- SELECT doc_UDF_transparent_id('public','doc_UDF_show','{text,text,text,oid}');

CREATE or replace FUNCTION doc_UDF_transparent_id(
  name text,
  arguments_simplified text[],
  md5_digits int DEFAULT 6
) RETURNS text AS $wrap$
  SELECT doc_UDF_transparent_id('public',$1,$2,$3);
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION doc_UDF_transparent_id(text,text[],int)
  IS 'Prepare parameters for doc_UDF_transparent_id().'
;
-- SELECT doc_UDF_transparent_id('doc_UDF_show','{text,text,text,oid}');

CREATE or replace FUNCTION doc_UDF_show_simple(
  p_schema_name text DEFAULT NULL,
  p_name_like text DEFAULT '',
  p_name_notlike text DEFAULT '',
  p_oid oid DEFAULT NULL
) RETURNS TABLE (
  id text,
  oid oid,
  schema_name text,
  name text,
  arguments_simplified text[],
  arguments text,
  return_type text,
  prokind text,
  comment text
) AS $f$
  SELECT doc_UDF_transparent_id(u.schema_name, u.name::text, s.arguments_simplified::text[]) AS id,
         u.oid, u.schema_name, u.name::text,
         s.arguments_simplified::text[] as arguments_simplified,
         u.arguments::text AS arguments,
         u.return_type, u.prokind, u.comment
  FROM doc_UDF_show_simplified_signature($1,$2,$3) s
      INNER JOIN doc_UDF_show($1,$2,$3,$4) u ON s.oid=u.oid::text
$f$ LANGUAGE SQL IMMUTABLE;
-- SELECT * FROM doc_UDF_show_simple('','%geohash%','st_%');
