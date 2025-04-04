/**
 * pgdoc - PostgreSQL's backenb sustem documentation.
 * Module: functional and structural initializations.
 * @see also: http://git.AddressForAll.org/pg_pubLib-v1/blob/main/src/pubLib03-admin.sql
 *
 * @notes: it is not https://github.com/pgdoc/PgDoc
 *  for DAG of dependencis, see  https://www.bustawin.com/dags-with-materialized-paths-using-postgres-ltree/
 */


CREATE EXTENSION IF NOT EXISTS xml2;
DROP SCHEMA IF EXISTS pgdoc CASCADE;
CREATE SCHEMA pgdoc;

-- -- -- -- -- --
-- -- Tables


CREATE TABLE pgdoc.assert (
  assert_id serial NOT NULL PRIMARY KEY,
  udf_pubid text, -- when not null is a library function, valid example
  assert_group text, -- when not null is a section name or taxonomic classificastion
  query text NOT NULL CHECK(trim(query)>''),
  result text, -- when not null it is to ASSERT
  UNIQUE(query)  -- aboids basic copy/paste duplication
);

CREATE TABLE pgdoc.selected_docs (
  file text  NOT NULL DEFAULT 'test.md', 
  grlabel text NOT NULL DEFAULT '',    -- group label
  -- same strutucture as doc_UDF_show_simplelines_asXHTML or doc_UDF_show() from here: 
  jinfo jsonb,
  xrendered xml
);
-- INSERT INTO  pgdoc.selected_docs SELECT 'a', * FROM doc_UDF_show_simplelines_asXHTML('public','','^(ST_|_st_|geometry_)') WHERE j->>'language'!='c';


-- -- -- -- -- --
-- Generic functions:
CREATE FUNCTION pgdoc.rel_description(
     p_relname text,
     p_schemaname text DEFAULT NULL
) RETURNS text AS $f$
    -- see https://stackoverflow.com/a/12736192/287948
    SELECT obj_description((CASE 
       WHEN strpos($1, '.')>0 THEN $1
       WHEN $2 IS NULL THEN 'public.'||$1
       ELSE $2||'.'||$1
            END)::regclass, 'pg_class');
$f$ LANGUAGE SQL;
 
CREATE FUNCTION pgdoc.col_description(
    p_relname text,  -- table name or schema.table 
    p_colname text,  -- table's column name
    p_database text DEFAULT NULL -- NULL for current
) RETURNS text AS $f$
    -- see https://stackoverflow.com/a/12736192/287948
    WITH r AS (
      SELECT CASE WHEN array_length(x,1)=1 THEN array['public',x[1]] ELSE x END
      FROM regexp_split_to_array(p_relname,'\.') t(x)
     ) 
    SELECT col_description(p_relname::regClass, ordinal_position)
    FROM r, information_schema.columns i
    WHERE i.table_catalog = CASE WHEN $3 IS NULL THEN current_database() ELSE $3 END 
      AND i.table_schema  = r.x[1]
      AND i.table_name    = r.x[2]
      AND i.column_name = p_colname
