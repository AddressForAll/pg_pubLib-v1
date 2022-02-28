/**
 * (reference implementation, for asserts and PoCs, no performance)
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * HCode is a left-to-right hierarchical code. See http://addressforall.org/_foundations/art1.pdf
 * A typical class of HCodes are the Geocode systems of regular hierarchical grids, as defined in
 *   https://en.wikipedia.org/w/index.php?title=Geocode&oldid=1052536888#Hierarchical_grids
 * Generalized Geohash is a typical example of valid HCode for this library.
 *
 * Module: HCode/EncodeDecode.
 * DependsOn: pubLib03-json
 * Prefix: hcode
 * license: CC0
 */

-- -- -- -- -- --
-- Main functions

CREATE or replace FUNCTION str_ggeohash_encode(
   x float,
   y float,
   code_size int default NULL, -- default 9 for base32 and 23 for base4
   code_digit_bits int default 5,   -- 5 for base32, 4 for base16 or 2 for base4
   code_digits_alphabet text default '0123456789BCDFGHJKLMNPQRSTUVWXYZ',
   -- see base32nvU at http://addressforall.org/_foundations/art1.pdf
   min_x float default -90.,
   min_y float default -180.,
   max_x float default 90.,
   max_y float default 180.
) RETURNS text as $f$
DECLARE
 chars      text[]  := array[]::text[];
 bits       int     := 0;
 bitsTotal  int     := 0;
 hash_value int     := 0;
 safe_loop  int     := 0;
 mid        float;
 digit      char;
BEGIN
 IF code_size IS NULL OR code_size=0 THEN
    code_size := (array[38,23,18,12,9])[code_digit_bits];
 END IF;
 WHILE safe_loop<200 AND cardinality(chars) < code_size LOOP
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
   -- RAISE NOTICE '-- %. mid=% (% to % x=%) %bits.',safe_loop,mid,min_y,max_y,y,bits;
   bits := bits + 1;
   bitsTotal := bitsTotal +1;
   IF bits = code_digit_bits THEN
     digit := substr(code_digits_alphabet, hash_value+1, 1);
     chars := array_append(chars, digit);
     bits := 0;
     hash_value := 0;
   END IF;
 END LOOP; -- \chars
 RETURN  array_to_string(chars,''); -- code
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_encode(float, float, integer, integer, text, float, float, float, float)
  IS 'Encondes LatLon WGS84 as Generalized Geohash. Algorithm adapted from https://github.com/ppKrauss/node-geohash/blob/master/main.js'
;

CREATE or replace FUNCTION str_ggeohash_encode(
   x float,
   y float,
   code_size int,
   code_digit_bits int,
   code_digits_alphabet text,
   bbox float[]
) RETURNS text as $f$
   SELECT str_ggeohash_encode($1, $2, $3, $4, $5, bbox[1], bbox[2], bbox[3], bbox[4])
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_encode(float, float, integer, integer, text, float[])
  IS 'Wrap for str_ggeohash_encode(...,float,float,float,float).'
;

-- -- --

CREATE or replace FUNCTION str_ggeohash_decode_box(
   code text,
   code_digit_bits int default 5,  -- 5 for base32, 4 for base16 or 2 for base4
   -- SELECT jsonb_object_agg(x,i-1) from regexp_split_to_table(code_digits_alphabet,'') WITH ORDINALITY AS t(x,i);
   code_digits_lookup jsonb  default '{"0":0, "1":1, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9, "b":10, "c":11, "d":12, "e":13, "f":14, "g":15, "h":16, "j":17, "k":18, "m":19, "n":20, "p":21, "q":22, "r":23, "s":24, "t":25, "u":26, "v":27, "w":28, "x":29, "y":30, "z":31}'::jsonb,
   min_x float default -90.,
   min_y float default -180.,
   max_x float default 90.,
   max_y float default 180.
) RETURNS float[] as $f$
DECLARE
  isX  boolean := true;
  hashValue int := 0;
  mid    float;
  bits   int;
  bit    int;
  i int;
  digit text;
BEGIN
   code = lower(code);
   FOR i IN 1..length(code) LOOP
      digit = substr(code,i,1);
      hashValue := (code_digits_lookup->digit)::int;
      FOR bits IN REVERSE (code_digit_bits-1)..0 LOOP
	      bit = (hashValue >> bits) & 1; -- can be boolean
	      IF isX THEN
          mid = (max_y + min_y) / 2;
          IF bit = 1 THEN
            min_y := mid;
          ELSE
            max_y := mid;
          END IF; -- \bit
        ELSE
          mid = (max_x + min_x) / 2;
          IF bit =1 THEN
            min_x = mid;
          ELSE
            max_x = mid;
          END IF; --\bit
        END IF; -- \isX
        isX := NOT(isX);
      END LOOP; -- \bits
   END LOOP; -- \i
   RETURN array[min_x, min_y, max_x, max_y];
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_decode_box(text, integer, jsonb, float, float, float, float)
  IS 'Decodes string of a Generalized Geohash into a bounding Box that matches it. Returns a four-element array: [minlat, minlon, maxlat, maxlon]. Algorithm adapted from https://github.com/ppKrauss/node-geohash/blob/master/main.js'
