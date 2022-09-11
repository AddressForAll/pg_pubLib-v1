/**
 * System's Public library (commom for many scripts)
 * Module: PostGIS general complements. Fragment.
 */

CREATE extension IF NOT EXISTS postgis;

-- -- -- -- -- -- -- --
-- -- -- UTM Functions
CREATE or replace FUNCTION utmzone_from4326(
  p_geom geometry(Point,4326)
) RETURNS integer[] AS $f$
   -- see https://gis.stackexchange.com/a/439316/7505
   SELECT array[
     ((ST_Y(p_geom))>0)::boolean::int, -- 1 is Northern, 0 is Southern
     floor((ST_X(p_geom)+180)/6)+1
    ]
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION srid_utmzone_from4326(
  p_geom geometry(Point,4326)
) RETURNS integer AS $wrap$
   SELECT CASE WHEN x[1]::boolean THEN 32600  ELSE 32700 END  +  x[2]
   FROM (SELECT utmzone_from4326(p_geom)) t(x)
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION utmzone_from4326_label(
  p_geom geometry(Point,4326)
) RETURNS text AS $wrap$
  -- The Southern/Northern label is redundant?? So, need only the number
  SELECT x[2]::text || CASE WHEN x[1]::boolean THEN 'N'  ELSE 'S' END
  FROM (SELECT utmzone_from4326(p_geom)) t(x)
$wrap$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION srid_utmzone_title(p_srid int) RETURNS text AS $f$
  -- SIRGAS or WGS 84. At srtext the PROJCS keyword is the "PROJ Coordinate System title"
  SELECT substr(srtext, 9, 21 + CASE WHEN p_srid<32600 THEN 5 ELSE 0 END)
  FROM  spatial_ref_sys
  WHERE srid=p_srid;
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION srid_utmzone_title(
  p_geom geometry(Point,4326)
) RETURNS integer AS $wrap$
    SELECT srid_utmzone_title( utmzone_from4326(p_geom) )
$wrap$ LANGUAGE SQL IMMUTABLE;


-- test:
-- select srid_utmzone_title(srid_utmzone_from4326(pt)) from (select ST_SetSRID(ST_MakePoint(-46.655833,-23.561111),4326) as pt UNION ALL   select ST_SetSRID(ST_MakePoint(-71.1043443253471, 42.3150676015829),4326) ) t;


CREATE or replace FUNCTION st_transform_to_utmzone(
  p_geom geometry
) RETURNS geometry AS $f$
  SELECT ST_Transform(p_geom, srid_utmzone_from4326( ST_Transform(ST_Centroid(p_geom),4326) ) )
$f$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- --
