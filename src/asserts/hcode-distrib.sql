-- supposing installed pg_dump of grade_id04_pts table

SELECT COUNT(*) FROM grade_id04_pts;

-- Exemples without backtracking:
SELECT * FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts'), 22, 2);
SELECT * FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts') );
SELECT * FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts'), 1, 1, 30 );
SELECT * FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts'), 1, 1, 300 );



-- Exemples with backtracking:
SELECT hcode, n_items, mdn_items, n_keys FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts'), 3, 1, 500, 5000 );
SELECT * FROM hcode_distribution_reduce_pre_raw( generate_geohashes('grade_id04_pts'), 2, 1, 500, 5000 );
