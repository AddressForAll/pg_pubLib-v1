## PostgreSQL's Public schema common Library (pg_PubLib) version 1

Set of PostgreSQL funcions distributed by [CC0 License](https://creativecommons.org/publicdomain/zero/1.0/).
Plese cite this *git* by its canonical URL, http://git.addressforall.org/pg_pubLib

PubLib is an effort to reduce the impact of the "historic rationale" used by PostgreSQL developer team,
like [the lack of overloads in some native functions, as the *round*() function](https://stackoverflow.com/a/20934099/287948),
or the lack of [orthogonality](https://en.wikipedia.org/wiki/Orthogonal_instruction_set) in overloads and casts.
PubLib is also a [Library of Snippets](https://wiki.postgresql.org/wiki/Category:Library_Snippets),
implementating small and frequently used functions.
Typical  "small function" are also [IMMUTABLE](https://www.postgresql.org/docs/current/xfunc-volatility.html) ones.

## Usage

Your project not need to copy all source-code of this *git* (that is the "PubLib Central-v1"), so,
in general PubLib functions of your project are a subset of the PubLib-central.
Each project selects the functions it needs, maintaining it updated to be compatible with newer ones,
of other projects, in the same database.

## Lib Organization

Functions are grouped in thematic source-files to maintainability.
Most of the thematic groups comes from PostgreSQL Documentation's "[Chapter 9. Functions and Operators](https://www.postgresql.org/docs/current/functions.html)". Others are inspired in "snippet classes".<!-- pending src/pubLib01py-string.sql-->

Function group         | Labels | Inspiration
-----------------------|--------------|------------
(System) [Administration](src/pubLib03-admin.sql)  |  `admin`     |  [pg/docs/functions-admin](https://www.postgresql.org/docs/current/functions-admin.html)
[Aggregate](src/pubLib04-aggregate.sql)  |  `agg`/`aggregate`     |  [pg/docs/functions-aggregate](https://www.postgresql.org/docs/current/functions-aggregate.html)
[Array](src/pubLib01-array.sql)  |  `array`     |  [pg/docs/functions-array](https://www.postgresql.org/docs/current/functions-array.html)
[GeoJSON](src/pubLib06pgis-geoJSON.sql)  |  `geoJSON`     |  [PostGIS/GeoJSON](https://postgis.net/docs/ST_GeomFromGeoJSON.html)
[JSON](src/pubLib03-json.sql)  |  `json`/`jsonb`     |  [pg/docs/functions-json](https://www.postgresql.org/docs/current/functions-admin.html)
[PostGIS](src/pubLib05pgis-extraSRID.sql)  |  `st`/`postGis`     |  [PostGIS/docs](https://postgis.net/docs/reference.html)
[String](src/pubLib01-string.sql)  |  `str`/`string`     |  [pg/docs/functions-string](https://www.postgresql.org/docs/current/functions-string.html)
[Geohash](src/pubLib05pgis-geohash.sql) | `geohash`/`postGis` | [PostGIS/Geohash](https://postgis.net/docs/ST_GeoHash.html)

Libs also labeled by "dependence level"; for example Array library has no dependence, is level 01; JSON depends on Array, is level 03; and GeoJSON library depends on JSON, is level 4.

## Installation

Edit makefile of your project to run each `psql $(pg_uri)/$(pg_db) < pubLib$(i).sql` in the correct order. For example any `pubLib02-*.sql` must run before `pubLib03-*.sql`, but same tab-order like `pubLib03-admin.sql` and `pubLib03-json.sql` can be run in any order &mdash; by convention we adopt the alphabetic order, so use the `ls pubLib*.sql` order.
