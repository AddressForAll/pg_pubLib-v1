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
-- str_geouri_decode

-- MOVE TO https://git.osm.codes/NaturalCodes/blob/main/src/step01def-lib_NatCod.sql
-- varbit_to_int --TO--> varbit_to_int
-- vbit_to_baseh --TO--> natcod.vbit_to_baseh
-- baseh_to_vbit --TO--> natcod.baseh_to_vbit

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

-- -- -- -- -- -- -- -- -- --
-- Wrap and helper functions:

CREATE OR REPLACE FUNCTION str_geouri_decode(uri TEXT) RETURNS float[] AS $f$
  SELECT regexp_match(uri,'^geo:(?:olc:|ghs:)?([-0-9\.]+),([-0-9\.]+)(?:,([-0-9\.]+))?(?:;u=([-0-9\.]+))?','i')::float[]
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION str_geouri_decode(text)
  IS 'Decodes standard GeoURI of latitude and longitude into float array.'
;
