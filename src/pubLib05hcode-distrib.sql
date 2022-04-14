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
   p_relation  text, -- 'or something as (SELECT *  FROM t LIMIT 10)'
   p_geocode_size   integer, -- 0 or NULL is full
   p_sum  boolean  DEFAULT false
) RETURNS jsonB AS $f$
DECLARE
  q text;
  ret jsonB;
BEGIN
  q := $$
  SELECT jsonb_object_agg( hcode,n )
  FROM (
    SELECT substring(hcode,1,%s) AS hcode, %s
    FROM %s t(hcode)
    GROUP BY 1
    ORDER BY 1
  ) scan
  $$;
  EXECUTE format(
    q,
    p_geocode_size,
    CASE WHEN p_sum THEN $$SUM((info->'bytes')::bigint) n$$ ELSE 'COUNT(*) n' END,
    p_relation
    ) INTO ret;
  RETURN ret;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;

CREATE or replace FUNCTION geocode_distribution_generate(
   -- geocode is a subclass of hcode.
   p_tabname  text,
   p_ispoint  boolean  DEFAULT false,
   p_geom_col text     DEFAULT 'geom',
   p_geocode_size   integer  DEFAULT 5,
   p_geocode_function text DEFAULT 'ST_Geohash',
   p_sum  boolean  DEFAULT false
) RETURNS jsonB AS $f$
DECLARE
  q text;
  ret jsonB;
