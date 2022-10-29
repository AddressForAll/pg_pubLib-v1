/**
 * pgdoc - PostgreSQL's backenb sustem documentation.
 * Module: functional and structural initializations.
 * @see also: http://git.AddressForAll.org/pg_pubLib-v1/blob/main/src/pubLib03-admin.sql
 *
 * @notes: it is not https://github.com/pgdoc/PgDoc
 *  for DAG of dependencis, see  https://www.bustawin.com/dags-with-materialized-paths-using-postgres-ltree/
 */


CREATE EXTENSION IF NOT EXISTS xml2;
DROP SCHEMA IF EXISTS pgdoc;
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

-- -- -- -- -- --
-- -- Functions

CREATE or replace FUNCTION pgdoc.doc_UDF_show_simple_asJSONb(
    p_schema_name text,    -- schema choice
    p_regex_or_like text,   -- name filter
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
    FROM doc_UDF_show_simple(p_schema_name,p_regex_or_like) u
         LEFT JOIN (
           SELECT udf_pubid,
                  '<code>'||string_agg(query,'</code> <br/> <code>')||'</code>' as examples
           FROM pgdoc.assert
           GROUP BY udf_pubid
         ) a
         ON u.id=a.udf_pubid
  ) t;

$f$  LANGUAGE SQL IMMUTABLE;
-- SELECT pgdoc.doc_UDF_show_simple_asJSONb( 'public', '^(iif|round|round|minutes|trunc_bin)$' );

CREATE or replace FUNCTION pgdoc.doc_UDF_show_simple_asXHTML(
    p_schema_name text,    -- schema choice
    p_regex_or_like text,   -- name filter
    p_include_udf_pubid boolean DEFAULT false
) RETURNS xml AS $f$

  SELECT xmlelement(
           name table,
           xmlattributes('pgdoc_tab' as class),
           concat('<tr>', CASE WHEN p_include_udf_pubid THEN '<td> ID </td>' ELSE '' END, '<td> Function / Description / Example </td></tr>')::xml,
    
           xmlagg( jsonb_mustache_render(
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
             
           )::xml )
    
         )
     FROM pgdoc.doc_UDF_show_simple_asJSONb(p_schema_name,p_regex_or_like,p_include_udf_pubid) t(template_input)
     
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pgdoc.doc_UDF_show_simple_asXHTML
  IS 'Generates a XHTML table with standard UFD documentation.'
;
-- SELECT volat_file_write( '/tmp/lix.md', pgdoc.doc_UDF_show_simple_asXHTML( 'public', '^(iif|round|round|minutes|trunc_bin)$', false)::text );
-- SELECT xml_pretty( pgdoc.doc_UDF_show_simple_asXHTML( 'public', '^(iif|round|round|minutes|trunc_bin)$', true)  );