$f$ LANGUAGE SQL;
-- SELECT col_description('tableName','colName'); 
-- SELECT col_description('schemaName.tableName','colName','databaseName); 

-- -- -- -- -- --
-- -- Functions

CREATE or replace FUNCTION pgdoc.doc_UDF_show_simple_asJSONb(
    p_schema_name text,    -- schema choice
    p_regex_or_like text,   -- name filter
    p_name_notlike text DEFAULT '',
    p_include_udf_pubid boolean DEFAULT false
) RETURNS SETOF jsonb AS $f$

  SELECT to_jsonb(t)
  FROM  (
    SELECT p_include_udf_pubid AS include_udf_pubid,
           u.*, -- reduzir, eliminando arguments
           array_to_string(arguments_simplified,', ') AS str_args,
           CASE WHEN arguments!=array_to_string(arguments_simplified,', ') THEN arguments ELSE NULL END AS str_fullargs,
           a.examples
           -- CASE WHEN a.udf_pubid IS NOT NULL THEN '<p>'||queries_xhtml||'</p>' ELSE '' END AS if_examples
    FROM doc_UDF_show_simple(p_schema_name,p_regex_or_like,p_name_notlike) u
         LEFT JOIN (
           SELECT udf_pubid,
                  '<code>'||string_agg(query,'</code> <br/> <code>')||'</code>' as examples
           FROM pgdoc.assert
           GROUP BY udf_pubid
         ) a
         ON u.id=a.udf_pubid
  ) t;

$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pgdoc.doc_UDF_show_simple_asJSONb
  IS 'Generates a JSONb array of descriptors with each standard UFD documentation.'
;
-- SELECT pgdoc.doc_UDF_show_simple_asJSONb( 'public', '^(iif|round|round|minutes|trunc_bin)$' );


CREATE or replace FUNCTION pgdoc.doc_UDF_show_simplelines_asXHTML(
    p_schema_name text,    -- schema choice
    p_regex_or_like text,   -- name filter
    p_name_notlike text DEFAULT '',
    p_include_udf_pubid boolean DEFAULT false
) RETURNS table (j jsonb, xrendered xml) AS
$f$
  SELECT template_input as j,
         jsonb_mustache_render(
              $$<tr>
                {{#include_udf_pubid}}<td>{{id}}</td>{{/include_udf_pubid}}
                <td>
                  <b><code>{{name}}(</code></b>{{#str_args}}<i>{{.}}</i>{{/str_args}}<b><code>)</code> → </b> <i>{{return_type}}</i>
                  {{#comment}}  <p class="pgdoc_comment">{{.}}</p>  {{/comment}}
                  {{#str_fullargs}}  <p class="pgdoc_args">Argument names: <i>{{.}}</i></p>  {{/str_fullargs}}
                  {{#examples}}  <p class="pgdoc_examples">{{{.}}}</p>  {{/examples}}
                </td>
              </tr>$$,
             
              template_input
             
         )::xml
   FROM pgdoc.doc_UDF_show_simple_asJSONb(p_schema_name,p_regex_or_like,p_name_notlike,p_include_udf_pubid) t(template_input)
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pgdoc.doc_UDF_show_simplelines_asXHTML(text,text,text,boolean)
  IS 'Generates a XHTML-row per function, with standard UFD documentation, from doc_UDF_show_simple_asJSONb().'
;

CREATE or replace FUNCTION pgdoc.doc_UDF_show_simple_asXHTML(
    p_schema_name text,    -- schema choice
    p_regex_or_like text,   -- name filter
    p_name_notlike text DEFAULT '',
    p_include_udf_pubid boolean DEFAULT false
) RETURNS xml AS
$f$
  SELECT xmlelement(
           name table,
           xmlattributes('pgdoc_tab' as class),
           concat('<tr>', CASE WHEN p_include_udf_pubid THEN '<td> ID </td>' ELSE '' END, '<td> Function / Description / Example </td></tr>')::xml,
           xmlagg(xrendered)
         )
  FROM pgdoc.doc_UDF_show_simplelines_asXHTML(p_schema_name,p_regex_or_like,p_name_notlike,p_include_udf_pubid)
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pgdoc.doc_UDF_show_simple_asXHTML(text,text,text,boolean)
  IS 'Generates a XHTML table with standard UFD documentation, from doc_UDF_show_simple_asJSONb().'
;
-- SELECT volat_file_write( '/tmp/lix.md', pgdoc.doc_UDF_show_simple_asXHTML( 'public', '^(iif|round|round|minutes|trunc_bin)$', false)::text );
-- SELECT xml_pretty( pgdoc.doc_UDF_show_simple_asXHTML( 'public', '^(iif|round|round|minutes|trunc_bin)$', true)  );

------

CREATE or replace FUNCTION pgdoc.doc_UDF_showselected_asMD_file(
  fpath text default '/tmp/',
  p_include_udf_pubid boolean DEFAULT false
) RETURNS SETOF text AS
$f$
  WITH files AS (
    SELECT file, 
           ' '|| count(*) || ' sections' AS secs,
           string_agg( '## '|| grlabel || E'\n' ||  regexp_replace(xcontent::text, '\n\s*\n',E'\n','g') ,  E'\n\n' ) AS mdcontent
    FROM (
      SELECT file, grlabel,
         xmlelement(
           name table,
           xmlattributes('pgdoc_tab' as class),
           concat('<tr>', CASE WHEN p_include_udf_pubid THEN '<td> ID </td>' ELSE '' END, '<td> Function / Description / Example </td></tr>')::xml,
           xmlagg(xrendered)
          ) as xcontent
      FROM pgdoc.selected_docs
      GROUP BY 1,2 ORDER BY 1, 2
    ) t1
    GROUP BY file ORDER BY file  
  ) 
  SELECT volat_file_write(fpath||file, mdcontent, secs)
  FROM files;
$f$  LANGUAGE SQL IMMUTABLE;
