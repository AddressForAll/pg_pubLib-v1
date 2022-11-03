/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * HCode is a left-to-right hierarchical code. See http://addressforall.org/_foundations/art1.pdf
 * A typical class of HCodes are the Geocode systems of regular hierarchical grids, as defined in
 *   https://en.wikipedia.org/w/index.php?title=Geocode&oldid=1052536888#Hierarchical_grids
 * Geohash is a typical example of valid HCode for this library.
 *
 * Module: HCode/Distribution.
 * DependsOn: pubLib03-json
 * Prefix: hcode
 * license: CC0
 */


-- OLD FUNCTIONS moved to https://git.osm.codes/GGeohash/blob/main/src/step01def-libHcode.sql

--  hcode_prefixset_parse  --TO-->  hcode.prefixset_parse
--  hcode_prefixset_element  --TO-->  hcode.prefixset_element
--  hcode_prefixset_element  --TO-->  hcode.prefixset_element
--  hcode_prefixset_isin  --TO-->  hcode.prefixset_isin
--  hcode_prefixset_element_slower  --TO-->  hcode.prefixset_element_slower
--  geocode_distribution_generate  --TO-->  geocode_distribution_generate??
--  geocode_distribution_generate  --TO-->  geocode_distribution_generate
--  hcode_distribution_kpis  --TO-->  hcode.distribution_kpis
--  hcode_distribution_format  --TO-->  hcode.distribution_format
--  hcode_distribution_reduce_pre_raw  --TO-->  hcode.distribution_reduce_pre_raw
--  hcode_distribution_reduce_recursive_raw  --TO-->  hcode.distribution_reduce_recursive_raw
--  hcode_distribution_reduce  --TO-->  hcode.distribution_reduce
--  hcode_distribution_reduce  --TO-->  hcode.distribution_reduce
--  hcode_signature_reduce_pre_raw  --TO-->  hcode.signature_reduce_pre_raw
--  hcode_signature_reduce_recursive_raw  --TO-->  hcode.signature_reduce_recursive_raw
--  hcode_signature_reduce  --TO-->  hcode.signature_reduce
--  hcode_signature_reduce  --TO-->  hcode.signature_reduce
--  hcode_distribution_reduce_pre_raw_alt  --TO-->  hcode.distribution_reduce_pre_raw_alt
--  hcode_distribution_reduce_recursive_pre_raw_alt  --TO-->  hcode.distribution_reduce_recursive_pre_raw_alt
--  hcode_distribution_reduce_recursive_raw_alt  --TO-->  hcode.distribution_reduce_recursive_raw_alt

