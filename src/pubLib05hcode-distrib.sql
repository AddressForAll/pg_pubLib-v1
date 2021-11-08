/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * HCode is a left-to-right hierarchical code. See http://addressforall.org/_foundations/art1.pdf
 * A typical class of HCodes are the Geocode systems of regular hierarchical grids, as defined in
 *   https://en.wikipedia.org/w/index.php?title=Geocode&oldid=1052536888#Hierarchical_grids
 * Geohash is a typical example of valid HCode for this library.
 *
 * Module: HCode/Distribution.
 * DependsOn: pubLib03-json
 * Prefix: hcode
 * license: CC0
 */

-- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Check prefix in a set of hcode prefixes:

CREATE or replace FUNCTION hcode_prefixset_parse( p_prefixes text[] ) RETURNS text AS $f$  -- ret a regex.
 SELECT string_agg(x,'|')
 FROM (
   SELECT *
   FROM unnest(p_prefixes) t1(x)
   ORDER BY length(x) DESC, x
 ) t2
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION hcode_prefixset_element(
 p_check text,     -- hcode to be checked (if its prefix is in prefix set)
 p_prefixes text[] -- the prefix set
) RETURNS text AS $f$ -- ret the prefix ,or null when not in. Slow, use hcode_prefixset_element(text,text).
 SELECT x
 FROM unnest(p_prefixes) t(x)
 WHERE p_check like (x||'%')
 ORDER BY length(x) desc, x
 LIMIT 1
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_prefixset_element(
 p_check text,           -- hcode to be checked (if its prefix is in prefix set)
 p_prefixeset_regex text -- obtained from prefix set by hcode_prefixset_parse()
) RETURNS text AS $f$ -- ret the prefix ,or null when not in. Faster than hcode_prefixset_element(text,text[]).
 SELECT (regexp_match(p_check, p_prefixeset_regex))[1]
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_prefixset_isin(
  p_check text,           -- hcode to be checked (if its prefix is in prefix set)
  p_prefixeset_regex text -- obtained from prefix set by hcode_prefixset_parse()
) RETURNS boolean AS $wrap$
  SELECT p_check ~ p_prefixeset_regex;
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_prefixset_element_slower(
  p_check text,     -- hcode to be checked (if its prefix is in prefix set)
  p_prefixes text[] -- the prefix set
) RETURNS text AS $wrap$ -- obly to show how to use, and use in ASSERTs and benchmarks.
  SELECT hcode_prefixset_element( p_check, hcode_prefixset_parse(p_prefixes) )
$wrap$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --
-- Distribution-generative functions:

CREATE or replace FUNCTION geocode_distribution_generate(
   -- geocode is a subclass of hcode.
   p_tabname  text,
   p_ispoint  boolean  DEFAULT false,
   p_geom_col text     DEFAULT 'geom',
   p_geocode_size   integer  DEFAULT 5,
   p_geocode_function text DEFAULT 'ST_Geohash'
) RETURNS jsonb AS $f$
DECLARE
  q text;
  ret jsonb;
BEGIN
  q := $$
  SELECT jsonb_object_agg( hcode,n )
  FROM (
    SELECT  hcode, COUNT(*) n
    FROM (
      SELECT
        %s(
          CASE WHEN %s THEN %s ELSE ST_PointOnSurface(%s) END
          ,%s
        ) as hcode
      FROM %s
    ) t2
    GROUP BY 1
    ORDER BY 1
  ) scan
  $$;
  EXECUTE format(
    q,
    p_geocode_function,
    CASE WHEN p_ispoint THEN 'true' ELSE 'false' END,
    p_geom_col, p_geom_col,
    p_geocode_size::text,
    p_tabname
  ) INTO ret;
  RETURN ret;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
-- ex. SELECT geocode_distribution_generate('grade_id04');
--     SELECT geocode_distribution_generate('grade_id04_pts',true);

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --
-- Distribution analytics-functions:

CREATE or replace FUNCTION hcode_distribution_kpis(p_j jsonb) RETURNS jsonb AS $f$
  -- Key Performance Indicators (KPIs) for distribution analysis
  SELECT jsonb_build_object(
    'keys_n',  MAX( jsonb_object_length(p_j) ), --constant, number of keys
    'n_tot', SUM(n::int)::int,  -- total of n
    'n_avg', ROUND(AVG(n::int))::int,  -- average of n
    'n_dev', ROUND(STDDEV_POP(n::int))::int,  -- standard deviation of n, from average
    'n_mdn', percentile_disc(0.5) WITHIN GROUP (ORDER BY n::int),  -- median
    'n_mad', null, -- see  https://en.wikipedia.org/wiki/Median_absolute_deviation
    'n_min', MIN(n::int), -- minimum n
    'n_max', MAX(n::int)  -- maximum n
    )
  FROM  jsonb_each(p_j) t(hcode,n) -- unnest key-value pairs preserving the datatype of values.
