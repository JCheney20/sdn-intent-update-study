# Controller validation gate

26 October 2026 (source-bound revalidation; earlier runs retained). **PASS for the seven declared controller adaptations on the two frozen original-intent fixtures and bounded workload.** This means independent checking agrees with their outcomes; it does not mean every controller is safe or resource-feasible.

## Executed evidence

- [Cisco final receipt](validation/runs/cos738-revision-1792996081759461393/receipt.toml): **227,590 assertions**, 27.30 seconds including startup, checkpoint peak 383,348,736 bytes.
- [Fat-tree final receipt](validation/runs/cos738-revision-1792996109974263456/receipt.toml): **601,999 assertions**, 32.74 seconds including startup, checkpoint peak 405,413,888 bytes.
- [Prospective controller semantics](Controller_Validation_Spec.md) and [frozen validation inputs](validation/Controller_Inputs.toml).

Each fixture has 26 method/condition rows but only eight distinct normalized plans/refusals; identical plan evidence is reused, not represented as independent workloads. Complete representative coverage is required for every PASS. An unsafe plan may stop after an independently valid negative witness; its coverage field does not imply exhaustive negative frequency. Earlier passing controller jobs are retained; final jobs include joint sanity checks, a post-execution recheck of every frozen validation input and exact plan fingerprints used by the frozen Stage 3 evidence catalogue.

## Independent coverage

For accepted plans, the raw-input oracle and numeric engine agree on all per-round representative packet-edge sets, boundary states, applied tables/gates, final targets, actual row capacity and old-packet drainage at claimed completion. New requests use the explicit source slot in the numeric execution path; the slot is allocated at the declared arrival boundary, not before a future request exists. Identity, original arrival, once-only admission and conservation are checked throughout each branch.

Every distinct non-refused plan also has an actual old/new joint execution compared across engines. General universal packet factorization still relies on the declared stateless/no-congestion/no-shared-packet-buffer assumptions and on controllers being independent of probe locations/delivery; it is not arbitrary-load verification. The earlier 120 Q/V joint cases remain supporting evidence.

The CCG-inspired scheduler's recorded removed-edge states are independently reconstructed from raw acknowledged table removals at each opening boundary, including expiry. Repeated work/progress constraints, exact target/cleanup, resource refusals, an explicit lost-target progress-blocked control and an incomplete guard selecting fallback are tested. Guard decisions use the candidate engine, never the independent oracle's verdict. The detector's actual full graph search matches captured Python pair counts and ordered alarms; it does not look up a precomputed exhaustive event set.

The existing 2,592 raw-oracle assertions also passed in each controller job. Historical 194-file/two-context seals and all frozen job inputs were rechecked. Effective two-CPU/2-GiB/zero-swap/120-second limits were verified; aggregate accounting remains documentary only.

## Model findings

| Procedure | Extra rows 0 | Extra rows 1 | Cisco / fat-tree completion bound observed for accepted control |
| --- | --- | --- | --- |
| Ordinary | FAIL | FAIL | Applied target in round 1, but old delivery/completion obligations fail |
| Q | PASS | PASS | 7 / 8 rounds |
| V | RESOURCE_BLOCKED | PASS | 7 / 8 rounds; needs one extra forwarding row |
| CCG-inspired no-rollback | PASS | PASS | 11 / 13 rounds; zero extra forwarding rows |
| Guard-only | RESOURCE_BLOCKED | PASS via V | 7 / 8 rounds when fallback feasible |

Captured k=3/k=20 reference caches produced alerts in these validation cases, so detector-guided variants selected V. Deliberately empty caches exercised negative release: the unguarded variant releases the unsafe ordinary plan, whereas the guarded variant rejects it and selects V (or reports RESOURCE_BLOCKED at zero extra rows). All-host controls exercise the alert branch. These are validation controls, not seed-population observations.

Q already provides a safe zero-extra-forwarding-row baseline under bounded handover. The conservative history scheduler does not improve its activation/completion rounds on these cases; it waits longer for its overapproximation to clear. Forwarding rows, source-slot storage and controller history are distinct costs. These findings do not overturn the old continuous-service study, which had a different contract.

## Adjustments and scope

- Ordinary activation is explicitly one switch-local replace/close/open batch, not a free network-wide change.
- The CCG-inspired adapter is prospectively declared no-rollback and returns PROGRESS_BLOCKED rather than inventing an unvalidated partial-state V fallback. It is not the full published CCG system or a literal port of the old continuous-service scheduler.
- Guard/detector fallbacks remain V, not an outcome-selected Q rescue. Thus their zero-row refusal is visible rather than hidden by changing the method after results.
- Shared validation representation mapping was extracted without sharing forwarding/transition logic between engines. Source snapshots retain earlier versions. No scientific parameter, topology, seed, switch priority or fallback was tuned after validation outcomes.
- The snapshot detector is validated on the artifact's fixed broad-prefix inputs. General predicate policies, congestion, in-switch holding and deployment failure modes remain outside the model.

## Next

All three authorized stages are now complete on the bounded domain. See [the completion report](study/Completion_Report.md): 576 sensitivity records, 48 matched full-snapshot benchmark jobs and all 12 one-attempt primary cells. Native k=3 differences materially change evaluated decisions/qualification; exact replay did not establish native equivalence. Warm Julia inner searches were faster here, while fresh-process/JIT costs were substantially higher. The next step is manuscript claim review, not an automatic new campaign.
