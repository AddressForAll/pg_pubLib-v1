/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * Module: PostGIS/Geohash.
 * DependsOn: pubLib03-json
 * Prefix: geohash_
 * license: CC0
 * -- see also pubLib05hcode-distrib.sql
 */

 CREATE extension IF NOT EXISTS postgis;


CREATE or replace FUNCTION geohash_GeomsFromPrefix(
  prefix text DEFAULT ''
) RETURNS TABLE(ghs text, geom geometry) AS $f$
  SELECT prefix||x, ST_SetSRID( ST_GeomFromGeoHash(prefix||x), 4326)
  FROM unnest('{0,1,2,3,4,5,6,7,8,9,b,c,d,e,f,g,h,j,k,m,n,p,q,r,s,t,u,v,w,x,y,z}'::text[]) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsFromPrefix
  IS 'Return a Geohash grid, the quadrilateral geometry of each child-cell and its geocode. The parameter is the Geohash the parent-cell, that will be a prefix for all child-cells.'
;
/*
CREATE or replace FUNCTION geohash_cover(
  input_geom geometry,
  input_prefix text  DEFAULT '',       -- Geohash prefix to enforce only equal or contained cells
  onlycontained boolean DEFAULT NULL,  -- true=interior cells; false=contour cells; NULL=both.
  force_scan boolean DEFAULT true      -- rare use, on non-recusive context
) RETURNS text[] AS $f$
  WITH t0 AS (
    SELECT ghs0,
           ghs0>'' AND (NOT(force_scan) OR input_prefix!=ghs0) AS test0,
           onlycontained IS NULL                               AS must_both
           onlycontained IS NOT NULL AND onlycontained         AS must_contained
    FROM ( SELECT ST_GeoHash(input_geom) ) t(ghs0)
  )
  SELECT CASE
     WHEN test0 THEN
        CASE WHEN ghs0 LIKE input_prefix||'%' THEN array[ghs0] ELSE NULL END
     ELSE (
       SELECT array_agg(ghs)
       FROM (
         SELECT t.ghs,
                ST_Contains(input_geom,t.geom) as is_contained
         FROM geohash_GeomsFromPrefix(input_prefix) t
         WHERE ST_Intersects(t.geom,input_geom)
       ) t2, t0
       WHERE t0.must_both
         OR ( NOT(t0.must_contained) AND NOT(t2.is_contained) )
         OR ( t0.must_contained AND t2.is_contained )
     ) END
  FROM t0
$f$ LANGUAGE SQL IMMUTABLE;
*/

CREATE or replace FUNCTION geohash_cover_geoms(
  input_geom geometry,
  input_prefix text     DEFAULT '',
  onlycontained boolean DEFAULT false,  -- true=interior cells; false=contour cells; NULL=both.
  force_scan boolean    DEFAULT true    -- BUG? necessary?
) RETURNS TABLE(ghs text, is_contained boolean, geom geometry, cut_geom geometry)  AS $f$
  WITH t0 AS (
    SELECT ghs0,
           ghs0>'' AND (NOT(force_scan) OR input_prefix!=ghs0) AS test0,
           onlycontained IS NULL                               AS must_both,
           onlycontained IS NOT NULL AND onlycontained         AS must_contained
    FROM ( SELECT ST_GeoHash(input_geom) ) t(ghs0)
  )
   SELECT ghs0, false,
          ST_SetSRID(ST_GeomFromGeoHash(ghs0),4326) AS geom,
          input_geom AS cut_geom
   FROM t0
   WHERE test0 AND ghs0 LIKE input_prefix||'%'

  UNION ALL  -- theoretically never duplicates

   SELECT ghs, is_contained, geom, cut_geom
   FROM (
     SELECT ghs, t1.geom, t0.must_both, t0.must_contained,
            ST_Intersection(input_geom,t1.geom) as cut_geom,
            ST_Contains(input_geom,t1.geom) as is_contained
     FROM geohash_GeomsFromPrefix(input_prefix) t1, t0
     WHERE NOT(t0.test0) AND ST_Intersects(t1.geom,input_geom)
   ) t2
   WHERE must_both
         OR ( NOT(must_contained) AND NOT(is_contained) )
         OR ( must_contained AND is_contained )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover_geoms
  IS 'Geometry of geohash_cover() list, assuming a region delimited by the prefix.'
;
-- SELECT row_number() OVER () as gid, g.* FROM countries c, LATERAL geohash_cover_geom(c.geom,'6') g WHERE c.iso_a2='BR';

