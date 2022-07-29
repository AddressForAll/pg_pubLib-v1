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

CREATE extension IF NOT EXISTS postgis;
----------------
------ Criar publib04 vbit!  falta baseh_to_vbit


CREATE or replace FUNCTION varbit_to_int( b varbit, blen int DEFAULT NULL)
RETURNS int AS $f$
  SELECT (  (b'0'::bit(32) || b) << COALESCE(blen,bit_length(b))   )::bit(32)::int
$f$ LANGUAGE SQL IMMUTABLE;

/**
 * Converts bit string to text, using base2h, base4h, base8h, base16h or base32.
 * Uses letters "G" and "H" to sym44bolize non strandard bit strings (0 for44 bases44)
 * Uses extended alphabet (with no letter I,O,U W or X) for base8h and base16h.
 * @see http://osm.codes/_foundations/art1.pdf
 * @version 1.0.1.
 */
CREATE FUNCTION vbit_to_baseh(
  p_val varbit,  -- input
  p_base int DEFAULT 4, -- selecting base2h, base4h, base8h, base16h or base32
  p_size int DEFAULT 0
) RETURNS text AS $f$
DECLARE
    vlen int;
    pos0 int;
    ret text := '';
    blk varbit;
    blk_n int;
    bits_per_digit int;
    tr int[] := '{ {1,2,0,0,0}, {1,3,4,0,0}, {1,3,5,6,0}, {0,0,0,0,7} }'::int[]; --4h(bits,pos), 8h(bits,pos)
    tr_selected JSONb;
    trtypes JSONb := '{"2":[1,1], "4":[1,2], "8":[2,3], "16":[3,4], "32":[4,5]}'::JSONb; -- TrPos,bits
    trpos int;
    baseh "char"[] := array[
      '[0:31]={G,H,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --1. 4h,8h,16h 1bit
      '[0:31]={0,1,2,3,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --2. 4h        2bit
      '[0:31]={J,K,L,M,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --3. 8h,16h    2bit
      '[0:31]={0,1,2,3,4,5,6,7,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --4. 8h        3bit
      '[0:31]={N,P,Q,R,S,T,V,Z,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --5. 16h       3bit
      '[0:31]={0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --6. 16h       4bit
      '[0:31]={0,1,2,3,4,5,6,7,8,9,B,C,D,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z}'::"char"[]  --7. 32        5bit
    ]; -- jumpping I,O and U,W,X letters!
       -- the standard alphabet is https://tools.ietf.org/html/rfc4648#section-6
BEGIN
  vlen := bit_length(p_val);
  tr_selected := trtypes->(p_base::text);
  IF p_val IS NULL OR tr_selected IS NULL OR vlen=0 THEN
    RETURN NULL; -- or  p_retnull;
  END IF;
  IF p_base=2 THEN
    RETURN $1::text; --- direct bit string as string
  END IF;
  bits_per_digit := (tr_selected->>1)::int;
  blk_n := vlen/bits_per_digit;  -- poderia controlar p_size por aqui
  pos0  := (tr_selected->>0)::int;
  trpos := tr[pos0][bits_per_digit];
  FOR counter IN 1..blk_n LOOP
      blk := substring(p_val FROM 1 FOR bits_per_digit);
      ret := ret || baseh[trpos][ varbit_to_int(blk,bits_per_digit) ];
      p_val := substring(p_val FROM bits_per_digit+1); -- same as p_val<<(bits_per_digit*blk_n)
  END LOOP;
  vlen := bit_length(p_val);
  IF p_val!=b'' THEN -- vlen % bits_per_digit>0
    trpos := tr[pos0][vlen];
    ret := ret || baseh[trpos][ varbit_to_int(p_val,vlen) ];
  END IF;
  IF p_size>0 THEN
    ret := substr(ret,1,p_size);
  END IF;
  RETURN ret;
END
$f$ LANGUAGE plpgsql IMMUTABLE;
COMMENT ON FUNCTION vbit_to_baseh(varbit,int,int)
 IS 'Encodes varbit (string of bits) into Base4h, Base8h, Base16h or Base32. See http://osm.codes/_foundations/art1.pdf'
;