$f$ LANGUAGE SQL;

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --
-- Distribution analytics-report functions:

CREATE or replace FUNCTION hcode_distribution_format(
  p_j jsonb,
  p_perc boolean DEFAULT true,
  p_glink text DEFAULT '', -- ex. http://git.AddressForAll.org/out-BR2021-A4A/blob/main/data/SP/RibeiraoPreto/_pk058/via_
  p_sep text DEFAULT ', '
) RETURNS text AS $f$
  WITH scan AS (SELECT hcode,n::int as n FROM jsonb_each(p_j) t1(hcode,n) ORDER BY hcode)
  SELECT string_agg(
          CASE
            WHEN p_glink>'' THEN  '<a href="'||p_glink||hcode||'.geojson"><code>'||hcode||'</code></a>: '
            ELSE  '<code>'||hcode||'</code>: '
          END || CASE WHEN p_perc THEN round(100.0*n/tot)::int::text ELSE n::text END || '%'
         , p_sep )
  FROM  scan , (SELECT SUM(n::int) tot FROM scan) t2
$f$ LANGUAGE SQL;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Distribution analytic-rebuild functions:

CREATE or replace FUNCTION hcode_distribution_reduce_pre_raw(
  p_j jsonb,
  p_left_erode int DEFAULT 1,
  p_size_min int DEFAULT 1,
  p_threshold int DEFAULT NULL,     -- conditional reducer
  p_threshold_sum int DEFAULT NULL, -- conditional backtracking
  p_percentile float DEFAULT 0.5    -- fraction of percentile (default 0.5 for median)
)  RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j jsonB) AS $f$
WITH preproc AS (
 SELECT CASE
        WHEN p_threshold IS NULL OR n<p_threshold THEN
         substr(hcode,1,CASE WHEN size>=p_size_min THEN size ELSE p_size_min END)
        ELSE hcode
      END AS hcode,
      SUM(n)::int AS n,
      percentile_disc(0.5) WITHIN GROUP (ORDER BY n) AS mdn_items,
      COUNT(*) AS n_keys,
      jsonb_object_agg(hcode,n) as backup
 FROM (
   SELECT hcode, n::int n, length(hcode)-p_left_erode AS size
   FROM  jsonb_each(p_j) t(hcode,n)
 ) t
 GROUP BY 1
)

  SELECT hcode, n, mdn_items, n_keys, NULL as j
  FROM preproc
  WHERE p_threshold_sum IS NULL OR n<p_threshold_sum

  UNION
  -- below for use in https://en.wikipedia.org/wiki/Backtracking
  SELECT hcode||'*', n, mdn_items, n_keys, backup
  FROM preproc
  WHERE p_threshold_sum IS NOT NULL AND n>=p_threshold_sum

  ORDER BY 1
$f$ LANGUAGE SQL IMMUTABLE;

-- Exemples without backtracking:
--  SELECT * FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts'), 22, 2);
--  SELECT * FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts') );
--  SELECT * FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts'), 1, 1, 30 );
--  SELECT * FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts'), 1, 1, 300 );
-- Exemple with backtracking:
--  SELECT hcode, n_items, mdn_items, n_keys FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts'), 3, 1, 500, 5000 );
--  SELECT * FROM hcode_distribution_reduce_raw( generate_geohashes('grade_id04_pts'), 2, 1, 500, 5000 );

-- ...Next:
--   1. develop heuristic for geohash_distribution_reduce_balanced() RETURNS JSONb, for threshold-balanced distribuition.
--      ... and percentile-balanced ...
--   2. develop heuristic for geohash_distribution_reduce_balanced() RETURNS JSONb, for unbalanced distribuition.
--   3. develop heuristic for geohash_distribution_reduce() RETURNS JSONb, for n-key reduction.

