/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Module: general. (simple aliases and basic functions)
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

-- -- -- -- -- -- -- -- -- -- --
-- Complementar CAST functions:

CREATE or replace FUNCTION ROUND(float,int) RETURNS NUMERIC AS $wrap$
   SELECT ROUND($1::numeric,$2)
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,int)
  IS 'Cast for ROUND(float,x). Useful for SUM, AVG, etc. See also https://stackoverflow.com/a/20934099/287948.'
;

CREATE FUNCTION ROUND(
  input float,    -- the input number
  dec_digits int, -- decimal digits to reduce precision
  accuracy float  -- compatible accuracy, a "counting unit"
) RETURNS float AS $f$
   SELECT ROUND($1/accuracy,dec_digits)*accuracy
$f$ language SQL IMMUTABLE;
