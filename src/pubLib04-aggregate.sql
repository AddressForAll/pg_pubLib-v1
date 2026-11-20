CREATE or replace FUNCTION  stragg_prefix(prefix text, s text[], sep text default ',') RETURNS text
LANGUAGE SQL IMMUTABLE PARALLEL SAFE
BEGIN ATOMIC
  SELECT string_agg(x,sep) FROM ( select prefix||(unnest(s)) ) t(x);
END;

CREATE OR REPLACE AGGREGATE array_agg_cat(anycompatiblearray) (
  SFUNC=array_cat,
  STYPE=anycompatiblearray,
  INITCOND='{}',
  PARALLEL=SAFE
);


-- -- -- -- -- -- -- -- -- -- --
-- Depends on pubLib01-array.sql

CREATE or replace AGGREGATE array_agg_cat_distinct(anyarray) (
  SFUNC=array_cat_distinct,
  STYPE=anyarray,
  INITCOND='{}',
  PARALLEL=UNSAFE
);

-- -- -- -- -- -- -- -- -- -- --
-- ! Depends on pubLib03-json.sql

CREATE OR REPLACE AGGREGATE jsonb_summable_aggmerge(jsonb) ( -- important!
  SFUNC=jsonb_summable_merge,
  STYPE=jsonb,
  INITCOND=NULL,
  PARALLEL=SAFE
);

/* DROP AGGREGATE IF EXISTS jsonb_summable_aggmerge(jsonb[]) CASCADE;
CREATE OR REPLACE AGGREGATE jsonb_summable_aggmerge(jsonb[]) ( -- low use
  SFUNC=jsonb_summable_merge,
  STYPE=jsonb[],
  INITCOND='{}' -- test with null
);
*/