CREATE or replace FUNCTION baseh_to_vbit(
  p_val text,  -- input
  p_base int DEFAULT 4 -- selecting base2h, base4h, base8h, base16h or base32.
) RETURNS varbit AS $f$
DECLARE
  tr_hdig jsonb := '{
    "G":[1,0],"H":[1,1],
    "J":[2,0],"K":[2,1],"L":[2,2],"M":[2,3],
    "N":[3,0],"P":[3,1],"Q":[3,2],"R":[3,3],
    "S":[3,4],"T":[3,5],"V":[3,6],"Z":[3,7]
  }'::jsonb;
  tr_full jsonb := '{
    "0":0,"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,
    "9":9,"A":10,"B":11,"C":12,"D":13,"E":14,"F":15
  }'::jsonb;
  tr_full32 jsonb := '{
    "0":0,"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,
    "9":9,"B":10,"C":11,"D":12,"F":13,"G":14,"H":15,"J":16,
    "K":17,"L":18,"M":19,"N":20,"P":21,"Q":22,"R":23,"S":24,
    "T":25,"U":26,"V":27,"W":28,"X":29,"Y":30,"Z":31
    }'::jsonb;
  blk text[];
  bits varbit;
  n int;
  i char;
  ret varbit;
  BEGIN
  ret = '';
  blk := regexp_match(p_val,'^([0-9A-F]*)([GHJ-NP-TVZ])?$');
  IF blk[1] >'' AND p_base <> 32 THEN
    FOREACH i IN ARRAY regexp_split_to_array(blk[1],'') LOOP
      ret := ret || CASE p_base
        WHEN 16 THEN (tr_full->>i)::int::bit(4)::varbit
        WHEN 8 THEN (tr_full->>i)::int::bit(3)::varbit
        WHEN 4 THEN (tr_full->>i)::int::bit(2)::varbit
        END;
    END LOOP;
  END IF;
  IF blk[2] >'' AND p_base <> 32 THEN
    n = (tr_hdig->blk[2]->>0)::int;
    ret := ret || CASE n
      WHEN 1 THEN (tr_hdig->blk[2]->>1)::int::bit(1)::varbit
      WHEN 2 THEN (tr_hdig->blk[2]->>1)::int::bit(2)::varbit
      WHEN 3 THEN (tr_hdig->blk[2]->>1)::int::bit(3)::varbit
      END;
  END IF;
  blk := regexp_match(p_val,'^([0123456789BCDFGHJKLMNPQRSTUVWXYZ]*)$');
  IF blk[1] >'' AND p_base = 32 THEN
    FOREACH i IN ARRAY regexp_split_to_array(blk[1],'') LOOP
      ret := ret || (tr_full32->>i)::int::bit(5)::varbit;
    END LOOP;
  END IF;

  RETURN ret;
  END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
-- select baseh_to_vbit('F3V',16);

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

CREATE or replace FUNCTION str_ggeohash_encode2(
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
) RETURNS jsonb as $f$
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
 RETURN  jsonb_build_object('code',array_to_string(chars,''), 'box',array[min_x, min_y, max_x, max_y]);
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;


CREATE or replace FUNCTION str_ggeohash_encode2(
   x float,
   y float,
   code_size int,
   code_digit_bits int,
   code_digits_alphabet text,
   bbox float[]
) RETURNS jsonb as $f$
   SELECT str_ggeohash_encode2($1, $2, $3, $4, $5, bbox[1], bbox[2], bbox[3], bbox[4])
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION str_ggeohash_encode3(
   x float,
   y float,
   min_x float default -90.,
   min_y float default -180.,
   max_x float default 90.,
   max_y float default 180.,
   bit_length int default 40
) RETURNS varbit as $f$
DECLARE
 bit_string varbit := b'';
 i int := 0;
 mid float;
BEGIN
 FOR i in 0..(bit_length-1) LOOP
   IF i % 2 = 0 THEN
     mid := (max_y + min_y) / 2.0;
     IF y > mid THEN
       bit_string := bit_string || B'1';
       min_y := mid;
     ELSE
       bit_string := bit_string || B'0';
       max_y := mid;
     END IF;
   ELSE
     mid := (max_x + min_x) / 2.0;
     IF x > mid THEN
       bit_string := bit_string || B'1';
       min_x := mid;
     ELSE
       bit_string := bit_string || B'0';
       max_x := mid;
     END IF;
   END IF;
 END LOOP;
 RETURN bit_string;
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
-- SELECT str_ggeohash_encode3(4642144.0,1759788.0,4442144,1559788,4704288,1821932,10);

CREATE or replace FUNCTION str_ggeohash_encode3(
   x float,
   y float,
   bbox float[],
   bit_length int
) RETURNS varbit as $f$
   SELECT str_ggeohash_encode3(x,y,bbox[1],bbox[2],bbox[3],bbox[4],bit_length)