CREATE or replace FUNCTION geohash_cover_list(
  input_geom geometry,
  input_prefix text  DEFAULT '',       -- Geohash prefix to enforce only equal or contained cells
  onlycontained boolean DEFAULT NULL,  -- true=interior cells; false=contour cells; NULL=both.
  force_scan boolean DEFAULT true      -- rare use, on non-recusive context
) RETURNS text[] AS $wrap$
  SELECT array_agg(ghs)
  FROM geohash_cover_geoms($1,$2,$3,$4)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover_list
  IS 'Geohash list of covering Geohashes, assuming a region delimited by the prefix. Returns null for incompatible prefixes, and 32 itens from prefix-contained geometry.'
;
-- SELECT geohash_cover_list(geom,'6') FROM countries WHERE iso_a2='BR';

CREATE or replace FUNCTION geohash_cover_testlist(
  input_geom geometry,
  input_prefix text DEFAULT '',
  force_scan boolean DEFAULT true
) RETURNS jsonb AS $wrap$
  SELECT jsonb_object_agg(ghs,is_contained)
  FROM geohash_cover_geoms(input_geom, input_prefix, NULL, force_scan)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover_testlist
  IS 'Geohash jsonb object (geocode-is_contained pairs) of covering Geohashes, a wrap for geohash_cover_geoms function.'
;
-- SELECT geohash_cover_contains(geom,'6') FROM countries WHERE iso_a2='BR';

CREATE or replace FUNCTION geohash_coverContour_geoms(
  input_geom geometry,
  ghs_len int default 3,
  prefix0 text DEFAULT ''
) RETURNS TABLE(ghs text, geom geometry, cut_geom geometry) AS $f$

 WITH RECURSIVE rcover(ghs, is_contained, geom, cut_geom) AS (
   SELECT *
   FROM geohash_cover_geoms(input_geom,prefix0,false) t0
  UNION ALL
   SELECT c.*
   FROM rcover,
        LATERAL geohash_cover_geoms(input_geom, rcover.ghs, false) c
   WHERE length(rcover.ghs)<ghs_len AND NOT(rcover.is_contained) -- redundant AND NOT(c.is_contained)
 )
 SELECT ghs,geom,cut_geom
 FROM rcover WHERE length(ghs)=ghs_len;

$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_coverContour_geoms
  IS 'Geohash cover of the contour.'
;
-- CREATE TABLE br_coverContour3 AS SELECT * FROM geohash_coverContour_geoms( (SELECT geom FROM ingest.fdw_jurisdiction_geom where isolabel_ext='BR'), 3 );

CREATE or replace FUNCTION geohash_coverContour_geoms_splitarea(
  input_geom geometry,
  ghs_len int default 3,
  max_area_factor float default 0.8,
  prefix0 text default ''
) RETURNS TABLE(ghs text, geom geometry, cut_geom geometry, area_factor float) AS $f$
  WITH rcover_area AS (
    SELECT *, ST_Area(cut_geom)/ST_Area(geom) AS k
    FROM geohash_coverContour_geoms($1,$2,prefix0) -- all recurrency steps here.
  )
   SELECT ghs, geom, cut_geom, k
   FROM rcover_area
   WHERE k < max_area_factor
  UNION ALL  -- More one recurrency step for big area_factor cells:
   SELECT g.ghs, g.geom, g.cut_geom, ST_Area(g.cut_geom)/ST_Area(g.geom)
   FROM rcover_area r, LATERAL geohash_cover_geoms(input_geom, ghs, false) g
   WHERE r.k >= max_area_factor
$f$ LANGUAGE SQL IMMUTABLE;

-------------

CREATE or replace FUNCTION geohash_GeomsMosaic(ghs_array text[], geom_mask geometry DEFAULT null)
RETURNS TABLE(ghs text, lghs int, geom geometry) AS $f$
  WITH ghsgeom AS (
    SELECT ghs, length(ghs) as lghs,
           ST_SetSRID( ST_GeomFromGeoHash(ghs) , 4326) AS geom
    FROM unnest(ghs_array) t1(ghs)
  )
  ,lghsgeom AS (
    SELECT lghs, ST_UNION(geom) as ugeom
    FROM ghsgeom GROUP BY 1 ORDER BY 1
  ),final AS (
    SELECT g.ghs, g.lghs, COALESCE(
         (SELECT ST_Difference(g.geom,ST_UNION(ugeom)) FROM lghsgeom WHERE lghs>g.lghs),
         g.geom
       ) AS geom
    FROM lghsgeom l INNER JOIN ghsgeom g ON l.lghs=g.lghs
  )
    SELECT  ghs, lghs,
            CASE WHEN geom_mask IS NULL THEN geom ELSE ST_Intersection(geom,geom_mask) END
    FROM final
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsMosaic(text[],geometry)
  IS 'Return a mosaic the geometries of an arbitrary set of Geohashes, cuting, when exists, contained cells from its parent-cell.'
