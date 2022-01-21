
CREATE or replace FUNCTION  jsonb_objslice(
    key text, j jsonb, rename text default NULL
) RETURNS jsonb AS $f$
    SELECT COALESCE( jsonb_build_object( COALESCE(rename,key) , j->key ), '{}'::jsonb )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_objslice(text,jsonb,text)
  IS 'Get the key as encapsulated object, with same or changing name. Prefer subtract keys or jsonb_path_query() when valid'
;

CREATE or replace FUNCTION  jsonb_objslice(
    keys text[], j jsonb, renames text[] default NULL
) RETURNS jsonb AS $f$
    SELECT COALESCE( jsonb_object_agg(COALESCE(rename,key),j->key),   '{}'::jsonb )
    FROM (SELECT unnest(keys), unnest(renames)) t(key,rename)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_objslice(text,jsonb,text)
  IS 'Get the keys as encapsulated object, with same or changing names.'
;

CREATE or replace FUNCTION  jsonb_objslice(
    keypath jsonpath, j jsonb, keyname text
) RETURNS jsonb AS $f$
    SELECT COALESCE( jsonb_build_object(keyname,j_0), '{}'::jsonb )
    FROM jsonb_path_query_first(j, keypath) t(j_0)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_objslice(text,jsonb,text)
  IS 'Get the first path-result as keyname-result object.'
;

CREATE or replace FUNCTION jsonb_object_keys_asarray(j jsonb) RETURNS text[] AS $f$
  SELECT  array_agg(x) FROM jsonb_object_keys(j) t(x)
$f$ LANGUAGE sql IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- --
-- Extends native functions:

CREATE or replace FUNCTION jsonb_strip_nulls(
  p_input jsonb,      -- any input
  p_ret_empty boolean -- true for normal, false for ret null on empty
) RETURNS jsonb AS $f$
  SELECT CASE
     WHEN p_ret_empty THEN x
     WHEN x='{}'::JSONb THEN NULL
     ELSE x END
  FROM ( SELECT jsonb_strip_nulls(p_input) ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_strip_nulls(jsonb,boolean)
  IS 'Extends jsonb_strip_nulls to return NULL instead empty';


--- JSONb  functions  ---

CREATE or replace FUNCTION jsonb_object_length( jsonb ) RETURNS int AS $f$
  -- Integer because never expect a big JSON, with more tham 10^9 or 2147483647 items
  SELECT count(*)::int FROM jsonb_object_keys($1)  -- faster tham jsonb_each()
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_rename(
  js JSONB, nmold text, nmnew text
) RETURNS jsonb AS $f$
  SELECT js - nmold || jsonb_build_object(nmnew, js->nmold)
$f$ language SQL IMMUTABLE;


---

/**
 * JSON-summable or "merge sum" functions are for JSONb key-numericValue objects (ki objects).
 * They are "key counters", so, to merge two keys, the numericValues must be added.
 * Change the core of jsonb_summable_merge(jsonb,jsonb) to the correct datatype.
 * The JSON "number" is equivalent to the SQL's ::numeric, but can be ::int, ::float or ::bigint.
 * Any invalid or empty JSONb object will be represented as SQL NULL.
 * See https://gist.github.com/ppKrauss/679cea825002076c8697e734763076b9
 */

CREATE or replace FUNCTION jsonb_summable_check(jsonb, text DEFAULT 'numeric') RETURNS boolean AS $f$
  -- CORE function of jsonb_summable_*().
  SELECT not($1 IS NULL OR jsonb_typeof($1)!='object' OR $1='{}'::jsonb)
        AND CASE
          WHEN $2='numeric' OR $2='float' THEN (SELECT bool_and(jsonb_typeof(value)='number') FROM jsonb_each($1))
          ELSE (SELECT bool_and(value ~ '^\d+$') FROM jsonb_each_text($1))
          END
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_summable_values( jsonb ) RETURNS int[] AS $f$
  -- CORE function of jsonb_summable_*().
  -- CHANGE replacing ::int by your choice of type in the jsonb_summable_check(x,choice)
  SELECT array_agg(value::int) from jsonb_each_text($1)
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_summable_maxval( jsonb ) RETURNS bigint AS $f$
  -- CORE function of jsonb_summable_*(), change also the "returns" to bigint or float.
  SELECT max(value::bigint) from jsonb_each_text($1)
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_summable_merge(  jsonb, jsonb ) RETURNS jsonb AS $f$
  -- CORE function of jsonb_summable_*().
  SELECT CASE
    WHEN emp1 AND emp2 THEN NULL
    WHEN emp2 THEN $1
    WHEN emp1 THEN $2
    ELSE $1 || (
      -- CHANGE replacing ::int by your choice of type in the jsonb_summable_check(x,choice)
      SELECT jsonb_object_agg(
          COALESCE(key,'')
          , value::int + COALESCE(($1->>key)::int,0)
        )
      FROM jsonb_each_text($2)
    ) END
  FROM (
   SELECT $1 IS NULL OR jsonb_typeof($1)!='object' OR $1='{}'::jsonb emp1,
          $2 IS NULL OR jsonb_typeof($2)!='object' OR $2='{}'::jsonb emp2
  ) t
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_summable_output(
   p_j jsonb
  ,p_sep text DEFAULT ', '
  ,p_prefix text DEFAULT ''
) RETURNS text AS $f$
  SELECT array_to_string(
    array_agg(concat(p_prefix,key,':',value)) FILTER (WHERE key is not null)
    ,p_sep
  )
  FROM jsonb_each_text(p_j)
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_summable_merge(  jsonb[] ) RETURNS jsonb AS $f$
 DECLARE
  x JSONb;
  j JSONb;
 BEGIN
    IF $1 IS NULL OR array_length($1,1)=0 THEN
      RETURN NULL;
    ELSEIF array_length($1,1)=1 THEN
      RETURN $1[1];
    END IF;
    x := $1[1];
    FOREACH j IN ARRAY $1[2:] LOOP
      x:= jsonb_summable_merge(x,j);
    END LOOP;
    RETURN x;
 END
$f$ LANGUAGE plpgsql IMMUTABLE;

/* bug revisar:
  ERROR:  a column definition list is required for functions returning "record"
  LINE 9:        FROM array_fillto_duo($1,$2) t(a,b)

CREATE or replace FUNCTION jsonb_summable_merge(  jsonb[], jsonb[] ) RETURNS jsonb[] AS $f$
 SELECT CASE
   WHEN $2 IS NULL THEN $1
   WHEN $1 IS NULL THEN $2
   ELSE (
     SELECT array_agg( jsonb_summable_merge(j1,j2) )
     FROM (
       SELECT unnest(a) j1, unnest(b) j2
       FROM array_fillto_duo($1,$2) t(a,b)
     ) t
   ) END
$f$ language SQL IMMUTABLE;
*/

CREATE or replace FUNCTION jsonb_pretty_lines(j_input jsonb, opt int DEFAULT 0) RETURNS text AS $f$
 SELECT CASE opt
   WHEN 0  THEN j_input::text
   WHEN 1  THEN jsonb_pretty(j_input)
   WHEN 2  THEN regexp_replace(regexp_replace(j_input::text, ' ?\{"type": "Feature", "geometry":\n', '{"type": "Feature", "geometry": ', 'g'), ' ?\{"type": "Feature", "geometry":', E'\n{"type": "Feature", "geometry":', 'g') || E'\n'  -- GeoJSON
   WHEN 3  THEN replace(regexp_replace(j_input::text, ' ?\{"type": "Feature", "geometry":\n', '{"type": "Feature", "geometry": ', 'g'),' ','') || E'\n'  -- GeoJSON
   END
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION json_pretty_lines(j_input json, opt int DEFAULT 0) RETURNS text AS $f$
 SELECT CASE opt
   WHEN 0  THEN j_input::text
   WHEN 1  THEN jsonb_pretty(j_input::jsonb)
   WHEN 2  THEN regexp_replace(regexp_replace(j_input::text, ' ?\{"type": "Feature", "geometry":\n', '{"type": "Feature", "geometry": ', 'g'), ' ?\{"type": "Feature", "geometry":', E'\n{"type": "Feature", "geometry":', 'g') || E'\n'  -- GeoJSON
   WHEN 3  THEN replace(regexp_replace(j_input::text, ' ?\{"type": "Feature", "geometry":\n', '{"type": "Feature", "geometry": ', 'g'),' ','') || E'\n'  -- GeoJSON
   END
$f$ language SQL IMMUTABLE;