;

------------------------------
--- Classic Geohash functions:

CREATE or replace FUNCTION str_geohash_encode(
 latitude float,
 longitude float,
 code_size int default NULL
) RETURNS text as $f$
 SELECT str_ggeohash_encode(latitude,longitude,code_size,5,'0123456789bcdefghjkmnpqrstuvwxyz')
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(float,float,int)
  IS 'Encondes LatLon as classic Geohash of Niemeyer 2008.'
;

CREATE or replace FUNCTION str_ggeohash_decode_box(
   code text,                 -- 1
   code_digit_bits int,       -- 2
   code_digits_lookup jsonb,  -- 3
   bbox float[]
) RETURNS float[] as $wrap$
  SELECT str_ggeohash_decode_box($1, $2, $3, bbox[1], bbox[2], bbox[3], bbox[4])
$wrap$ LANGUAGE sql IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_decode_box(text, integer, jsonb, float[])
  IS 'Wrap for str_ggeohash_decode_box(...,float,float,float,float).'
;

CREATE or replace FUNCTION str_geohash_decode(
   code text,
   witherror boolean default false
) RETURNS float[] as $f$
  SELECT CASE WHEN witherror THEN latlon || array[bbox[3] - latlon[1], bbox[4] - latlon[2]] ELSE latlon END
  FROM (
    SELECT array[(bbox[1] + bbox[3]) / 2, (bbox[2] + bbox[4]) / 2] as latlon, bbox
    FROM (SELECT str_ggeohash_decode_box(code)) t1(bbox)
  ) t2
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(float,float,int)
  IS 'Decodes classic Geohash (of Niemeyer 2008) to latitude and longitude, optionally adding error to the array.'
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
  latLon text
) RETURNS text as $wrap$
  SELECT str_geohash_encode(x[1],x[2],8)
  FROM (SELECT str_geouri_decode(LatLon)) t(x)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(text)
  IS 'Wrap for str_geohash_encode() with text GeoURI input.'
;

CREATE or replace FUNCTION str_geohash_encode(
  latLon float[],
  code_size int default NULL
) RETURNS text as $wrap$
  SELECT str_geohash_encode(latLon[1],latLon[2],code_size)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geohash_encode(float[],int)
  IS 'Wrap for str_geohash_encode() with array input.'
;

-------------------------------------
----- Using UV normalized coordinates

-- pending XY_to_UV(x,y,bbox) and UV_to_XY(u,v,bbox)

CREATE or replace FUNCTION str_ggeohash_uv_encode(
   u float,  -- 0.0 to 1.0, normalized X.
   v float,  -- 0.0 to 1.0, normalized Y.
   code_size int default NULL,
   code_digit_bits int default 5,   -- 5 for base32, 4 for base16 or 2 for base4
   code_digits_alphabet text default '0123456789BCDFGHJKLMNPQRSTUVWXYZ'
	-- see base32nvU at http://addressforall.org/_foundations/art1.pdf
) RETURNS text as $wrap$
   SELECT str_ggeohash_encode($1, $2, $3, $4, $5, 0.0, 0.0, 1.0, 1.0)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_uv_encode
  IS 'Wrap for str_ggeohash_encode() with normalized UV coordinates.'
;

CREATE or replace FUNCTION str_ggeohash_uv_decode_box(
   code text,
   code_digit_bits int default 5,  -- 5 for base32, 4 for base16 or 2 for base4
   code_digits_lookup jsonb  default '{"0":0, "1":1, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9, "b":10, "c":11, "d":12, "f":13, "g":14, "h":15, "j":16, "k":17, "l":18, "m":19, "n":20, "p":21, "q":22, "r":23, "s":24, "t":25, "u":26, "v":27, "w":28, "x":29, "y":30, "z":31}'::jsonb
) RETURNS float[] as $wrap$
   SELECT str_ggeohash_decode_box($1, $2, $3, 0.0, 0.0, 1.0, 1.0)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_uv_decode_box
  IS 'Wrap for str_ggeohash_decode_box(), returning normalized UV coordinates.'
;
