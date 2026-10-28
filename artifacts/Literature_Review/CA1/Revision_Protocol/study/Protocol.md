# Stage 3 fixed execution and interpretation

26 October 2026. This refines the already authorized [three-stage plan](../Three_Stage_Execution_Plan.md) before any Stage 3 outcomes. Reference observability/replay and controller gates passed; gate receipts are recorded by `freeze.jl`. Historical results are not overwritten.

**Pre-data refinement:** the first machine freeze is retained under `freeze-v1-pre-data/`. Before any sensitivity/benchmark/primary outcome, the coordinator was refined to review all native Python detector results against Julia and the plan certificates immediately after sensitivity, rather than waiting until final analysis. Grid, seeds, thresholds, methods and measurements are unchanged. The active freeze hashes the refined coordinator.

## Inputs and repetitions

- Original Cisco and fat-tree k=4 fixtures only. Cache configurations: k3, k20, k3_adjacent. Physical node/neighbor order and all rule/packet assumptions remain frozen.
- Native sensitivity: labels 20261101–20261132, directly used as initialization seeds, once per complete cache construction, never between queries. Python NumPy legacy RandomState/full-node weighted choice versus Julia MersenneTwister/full-node weighted-CDF versus Julia MersenneTwister/uniform-neighbor optimization. Identical labels do not mean common random numbers. Julia uses its declared descending-index equal-count tie policy. No population-equivalence margin, significance claim or outcome-driven sample-size change.
- Review every sensitivity cache's executed Python detector result against Julia before proceeding to benchmarks or primary. Unexpected semantic/proof mismatches stop; expected native cache/qualification differences are reported as material findings, not silently removed.
- Primary: twelve cells, in fixture / row allowance 0,1 / configuration k3,k20,k3_adjacent order. Detector-dependent rows use seeds 20261025–20261027 and Julia's weighted-CDF adaptation. Five seed-independent procedures run only in the first configuration for each fixture/allowance; later cells reference those controls instead of counting repeats as workloads. Each cell has one attempt; failed/partial cells remain visible and are never automatically retried or split.
- Primary seeds were fixed before the reference observations. The correctness-capture seed overlaps one primary label; disclose this rather than presenting it as an unseen confirmatory RNG trial. Sensitivity seeds are disjoint.

## Exact-plan independent evidence reuse

These controllers produce fixed schedules before packet execution and only select from a small number of behaviors. `Catalogue.toml` retains the complete independent result for each validated fixture/allowance/normalized-plan hash. Its source hashes bind the exact controller, forwarding, slot/history, oracle and fixture kernels. Every study decision is reconstructed normally and fingerprinted; an unrecognized plan is an error, not a guessed verdict. PASS requires the catalogue's complete coverage; unsafe/blocked proofs remain unsafe/blocked.

This avoids re-exploring an identical packet graph for every cache seed. It does not manufacture independent assurance evidence per seed, validate a new topology, share the guard's verdict as the expected answer or waive independent validation. Cache-dependent choices and costs are still measured per trial. The catalogue is a replayable certificate index of completed validation, not a new learned safety oracle.

## Matched benchmark boundary

Only the overlapping **full snapshot search with the same captured caches** is benchmarked against Python. No Python temporal-controller baseline exists. Inputs include the same original intent rules, complete subset/pair domain and stopping behavior; both return the captured pair/alarm counts. Cache construction and logging are outside this timed component. Python clears its memo before each call outside the timer; within-call memoization remains. Julia creates its normal within-call memo. Both use no warning output during measurement.

- Four conditions: Cisco k3/k20 and fat-tree k3/k20, using the captured reference-compatible caches, not unrelated native samples.
- Five new-process cold repetitions per condition/language. Alternate Python/Julia launch order by repetition. Retain inner search time and complete supervised process elapsed separately.
- One warm-up then twenty timed repetitions in a persistent language process per condition. Alternate which language block runs first across conditions. This prospectively clarifies that warm **blocks**, not individual repetitions, alternate: it avoids a custom dual-process IPC harness and keeps one active job. Do not claim individual-repetition interleaving or independent timing samples.
- "Cold" means a new process, not flushed OS page caches. Complete process cost includes imports/JIT, identical trace-file input parsing and output/supervision. It is not pure useful-search time. Memory is the cgroup checkpoint peak including setup, not isolated per-call allocation. Julia allocation counts have no falsely equivalent Python metric.
- Report medians/ranges/IQR descriptively. Shared-host load, representation/memo/predicate specialization and dependency/JIT differences remain limitations. These are combined implementation effects, not proof that language alone causes a speedup. The Julia specialization uses the fixed broad-prefix fixture domain; Python retains the unmodified generic prefix machinery.

## Costs and qualification

Keep cache build/augmentation, decision/guard/scheduler work, exact-plan proof lookup, network batches/row/gate/tag mutations, per-switch peaks and logical admission/completion bounds separate. Primary method timings include the actual cold/warmed state in fixed row order; do not substitute them for the matched warmed benchmark. No logical-round-to-millisecond conversion or physical TCAM claim.

Report qualification before costs. A detector-negative ordinary release can be an expected unsafe method outcome, not a safe result or an unexplained checker mismatch. Any claimed qualified result without matching complete independent evidence stops acceptance. Materiality includes changed alarms, unsafe release or qualification across native implementations/labels; matching outcomes support only a bounded descriptive observation, never native equivalence.

## Enforcement and attempts

One local job at a time; two-CPU quota/affinity, hard 2 GiB RAM, zero swap, 120-second whole-job ceiling. No cumulative runtime stop. Every job retains source hashes, process/final exits, partial checkpoints and resource observations. Source/input drift, unexplained output mismatch or timeout stops the coordinator; all remaining jobs are unattempted until disposition. No installations, source-package builds, remote jobs or global system changes are needed.
