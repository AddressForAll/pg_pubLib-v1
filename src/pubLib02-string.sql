CREATE EXTENSION IF NOT EXISTS unaccent;

-- -- -- -- -- -- -- --
-- Casts, str_to_something:

CREATE or replace FUNCTION to_bigint(str text) RETURNS bigint as $f$
  SELECT CASE WHEN s='' THEN NULL::int ELSE substr(s,1,18)::bigint END
  FROM (SELECT regexp_replace(str, '[^0-9]', '','g')) t(s)
  -- pendente avaliar solução que pega só o primero de vários número separados por espaço.
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION to_integer(str text) RETURNS int as $f$
  SELECT CASE WHEN s='' THEN NULL::int ELSE s::int END
  FROM (SELECT regexp_replace(str, '[^0-9]', '','g')) t(s)
$f$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- --
-- Array-aggregators:

-- string lib??

CREATE or replace FUNCTION to_hex( p_x bigint[], p_fill_zeros int DEFAULT NULL) RETURNS text[] AS $f$
  SELECT array_agg( CASE WHEN $2>0 THEN lpad(x,p_fill_zeros,'0') ELSE x END )
  FROM (SELECT to_hex(x) x FROM unnest($1) t1(x)) t
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION  stragg_prefix(prefix text, s text[], sep text default ',') RETURNS text AS $f$
  SELECT string_agg(x,sep) FROM ( select prefix||(unnest(s)) ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;


----
--- ISO 3166 ABBREVIATION scores.
CREATE or replace FUNCTION str_abbrev_regex(
  abbrev text
) RETURNS text AS $f$
  SELECT string_agg(x||'.*','') FROM regexp_split_to_table(abbrev,'') t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION str_abbrev_minscore(
  abbrev text, name text, lexlabel text DEFAULT '', old_score text DEFAULT ''
) RETURNS text AS $f$
  -- SCORES CONVENCIONADOS: 'B'=bom = 7 a 9, 'R'=regular=4 a 6, 'F'=fraco = 0 a 3
  -- ou mudar?  1 e 2    Fraca (ou Péssima);  3 e 4 Ruim;  5 e 6 Regular,  7 e 8 Boa; 9 e 10 Ótima.
  SELECT CASE WHEN NOT(upper(unaccent(lexlabel)) ~ str_abbrev_regex(abbrev)) THEN
     iif( upper(unaccent(name)) ~ str_abbrev_regex(abbrev), iif(old_score>'',old_score, 'R'::text), 'F'::text)
  ELSE COALESCE(old_score,'') END
$f$ LANGUAGE SQL IMMUTABLE;
-- Exemplos:
-- SELECT abbrevx, name, str_abbrev_minscore(abbrevx,name,lexlabel) as score FROM vw_jurabbrev;
-- SELECT parent_abbrev, abbrev, name, str_abbrev_minscore(abbrev,name,lexlabel) as score FROM jurabbrev_aux order by 4 desc, 1,2;

CREATE or replace FUNCTION str_urldecode(p text) RETURNS text AS $f$
 SELECT convert_from(CAST(E'\\x' || string_agg(
    CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex')
    ELSE substring(r.m[1] from 2 for 2)
 END, '') AS bytea), 'UTF8')
FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m);
  -- adapted from https://stackoverflow.com/a/8494602/287948
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION lexname_to_unix(p_lexname text) RETURNS text AS $$
  SELECT string_agg(initcap(p),'') FROM regexp_split_to_table($1,'\.') t(p)
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION lexname_to_unix(text)
  IS 'Convert URN LEX jurisdiction string to camel-case filename for Unix-like file systems.'
;

CREATE or replace FUNCTION substring_occurs(p_main text, p_sub text) RETURNS int AS $$
  SELECT ( CHAR_LENGTH(p_main) - CHAR_LENGTH(REPLACE(p_main,p_sub,'')) )  / CHAR_LENGTH(p_sub);
  -- see https://stackoverflow.com/a/36376548/287948
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION substring_occurs(text,text)
  IS 'Counts the number of occurences of a substring.'
;

----------------
--- REPORTS: ---

CREATE or replace FUNCTION treport_to_json_rows(treport_name text, p_safe_limit int default 1000)
RETURNS  TABLE(j json, idx int) as $f$
   -- Note: JSONB not good because losts column-order
 DECLARE
    query text;
 BEGIN
    query := format(
      'SELECT to_json(t) j, (ROW_NUMBER () OVER())::int idx FROM %s t LIMIT %s',
      treport_name,
      p_safe_limit
    );
    RETURN QUERY EXECUTE query; 
 END;
$f$ LANGUAGE PLpgSQL;

CREATE or replace FUNCTION treport_aswikitext(
  treport_name text,
  p_caption text DEFAULT '',
  p_safe_limit int DEFAULT 1000
) RETURNS text as $f$
 WITH r AS ( SELECT * FROM treport_to_json_rows($1,p_safe_limit) )
 ,h AS ( SELECT json_object_keys(j) k FROM (select j from r limit 1) t  )
 ,v AS ( SELECT idx,  (json_each_text(j)).value as txt FROM  r )
 SELECT string_agg(x,'') FROM (
   SELECT E'{| class="wikitable"' as x
   UNION ALL
   SELECT E'\n|+' as x WHERE p_caption>''
   UNION ALL
   SELECT format(E'\n|-\n!%s', string_agg(k,'!!')) FROM h
   UNION ALL
   SELECT E'\n|-\n|'|| string_agg(txt,'||' order by idx) FROM v group by idx
   UNION ALL
   SELECT E'\n|}'
 )
$f$ LANGUAGE SQL IMMUTABLE;
-- select volat_file_write( '/tmp/my_report_1_2.txt', (select * from treport_aswikitext('prod.vw_tmp_r1_2')) );