BEGIN
  q := $$
  SELECT jsonb_object_agg( hcode,n )
  FROM (
    SELECT  hcode,  %s
    FROM (
      SELECT
        %s(
          CASE WHEN %s THEN %s ELSE ST_PointOnSurface(%s) END
          ,%s
        ) as hcode %s
      FROM %s
    ) t2
    GROUP BY 1
    ORDER BY 1
  ) scan
  $$;
  EXECUTE format(
    q,
    CASE WHEN p_sum THEN $$SUM((info->'bytes')::bigint) n$$ ELSE 'COUNT(*) n' END,
    p_geocode_function,
    CASE WHEN p_ispoint THEN 'true' ELSE 'false' END,
    p_geom_col, p_geom_col,
    p_geocode_size::text,
    CASE WHEN p_sum THEN ', info' ELSE '' END,
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

CREATE or replace FUNCTION hcode_distribution_kpis(p_j jsonB) RETURNS jsonB AS $f$
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
  p_j jsonB,
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
  p_j jsonB,
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
      COUNT(*)::int AS n_keys,
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
-- ...Next:
--   1. develop heuristic for geohash_distribution_reduce_balanced() RETURNS jsonB, for threshold-balanced distribuition.
--      ... and percentile-balanced ...
--   2. develop heuristic for geohash_distribution_reduce_balanced() RETURNS jsonB, for unbalanced distribuition.
--   3. develop heuristic for geohash_distribution_reduce() RETURNS jsonB, for n-key reduction.


CREATE or replace FUNCTION hcode_distribution_reduce_recursive_raw(
  p_j             jsonB,             -- 1. input pairs {$hcode:$n_items}
  p_left_erode    int DEFAULT 1,     -- 2. number of charcters to drop from left to right
  p_size_min      int DEFAULT 1,     -- 3. minimal size of hcode
  p_threshold     int DEFAULT NULL,  -- 4. conditional reducer
  p_threshold_sum int DEFAULT NULL,  -- 5. conditional backtracking
  p_heuristic     int DEFAULT 1,     -- 6. algorithm options 1-6, zero is no recursion.
  ctrl_recursions smallint DEFAULT 1 -- 7. recursion counter
)  RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j jsonB) AS $f$
  DECLARE
    lst_heuristic text;
    lst_pre       text;
  BEGIN

   IF  COALESCE(p_heuristic,0)=0 OR ctrl_recursions>50 THEN --  OR p_heuristic>3
      RETURN QUERY
        SELECT * FROM
        hcode_distribution_reduce_pre_raw( p_j, p_left_erode, p_size_min, p_threshold, p_threshold_sum );

   ELSE
      lst_pre := format(
          '%L::jsonB, %s, %s, %s, %s',
          p_j::text, p_left_erode::text, p_size_min::text, p_threshold::text, p_threshold_sum::text
      );

      lst_heuristic := format(
        CASE p_heuristic
          --   2.p_left_erode                3.p_size_min              4.p_threshold                 5.p_threshold_sum
          WHEN 1 THEN -- H01. heuristica básica:
           $$  %5$s - 1,                     %2$s,                      %3$s,                         %4$s  $$
          WHEN 2 THEN -- H02. básica com redução dos thresholds:
           $$  %5$s - 1,                     %2$s,                      round(%3$s*0.85)::int,       round(%4$s*0.85)::int  $$
          WHEN 3 THEN -- H03. variação da básica com erosão unitária:
           $$  1,                            %2$s,                      %3$s,                         %4$s   $$
          WHEN 4 THEN -- H04. básica com redução dos thresholds e erosão unitária:
           $$  1,                            %2$s,                      round(%3$s*0.85)::int,       round(%4$s*0.85)::int  $$
          WHEN 5 THEN -- H05. heuristica básica com erosão constante:
           $$  %1$s,                         %2$s,                      %3$s,                         %4$s  $$
          ELSE        -- H06. básica com redução dos thresholds e erosão constante:
           $$  %1$s,                         %2$s,                      round(%3$s*0.85)::int,       round(%4$s*0.85)::int  $$
        END,
        p_left_erode::text,                  p_size_min::text,          p_threshold::text,            p_threshold_sum::text,
        iif(p_size_min<=1,p_size_min+1,p_size_min)::text
      );

      RETURN QUERY EXECUTE format($$
          WITH t AS ( SELECT * FROM hcode_distribution_reduce_pre_raw(%1$s) )

            SELECT hcode,
                   SUM(n_items)::int AS n_items,
                   round(AVG(mdn_items))::int AS mdn_items,
                   SUM(n_keys)::int AS n_keys,
                   NULL::jsonB as j
            FROM (
              -- Accepted rows:
              SELECT  *
              FROM t
              WHERE t.j IS NULL AND (%5$s IS NULL OR n_items>=%5$s)

              UNION ALL

              -- Erode more (but can fail with no p_threshold_sum backtrack) and joins with accepted rows:
              SELECT *
              FROM hcode_distribution_reduce_recursive_raw(
                ( SELECT jsonb_object_agg(hcode,n_items) FROM t WHERE t.j IS NULL AND n_items<%5$s ),
                %2$s, %3$s, (%4$s+1)::smallint
              )

              UNION ALL

              -- Backtracking non-accepted rows:
        	    SELECT q.* FROM t,
        	     LATERAL (   SELECT * FROM hcode_distribution_reduce_recursive_raw( t.j, %2$s, %3$s, (%4$s+1)::smallint )   ) q
        	    WHERE t.j IS NOT NULL
            ) t2
            GROUP BY hcode ORDER BY hcode
         $$,
         lst_pre,              -- %$1
         lst_heuristic,        -- %$2 = p2 left_erode, p3 size_min, p4 threshold, p5 threshold_sum
         p_heuristic::text,    -- %$3 = p6
         ctrl_recursions::text,-- %$4 = p7
         p_threshold::text     -- %5$
        );
      END IF;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
-- e.g. BeloHorizonte:   hcode_distribution_reduce_recursive_raw(geocode_distribution_generate('tmp_lixo2',7), 1, 2, 750, 8000, 3) 
-- e.g. IBGE grid for QGIS:
--  SELECT hcode as gid, hcode || ' ' || n_items AS name, ST_GeomFromGeoHash(replace(hcode,'','')) AS geom
--  FROM hcode_distribution_reduce_recursive_raw(geocode_distribution_generate('grade_id04_pts',true), 2, 1, 500, 5000, 2);

CREATE FUNCTION hcode_distribution_reduce_recursive_raw(
  p_j              jsonB,              -- 1. input pairs {$hcode:$n_items}
  p_left_erode     int DEFAULT 1,      -- 2. number of charcters to drop from left to right
  p_size_min       int DEFAULT 1,      -- 3. minimal size of hcode
  hcode_parameters jsonb DEFAULT NULL, -- 4. hcode_distribution_parameters
  ctrl_recursions  smallint DEFAULT 1  -- 5. recursion counter
) RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j jsonB) AS $wrap$
   SELECT hcode_distribution_reduce_recursive_raw($1, $2, $3, (hcode_parameters->'p_threshold')::int, (hcode_parameters->'p_threshold_sum')::int, (hcode_parameters->'p_heuristic')::int, $5)
