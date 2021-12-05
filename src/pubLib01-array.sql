/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Module: array.
 *
 * Complementing https://www.postgresql.org/docs/current/functions-array.html
 */

CREATE or replace FUNCTION pg_csv_head(filename text, separator text default ',', linesize bigint default 9000) RETURNS text[] AS $f$
  SELECT regexp_split_to_array(replace(s,'"',''), separator)
  FROM regexp_split_to_table(  pg_read_file(filename,0,linesize,true),  E'\n') t(s)
  LIMIT 1
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pg_csv_head(text,text,bigint)
  IS 'Devolve array do header de um arquivo CSV com separador estrito, lendo apenas primeiros bytes.'
;

CREATE or replace FUNCTION  pg_csv_head_tojsonb(
  filename text, tolower boolean = false,
  separator text = ',', linesize bigint = 9000,
  is_idx_json boolean = true
) RETURNS jsonb AS $f$
    SELECT  jsonb_object_agg(
      CASE WHEN tolower THEN lower(x) ELSE x END ,
      ordinality - CASE WHEN is_idx_json THEN 1 ELSE 0 END
    )
    FROM unnest( pg_csv_head($1,$3,$4) ) WITH ORDINALITY x
$f$ LANGUAGE SQL IMMUTABLE;
-- exemplo, select x from pg_csv_head_tojsonb('/tmp/pg_io/ENDERECO.csv') t(x);

 ----

CREATE or replace FUNCTION array_last(
  p_input anyarray
) RETURNS anyelement AS $f$
  SELECT $1[array_upper($1,1)]
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION array_last_butnot(
  p_input anyarray,
  p_not anyarray
) RETURNS anyelement AS $f$
  SELECT CASE
     WHEN array_length($1,1)<2 THEN   $1[array_lower($1,1)]
     WHEN p_not IS NOT NULL AND thelast=any(p_not) THEN   $1[x-1]
     ELSE thelast
     END
  FROM (select x,$1[x] thelast FROM (select array_upper($1,1)) t(x)) t2
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION array_last_butnot(
  p_input anyarray,
  p_not anyelement
) RETURNS anyelement AS $wrap$
  SELECT array_last_butnot($1,array[$2])
$wrap$ LANGUAGE SQL IMMUTABLE;


----

--CREATE or replace FUNCTION jsonb_to_bigints( p_j jsonb ) RETURNS bigint[] AS $f$
  --SELECT array_agg(value::text::bigint) jsonb_array_elements($1)
--$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION jsonb_to_bigints( p_j jsonb ) RETURNS bigint[] AS $f$
  SELECT array_agg(value::text::bigint) FROM jsonb_array_elements($1)
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION array_subtract(
  p_a anyarray, p_b anyarray
  ,p_empty_to_null boolean default true
) RETURNS anyarray AS $f$
  SELECT CASE WHEN p_empty_to_null AND x='{}' THEN NULL ELSE x END
  FROM (
    SELECT array(  SELECT unnest(p_a) EXCEPT SELECT unnest(p_b)  )
  ) t(x)
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION public.array_reduce_dim(anyarray)
RETURNS SETOF anyarray AS $f$ -- see https://wiki.postgresql.org/wiki/Unnest_multidimensional_array
DECLARE
    s $1%TYPE;
BEGIN
    FOREACH s SLICE 1  IN ARRAY $1 LOOP
        RETURN NEXT s;
    END LOOP;
    RETURN;
END;
$f$ LANGUAGE plpgsql IMMUTABLE;


CREATE or replace FUNCTION array_fillTo(
    -- see https://stackoverflow.com/a/10518236/287948
    p_array anyarray, p_len integer, p_null anyelement DEFAULT NULL
) RETURNS anyarray AS $f$
   SELECT CASE
       WHEN len=0 THEN array_fill(p_null,array[p_len])
       WHEN len<p_len THEN p_array || array_fill($3,array[$2-len])
       ELSE $1 END
   FROM ( SELECT COALESCE( array_length(p_array,1), 0) ) t(len)
$f$ LANGUAGE SQL IMMUTABLE;


/**
 * Transforms 2 simple non-aligned arrays into a "duo" array of arrays of same size.
 */
CREATE or replace FUNCTION array_fillto_duo(
  anyarray,anyarray,anyelement DEFAULT NULL
) RETURNS table (a anyarray, b anyarray) AS $f$
  SELECT CASE WHEN l1>=l2 THEN $1 ELSE array_fillto($1,l2,$3) END a,
   CASE WHEN l1<=l2 THEN $2 ELSE array_fillto($2,l1,$3) END b
  FROM (SELECT array_length($1,1) l1, array_length($2,1) l2) t
$f$ language SQL IMMUTABLE;


