

-- -- -- -- -- --
-- Python Wraps

CREATE EXTENSION plpythonu;

CREATE or replace FUNCTION unicode_normalize(str text) RETURNS text as $f$
  # check details at https://stackoverflow.com/questions/24863716
  import unicodedata
  return unicodedata.normalize('NFC', str.decode('UTF-8'))
$f$ LANGUAGE PLPYTHONU STRICT;

CREATE or replace FUNCTION to_integer(str text) RETURNS int as $f$
  SELECT CASE WHEN s='' THEN NULL::int ELSE s::int END
  FROM (SELECT regexp_replace(str, '[^0-9]', '','g')) t(s) 
$f$ LANGUAGE SQL IMMUTABLE;