$wrap$ LANGUAGE SQL;

CREATE or replace FUNCTION hcode_distribution_reduce(
  p_j             jsonB,             -- 1. input pairs {$hcode:$n_items}
  p_left_erode    int DEFAULT 1,     -- 2. number of charcters to drop from left to right
  p_size_min      int DEFAULT 1,     -- 3. minimal size of hcode
  p_threshold     int DEFAULT NULL,  -- 4. conditional reducer
  p_threshold_sum int DEFAULT NULL,  -- 5. conditional backtracking
  p_heuristic     int DEFAULT 1      -- 6. algorithm options 1-6, zero is no recursion.
)  RETURNS jsonB AS $wrap$
  SELECT jsonb_object_agg(hcode, n_items)
  FROM hcode_distribution_reduce_recursive_raw($1,$2,$3,$4,$5,$6)
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_distribution_reduce(
  p_j              jsonB,             -- 1. input pairs {$hcode:$n_items}
  p_left_erode     int DEFAULT 1,     -- 2. number of charcters to drop from left to right
  p_size_min       int DEFAULT 1,     -- 3. minimal size of hcode
  hcode_parameters jsonb DEFAULT NULL -- 4. hcode_distribution_parameters
)  RETURNS jsonB AS $wrap$
  SELECT jsonb_object_agg(hcode, n_items)
  FROM hcode_distribution_reduce_recursive_raw($1,$2,$3,(hcode_parameters->'p_threshold')::int, (hcode_parameters->'p_threshold_sum')::int, (hcode_parameters->'p_heuristic')::int)
$wrap$ LANGUAGE SQL IMMUTABLE;

-- Função em teste, buscam reduzir em até 10 geohashes

--Exemplo:
--SELECT * FROM hcode_signature_reduce(geocode_distribution_generate('grade_id04_pts',true), null, 2, .7,1);
--SELECT * FROM hcode_signature_reduce_recursive_raw(geocode_distribution_generate('grade_id04_pts',true), null, 2, .7,1);


CREATE or replace FUNCTION hcode_signature_reduce_pre_raw(
  p_j jsonB,
  p_left_erode int DEFAULT 1,
  p_size_min int DEFAULT 1,
  p_percentile float DEFAULT 0.5    -- fraction of percentile (default 0.5 for median)
)  RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j jsonB) AS $f$

WITH
j_each AS (
  SELECT hcode, n::int n, 5-p_left_erode AS size
  FROM  jsonb_each(p_j) t(hcode,n)
),
perc AS (
  SELECT percentile_disc(p_percentile) WITHIN GROUP (ORDER BY n) as mdn_items
  FROM j_each
),
preproc AS (
  SELECT CASE
        WHEN n<=(SELECT mdn_items FROM perc) THEN
         substr(hcode,1,CASE WHEN size>=p_size_min THEN size ELSE p_size_min END)
        ELSE hcode
      END AS hcode,
      SUM(n)::int AS n,
      (SELECT mdn_items FROM perc) AS mdn_items,
      COUNT(*)::int AS n_keys,
      jsonb_object_agg(hcode,n) as backup
  FROM j_each
  GROUP BY 1
)

  SELECT hcode, n, mdn_items, n_keys, backup
  FROM preproc
  ORDER BY 1
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION hcode_signature_reduce_recursive_raw(
  p_j jsonB,
  p_left_erode int DEFAULT 1,
  p_size_min int DEFAULT 1,
  p_percentile    real DEFAULT 0.75,
  p_heuristic int DEFAULT 1,   -- algorithm options
  ctrl_recursions smallint DEFAULT 0
)  RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j jsonB) AS $f$
  DECLARE
    lst_heuristic text;
    lst_pre       text;
    ghs_len int;
    len int;
  BEGIN
   len := jsonb_object_length(p_j);

   -- incremonto de ctrl_recursions implica na erosão de 1 caracter do geohash
   IF  COALESCE(p_heuristic,0)=0 OR ctrl_recursions>4 OR len <= 10 THEN
      RETURN QUERY
        SELECT * FROM
        hcode_signature_reduce_pre_raw( p_j, ctrl_recursions::int, p_size_min, p_percentile );
   ELSE
      lst_pre := format(
          '%L::jsonB, %s, %s, %s',
          p_j::text, ctrl_recursions::text, p_size_min::text, p_percentile::text
      );
      lst_heuristic := CASE p_heuristic
         -- p_left_erode                  p_size_min                 p_percentile

         -- H1. heurística básica:
         WHEN 1 THEN format($$
	    %s,                       %s,                        %s
         $$, ctrl_recursions::text, p_size_min::text, p_percentile::text)

         -- H3. variação da básica com erosão sempre unitária:
         WHEN 3 THEN format($$
            1,                            %s,                       %s
         $$, p_size_min::text, p_percentile::text)
         END;

      RETURN QUERY EXECUTE format($$
          WITH t AS (
	      SELECT jsonb_object_agg(hcode,n_items) AS j FROM hcode_signature_reduce_pre_raw( %s )
	   )

	    SELECT q.* FROM t,
	     LATERAL ( SELECT * FROM hcode_signature_reduce_recursive_raw( t.j, %s, %s, (%s+1)::smallint ) ) q
         $$,
         lst_pre,
         lst_heuristic,
         p_heuristic::text,
         ctrl_recursions::text
        );
      END IF;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;