CREATE or replace FUNCTION unnest_2d_1d(
  ANYARRAY, OUT a ANYARRAY
) RETURNS SETOF ANYARRAY AS $func$
 BEGIN
    -- https://stackoverflow.com/a/41405177/287948
    -- IF $1 = '{}'::int[] THEN ERROR END IF;
    FOREACH a SLICE 1 IN ARRAY $1 LOOP
       RETURN NEXT;
    END LOOP;
 END
$func$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE or replace FUNCTION array_sample(
  p_items ANYARRAY,     -- the array to be random-sampled
  p_qt int default NULL -- null is "all" with ramdom order.
) RETURNS ANYARRAY AS $f$
  SELECT array_agg(x)
  FROM (
    SELECT x FROM unnest($1) t2(x)
    ORDER BY random() LIMIT $2
  ) t
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION array_fastsort (
  -- for future when bigint use CREATE EXTENSION intarray; sort(x)
  ANYARRAY
) RETURNS ANYARRAY AS $f$
  SELECT ARRAY(SELECT unnest($1) ORDER BY 1)
$f$ language SQL strict IMMUTABLE;


CREATE or replace FUNCTION array_is_allsame ( ANYARRAY ) RETURNS boolean AS $f$
  SELECT CASE
           WHEN $1 is NULL OR l=0 THEN NULL
           WHEN l=1 THEN true
           ELSE (
             SELECT bool_and($1[1]=x)
             FROM unnest($1[2:]) t1(x)
           )
           END
  FROM (SELECT array_length($1,1)) t2(l)
$f$ language SQL strict IMMUTABLE;


CREATE or replace FUNCTION array_distinct_sort (
  ANYARRAY,
  p_no_null boolean DEFAULT true
) RETURNS ANYARRAY AS $f$
  SELECT CASE WHEN array_length(x,1) IS NULL THEN NULL ELSE x END -- same as  x='{}'::anyarray
  FROM (
  	SELECT ARRAY(
        SELECT DISTINCT x
        FROM unnest($1) t(x)
        WHERE CASE
          WHEN p_no_null  THEN  x IS NOT NULL
          ELSE  true
          END
        ORDER BY 1
   )
 ) t(x)
$f$ language SQL strict IMMUTABLE;

CREATE or replace FUNCTION array_merge_sort(
  ANYARRAY, ANYARRAY, boolean DEFAULT true
) RETURNS ANYARRAY AS $wrap$
  SELECT array_distinct_sort(array_cat($1,$2),$3)
$wrap$ language SQL IMMUTABLE;

CREATE or replace FUNCTION array_cat_distinct(a anyarray, b anyarray) RETURNS anyarray AS $f$
  SELECT CASE WHEN a is null THEN b WHEN b is null THEN a ELSE (
    SELECT a || array_agg(b_i)
    FROM unnest(b) t(b_i)
    WHERE NOT( b_i=any(a) )
  ) END
$f$  LANGUAGE SQL IMMUTABLE;

-----------


/*
to use array[array[k,v],...]::bigint[]   instead jsonb  ... no real optimization.

CREATE or replace FUNCTION bigint2d_find( bigint[], bigint ) RETURNS bigint AS $f$
  SELECT x[2] -- value
  FROM unnest_2d_1d($1) t(x)
  WHERE x[1]=$2  -- key
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION bigint2d_merge_sum(  bigint[], bigint[] ) RETURNS bigint[] AS $f$
 SELECT CASE
   WHEN $2 IS NULL THEN $1
   WHEN $1 IS NULL THEN $2
   ELSE (
     SELECT array_agg(array[  x[1],  x[2] + COALESCE(bigint2d_find($1,x[1]),0)  ])
     FROM unnest_2d_1d($2) t(x)
   ) END
$f$ language SQL IMMUTABLE;

*/

-----


CREATE or replace FUNCTION base36_encode(
  -- adapted from https://gist.github.com/btbytes/7159902
  IN digits bigint -- positive
) RETURNS text AS $f$
  DECLARE
			chars char[] := ARRAY['0','1','2','3','4','5','6','7','8','9'
  			,'A','B','C','D','E','F','G','H','I','J','K','L','M'
  			,'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
			ret text := '';
			val bigint;
  BEGIN
  val := digits;
  WHILE val != 0 LOOP
  	ret := chars[(val % 36)+1] || ret;
  	val := val / 36;
  END LOOP;
  RETURN ret;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE or replace FUNCTION array_distinct_sort (
  ANYARRAY,
  p_no_null boolean DEFAULT true
) RETURNS ANYARRAY AS $f$
  SELECT CASE WHEN array_length(x,1) IS NULL THEN NULL ELSE x END -- same as  x='{}'::anyarray
  FROM (
  	SELECT ARRAY(
        SELECT DISTINCT x
        FROM unnest($1) t(x)
        WHERE CASE
          WHEN p_no_null  THEN  x IS NOT NULL
          ELSE  true
          END
        ORDER BY 1
   )
 ) t(x)
$f$ language SQL strict IMMUTABLE;
