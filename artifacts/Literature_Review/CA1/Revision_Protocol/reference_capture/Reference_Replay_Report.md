# Executed original-reference observability and Julia replay

25 October 2026. **PASS on the frozen correctness-capture domain.** These are validation traces, not primary or benchmark observations.

## Findings

The byte-identical Zenodo 12735280 detector, generator and device types were executed using the locked Nix Python 3.11.7 environment. The installed NetworkX similarity and unweighted-shortest-path source hashes matched the archived 3.2.1 sources before execution. No original file was modified.

Uninstrumented and instrumented helper executions agreed on normal state/violation counts, warning logs, warnings and complete final NumPy RandomState state. Timing fields were prospectively excluded from equality, not silently normalized after a difference. Each complete cache construction starts from the declared state; there is no reseeding between its queries and no extra random draw in the hooks.

| Original fixture / condition | Cache queries | Pair checks | Reported alarms |
| --- | ---: | ---: | ---: |
| Cisco, k=3 | 10 | 43 | 1 |
| Cisco, k=20 | 10 | 198 | 2 |
| Fat tree k=4, cache k=3 | 20 | 236 | 4 |
| Fat tree k=4, cache k=20 | 20 | 1,403 | 4 |
| Cisco no-op control, exhaustive | 0 | 66 | 0 |

These use fixed seed 20261025 and path length 4. Cisco k=3 missed an alert that k=20 returned in this captured experiment; this is not a population detection rate or a cross-language discrepancy. Main cache constructions contain 82 walks per Cisco query and 141 per fat-tree query. The capture contains 60 main cache queries plus four small boundary/order-control queries.

## Exact replay

**44,800 Julia replay assertions passed**, covering:

- Ordered physical nodes/adjacency/edges, source-derived rules/differences/prefixes and initial/final connector graphs.
- Actual query order/arguments, exact walk counts and legal steps; per-walk visited membership with repeated vertices deduplicated; independent co-occurrence counts compared with the existing Julia kernel.
- Bit-exact score arithmetic (zero ULP tolerance), valid top-k partition boundaries, score ordering, eligible equal-score tie decisions, selected cache order/scores and conditional query removal. Reference indices are not accepted as an unchecked replacement cache.
- Continuous complete RNG checkpoints between queries, without claiming Julia can regenerate the NumPy stream from the seed.
- Complete subset/pair/direction tested/skipped domains, every captured initial/intermediate/final connector path, alarm/status semantics, prefix decisions, complete ordered alarms and warning output. The existing Julia snapshot coverage kernel agrees too.
- k=1, k=N, k>N's actual clamp/warning behavior, repeated vertices, all-zero eligible boundary choices, reversed node/neighbor order, prefix mismatches and no-op updates.
- Rejection of deliberately corrupted walk, membership/count, ranking selection and missing-query traces.

The original helper scans the complete chosen subset/pair domain and merely records its first-alarm time; it does not stop after the first alarm. A first-alert Julia optimization must therefore be labelled separately and cannot be used as a matched full-search benchmark without changing the stated boundary.

The source's prefix-filter loop uses initial rules at updated switches and added rules at unchanged switches. Replay faithfully retains this behavior; it is not promoted to the new temporal service/safety contract. All original fixture addresses/prefixes match, so this loop's direction does not establish broader prefix correctness.

## Important adaptation difference remains

Replaying the **same recorded walks** with Julia's existing native descending-index tie policy changes cache membership for two fat-tree k=3 queries (`A0-0`, `E3-1`) and all twenty fat-tree k=20 queries. Cisco has order differences but no membership difference in these captures. Thus native tie adaptation is demonstrably not byte-for-byte equivalent even before considering native RNG draw differences. The subsequent fixed sensitivity study has now measured decision/qualification changes at k=3: weighted Julia differs from Python on 13/32 Cisco and 10/32 fat-tree seed labels; the neighbor variant differs on 14/32 and 12/32. Labels are not common random numbers or a population error-rate estimate, but the adaptations cannot be called inconsequential. See [the completion report](../study/Completion_Report.md).

## Evidence and limits

- [Frozen capture plan](Capture_Plan.toml).
- [Capture receipt](runs/cos738-reference-capture-1792956866366487215/capture_receipt.json), [trace TOML](runs/cos738-reference-capture-1792956866366487215/trace.toml) and [JSON](runs/cos738-reference-capture-1792956866366487215/trace.json).
- [Replay receipt](runs/cos738-reference-replay-1792957198528826086/replay_receipt.toml) and [log](runs/cos738-reference-replay-1792957198528826086/output.log).
- Each run retains source hashes, source rechecks, process exit and final exit. The 194-file/two-snapshot historical seal was checked before and after both jobs.

Both jobs used the unchanged two-CPU/2-GiB/zero-swap/120-second process envelope. The bounded Nix launcher enforces the reference process constraints; replay additionally checks its inherited scope. Replay checkpoint memory peak was 529,088,512 bytes. No matched performance claim follows from these validation jobs.

The original Cisco CLI hardcodes k=20. These captures explicitly call the original detection helper with k=3/k=20, record the effective arguments and verify the CLI distinction from its AST. They are not falsely labelled k=3 CLI runs.

## Next gate

The subsequent controller gate and all authorized Stage 3 jobs have passed their declared checks; expected unsafe and resource-blocked methods remain findings, not all-controller PASS. See [controller validation](../Controller_Validation_Report.md) and [the bounded-study completion report](../study/Completion_Report.md). This report remains correctness-capture evidence, not native equivalence or a performance result.
