
/**
 * PostgreSQL's Public schema, common Library (pubLib)
 * Original at http://git.AddressForAll.org/pg_pubLib-v1
 *
 * Module: XML.
 * Prefix: xml_
 * license: CC0
 */

CREATE EXTENSION IF NOT EXISTS xml2;

CREATE or replace FUNCTION xml_pretty(x xml,mode int DEFAULT 0)
RETURNS xml as $f$
  -- requires xml2 pg extension
  -- https://postgres.cz/wiki/PostgreSQL_SQL_Tricks#Pretty_xml_formating
  select xslt_process($1::text,
CASE WHEN mode=1 THEN  -- see https://stackoverflow.com/a/29113073/287948
$$
<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
<xsl:template match="*">
    <xsl:variable name="indent" select="concat('&#10;', substring('    ', 1, 3*count(ancestor::*)))" />
    <xsl:value-of select="$indent" />
    <xsl:copy>
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates select="node()"/>
        <xsl:value-of select="$indent" />
    </xsl:copy>
</xsl:template>
$$
ELSE -- See https://gist.github.com/LeKovr/e7b365d2dca58e4bc8c8f4695e0ca435
$$
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*" />
<xsl:output method="xml" indent="yes" />
<xsl:template match="node() | @*"><xsl:copy><xsl:apply-templates select="node() | @*" /></xsl:copy></xsl:template>
</xsl:stylesheet>
$$
END
)::xml
$f$ language SQL immutable;

CREATE or replace FUNCTION xml_to_dec(text)
RETURNS integer as $f$
  -- https://postgres.cz/wiki/PostgreSQL_SQL_Tricks_II#Conversion_between_hex_and_dec_numbers
declare r int;
begin
 execute E'select x\''||$1|| E'\'::integer' into r;
 return r;
end
$f$ language plpgsql immutable;

CREATE or replace FUNCTION xml_unescape(xml)
returns text as $f$
  -- this function do similar work as PHP's preg_replace_callback().
  -- convert escaped sybols like '&#x43E;' to unicode
  -- sample: select xml_unescape('&#x43E;&#x43F;&#x43B;&#x44F;&#x44F;'::xml) = 'опляя';
  -- See https://gist.github.com/LeKovr/e7b365d2dca58e4bc8c8f4695e0ca435
declare
  s text;
  rv text := $1;
begin
  for s in select distinct unnest(regexp_matches($1::text,'&#x(\w+);','g')) loop
    rv := replace(rv,'&#x'||s||';',chr(xml_to_dec(s)));
  end loop;
  return rv;
end
$f$ language plpgsql immutable;
