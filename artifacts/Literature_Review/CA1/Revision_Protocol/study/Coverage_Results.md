# Exhaustive snapshot-alarm coverage

Derived from the retained fixed sensitivity caches; no new seeds, primary attempts or tuning. The Julia exhaustive snapshot baseline has two Cisco and four fat-tree alarm events; two snapshot traversals agree on its event set (they share graph/shortest-path helpers, so this is not an independent-engine proof). Offline coverage equals every executed Python/Julia alarm and pair-check count. This is not temporal packet safety or a population detection rate.

| Fixture | Cache | Implementation | No alarms /32 | All baseline alarms /32 | Found / exhaustive alarm occurrences |
|---|---|---|---:|---:|---:|
| cisco | k3 | python_numpy | 9 | 3 | 26 / 64 |
| cisco | k3 | julia_weighted | 8 | 5 | 29 / 64 |
| cisco | k3 | julia_neighbors | 11 | 3 | 24 / 64 |
| cisco | k20 | python_numpy | 0 | 32 | 64 / 64 |
| cisco | k20 | julia_weighted | 0 | 32 | 64 / 64 |
| cisco | k20 | julia_neighbors | 0 | 32 | 64 / 64 |
| cisco | k3_adjacent | python_numpy | 0 | 32 | 64 / 64 |
| cisco | k3_adjacent | julia_weighted | 0 | 32 | 64 / 64 |
| cisco | k3_adjacent | julia_neighbors | 0 | 32 | 64 / 64 |
| fat4 | k3 | python_numpy | 9 | 3 | 52 / 128 |
| fat4 | k3 | julia_weighted | 5 | 9 | 72 / 128 |
| fat4 | k3 | julia_neighbors | 9 | 10 | 66 / 128 |
| fat4 | k20 | python_numpy | 0 | 32 | 128 / 128 |
| fat4 | k20 | julia_weighted | 0 | 32 | 128 / 128 |
| fat4 | k20 | julia_neighbors | 0 | 32 | 128 / 128 |
| fat4 | k3_adjacent | python_numpy | 0 | 32 | 128 / 128 |
| fat4 | k3_adjacent | julia_weighted | 0 | 32 | 128 / 128 |
| fat4 | k3_adjacent | julia_neighbors | 0 | 32 | 128 / 128 |

Alarm occurrences repeat fixed fixture events over seed labels; they are not independent vulnerabilities or networks. The event keys and per-label records are retained in Coverage_Results.toml. This post-run implementation completes the coverage summary declared in Three_Stage_Execution_Plan.md; the original experimental sources and primary grid remain unchanged.