CREATE or replace FUNCTION hcode_signature_reduce(
  p_j             jsonB,             -- 1. input pairs {$hcode:$n_items}
  p_left_erode    int  DEFAULT 1,    -- 2. number of charcters to drop from left to right
  p_size_min      int  DEFAULT 1,    -- 3. minimal size of hcode
  p_percentile    real DEFAULT 0.75, -- 4.
  p_heuristic     int  DEFAULT 1     -- 5. algorithm options 1-3, zero is no recursion.
) RETURNS jsonB AS $wrap$
  SELECT jsonb_object_agg(hcode, n_items)
  FROM hcode_signature_reduce_recursive_raw($1,$2,$3,$4,$5)
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_signature_reduce(
  p_j             jsonB,              -- 1. input pairs {$hcode:$n_items}
  p_left_erode    int  DEFAULT 1,     -- 2. number of charcters to drop from left to right
  p_size_min      int  DEFAULT 1,     -- 3. minimal size of hcode
  hcode_parameters jsonb DEFAULT NULL -- 4. hcode_signature_parameters
) RETURNS jsonB AS $wrap$
  SELECT jsonb_object_agg(hcode, n_items)
  FROM hcode_signature_reduce_recursive_raw($1,$2,$3,(hcode_parameters->'p_percentile')::real,(hcode_parameters->'p_heuristic')::int)
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_distribution_reduce_pre_raw_alt(
    p_j             jsonB,               -- 1. input pairs {$hcode:$n_items}
    p_left_erode    int    DEFAULT 1,    -- 2. number of charcters to drop from left to right
    p_size_min      int    DEFAULT 1,    -- 3. minimal size of hcode
    p_size_max      int    DEFAULT 1,    -- 5. max size of hcode
    p_threshold_sum int    DEFAULT NULL  -- 6. byte size of bucket
) RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j boolean, jj text[]) AS $f$
    WITH
    b AS (
        SELECT *,
               MAX(sum_hcodeb) OVER (PARTITION BY substr(hcode,1,length(hcode)-(p_size_max-p_size_min-1)) ) AS max_hcodeb
        FROM (
                SELECT  hcode,
                        n::int n,
                        length(hcode)-(p_size_max-p_size_min) AS size,
                        SUM(n::int) OVER (PARTITION BY substr(hcode,1,length(hcode)-(p_size_max-p_size_min-1)) ORDER BY hcode) AS sum_hcodeb
                FROM  jsonb_each(p_j) t(hcode,n) 
                WHERE length(hcode)-(p_size_max-p_size_min) >= 0
            ) a
    ),
    e AS (
        SELECT hcodea,
               hcodeb,
               max_hcodeb,
               SUM(max_hcodeb) OVER (PARTITION BY hcodea ORDER BY max_hcodeb ) AS sum_max_hcodeb
        FROM (
                SELECT hcodea,
                    hcodeb,
                    MAX(max_hcodeb)  AS max_hcodeb
                FROM (
                        SELECT hcode,
                            substr(hcode,1,length(hcode)-(p_size_max-p_size_min  )) hcodea,
                            substr(hcode,1,length(hcode)-(p_size_max-p_size_min-1)) hcodeb,
                            max_hcodeb
                        FROM b
                    ) c
                GROUP BY 1,2
                ORDER BY max_hcodeb
            ) d
    ),
    g AS (
        SELECT  CASE
                    WHEN sum_max_hcodeb < p_threshold_sum
                    THEN substr(hcode,1,size)
                    ELSE hcode
                END AS hcode,
                SUM(n)::int AS n,
                percentile_disc(0.5) WITHIN GROUP (ORDER BY n) AS mdn_items,
                COUNT(*)::int AS n_keys,
                array_agg(hcode) as hcode_agg
        FROM (
                SELECT *
                FROM b
                LEFT JOIN e
                ON      e.hcodea=substr(hcode,1,length(hcode)-(p_size_max-p_size_min  )) 
                    AND e.hcodeb=substr(hcode,1,length(hcode)-(p_size_max-p_size_min-1))
            ) f
        GROUP BY 1
    )
    SELECT hcode,
            n,
            mdn_items,
            n_keys,
            CASE
                WHEN length(hcode) = p_size_min THEN TRUE
                ELSE FALSE
            END AS j,
            hcode_agg
    FROM g
    ORDER BY 1
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION hcode_distribution_reduce_recursive_pre_raw_alt(
    p_j             jsonB,               -- 1. input pairs {$hcode:$n_items}
    p_left_erode    int    DEFAULT 1,    -- 2. number of charcters to drop from left to right
    p_size_min      int    DEFAULT 1,    -- 3. minimal size of hcode
    p_size_max      int    DEFAULT 1,    -- 5. max size of hcode
    p_threshold_sum int    DEFAULT NULL  -- 6. byte size of bucket
) RETURNS TABLE (hcode text, n_items int, mdn_items int, n_keys int, j boolean, jj text[]) AS $f$
    BEGIN
    IF p_size_min = p_size_max THEN
        RETURN QUERY
            SELECT *
            FROM hcode_distribution_reduce_pre_raw_alt( p_j, p_left_erode, p_size_min, p_size_max, p_threshold_sum );
    ELSE
        RETURN QUERY
            WITH t AS (
                SELECT * FROM hcode_distribution_reduce_pre_raw_alt(p_j, p_left_erode, p_size_min, p_size_max, p_threshold_sum)
            )
            SELECT  *
            FROM t
            WHERE t.j IS TRUE

            UNION ALL

            SELECT *
            FROM hcode_distribution_reduce_recursive_pre_raw_alt( (SELECT jsonb_object_agg(t.hcode,t.n_items) FROM t WHERE t.j IS FALSE), p_left_erode, p_size_min+1, p_size_max, p_threshold_sum )
            ;
    END IF;
    END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;


