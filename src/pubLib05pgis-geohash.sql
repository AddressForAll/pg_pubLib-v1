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

CREATE or replace FUNCTION geohash_GeomsFromPrefix(
  prefix text DEFAULT ''
) RETURNS TABLE(ghs text, geom geometry) AS $f$
  SELECT prefix||x, ST_SetSRID( ST_GeomFromGeoHash(prefix||x), 4326)
  FROM unnest('{0,1,2,3,4,5,6,7,8,9,b,c,d,e,f,g,h,j,k,m,n,p,q,r,s,t,u,v,w,x,y,z}'::text[]) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_GeomsFromPrefix
  IS 'Return a Geohash grid, the quadrilateral geometry of each child-cell and its geocode. The parameter is the Geohash the parent-cell, that will be a prefix for all child-cells.'
;

CREATE or replace FUNCTION geohash_cover(
  input_geom geometry,
  input_prefix text DEFAULT '',
  force_scan boolean DEFAULT true
) RETURNS text[] AS $f$
  SELECT CASE
     WHEN ghs0>'' AND (NOT(force_scan) OR input_prefix!=ghs0) THEN
        CASE WHEN ghs0 LIKE input_prefix||'%' THEN array[ghs0] ELSE NULL END
     ELSE (
       SELECT array_agg(ghs)
       FROM geohash_GeomsFromPrefix(input_prefix) t
       WHERE ST_Intersects(t.geom,input_geom)
     ) END
  FROM (SELECT ST_GeoHash(input_geom) AS ghs0) t0
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover
  IS 'Geohash list of covering Geohashes, assuming a region delimited by the prefix. Returns null for incompatible prefixes, and 32 itens from prefix-contained geometry.'
;
-- SELECT geohash_cover(geom,'6') FROM countries WHERE iso_a2='BR';

CREATE or replace FUNCTION geohash_cover_geom(
  input_geom geometry,
  input_prefix text DEFAULT '',
  cut boolean DEFAULT false,
  force_scan boolean DEFAULT true
) RETURNS TABLE(ghs text, is_contained boolean, geom geometry)  AS $f$
  WITH t0 AS (
    SELECT ghs0, ghs0>'' AND (NOT(force_scan) OR input_prefix!=ghs0) AS test0
    FROM ( SELECT ST_GeoHash(input_geom) ) t(ghs0)
  )
   SELECT ghs0,
             false AS is_contained,
             CASE WHEN cut THEN input_geom ELSE ST_SetSRID(ST_GeomFromGeoHash(ghs0),4326) END  AS geom
   FROM t0
   WHERE test0 AND ghs0 LIKE input_prefix||'%'
  UNION ALL
   SELECT ghs,
             ST_Contains(input_geom,t1.geom) AS is_contained,
             CASE WHEN cut THEN ST_Intersection(input_geom,t1.geom) ELSE t1.geom END AS geom
   FROM geohash_GeomsFromPrefix(input_prefix) t1, t0
   WHERE NOT(t0.test0) AND ST_Intersects(t1.geom,input_geom)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover_geom
  IS 'Geometry of geohash_cover() list, assuming a region delimited by the prefix.'
;
-- SELECT row_number() OVER () as gid, g.* FROM countries c, LATERAL geohash_cover_geom(c.geom,'6') g WHERE c.iso_a2='BR';

CREATE or replace FUNCTION geohash_cover_contains(
  input_geom geometry,
  input_prefix text DEFAULT '',
  force_scan boolean DEFAULT true
) RETURNS jsonb AS $wrap$
  SELECT jsonb_object_agg(ghs,is_contained)
  FROM geohash_cover_geom(input_geom,input_prefix,false,force_scan)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geohash_cover_contains
  IS 'Geohash jsonb object (geocode-is_contained pairs) of covering Geohashes, a wrap for geohash_cover_geom function.'
;
-- SELECT geohash_cover_contains(geom,'6') FROM countries WHERE iso_a2='BR';

CREATE or replace FUNCTION geohash_cover_noncontained_recursive(
  input_geom geometry,
  ghs_len int default 3,
  cut boolean DEFAULT false,
  prefix0 text DEFAULT ''
) RETURNS TABLE(ghs text, geom geometry) AS $f$

 WITH RECURSIVE rcover(ghs, is_contained, geom) AS (
   SELECT * FROM geohash_cover_geom(input_geom,prefix0,cut) t0
  UNION ALL
   SELECT c.* FROM rcover, LATERAL geohash_cover_geom(input_geom,rcover.ghs,cut) c
   WHERE length(rcover.ghs)<ghs_len AND NOT(c.is_contained) AND NOT(rcover.is_contained)
 )
 SELECT ghs, geom FROM rcover WHERE length(ghs)=ghs_len;

$f$ LANGUAGE SQL;
-- create table lix AS SELECT * FROM geohash_cover_noncontained_recursive( (SELECT geom FROM ingest.fdw_jurisdiction_geom where isolabel_ext='BR') );

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
