# Revised bounded study results

All declared jobs completed; no population equivalence or pure-language speedup is established. Two network fixtures, not 92 independent workloads.

## Native sensitivity

| Fixture | Cache | Julia implementation | Cache membership differences /32 | Alert differences /32 | Qualification differences at extra=1 /32 |
|---|---|---|---:|---:|---:|
| cisco | k3 | julia_weighted | 32 | 13 | 13 |
| cisco | k3 | julia_neighbors | 32 | 14 | 14 |
| cisco | k20 | julia_weighted | 32 | 0 | 0 |
| cisco | k20 | julia_neighbors | 32 | 0 | 0 |
| cisco | k3_adjacent | julia_weighted | 32 | 0 | 0 |
| cisco | k3_adjacent | julia_neighbors | 32 | 0 | 0 |
| fat4 | k3 | julia_weighted | 32 | 10 | 10 |
| fat4 | k3 | julia_neighbors | 32 | 12 | 12 |
| fat4 | k20 | julia_weighted | 32 | 0 | 0 |
| fat4 | k20 | julia_neighbors | 32 | 0 | 0 |
| fat4 | k3_adjacent | julia_weighted | 32 | 0 | 0 |
| fat4 | k3_adjacent | julia_neighbors | 32 | 0 | 0 |

Differences compare identical seed labels, not common random numbers. Any qualification/unsafe-release difference is case-material. Absence of such a difference is bounded observation only. Conditions on the same graph/seed are correlated.

## Primary qualification

| Cell | Fixture | Extra rows | Cache | Q | V | CCG-inspired | Guard-only | Detector qualified /3 | Guarded detector qualified /3 |
|---:|---|---:|---|---|---|---|---|---:|---:|
| 0 | cisco | 0 | k3 | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 1 | cisco | 0 | k20 | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 2 | cisco | 0 | k3_adjacent | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 3 | cisco | 1 | k3 | PASS | PASS | PASS | PASS | 3 | 3 |
| 4 | cisco | 1 | k20 | PASS | PASS | PASS | PASS | 3 | 3 |
| 5 | cisco | 1 | k3_adjacent | PASS | PASS | PASS | PASS | 3 | 3 |
| 6 | fat4 | 0 | k3 | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 7 | fat4 | 0 | k20 | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 8 | fat4 | 0 | k3_adjacent | PASS | RESOURCE_BLOCKED | PASS | RESOURCE_BLOCKED | 0 | 0 |
| 9 | fat4 | 1 | k3 | PASS | PASS | PASS | PASS | 3 | 3 |
| 10 | fat4 | 1 | k20 | PASS | PASS | PASS | PASS | 3 | 3 |
| 11 | fat4 | 1 | k3_adjacent | PASS | PASS | PASS | PASS | 3 | 3 |

Ordinary is an independently witnessed failure on both fixtures. Seed-independent controls are referenced once per fixture/row allowance. Proof reuse requires the exact validated plan and unchanged sources; it is not new packet-coverage evidence per seed. Detailed costs are in Primary_Results.csv and per-job TOML.

## Matched full snapshot search

| Condition | Implementation | Process state | Inner search median (s) | IQR (s) | Supervised process median (s) |
|---:|---|---|---:|---:|---:|
| 0 | python_numpy | cold | 0.0020406850380823016 | 7.192953489720821e-6 | 1.384561888 |
| 0 | python_numpy | warm | 0.0016451974515803158 | 9.90609114523977e-5 | 1.495789629 |
| 0 | julia | cold | 0.696219213 | 0.052573442000000026 | 9.84528338 |
| 0 | julia | warm | 0.00020625249999999998 | 1.7923499999999965e-5 | 10.000025681 |
| 1 | python_numpy | cold | 0.005352040054276586 | 7.446098607033491e-5 | 1.349316298 |
| 1 | python_numpy | warm | 0.0049209099961444736 | 6.535020656883717e-5 | 1.59986972 |
| 1 | julia | cold | 0.683771771 | 0.017837052000000075 | 9.691035138 |
| 1 | julia | warm | 0.000338381 | 5.608775000000006e-5 | 9.75311027 |
| 2 | python_numpy | cold | 0.00855784397572279 | 0.0002874719211831689 | 1.341738696 |
| 2 | python_numpy | warm | 0.00779136992059648 | 0.00013010192196816206 | 1.486593807 |
| 2 | julia | cold | 0.729462924 | 0.009137589999999918 | 9.803276317 |
| 2 | julia | warm | 0.0010543465 | 0.0001982952500000001 | 9.908508051 |
| 3 | python_numpy | cold | 0.02877166902180761 | 0.0004714331589639187 | 1.374069738 |
| 3 | python_numpy | warm | 0.027039144013542682 | 0.00024199829204007983 | 2.100707682 |
| 3 | julia | cold | 0.755988205 | 0.04391654199999995 | 9.886381082 |
| 3 | julia | warm | 0.0020654469999999998 | 0.0004921227499999998 | 9.887859079 |

Conditions are Cisco k3/k20 then fat-tree k3/k20. Warm process totals include warm-up and all 20 calls; they are not per-call latency. Cold means new process, not cold OS caches. Timings include implementation/representation/predicate/dependency differences, not an isolated language effect. Memory is job checkpoint peak including setup. No Python temporal-controller baseline is claimed. See Protocol.md and raw jobs for all measurement boundaries.

