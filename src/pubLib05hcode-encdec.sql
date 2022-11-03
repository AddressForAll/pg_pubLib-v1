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


-- NO MOVE!
-- varbit_to_int
-- vbit_to_baseh
-- baseh_to_vbit
-- str_geouri_decode

-- MOVE TO https://git.osm.codes/GGeohash/blob/main/src/step02def-libGGeohash.sql
-- str_ggeohash_encode --TO--> ggeohash.encode
-- str_ggeohash_encode2 --TO--> ggeohash.encode2
-- str_ggeohash_encode2 --TO--> ggeohash.encode2
-- str_ggeohash_encode3 --TO--> ggeohash.encode3
-- str_ggeohash_encode3 --TO--> ggeohash.encode3
-- str_ggeohash_encode --TO--> ggeohash.encode
-- str_ggeohash_decode_box --TO--> ggeohash.decode_box
-- str_ggeohash_decode_box2 --TO--> ggeohash.decode_box2
-- str_ggeohash_decode_box2 --TO--> ggeohash.decode_box2
-- str_geohash_encode --TO--> ggeohash.classic_encode
-- str_ggeohash_decode_box --TO--> ggeohash.classic_decode
-- str_geohash_decode --TO--> ggeohash.classic_decode
-- str_geohash_encode --TO--> ggeohash.classic_encode
-- str_geohash_encode --TO--> ggeohash.classic_encode
-- str_ggeohash_uv_encode --TO--> ggeohash.uv_encode
-- str_ggeohash_uv_decode_box --TO--> ggeohash.uv_decode_box
-- str_ggeohash_draw_cell_bycenter --TO--> ggeohash.draw_cell_bycenter
-- str_ggeohash_draw_cell_bybox --TO--> ggeohash.draw_cell_bybox


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
CREATE or replace FUNCTION vbit_to_baseh(
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
      '[0:31]={0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --6. 16h       4bit
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



