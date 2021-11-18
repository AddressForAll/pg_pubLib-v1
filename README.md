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
of other projects, in the same database or same "ecosystem".

## Lib Organization

Functions are grouped in thematic source-files to maintainability.
Most of the thematic groups comes from PostgreSQL Documentation's "[Chapter 9. Functions and Operators](https://www.postgresql.org/docs/current/functions.html)". Others are inspired in "snippet classes".<!-- pending src/pubLib01py-string.sql-->

Function group         | Labels | Inspiration / dependence
-----------------------|--------------|------------
(System) [Administration](docs/admin.md) ([src](src/pubLib03-admin.sql)  |  `admin`     |  [pg/docs/functions-admin](https://www.postgresql.org/docs/current/functions-admin.html)) / string.
[Aggregate](docs/aggregate.md) ([src](src/pubLib04-aggregate.sql)  |  `agg`, `aggregate`     |  [pg/docs/functions-aggregate](https://www.postgresql.org/docs/current/functions-aggregate.html)) / array, json, sring.
[Array](docs/array.md) ([src](src/pubLib01-array.sql))  |  `array`     |  [pg/docs/functions-array](https://www.postgresql.org/docs/current/functions-array.html) (no dependency).
[GeoJSON](docs/pgis-geoJSON.md) ([src](src/pubLib06pgis-geoJSON.sql))  |  `geoJSON`     |  [PostGIS/GeoJSON](https://postgis.net/docs/ST_GeomFromGeoJSON.html) / pgis, json, admin.
[JSON](docs/json.md) ([src](src/pubLib03-json.sql))  |  `json`, `jsonb`     |  [pg/docs/functions-json](https://www.postgresql.org/docs/current/functions-admin.html) / array.
[PostGIS](docs/pgis-extraSRID.md) ([src](src/pubLib05pgis-extraSRID.sql))  |  `st`, `postGis`     |  [PostGIS/docs](https://postgis.net/docs/reference.html) / (fixed level-04 dependencies).
[String](docs/string.md) ([src](src/pubLib01-string.sql))  |  `str`, `string`     |  [pg/docs/functions-string](https://www.postgresql.org/docs/current/functions-string.html) (no dependency).
[HCodes](docs/hcode-distrib.md) ([src](src/pubLib05hcode-distrib.sql)) | `hcode`, `distrib` |  (Hierarchical or) [Natural Codes](http://addressforall.org/_foundations/art1.pdf) / json, array.
[Geohash](docs/pgis-geohash.md) ([src](src/pubLib06pgis-geohash.sql)) | `geohash`, `postGis` | [PostGIS/Geohash](https://postgis.net/docs/ST_GeoHash.html) / hcodes, pgis.

Libs also labeled by "dependence level"; for example Array library has no dependence, is level 01; JSON depends on Array, is level 03; and GeoJSON library depends on JSON, is level 4. The installation order is the dependency level.

## Installation

Edit makefile of your project to run each `psql $(pg_uri)/$(pg_db) < pubLib$(i).sql` in the correct order. For example any `pubLib02-*.sql` must run before `pubLib03-*.sql`, but same order like `pubLib03-admin.sql` and `pubLib03-json.sql` can be run in any order &mdash; by convention we adopt the alphabetic order, so use the `ls pubLib*.sql` order.

RECOMMENDATION: to install (in a database) only the used modules.

RATIONALE: each database in each project can use a different set of pubLib functions. It is good practice to avoid "namespace pollution" with unused functions, so, the pubLib modularization makes a reasonable partition over this "pollution risk".
