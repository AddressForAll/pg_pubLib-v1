
-- -- -- -- -- -- -- --
-- Casts, str_to_something:

CREATE or replace FUNCTION to_bigint(str text) RETURNS bigint as $f$
  SELECT CASE WHEN s='' THEN NULL::int ELSE s::bigint END
  FROM (SELECT regexp_replace(str, '[^0-9]', '','g')) t(s) 
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION to_integer(str text) RETURNS int as $f$
  SELECT CASE WHEN s='' THEN NULL::int ELSE s::int END
  FROM (SELECT regexp_replace(str, '[^0-9]', '','g')) t(s) 
$f$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- --
-- Array-aggregators:

-- string lib??

CREATE or replace FUNCTION to_hex( p_x bigint[], p_fill_zeros int DEFAULT NULL) RETURNS text[] AS $f$
  SELECT array_agg( CASE WHEN $2>0 THEN lpad(x,p_fill_zeros,'0') ELSE x END )
  FROM (SELECT to_hex(x) x FROM unnest($1) t1(x)) t
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION  stragg_prefix(prefix text, s text[], sep text default ',') RETURNS text AS $f$
  SELECT string_agg(x,sep) FROM ( select prefix||(unnest(s)) ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION str_urldecode(p text) RETURNS text AS $f$
 SELECT convert_from(CAST(E'\\x' || string_agg(
    CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex')
    ELSE substring(r.m[1] from 2 for 2)
 END, '') AS bytea), 'UTF8')
FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m);
  -- adapted from https://stackoverflow.com/a/8494602/287948
$f$ LANGUAGE SQL IMMUTABLE;
