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
| 0 | python_numpy | cold | 0.002037591999396682 | 0.0001088649732992053 | 1.340153358 |
| 0 | python_numpy | warm | 0.0016175575437955558 | 3.2120500691235065e-5 | 1.365827035 |
| 0 | julia | cold | 0.752177283 | 0.036142893000000065 | 10.123068782 |
| 0 | julia | warm | 0.000216507 | 1.808475000000001e-5 | 10.161856544 |
| 1 | python_numpy | cold | 0.005359129048883915 | 0.0001665129093453288 | 1.385738452 |
| 1 | python_numpy | warm | 0.004966636013705283 | 0.000177356181666255 | 1.650355325 |
| 1 | julia | cold | 0.747156618 | 0.015179107000000025 | 10.149539211 |
| 1 | julia | warm | 0.0003460815 | 2.505900000000002e-5 | 10.8243827 |
| 2 | python_numpy | cold | 0.008780114003457129 | 0.00034363591112196445 | 1.37890446 |
| 2 | python_numpy | warm | 0.007959534414112568 | 0.00016624800628051162 | 1.607688509 |
| 2 | julia | cold | 0.784919174 | 0.03029797699999992 | 10.189158135 |
| 2 | julia | warm | 0.001095856 | 0.00018939075000000004 | 10.411453426 |
| 3 | python_numpy | cold | 0.02893827494699508 | 0.0007880548946559429 | 1.412292896 |
| 3 | python_numpy | warm | 0.027873450482729822 | 0.0003710222663357854 | 2.039769791 |
| 3 | julia | cold | 0.792341201 | 0.012063811999999952 | 10.169144645 |
| 3 | julia | warm | 0.003260231 | 0.0012045182500000002 | 10.697046164 |

Conditions are Cisco k3/k20 then fat-tree k3/k20. Warm process totals include warm-up and all 20 calls; they are not per-call latency. Cold means new process, not cold OS caches. Timings include implementation/representation/predicate/dependency differences, not an isolated language effect. Memory is job checkpoint peak including setup. No Python temporal-controller baseline is claimed. See Protocol.md and raw jobs for all measurement boundaries.

