
## Extra-SRIDs on PostGIS

The [PostGIS table `spatial_ref_sys`](https://postgis.net/docs/using_postgis_dbmanagement.html#user-spatial-ref-sys) (see also ISO/IEC&nbsp;13249-3:2016 standard) must to be filled with at least:

* `srid`: a new non-confliting identifier, we adopting any positive integer from 950000. See also "grouping the new SRIDs"
* `proj4text`: a [PROJ](https://proj.org/) string.

We recommend filling in the other columns to help anyone who will consult in the future:
* `auth_name`: the name of the authority that published the projection.
* `auth_srid`: an internal authority's identifier, or bibliografic reference ID, with the yerar of the publication.
* `srtext`: an alternate representation expressed in the [OGC WKT](https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry) XML dialect.

## grouping the new SRIDs

* "EPSG number" group, any  SRID that not was in *default* `spatial_ref_sys` but is an "official EPSG".

* The "country's official projections" group,  from SRID 950000 to 953999

* The "DGGS projections" group, from SRID 955001 to 955099

* The "Etc projections" group,  from SRID 954000 to 954999
