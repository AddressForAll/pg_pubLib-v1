

-- -- -- -- -- --
-- Python3 Wraps

-- old CREATE EXTENSION plpythonu;
CREATE extension IF NOT EXISTS PLpython3u;  -- Python3 untrusted.
-- SELECT * FROM pg_language;

CREATE or replace FUNCTION py3_return_version() RETURNS text AS $$
    import sys
    return sys.version
$$ LANGUAGE plpython3u;
-- SELECT * FROM ingest.py3_return_version();

-- old unicode_normalize:
CREATE or replace FUNCTION str_to_normalized_unicode(str text) RETURNS text as $f$
  # check details at https://stackoverflow.com/questions/24863716
  import unicodedata
  return unicodedata.normalize('NFC', str.decode('UTF-8'))
$f$ LANGUAGE PLpython3u STRICT IMMUTABLE;  -- need STRICT?

CREATE or replace FUNCTION yaml_to_jsonb(p_yaml text) RETURNS jsonb AS $f$
    import yaml
    import json
    return json.dumps( yaml.safe_load(p_yaml) )
$f$ LANGUAGE PLpython3u IMMUTABLE;

CREATE or replace FUNCTION jsonb_to_yaml(p_jsonb text) RETURNS text AS $f$
    import yaml
    return yaml.dump(yaml.load( p_jsonb ), allow_unicode=True)
$f$ LANGUAGE PLpython3u IMMUTABLE;


CREATE or replace FUNCTION jsonb_to_yaml(p_jsonb text, flow_style boolean) RETURNS text AS $f$
    import yaml
    return yaml.dump(yaml.load( p_jsonb ), allow_unicode=True, default_flow_style=flow_style)
$f$ LANGUAGE PLpython3u IMMUTABLE;

CREATE or replace FUNCTION file_exists(p_file text) RETURNS boolean AS $f$
    import os
    return os.path.isfile(p_file)
$f$ LANGUAGE PLpython3u IMMUTABLE;

-------

CREATE or replace FUNCTION jsonb_mustache_render(
  tpl text,  -- input Mustache template
  i jsonb,   -- input content
  partials_path text DEFAULT '/var/gits/_dg/preserv/src/maketemplates/'
) RETURNS text AS $f$
  import chevron
  import json
  j = json.loads(i)
  return chevron.render(tpl,j,partials_path)
$f$ LANGUAGE plpython3u IMMUTABLE;
-- SELECT ingest.mustache_render('Hello, {{ mustache }}!', '{"mustache":"World"}'::jsonb);

----

CREATE or replace FUNCTION yamlfile_to_jsonb(file text) RETURNS JSONb AS $wrap$
  SELECT yaml_to_jsonb( pg_read_file(file) )
$wrap$ LANGUAGE SQL IMMUTABLE;

-----

CREATE or replace FUNCTION hcodes_common_prefix(
    -- pending to convert to SQL or PLpgSQL.
  a    text[]    -- the input codes with some common prefix
) RETURNS text AS $f$
    # See https://www.geeksforgeeks.org/longest-common-prefix-using-sorting/
    size = len(a)
  
    # if size is 0, return empty string 
    if (size == 0):
        return ""
  
    if (size == 1):
        return a[0]
  
    # sort the array of strings 
    a.sort()
      
    # find the minimum length from 
    # first and last string 
    end = min(len(a[0]), len(a[size - 1]))
  
    # find the common prefix between 
    # the first and last string 
    i = 0
    while (i < end and 
           a[0][i] == a[size - 1][i]):
        i += 1
  
    pre = a[0][0: i]
    return pre
  
$f$ language PLpython3u IMMUTABLE;
COMMENT ON FUNCTION hcodes_common_prefix(text[])
  IS 'Longest Common Prefix of a set of hcodes, sorting array'
;
-- SELECT hcodes_common_prefix( array['geeksforgeeks', 'geeks', 'geek', 'geezer'] );

