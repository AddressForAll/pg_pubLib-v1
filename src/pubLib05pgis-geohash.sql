/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * Module: PostGIS/Geohash.
 * DependsOn: pubLib03-json
 * Prefix: geohash_
 * license: CC0
 */

CREATE or replace FUNCTION geohash_generate(
   p_tabname  text,
   p_geom_col text     DEFAULT 'geom',
   p_ispoint  boolean  DEFAULT false,
   ghs_size   integer  DEFAULT 5
) RETURNS jsonb AS $f$
DECLARE
  q text;
  ret jsonb;
BEGIN
  q := $$
  SELECT jsonb_object_agg( ghs,n )
  FROM (
    SELECT  ghs, COUNT(*) n
    FROM (
      SELECT
        ST_Geohash(
          CASE WHEN %s THEN %s ELSE ST_PointOnSurface(%s) END
          ,%s
        ) as ghs
      FROM %s
    ) t2
    GROUP BY 1
    ORDER BY 1
  ) scan
  $$;
  EXECUTE format(
    q,
    CASE WHEN p_ispoint THEN 'true' ELSE 'false' END,
    p_geom_col, p_geom_col,
    ghs_size::text,
    p_tabname
  ) INTO ret;
  RETURN ret;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
-- ex. SELECT generate_geohashes('grade_id04');

CREATE or replace FUNCTION geohash_checkprefix(
  p_check text, p_prefixes text[]
) RETURNS text AS $f$
  SELECT x
  FROM unnest(p_prefixes) t(x)
  WHERE p_check like (x||'%')
  ORDER BY length(x) desc, x
  LIMIT 1
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION geohash_distribution_tots(p_j jsonb) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'keys',  MAX( jsonb_object_length(p_j) ), --constant
    'n_tot', SUM(n::int)::int,
    'n_avg', ROUND(AVG(n::int))::int,
    'n_dev', ROUND(STDDEV_POP(n::int))::int,
    'n_median', percentile_disc(0.5) WITHIN GROUP (ORDER BY n::int),
    'n_min', MIN(n::int),
    'n_max', MAX(n::int)
    )
  FROM  jsonb_each(p_j) t(ghs,n)
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION geohash_distribution_format(
  p_j jsonb,
  p_perc boolean DEFAULT true,
  p_glink text DEFAULT '', -- ex. http://git.AddressForAll.org/out-BR2021-A4A/blob/main/data/SP/RibeiraoPreto/_pk058/via_
  p_sep text DEFAULT ', '
) RETURNS text AS $f$
  WITH scan AS (SELECT ghs,n::int as n FROM jsonb_each(p_j) t1(ghs,n) ORDER BY ghs)
  SELECT string_agg(
          CASE
            WHEN p_glink>'' THEN  '<a href="'||p_glink||ghs||'.geojson"><code>'||ghs||'</code></a>: '
            ELSE  '<code>'||ghs||'</code>: '
          END || CASE WHEN p_perc THEN round(100.0*n/tot)::int::text ELSE n::text END || '%'
         , p_sep )
  FROM  scan , (SELECT SUM(n::int) tot FROM scan) t2
$f$ LANGUAGE SQL;


CREATE or replace FUNCTION geohash_distribution_summary(
  p_j jsonb,
  p_ghs_size int DEFAULT 6, -- 5 para áreas
  p_len_max int DEFAULT 10,
  p_percentile real DEFAULT 0.75,
  p_limite_n int DEFAULT NULL
) RETURNS jsonb AS $f$
  DECLARE
    len int;
    ghs_len int;
    newdistrib jsonb;
  BEGIN
  ghs_len := jsonb_object_keys_maxlength(p_j);
  IF p_ghs_size >= ghs_len THEN
    p_ghs_size := p_ghs_size-1;
  END IF;
  len := jsonb_object_length(p_j);

  IF p_ghs_size<1 OR p_len_max<2 OR len<=p_len_max THEN
    RETURN p_j;
  END IF;

  IF p_limite_n IS NULL THEN
    WITH
    j_each AS (
        SELECT ghs, n::int n
        FROM  jsonb_each(p_j) t(ghs,n) ORDER BY n
    ),
    perc AS (
        SELECT percentile_disc(p_percentile) WITHIN GROUP (ORDER BY n) as pct
        FROM j_each
    )
    SELECT  jsonb_object_agg( ghs,n ) INTO newdistrib
    FROM (
            SELECT ghs, n
            FROM j_each, perc
            WHERE n>=pct

            UNION

            SELECT substr(ghs,1,p_ghs_size), SUM(n) as n
            FROM j_each, perc
            WHERE n<pct
            GROUP BY 1
    ) t;

   ELSE

    WITH
    j_each AS (
        SELECT ghs, n::int n
        FROM  jsonb_each(p_j) t(ghs,n) ORDER BY n
    ),
    perc AS (
        SELECT percentile_disc(p_percentile) WITHIN GROUP (ORDER BY n) as pct
        FROM j_each
    )
    SELECT  jsonb_object_agg( ghs,n ) INTO newdistrib
    FROM (
            SELECT ghs, n
            FROM j_each, perc
            WHERE n>=pct 
                OR ghs = ANY((
                    SELECT array_agg(ghs)
                    FROM j_each, perc
                    WHERE n<pct
                    GROUP BY substr(ghs,1,p_ghs_size)
                    HAVING SUM(n) >= p_limite_n
                )::text[])

            UNION

            SELECT substr(ghs,1,p_ghs_size), SUM(n) as n
            FROM j_each, perc
            WHERE n<pct
            GROUP BY 1
            HAVING SUM(n) < p_limite_n
    ) t;
    END IF;

  RETURN geohash_distribution_summary(newdistrib, p_ghs_size-1, p_len_max, p_percentile,p_limite_n);
  END;
$f$ LANGUAGE PLpgSQL;