CREATE or replace FUNCTION hcode_distribution_reduce_recursive_raw_alt(
    p_j             jsonB,               -- 1. input pairs {$hcode:$n_items}
    p_left_erode    int    DEFAULT 1,    -- 2. number of charcters to drop from left to right
    p_size_min      int    DEFAULT 1,    -- 3. minimal size of hcode
    p_size_max      int    DEFAULT 1,    -- 5. max size of hcode
    p_threshold_sum int    DEFAULT NULL, -- 6. byte size of bucket
    p_threshold_min int    DEFAULT 1000  -- 7. minimum value. default value refers to points
) RETURNS TABLE (hcode text, n_items bigint, mdn_items bigint, n_keys bigint, j boolean, jj text[]) AS $f$
    SELECT  s.hcode,
            SUM(s.n_items) AS n_items,
            MAX(s.mdn_items::bigint) AS mdn_items,
            SUM(s.n_keys) AS n_keys,
            TRUE,
            array_concat_agg(s.jj)
    FROM (
        SELECT  CASE
                    WHEN r.n_items           < p_threshold_min
                         AND length(r.hcode) > p_size_min
                    THEN substr(r.hcode,1,length(r.hcode)-1)
                    ELSE r.hcode
                END AS hcode,
                r.n_items,
                r.mdn_items,
                r.n_keys,
                r.j,
                r.jj
        FROM hcode_distribution_reduce_recursive_pre_raw_alt( p_j, p_left_erode, p_size_min, p_size_max, p_threshold_sum ) r
    ) s
    GROUP BY 1;
$f$ LANGUAGE SQL IMMUTABLE;
