# Version 0.2 migration (unreleased)

This release implements [issue #17](https://github.com/AddressForAll/pg_pubLib-v1/issues/17).
The repository remains pg_pubLib-v1; the library release changes from 0.1 to 0.2.

## Compatibility and behavior

PostgreSQL **14+** is required. SQL-standard function bodies were introduced in
PostgreSQL 14, so the issue comment's reference to 13+ does not apply to this release.

Concrete SQL functions now use `BEGIN ATOMIC` where possible. Their bodies are
parsed when installed and dependencies are recorded in PostgreSQL. Install modules
in dependency order, and install optional extensions before their wrappers.
Signatures, default arguments, NULL behavior and aggregate initial states are retained.

Parallel safety and volatility are separate properties. Catalog readers use
`STABLE`; file readers and template rendering use `VOLATILE`. Dynamic SQL and
file writes remain `PARALLEL UNSAFE`. Wrappers inherit the restrictions of their
callees. Safe aggregates have no new `COMBINEFUNC`: this change allows execution
in parallel queries, but does not promise partial aggregation or a speedup.

Aggregates use `CREATE OR REPLACE AGGREGATE` instead of dropping them with
`CASCADE`, preserving dependent objects during reinstallation. The PostGIS
characteristic diameter and resilient transform functions also support replacement.

## Exceptions

| Functions | Body / parallel classification | Reason |
|---|---|---|
| Polymorphic SQL functions (`iif`, generic array helpers) | Text SQL | Argument types cannot be resolved when defining an atomic body. |
| Generic array comparisons, sorting and distinct operations | UNSAFE | Operators for arbitrary user-defined element types may be unsafe. |
| `jsonb_array_to_text_array(jsonb,boolean)` | Atomic / UNSAFE | Calls the generic `array_distinct_sort` wrapper. |
| `array_sample` | Text SQL / VOLATILE / RESTRICTED | Uses `random()`. |
| `geohash_adjacent(text,int)` | Text SQL / SAFE | Self-recursion needs late resolution for clean installation; concrete operations were reviewed. |
| `geohash_adjacent2` | Text SQL / UNSAFE | Existing experimental recursive implementation is retained without redesign. |
| PL/pgSQL functions | PL/pgSQL | Atomic SQL syntax does not apply to procedural bodies; pure reviewed helpers can still be SAFE. |
| Catalog/documentation readers and SRID-title lookup | Atomic / STABLE / RESTRICTED | Results depend on catalogs or lookup tables and may reference session-local relations. |
| `utmgrid_from4326_coverlabels` | Atomic / VOLATILE / RESTRICTED | Uses random point generation. |
| PL/Python and `yamlfile_to_jsonb` | UNSAFE | External interpreter, imports, filesystem and unverified third-party dependencies. |
| `xml_pretty`, `xml_to_dec`, `xml_unescape` | UNSAFE | External XSLT processing or dynamic SQL. |

## Installation and tests

Use a disposable database for validation. From `src/`:

```sh
make core pg_uri=postgres://postgres@localhost/publib_test
make test pg_uri=postgres://postgres@localhost/publib_test
# After installing their respective optional modules:
make test-admin pg_uri=postgres://postgres@localhost/publib_test
make test-postgis pg_uri=postgres://postgres@localhost/publib_test
```

The makefile stops on the first SQL error. Tests cover concrete and polymorphic
functions, NULL/empty input, aggregates, serial/parallel results over 100,000 rows,
parallel planning, catalog changes, direct safety dependencies and preservation of
views depending on aggregates. Test objects and reinstallations are rolled back.

For an existing installation, reapply only the modules in use, in documented order.
Test the update on a copy first: atomic bodies now record dependencies, including
dependencies on extension functions. An installation using old aggregate signatures
from PostgreSQL 13 needs a separate migration of those signatures and their dependents.

## Validation performed

Validated on an isolated PostgreSQL 17 instance:

- Clean installation of core, PostGIS and XML modules.
- Functional core assertions also passed against the original sources.
- Updating the original installation with the migrated core, PostGIS and XML sources.
- Core, optional PostGIS and available admin assertions passed after the update.

Full admin installation remains untested: this PostgreSQL 17 installation has no
`adminpack`, so the extension declaration and `volat_file_write` were omitted
only in the disposable validation fixture. No production source was stubbed.
PL/Python validation is pending because the installed `plpython3.dll` fails to load
(error 126). PostgreSQL 14 execution and full admin/Python validation are still needed
before publishing the release. No release tag has been created.

References: [PostgreSQL 14 release notes](https://www.postgresql.org/docs/14/release-14.html),
[CREATE FUNCTION](https://www.postgresql.org/docs/17/sql-createfunction.html),
[Parallel safety](https://www.postgresql.org/docs/17/parallel-safety.html).
