
DO $a$
BEGIN
RAISE NOTICE '--- Function str_geohash_encode: ---';
ASSERT str_geohash_encode('geo:-9.97544,-67.83122') = '6qpz22nb',    'fail in 6qpz22nb';
ASSERT str_geohash_encode('geo:-3.130278,-60.023333') = '6xmq4nhk',  'fail in 6xmq4nhk';
ASSERT str_geohash_encode('geo:3.86139,-51.79611') = 'dbejvqgn',     'fail in dbejvqgn';
ASSERT str_geohash_encode('geo:3.8569,-51.82561') = 'dbejuwjs',      'fail in dbejuwjs';
ASSERT str_geohash_encode('geo:-13.002025,-38.532972') = '7jsw51j1', 'fail in 7jsw51j1';
ASSERT str_geohash_encode('geo:-3.807267,-38.522481') = '7pkd76uv',  'fail in 7pkd76uv';
ASSERT str_geohash_encode('geo:-15.799717,-47.864131') = '6vjyngdr', 'fail in 6vjyngdr';
ASSERT str_geohash_encode('geo:-20.292149,-40.28804') = '7h7ke1zj',  'fail in 7h7ke1zj';
ASSERT str_geohash_encode('geo:-2.529028,-44.302476') = '7p83xgeg',  'fail in 7p83xgeg';
ASSERT str_geohash_encode('geo:-15.603056,-56.120556') = '6v0p4zw3', 'fail in 6v0p4zw3';
ASSERT str_geohash_encode('geo:-1.43056,-48.4569') = '6ztxc7df',     'fail in 6ztxc7df';
ASSERT str_geohash_encode('geo:-3.854722,-32.428333') = '7r2fn462',  'fail in 7r2fn462';
ASSERT str_geohash_encode('geo:-25.5925,-54.593056') = '6g3nmtn8',   'fail in 6g3nmtn8';
ASSERT str_geohash_encode('geo:-22.952331,-43.210369') = '75cm2txh', 'fail in 75cm2txh';
ASSERT str_geohash_encode('geo:-5.756389,-35.194722') = '7nyzr05f',  'fail in 7nyzr05f';
ASSERT str_geohash_encode('geo:2.84139,-60.69222') = 'd8sb4vm2',     'fail in d8sb4vm2';
ASSERT str_geohash_encode('geo:5.20194,-60.7369') = 'd8uv9fux',      'fail in d8uv9fux';
ASSERT str_geohash_encode('geo:-33.7417,-53.3736') = '6f4013w8',     'fail in 6f4013w8';
ASSERT str_geohash_encode('geo:-29.78333,-57.03694') = '6dxqw44g',   'fail in 6dxqw44g';
ASSERT str_geohash_encode('geo:-23.550385,-46.633956') = '6gyf4bf1', 'fail in 6gyf4bf1';

RAISE NOTICE '--- Function str_geohash_decode: ---';
ASSERT array_round(str_geohash_decode('6qpz22nb'),0.001) = '{-9.976,-67.831}'::float[],   'fail in 6qpz22nb';
ASSERT array_round(str_geohash_decode('6xmq4nhk'),0.001) = '{-3.13,-60.023}'::float[],    'fail in 6xmq4nhk';
ASSERT array_round(str_geohash_decode('dbejvqgn'),0.001) = '{3.861,-51.796}'::float[],    'fail in dbejvqgn';
ASSERT array_round(str_geohash_decode('dbejuwjs'),0.001) = '{3.857,-51.826}'::float[],    'fail in dbejuwjs';
-- ...
ASSERT array_round(str_geohash_decode('d8uv9fux'),0.001) = '{5.202,-60.737}'::float[],   'fail in d8uv9fux';
ASSERT array_round(str_geohash_decode('6f4013w8'),0.001) = '{-33.742,-53.373}'::float[], 'fail in 6f4013w8';
ASSERT array_round(str_geohash_decode('6dxqw44g'),0.001) = '{-29.783,-57.037}'::float[], 'fail in 6dxqw44g';
ASSERT array_round(str_geohash_decode('6gyf4bf1'),0.001) = '{-23.55,-46.634}'::float[],  'fail in 6gyf4bf1';
END;$a$;

/*  -- generators --

wget https://github.com/osm-codes/BR_IBGE/blob/main/data/ptCtrl.csv

awk -F "," '{print "(" $3 "," $4 "," $5 "),";}' ptCtrl.csv

WITH glist AS (
  SELECT geouri,
         libgrid.str_geohash_encode_bypgis(geouri) as geohash,
         'http://wikidata.org/entity/Q'||wdid as descriptor
  FROM (VALUES
        ('geo:-9.97544,-67.83122',10387829),
        ('geo:-3.130278,-60.023333',1434444),
        ('geo:3.86139,-51.79611',9586256),
        ('geo:3.8569,-51.82561',996255),
        ('geo:-13.002025,-38.532972',58877523),
        ('geo:-3.807267,-38.522481',958185),
        ('geo:-15.799717,-47.864131',4155889),
        ('geo:-20.292149,-40.28804',28055077),
        ('geo:-2.529028,-44.302476',10378807),
        ('geo:-15.603056,-56.120556',641448),
        ('geo:-1.43056,-48.4569',10305532),
        ('geo:-3.854722,-32.428333',3312795),
        ('geo:-25.5925,-54.593056',2166850),
        ('geo:-22.952331,-43.210369',79961),
        ('geo:-5.756389,-35.194722',3304114),
        ('geo:2.84139,-60.69222',597669),
        ('geo:5.20194,-60.7369',578202),
        ('geo:-33.7417,-53.3736',2839542),
        ('geo:-29.78333,-57.03694',2744827),
        ('geo:-23.550385,-46.633956',10325364)
  ) AS t (geouri,wdid)
)
  SELECT format(E'ASSERT str_geohash_encode(\'%s\') = \'%s\', \'fail in %s\';',geouri,geohash,geohash)
  FROM glist;

*/
