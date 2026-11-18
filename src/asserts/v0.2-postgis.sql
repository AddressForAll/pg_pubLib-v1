-- Optional PostGIS regression checks; run after the PostGIS modules.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
BEGIN
  ASSERT ST_CharactDiam(ST_Point(0,0)) = 0, 'point diameter';
  ASSERT utmzone_from4326_label(ST_SetSRID(ST_Point(-46.6,-23.5),4326)) = '23S', 'UTM label';
  ASSERT ST_Equals(ST_Transform_Resilient(ST_SetSRID(ST_Point(0,0),4326),3857),ST_SetSRID(ST_Point(0,0),3857)), 'resilient transform';
  ASSERT (SELECT count(*) FROM geohash_GeomsFromPrefix('6')) = 32, 'geohash children';
  ASSERT cardinality(geohash_neighbours('6gyf')) = 8, 'recursive geohash exception';
  ASSERT ST_AsGeoJSONb(ST_SetSRID(ST_Point(1,2),4326))->>'type' = 'Feature', 'GeoJSON feature';
  ASSERT (SELECT provolatile='s' AND proparallel='r' FROM pg_proc WHERE oid='srid_utmzone_title(integer)'::regprocedure), 'SRID catalog classification';
END
$test$;
ROLLBACK;
