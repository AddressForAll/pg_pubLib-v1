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
