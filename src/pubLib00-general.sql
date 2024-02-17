/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Module: general. (simple aliases and basic CAST functions)
 *
 * Complementing https://www.postgresql.org/docs/current/functions-array.html
 */

-- -- -- -- -- -- -- -- -- -- --
-- Helper functions: avoid.

CREATE or replace FUNCTION iIF(
    condition boolean,       -- IF condition
    true_result anyelement,  -- THEN
    false_result anyelement  -- ELSE
    -- See https://stackoverflow.com/a/53750984/287948
) RETURNS anyelement AS $f$
  SELECT CASE WHEN condition THEN true_result ELSE false_result END
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION iif
  IS 'Immediate IF. Sintax sugar for the most frequent CASE-WHEN. Avoid with text, need explicit cast.'
;

-- -- -- -- -- -- -- -- -- --
-- ROUND and TRUNC functions

-- FLOAT:
CREATE or replace FUNCTION ROUND(float,int) RETURNS NUMERIC AS $wrap$
   SELECT ROUND($1::numeric,$2)
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,int)
  IS 'Cast for ROUND(float,x). Useful for SUM, AVG, etc. See also https://stackoverflow.com/a/20934099/287948.'
;

CREATE or replace FUNCTION ROUND(
  input    float,    -- the input number
  accuracy float     -- accuracy
) RETURNS float AS $f$
  SELECT (ROUND($1/accuracy)*accuracy)::numeric(99,9)::float
  -- SELECT ROUND($1/accuracy)*accuracy
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,float)
  IS 'ROUND by accuracy. See Round9 at https://stackoverflow.com/a/20933882/287948'
;
-- SELECT round(1/3., 0.00001);  -- 0.33333 float!
-- SELECT round(1/3., 0.005);    -- 0.335
-- SELECT round(21.04, 0.05);     -- 21.05
-- SELECT round(21.04, 5::float); -- 20
-- SELECT round(pi(), 0.0001);    -- 3.1416

-- TIME:
CREATE or replace FUNCTION round_minutes(
  input TIMESTAMP WITHOUT TIME ZONE,
  countUnit_minutes integer   -- count unit
) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $f$
  SELECT
     date_trunc('hour', $1)
     +  cast((countUnit_minutes::varchar||' min') as interval)
     * round(
       (date_part('minute',$1)::float + date_part('second',$1)/ 60.)::float
       / countUnit_minutes::float
     )
$f$ LANGUAGE SQL IMMUTABLE;
-- SELECT round_minutes('2010-09-17 16:23:12', 5);

CREATE or replace FUNCTION round_minutes(
  input TIMESTAMP WITHOUT TIME ZONE,
  countUnit_minutes integer,   -- count unit
  str_format text              -- to_chat() standard
) RETURNS text AS $f$
  SELECT to_char( round_minutes($1,countUnit_minutes), str_format)
$f$ LANGUAGE SQL IMMUTABLE;
-- SELECT round_minutes('2010-09-17 16:23:12', 10, 'HH24:MI');

CREATE or replace FUNCTION trunc_bin(x bigint, bits int) RETURNS bigint AS $f$
    SELECT ((x::bit(64) >> bits) << bits)::bigint;
$f$ language SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- -- -- -- --
-- EXPERIMENTS (functions under test or construction)

CREATE or replace FUNCTION decimal_zeros(
  x float,                   -- input
  d_correction int DEFAULT 1 -- correction on the number of digits
) RETURNS int AS $f$
    SELECT CASE WHEN d<0 THEN 0 ELSE d END
    FROM (
      SELECT length(s) - length( regexp_replace(s,'\.0+','') ) - d_correction AS d
      FROM (SELECT x::text) t1(s)
    ) t2
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION trunc(
   x float,
   xtype text,  -- 'bin', 'dec' or 'hex'
   xdigits int DEFAULT 0
) RETURNS float AS $f$
    SELECT CASE
       WHEN xtype NOT IN ('dec','bin','hex') THEN 'NaN'::float
       WHEN xdigits=0 THEN trunc(x)
       WHEN xtype='dec' THEN trunc(x::numeric,xdigits)
       ELSE (s1 ||'.'|| s2)::float
      END
    FROM (
      SELECT s1,
             lpad(
               trunc_bin( s2::bigint, CASE WHEN xd<bin_bits THEN bin_bits - xd ELSE 0 END )::text,
               l2,
               '0'
             ) AS s2
      FROM (
        SELECT *,
             (floor( log(2,s2::numeric) ) +1)::int AS bin_bits, -- most significant bit position, bitwise_MSB()
             CASE WHEN xtype='hex' THEN xdigits*4 ELSE xdigits END AS xd
        FROM (
          SELECT s[1] AS s1, s[2] AS s2, length(s[2]) AS l2
          FROM (SELECT regexp_split_to_array(x::text,'\.')) t1a(s)
        ) t1b
      ) t1c
    ) t2
$f$ language SQL IMMUTABLE;
-- SELECT round(1/3.,'dec',4);     -- 0.3333 float!
-- SELECT round(2.8+1/3.,'dec',1); -- 3.1 float!
-- SELECT round(2.8+1/3.,'dec');   -- ERROR, need to cast string
-- SELECT round(2.8+1/3.,'dec'::text); -- 3 float
-- SELECT round(2.8+1/3.,'dec',0); -- 3 float
-- SELECT round(2.8+1/3.,'hex',0); -- 3 float (no change)
-- SELECT round(2.8+1/3.,'hex',1); -- 3.1266
-- SELECT round(2.8+1/3.,'hex',3); -- 3.13331578486784
-- SELECT round(2.8+1/3.,'bin',1);  -- 3.1125899906842625
-- SELECT round(2.8+1/3.,'bin',6);  -- 3.1301821767286784
-- SELECT round(2.8+1/3.,'bin',12); -- 3.13331578486784

----

CREATE or replace FUNCTION bit_MSB(x bigint) RETURNS int AS $f$
  -- Must be optimized in C, see e.g. https://stackoverflow.com/a/673781/287948
  SELECT CASE 
        WHEN x IS NULL OR x<0 THEN NULL 
        WHEN x =0 THEN 0 
        ELSE (floor( log(2,x::numeric) ) +1)::int
        END 
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION bit_MSB(bigint)
  IS 'Must Significant Bit position, the length in a varbit representation.'
;
