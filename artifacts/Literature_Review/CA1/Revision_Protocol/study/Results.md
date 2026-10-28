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
| 0 | python_numpy | cold | 0.0020517129451036453 | 4.412501584738493e-5 | 1.35226161 |
| 0 | python_numpy | warm | 0.0016272750217467546 | 5.299453914631158e-5 | 1.394372217 |
| 0 | julia | cold | 0.689911085 | 0.0033481990000000517 | 9.79585663 |
| 0 | julia | warm | 0.000180436 | 1.1719499999999995e-5 | 9.947951182 |
| 1 | python_numpy | cold | 0.005400640948209912 | 6.261299131438136e-5 | 1.369426629 |
| 1 | python_numpy | warm | 0.004924162989482284 | 0.0001347102806903422 | 1.475035358 |
| 1 | julia | cold | 0.690337814 | 0.004972927000000071 | 9.800885901 |
| 1 | julia | warm | 0.00032712349999999997 | 1.6270750000000017e-5 | 9.889222829 |
| 2 | python_numpy | cold | 0.008493635978084058 | 5.631399108096957e-5 | 1.36287778 |
| 2 | python_numpy | warm | 0.007883329002652317 | 0.0003316915244795382 | 1.52223896 |
| 2 | julia | cold | 0.736164493 | 0.005373105999999961 | 9.862229712 |
| 2 | julia | warm | 0.001026484 | 0.0008051514999999998 | 10.101811731 |
| 3 | python_numpy | cold | 0.02914975502062589 | 0.0006199549534358084 | 1.398824498 |
| 3 | python_numpy | warm | 0.027453097485704347 | 0.0011380795476725325 | 1.97687612 |
| 3 | julia | cold | 0.73376987 | 0.01667447200000005 | 9.800604312 |
| 3 | julia | warm | 0.0023477505 | 0.0006146145 | 9.943727252 |

Conditions are Cisco k3/k20 then fat-tree k3/k20. Warm process totals include warm-up and all 20 calls; they are not per-call latency. Cold means new process, not cold OS caches. Timings include implementation/representation/predicate/dependency differences, not an isolated language effect. Memory is job checkpoint peak including setup. No Python temporal-controller baseline is claimed. See Protocol.md and raw jobs for all measurement boundaries.