;
-- SELECT geohash_GeomMosaic(array['7h2','7h2w','7h2wju','7h2wjv','7h2wjx','7h2wjy','7h2wjz','7h2wjz', '6urz']);

CREATE or replace FUNCTION geohash_GeomsMosaic(ghs_set jsonB, geom_mask geometry DEFAULT null)
RETURNS TABLE(ghs text, lghs int, val text, geom geometry) AS $wrap$
  SELECT ghs, lghs, ghs_set->>ghs AS val, geom
  FROM (
    SELECT * FROM geohash_GeomsMosaic( (SELECT array_agg(k) FROM jsonb_object_keys(ghs_set) t(k)), geom_mask )
  ) t
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsMosaic(jsonb,geometry)
  IS 'Wrap for geohash_GeomsMosaic(text[]), adding a val column of text-type from input key-value pairs.'
;
-- SELECT * FROM geohash_GeomsMosaic('{"7h2":100,"7h2w":200,"7h2wju":150,"7h2wjv":200,"7h2wjx":30,"6urz":110}'::jsonb);

CREATE or replace FUNCTION geohash_GeomsMosaic_jinfo(ghs_set jsonB, geom_mask geometry DEFAULT null)
RETURNS TABLE(ghs text, info jsonb, geom geometry) AS $wrap$
  SELECT ghs,
         CASE jsonb_typeof(ghs_set->ghs)
            WHEN 'null' THEN jsonb_build_object('ghs_len',lghs)
            WHEN 'object' THEN (ghs_set->ghs) || jsonb_build_object('ghs_len',lghs)
            ELSE jsonb_build_object('ghs_len',lghs, 'ghs_items',ghs_set->ghs)
         END,
         geom
  FROM geohash_GeomsMosaic(  (SELECT array_agg(k) FROM jsonb_object_keys(ghs_set) t(k)),  geom_mask   )
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsMosaic_jinfo(jsonb,geometry)
  IS 'Wrap for geohash_GeomMosaic(text[]), adding a val column of jsonb-type from input key-value pairs.'
;
-- SELECT * FROM geohash_GeomsMosaic_jinfo('{"7h2":{"x":12,"y":34},"7h2w":200,"7h2wju":{"x":55,"a":null},"6urz":null}'::jsonb);

CREATE or replace FUNCTION geohash_GeomsMosaic_jinfo(
    ghs_set jsonB,
    opts jsonB,
    geom_mask geometry DEFAULT null,
    minimal_area float DEFAULT 1.0 -- precision of point and geohash-cell are not superior than 1 m2.
)
RETURNS TABLE(ghs text, info jsonb, geom geometry) AS $wrap$
  SELECT ghs
         ,info || COALESCE(
            (SELECT jsonb_object_agg(
                 CASE WHEN substr(opt,1,7)='density' THEN (opts->>opt)||'_'||opt ELSE opt END,
                 CASE opt
                     WHEN 'area'        THEN  l.area
                     WHEN 'area_km2'    THEN  l.area/1000000.0
                     WHEN 'density'     THEN  (info->(opts->>opt))::float / l.area
                     WHEN 'density_km2' THEN  1000000.0*(info->(opts->>opt))::float / l.area
                     ELSE null
                 END) -- \agg
             FROM jsonb_object_keys(opts) t(opt) WHERE opts is not null AND opts!='{}'::jsonb
           ), -- \select
           '{}'::jsonb  -- when opts is null or empty
         ) -- \coalesce
         ,geom
  FROM geohash_GeomsMosaic_jinfo(ghs_set,geom_mask), LATERAL (SELECT ST_Area(geom,true)) l(area)
  WHERE l.area>minimal_area
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsMosaic_jinfo(jsonb,jsonB,geometry,float)
  IS 'Wrap for geohash_GeomsMosaic_jinfo, adding optional area and density values'
;
-- SELECT * FROM geohash_GeomsMosaic_jinfo('{"7h2":300,"7h2w":200,"7h2wju":245,"6urz":123,"7h2wju5222":1}'::jsonb, '{"area":1,"density_km2":"val"}'::jsonb);
