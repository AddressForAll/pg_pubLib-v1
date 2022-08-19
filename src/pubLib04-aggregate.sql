CREATE or replace FUNCTION  stragg_prefix(prefix text, s text[], sep text default ',') RETURNS text AS $f$
  SELECT string_agg(x,sep) FROM ( select prefix||(unnest(s)) ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

DROP AGGREGATE IF EXISTS array_agg_cat(anycompatiblearray) CASCADE;
CREATE AGGREGATE array_agg_cat(anycompatiblearray) (
  SFUNC=array_cat,
  STYPE=anycompatiblearray,
  INITCOND='{}'
);


-- -- -- -- -- -- -- -- -- -- --
-- Depends on pubLib01-array.sql

DROP AGGREGATE IF EXISTS array_agg_cat_distinct(anyarray);
CREATE or replace AGGREGATE array_agg_cat_distinct(anyarray) (
  SFUNC=array_cat_distinct,
  STYPE=anyarray,
  INITCOND='{}'
);

-- -- -- -- -- -- -- -- -- -- --
-- ! Depends on pubLib03-json.sql

DROP AGGREGATE IF EXISTS jsonb_summable_aggmerge(jsonb) CASCADE;
CREATE AGGREGATE jsonb_summable_aggmerge(jsonb) ( -- important!
  SFUNC=jsonb_summable_merge,
  STYPE=jsonb,
  INITCOND=NULL
);

/* DROP AGGREGATE IF EXISTS jsonb_summable_aggmerge(jsonb[]) CASCADE;
CREATE AGGREGATE jsonb_summable_aggmerge(jsonb[]) ( -- low use
  SFUNC=jsonb_summable_merge,
  STYPE=jsonb[],
  INITCOND='{}' -- test with null
);
*/
