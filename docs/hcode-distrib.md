
## Heurísticas implementadas

See `hcode.distribution_reduce_recursive_raw()` function at https://git.AddressForAll.org/pg_pubLib-v1/blob/main/src/pubLib05hcode-distrib.sql#L225


Title                            |p_left_erode                  |p_size_min                 |p_threshold                  |p_threshold_sum
---------------------------------|------------------------------|---------------------------|-----------------------------|---------------
H1. heuristica básica            |p - 1                         |p                          |p                            |p
H2. H1 com redução dos thresholds|p - 1                         |p                          |`round(p*0.85)::int`         |`round(p*0.85)::int`
H3. H1 com erosão unitária       |1                             |p                          |p                            |p
