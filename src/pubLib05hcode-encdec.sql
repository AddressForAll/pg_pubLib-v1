/**
 * (reference implementation, for asserts and PoCs, no performance)
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * HCode is a left-to-right hierarchical code. See http://addressforall.org/_foundations/art1.pdf
 * A typical class of HCodes are the Geocode systems of regular hierarchical grids, as defined in
 *   https://en.wikipedia.org/w/index.php?title=Geocode&oldid=1052536888#Hierarchical_grids
 * Geohash is a typical example of valid HCode for this library.
 *
 * Module: HCode/EncodeDecode0000000.
 * DependsOn: pubLib03-json
 * Prefix: hcode
 * license: CC0
 */

-- -- -- -- -- --
-- Main functions

CREATE or replace FUNCTION str_ggeohash_encode(
   x float,
   y float,
   numberOfChars int default NULL, -- default 9 for base32 and 23 for base4
   baseBits int default 5,   -- 5 for base32, 4 for base16 or 2 for base4
   BASE32_CODES text default '0123456789BCDFGHJKLMNPQRSTUVWXYZ',
   -- see base32nvU at http://addressforall.org/_foundations/art1.pdf
   max_x float default 90.,
   min_x float default -90.,
   max_y float default 180.,
   min_y float default-180.
) RETURNS text as $f$
DECLARE
 chars text[]  := array[]::text[];
 bits int      := 0;
 bitsTotal int := 0;
 hash_value int := 0;
 mid float;
 code char;
 safe_loop int := 0;
BEGIN
 IF numberOfChars IS NULL OR numberOfChars=0 THEN
    numberOfChars := (array[38,23,18,12,9])[baseBits];
 END IF;
 WHILE safe_loop<200 AND cardinality(chars) < numberOfChars LOOP
   IF bitsTotal % 2 = 0 THEN
     mid := (max_y + min_y) / 2.0;
     IF y > mid THEN
       hash_value := (hash_value << 1) + 1;
       min_y := mid;
     ELSE
       hash_value := (hash_value << 1) + 0;
       max_y := mid;
     END IF;
   ELSE -- \bitsTotal
     mid := (max_x + min_x) / 2.0;
     IF x > mid THEN
       hash_value := (hash_value << 1) + 1;
       min_x := mid;
     ELSE
       hash_value := (hash_value << 1) + 0;
       max_x := mid;
     END IF;
   END IF; -- \bitsTotal
   safe_loop := safe_loop + 1; -- new
   bits := bits + 1;
   bitsTotal := bitsTotal +1;
   IF bits = baseBits THEN
     code := substr(BASE32_CODES, hash_value+1, 1);
     chars := array_append(chars, code);
     bits := 0;
     hash_value := 0;
   END IF;
 END LOOP; -- \chars
 RETURN  array_to_string(chars,'');
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_encode
  IS 'Encondes LatLon as Generalized Geohash. Algorithm adapted from https://github.com/ppKrauss/node-geohash/blob/master/main.js'
;

-- -- -- -- -- -- -- -- -- --
-- Wrap and helper functions:

CREATE or replace FUNCTION str_geouri_decode(uri text) RETURNS float[] as $f$
  SELECT regexp_split_to_array(regexp_replace(uri,'^geo:','','i'),',')::float[]
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geouri_decode(text)
  IS 'Decodes standard GeoURI of latitude and longitude into float array.'
;

CREATE or replace FUNCTION str_geohash_encode(
 latitude float,
 longitude float,
 numberOfChars int default NULL
) RETURNS text as $f$
 SELECT str_ggeohash_encode(latitude,longitude,numberOfChars,5,'0123456789bcdefghjkmnpqrstuvwxyz')
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(float,float,int)
  IS 'Encondes LatLon as classic Geohash of Niemeyer 2008.'
;

----

CREATE or replace FUNCTION str_geohash_encode(
  latLon float[],
  numberOfChars int default NULL
) RETURNS text as $wrap$
  SELECT str_geohash_encode(latLon[1],latLon[2],numberOfChars)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(float[],int)
  IS 'Wrap for str_geohash_encode() with array input.'
;

CREATE or replace FUNCTION str_geohash_encode(
  latLon text
) RETURNS text as $wrap$
  SELECT str_geohash_encode(x[1],x[2],8)
  FROM (SELECT str_geouri_decode(LatLon)) t(x)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(text)
  IS 'Wrap for str_geohash_encode() with text GeoURI input.'
;