-- TESTE DIDATICO, NAO USAR SERIAMENTE:
CREATE or replace FUNCTION hcode_distribution_reduce_LIXO(
  p_j jsonb,
  p_left_erode int DEFAULT 1,
  p_size_min int DEFAULT 1,
  p_threshold int DEFAULT NULL,    -- conditional reducer
  p_threshold_sum int DEFAULT NULL, -- conditional backtracking
  p_heuristic int DEFAULT 1   -- algorithm options
)  RETURNS JSONb AS $f$
  WITH t AS (
    SELECT *
    FROM hcode_distribution_reduce_pre_raw( p_j, p_left_erode, p_size_min, p_threshold, p_threshold_sum )
  )
  SELECT jsonb_object_agg(hcode, n_items)
  FROM (
    SELECT hcode, n_items FROM t
    WHERE j IS NULL

    UNION ALL

    SELECT q.hcode, q.n_items
    FROM t, LATERAL (
      SELECT * FROM hcode_distribution_reduce_LIXO(
         t.j,
         p_left_erode - 1,
         p_size_min,
         p_threshold,
         p_threshold_sum
       ) ) q
    WHERE p_heuristic=1 AND t.j IS NOT NULL

    UNION ALL

    SELECT q.hcode, q.n_items
    FROM t, LATERAL (
      SELECT * FROM hcode_distribution_reduce_LIXO(
         t.j,
         p_left_erode - 1,
         p_size_min,
         round(p_threshold*0.85)::int,
         round(p_threshold_sum*0.85)::int
       ) ) q
    WHERE p_heuristic=2 AND t.j IS NOT NULL

       UNION ALL

    SELECT q.hcode, q.n_items
    FROM t, LATERAL (
      SELECT * FROM hcode_distribution_reduce_LIXO(
         t.j,
         1,
         p_size_min,
         p_threshold,
         p_threshold_sum
       ) ) q
    WHERE p_heuristic=3 AND t.j IS NOT NULL
   
    ORDER BY 1
  ) tfull
$f$ LANGUAGE SQL IMMUTABLE;

-- SELECT q.key AS gid, value::int as n_items, ST_GeomFromGeoHash(q.key) as geom  
-- FROM hcode_distribution_reduce_LIXO( generate_geohashes('grade_id04_pts'), 2, 1, 500, 5000, 2) t(x), LATERAL jsonb_each(x) q;
-- .. FROM hcode_distribution_reduce_LIXO( generate_geohashes('grade_id04_pts'), 2, 1, 500, 5000, 3) t(x), LATERAL jsonb_each(x) q;


-- função em construção, falta testar e aprimorar:
CREATE or replace FUNCTION hcode_distribution_reduce_recursive_raw(
  p_j jsonb,
  p_left_erode int DEFAULT 1,
  p_size_min int DEFAULT 1,
  p_threshold int DEFAULT NULL,    -- conditional reducer
  p_threshold_sum int DEFAULT NULL, -- conditional backtracking
  p_heuristic int DEFAULT 1,   -- algorithm options
  ctrl_recursions smallint DEFAULT 1
)  RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j JSONb) AS $f$
  DECLARE
    lst_heuristic text;
    lst_pre       text;
  BEGIN
   IF ctrl_recursions >5 THEN
      RETURN QUERY
        SELECT 
        hcode_distribution_reduce_pre_raw( p_j, p_left_erode, p_size_min, p_threshold, p_threshold_sum );
   ELSE
      lst_pre := format(
          '%L::jsonB, %s, %s, %s, %s',
          p_j::text, p_left_erode::text, p_size_min::text, p_threshold::text, p_threshold_sum::text
      );
      lst_heuristic := CASE p_heuristic
         -- p_left_erode                  p_size_min                 p_threshold                  p_threshold_sum
         
         -- H1. heuristica básica:
         WHEN 1 THEN format($$
	    %s - 1,                       %s,                        %s,                           %s
         $$, p_left_erode::text, p_size_min::text, p_threshold::text, p_threshold_sum::text)
         
         -- H2. básica com redução dos thresholds:
         WHEN 2 THEN format($$
            %s - 1,                       %s,                        round(%s*0.85)::int,         round(%s*0.85)::int
         $$, p_left_erode::text, p_size_min::text, p_threshold::text, p_threshold_sum::text)
         
         -- H3. variação da básica com erosão sempre unitária:
         WHEN 3 THEN format($$
            1,                            %s,                       %s,                           %s
         $$, p_size_min::text, p_threshold::text, p_threshold_sum::text)
         END;
         
      RETURN QUERY EXECUTE format($$
          WITH t AS (
	      SELECT * FROM hcode_distribution_reduce_pre_raw( %s )
	   )
	   
	    SELECT  *  FROM t
	    WHERE t.j IS NULL
	    
	    UNION ALL
	    
	    SELECT q.* FROM t,
	     LATERAL (   SELECT * FROM hcode_distribution_reduce_recursive_raw( t.j, %s, %s+1 )   ) q
	    WHERE t.j IS NOT NULL
         $$,
         lst_pre,
         lst_heuristic,
         ctrl_recursions::text
        );
      END IF;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