$f$ LANGUAGE SQL IMMUTABLE;
----

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
      FOR bits IN REVERSE
      (
        (
        CASE -- gambiarra para decode de base16h, ver str_ggeohash_decode_box2 com input varbit
          WHEN code_digit_bits = 4 AND digit IN ('g','h')                         THEN 1
          WHEN code_digit_bits = 4 AND digit IN ('j','k','l','m')                 THEN 2
          WHEN code_digit_bits = 4 AND digit IN ('n','p','q','r','s','t','v','z') THEN 3
          ELSE code_digit_bits
          END
        )-1
      )..0 LOOP
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

-- pode substituir str_ggeohash_decode_box
CREATE or replace FUNCTION str_ggeohash_decode_box2(
   code varbit,
   min_x float default -90.,
   min_y float default -180.,
   max_x float default 90.,
   max_y float default 180.
) RETURNS float[] as $f$
DECLARE
  mid    float;
  bit    int;
  i int;
BEGIN
   FOR i IN 0..(bit_length(code)-1) LOOP
      bit = get_bit(code,i);
      IF i % 2 = 0 THEN
        mid = (max_y + min_y) / 2;
        IF bit = 1 THEN
          min_y := mid;
        ELSE
          max_y := mid;
        END IF;
      ELSE
        mid = (max_x + min_x) / 2;
        IF bit =1 THEN
          min_x = mid;
        ELSE
          max_x = mid;
        END IF;
      END IF;
   END LOOP;
   RETURN array[min_x, min_y, max_x, max_y];
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_decode_box2(varbit, float, float, float, float)
  IS 'Decodes string of a Generalized Geohash into a bounding Box that matches it. Returns a four-element array: [minlat, minlon, maxlat, maxlon]. Algorithm adapted from https://github.com/ppKrauss/node-geohash/blob/master/main.js'
;

CREATE or replace FUNCTION str_ggeohash_decode_box2(
   code varbit,
   bbox float[]
) RETURNS float[] as $wrap$
  SELECT str_ggeohash_decode_box2($1, bbox[1], bbox[2], bbox[3], bbox[4])
$wrap$ LANGUAGE sql IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_decode_box2(varbit, float[])
  IS 'Wrap for str_ggeohash_decode_box(...,float,float,float,float).'
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
  SELECT
    CASE
      WHEN cardinality(a)=2 AND u IS     NULL THEN a || array[null,null]::float[]
      WHEN cardinality(a)=3 AND u IS     NULL THEN a || array[null]::float[]
      WHEN cardinality(a)=2 AND u IS NOT NULL THEN a || array[null,u]::float[]
      WHEN cardinality(a)=3 AND u IS NOT NULL THEN a || array[u]::float[]
      ELSE NULL
    END
  FROM (
    SELECT regexp_split_to_array(regexp_replace(uri,'^geo:|;.+$','','ig'),',')::float[]  AS a,
           (regexp_match(uri,';u=([0-9\.]+)'))[1]  AS u
  ) t
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

-----

CREATE or replace FUNCTION str_ggeohash_draw_cell_bycenter(
  cx int,  -- Center X
  cy int,  -- Center Y
  r int,   -- halfside ou raio do circulo inscrito
  p_translate boolean DEFAULT false, -- true para converter em LatLong (WGS84 sem projeção)
  p_srid int DEFAULT 4326          -- WGS84
) RETURNS geometry AS $f$
SELECT CASE WHEN p_translate THEN ST_Transform(geom,4326) ELSE geom END
FROM (
  SELECT ST_GeomFromText( format(
    'POLYGON((%s %s,%s %s,%s %s,%s %s,%s %s))',
    cx-r,cy-r, cx-r,cy+r, cx+r,cy+r, cx+r,cy-r, cx-r,cy-r
  ), p_srid) AS geom
) t
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_draw_cell_bycenter(int,int,int,boolean,int)
  IS 'Draws a square-cell centered on the requested point, with requested radius (half side) and optional translation and SRID.'
;

CREATE or replace FUNCTION str_ggeohash_draw_cell_bybox(
  b float[],  -- bbox [min_x, min_y, max_x, max_y]
  p_translate boolean DEFAULT false, -- true para converter em LatLong (WGS84 sem projeção)
  p_srid int DEFAULT 4326            -- WGS84
) RETURNS geometry AS $f$
SELECT CASE WHEN p_translate THEN ST_Transform(geom,4326) ELSE geom END
FROM (
  SELECT ST_GeomFromText( format(
    'POLYGON((%s %s,%s %s,%s %s,%s %s,%s %s))',
    b[1],b[2], b[1],b[4], b[3],b[4], b[3],b[2], b[1],b[2]
    -- min_x,min_y, min_x,max_y, max_x,max_y, max_x,min_y, min_x,min_y
  ), p_srid) AS geom
) t
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_ggeohash_draw_cell_bybox(float[],boolean,int)
  IS 'Draws a square-cell from BBOX.'
;
