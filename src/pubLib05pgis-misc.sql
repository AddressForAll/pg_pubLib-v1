/**
 * System's Public library (commom for many scripts)
 * Module: PostGIS general complements. Fragment.
 */

CREATE extension IF NOT EXISTS postgis;

-- -- -- -- -- -- -- -- -- --
-- -- -- UTM Zone Functions:

CREATE or replace FUNCTION str_url_todomain(
  url text,
  command text DEFAULT NULL --'rdap -j'
) RETURNS text AS $f$
   -- see https://stackoverflow.com/a/37835341/287948
   SELECT CASE WHEN command>'' THEN trim(command)||' ' ELSE '' END
          ||  regexp_replace(lower(trim(url,' /')), '(^(https?|s?ftp)://(?:www\d?\.)?)|(/.+$)|(^[^\.]+$)', '', 'g')
$f$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- -- -- --
-- -- -- UTM Zone Functions:

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
) RETURNS text AS $wrap$
    SELECT srid_utmzone_title( srid_utmzone_from4326(p_geom) )
$wrap$ LANGUAGE SQL IMMUTABLE;


-- test:
-- select srid_utmzone_title(srid_utmzone_from4326(pt)) from (select ST_SetSRID(ST_MakePoint(-46.655833,-23.561111),4326) as pt UNION ALL   select ST_SetSRID(ST_MakePoint(-71.1043443253471, 42.3150676015829),4326) ) t;


CREATE or replace FUNCTION st_transform_to_utmzone(
  p_geom geometry
) RETURNS geometry AS $f$
  SELECT ST_Transform(p_geom, srid_utmzone_from4326( ST_Transform(ST_Centroid(p_geom),4326) ) )
$f$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- --- -
-- -- -- -- -- -- -- -- -- --
-- -- -- UTM Grid Functions:

-- Each zone is divided into horizontal bands, 8° of latitude wide. The 20 bands are labeled with letters (UTM Zone Designators), beginning with C and ending with X from south to north


-- CREATE or replace FUNCTION utmgrid_from4326(lat float, lon float)


CREATE or replace FUNCTION utmgrid_from4326(
  p_geom geometry(Point,4326) -- ,try_sirgas boolean default false
) RETURNS integer[] AS $f$
   -- see https://gis.stackexchange.com/a/15613/7505
  SELECT array[
    x[1],   -- Hemisphere
    x[2],   -- UTM Zone
    floor( (ST_Y(p_geom)+80.0)/8.0 ), -- Latitude Band, normalize to positive interval before division (8° of latitude wide)
    CASE WHEN x[1]::boolean THEN 32600  ELSE 32700 END  +  x[2]    -- SRID
  ]
  FROM (SELECT utmzone_from4326(p_geom)) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION utmgrid_from4326_label(
  p_geom geometry(Point,4326) -- ,try_sirgas boolean default false
) RETURNS text AS $f$
  -- 'CDEFGHJKLM' are in the southern hemisphere, and 'NPQRSTUVWX' are in the northern hemisphere.
  --  A and B are below 80 South and Y and Z are above 84 North.
  SELECT x[2]::text || substr(lastBandChars, x[3]+1, 1)
  FROM (SELECT utmgrid_from4326(p_geom)) t(x),
       (SELECT 'CDEFGHJKLMNPQRSTUVWXX' lastBandChars) s
$f$ LANGUAGE SQL IMMUTABLE;


-- CREATE or replace FUNCTION utmgrid_from4326_string(lat float, lon float) return text
-- retorna sintaxe wikipedia, ex. coordenadas MASP, '23K 331001 7393387'

CREATE or replace FUNCTION utmgrid_from4326_coverlabels(
  p_geom geometry,
  p_samples int DEFAULT 1000
) RETURNS text[] AS $f$
  SELECT array_agg(code)
  FROM (
    SELECT DISTINCT utmgrid_from4326_label((pt).geom) code
    FROM ( SELECT ST_DumpPoints(ST_GeneratePoints(p_geom,p_samples)) ) t1(pt)
    ORDER BY 1
  ) t2
$f$ LANGUAGE SQL IMMUTABLE;
-- SELECT utmgrid_from4326_coverlabels(geom) FROM optim.jurisdiction_geom  where isolabel_ext='BR'
