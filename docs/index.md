**SUMMARY**


* [Introduction](intro.md)
* [Installation](install.md)
* Function Guide, by group:
    - [hcode](hcode.md)
    - [pgis](pgis.md)

## Dependencies
The SQL source code, at [/src](http://git.AddressForAll.org/pg_pubLib-v1/tree/main/src), files in the form `pubLib*.sql` have its `*` part as labels in the folowing dependency diagram:

```mermaid
graph LR
    x3["03-{admin,json}"]
    x5h["05hcode-{distrib,encdec}"]
    x5gis["05pgis-{extraSRID,geohash,misc}"]
    00-general --> 01-array & 01py-string
    01-array --> 02-string --> x3 --> 04-aggregate
    04-aggregate --> x5h & x5gis & 05xml-general
    x5gis & x5h --> 06pgis-geoJSON
```


