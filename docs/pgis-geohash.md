
## Step-by-step

Alguns exemplos usando passo-a-passo mais grosseiro e artesanal, usando apenas a função [geohash_cover(geom,prefix)](https://github.com/AddressForAll/pg_pubLib-v1/blob/main/src/pubLib05pgis-geohash.sql#L22).

### Brasil, recorrencia para cobertura da fronteira
Exemplo de resultados do uso de Geohash_cover com os limites de país do Brasil:

```sql
CREATE VIEW br_geom AS SELECT geom FROM ingest.fdw_jurisdiction_geom where isolabel_ext='BR';

select geohash_cover(geom) from br_geom;
--  {6,7,d,e}

select geohash_cover(geom,'6') from br_geom;
-- {6d,6f,6g,6q,6r,6s,6t,6u,6v,6w,6x,6y,6z} ; cardinality=13

select cardinality(geohash_cover(geom,'6qm')) br_geom;
-- 32  (a célula '6qm' está totalmente contida no Brasil)
```
Não precisamos conferir a cardinalidade para saber que uma célula está totalmente contida: uma pequena modificação na função, e usando objetos json ao invés de arrays, nos permite controlar o critério.

```sql
select geohash_cover_contains(geom) br_geom;
-- {"6": false, "7": false, "d": false, "e": false}

select geohash_cover_contains(geom,'6') br_geom;
--  {"6d": false, "6f": false, "6g": false, "6q": false, "6r": false, "6s": false, "6t": false, "6u": false,
--   "6v": true, "6w": false, "6x": true, "6y": true, "6z": false}

select geohash_cover_contains(geom,'6g') br_geom;
-- {"6g0": false, "6g1": false, "6g3": false, "6g4": true, "6g5": true, "6g6": true, "6g7": true, "6g8": false, ...}
```

Podemos estabelecer um número máximo de dígitos, mantendo apenas os geohashes indicados como *false* (não totalmente contidos no Brasil), e obter todos eles por recorrência. A ilustração abaixo mostra o resultado no QGIS sobrepondo as geometrias recortadas (cuT) às geometrias de célula puras (boxes).

```sql
CREATE qgis_output1_boxes AS
 SELECT row_number() OVER () as gid, g.*
 FROM br_geom b, LATERAL geohash_cover_noncontained_recursive(b.geom,3,false) g;

CREATE qgis_output2_cuts AS
 SELECT row_number() OVER () as gid, g.*
 FROM br_geom b, LATERAL geohash_cover_noncontained_recursive(b.geom,3,true) g;
```

![](assets/br_geohash3_countor2.png)

### Niteroi, cobertura análoga BBOX

Exemplo de resultados com o Niteroi, o município está inteiramente contido em um só Geohash, de 4 dígitos:

```sql
select geohash_cover(geom) from  ingest.fdw_jurisdiction_geom where isolabel_ext='BR-RJ-Niteroi';
-- {75cm}

select geohash_cover(geom,'75cm') from  ingest.fdw_jurisdiction_geom where isolabel_ext='BR-RJ-Niteroi';
-- {75cm5,75cm6,75cm7,75cmd,75cme,75cmf,75cmg,75cmh,75cmk,75cmm,75cms,75cmt,75cmu,75cmv,75cmw}
```

### Mosaicos de distribuição

Resumo dos requsitos de uma distribuição balanceada pelo tamanho dos arquivos formados por conjuntos de geometrias, tentando primeiro pelos Geohashes de maior área (menos dígitos), depois recorrentemente os seus filhos:
- Se pai pode conter tudo (ocupa menos que size_max), resolvido, ficamos com ele e fim.
- Senão pai é distribuída em filhos e pai absorve "poeira" (filhos com menos que  size_min).
- A cada filho grande demais (mais que size_max), recorrência usando ele como pai.
- A recorrência também encerra se número de dígitos Geohash passarem do limite (ghs_len).

... mostrar implementação ...
