

-- -- -- -- -- --
-- Python Wraps

CREATE EXTENSION plpythonu;

-- str_to_normalized_unicode
CREATE or replace FUNCTION unicode_normalize(str text) RETURNS text as $f$
  # check details at https://stackoverflow.com/questions/24863716
  import unicodedata
  return unicodedata.normalize('NFC', str.decode('UTF-8'))
$f$ LANGUAGE PLPYTHONU STRICT;

CREATE or replace FUNCTION yaml_to_jsonb(p_yaml text) RETURNS jsonb AS $f$
    import yaml
    import json

    return json.dumps( yaml.safe_load(p_yaml) )
$f$ LANGUAGE plpython3u IMMUTABLE;
