# Three-stage revision: completion and findings

26 October 2026. **All three authorized stages completed on the declared bounded domain.** This is a local validation/comparison result, not general deployment safety, population equivalence or a pure-language speedup claim.

## 1. Gates and retained evidence

| Stage | Executed outcome | Evidence |
|---|---|---|
| Independent controller/lifecycle validation | PASS: 227,590 Cisco and 601,999 fat-tree assertions; expected unsafe/blocked methods remain visible | [Controller report](../Controller_Validation_Report.md) |
| Original-reference observability and exact Julia replay | PASS: byte-identical original Python helper; 44,800 replay assertions, including corruption controls | [Reference report](../reference_capture/Reference_Replay_Report.md) |
| Frozen sensitivity, costs and primary comparison | PASS: 576 sensitivity records, 48 benchmark jobs, 12 one-attempt primary cells/92 raw method rows | [Generated results](Results.md), [active manifest](Manifest.toml), [protocol](Protocol.md) |
| Post-run consistency audit | PASS: 1,762 checks; exact plan evidence, attempts, cache fingerprints, resources and historical seals | [Audit](Artifact_Verification.toml), [audit source](verify_artifacts.jl) |

The active machine-manifest SHA-256 is `7ca19f71f0d88d709e4e415e9b4b28e4ba013fd3d73d45f066ddbc1aff6a915e`. The 194-file historical package and its two external snapshots remain unchanged. No failed campaign was erased or reset. Scientific jobs completed without an unexplained mismatch, timeout or resource failure. A deliberate duplicate-primary invocation was refused before any new run; its exit code and logs are retained under `verification/`.

The study directory's retained outputs, scripts, attempt records and pre-data freeze archive are checksummed in [Output_Manifest.sha256](Output_Manifest.sha256); verify from this directory with `sha256sum --check Output_Manifest.sha256`. Frozen external inputs are separately bound by `Manifest.toml`/`Sources.sha256`.

The experiment sources remain frozen. The coverage summary was implemented afterward as a derived analysis of retained caches, completing the coverage item already declared in the three-stage plan; it makes no new random draws or primary attempts. Its implementation hash and per-label event records are retained in [Coverage_Results.toml](Coverage_Results.toml).

## 2. Native RNG/tie adaptation is not inconsequential

Sensitivity uses 32 fixed seed labels, 20261101–20261132, on each original fixture and cache configuration. Python uses NumPy legacy RandomState MT19937; Julia uses its pinned MersenneTwister with either the declared full-node weighted-CDF transform or uniform-neighbor transform. Julia retains descending-index tie ranking. These labels are **not common random numbers**, so label-wise disagreement is not a cross-language error-rate estimate or proof of different population distributions.

Nevertheless, using native implementations does not reproduce the reference's evaluated decisions. Every native configuration differed in cache membership fingerprint on all 32 labels. At k=3:

| Fixture | Python alert labels /32 | Julia weighted /32 | Julia neighbors /32 | Weighted decision/qualification differences /32 | Neighbor differences /32 |
|---|---:|---:|---:|---:|---:|
| Cisco | 23 | 24 | 21 | 13 | 14 |
| Fat tree | 23 | 27 | 23 | 10 | 12 |

Qualification differences here concern the unguarded detector policy at one extra row: an alert selects validated V; a negative selects the independently unsafe ordinary plan. The guard prevents that unsafe negative release by checking the actual plan and falling back/refusing as declared. At zero extra rows, positive cases are resource-blocked and negative unguarded cases fail; neither is a qualified update.

Equal aggregate alert counts conceal different cases: Python and the fat-tree neighbor variant both alert on 23 labels but disagree on 12. Therefore neither seed-name agreement nor equal aggregate totals establish reproducibility or equivalence. See [sensitivity details](Sensitivity_Results.toml).

### Full snapshot-alarm coverage

The Julia exhaustive snapshot baseline contains two Cisco and four fat-tree alarm events. Two traversals agree on that event set, but share graph/shortest-path helpers; this is not claimed as an independent-engine proof. Offline coverage from every retained cache agrees with its executed Python/Julia alarm and pair-check counts.

At k=3, the total found/exhaustive alarm occurrences over the 32 labels were:

- Cisco: Python **26/64**, Julia weighted **29/64**, Julia neighbors **24/64**. Complete coverage occurred on only **3, 5 and 3** labels respectively.
- Fat tree: Python **52/128**, Julia weighted **72/128**, Julia neighbors **66/128**. Complete coverage occurred on **3, 9 and 10** labels.

An alert is therefore much weaker than detecting every snapshot event. k=20 and k=3-plus-adjacent-host augmentation found all baseline events on every recorded label in both fixtures and all three implementations. This bounded observation is not a general completeness or population-equivalence guarantee. Alarm occurrences repeat fixed fixture events; they are not independent vulnerabilities. [Coverage table](Coverage_Results.md).

## 3. Primary comparison: qualification before costs

The primary grid was unchanged after freezing: two fixtures × extra-row allowances 0/1 × three cache configurations. Detector rows use Julia weighted-CDF and fixed seeds 20261025–20261027; seed 20261025's earlier reference-capture use is disclosed. Seed-independent controls execute once per fixture/allowance, not repeatedly as independent workloads. There are **92 raw rows**, not 92 networks.

| Procedure | Zero extra forwarding rows | One extra forwarding row | Accepted Cisco / fat-tree completion rounds |
|---|---|---|---|
| Ordinary | FAIL | FAIL | Target applied at 1, but delivery/completion obligations fail |
| Q | PASS | PASS | 7 / 8 |
| V | RESOURCE_BLOCKED | PASS | 7 / 8 |
| CCG-inspired no-rollback | PASS | PASS | 11 / 13 |
| Guard-only, declared V fallback | RESOURCE_BLOCKED | PASS | 7 / 8 |
| Detector / guarded detector in recorded primary seeds | 0/3 qualified per cell | 3/3 qualified per cell | V selected; 7 / 8 |

All three primary seeds alerted in each configuration. Consequently these primary rows do **not** exercise negative release or demonstrate the guard's rescue advantage; the disjoint sensitivity seeds and explicit validation controls supply that evidence. This distinction must survive manuscript summarization.

Q is already a safe zero-extra-row baseline under this bounded-handover contract. The conservative CCG-inspired adapter also qualifies without extra forwarding rows, but completes later here. V permits earlier new opening with one extra row; no single universal cost winner is claimed. Logical rounds are not measured switch/network latency. Source-slot storage, tags, gates and controller history are not free forwarding rows.

Fallback remains V, not an outcome-selected Q rescue. Resource refusal is not PASS. The CCG-inspired adapter is not the complete published CCG system; it does not claim in-switch holding, rollback or general scheduling completeness.

Every selected plan must match a certificate in the 16-entry fixture/allowance/exact-plan catalogue with unchanged kernel and fixture sources. Unknown plans stop execution. Reusing a complete independent certificate is legitimate evidence reuse, **not new packet exploration for every seed**. [Catalogue](Catalogue.toml), [primary CSV](Primary_Results.csv), raw job TOML under `runs/`.

## 4. Matched snapshot-search costs: warm benefit, cold penalty

Both implementations run the complete snapshot search on the same captured caches; memoization is fresh per call, logging is disabled, and pair/alarm counts must match. There is no invented Python temporal-controller baseline. Five fresh processes and one warm-up plus 20 warm repetitions per condition were measured with alternating language order as frozen.

| Fixture / cache | Python warm inner median (ms) | Julia warm inner median (ms) | Python cold supervised process median (s) | Julia cold supervised process median (s) |
|---|---:|---:|---:|---:|
| Cisco k3 | 1.627 | 0.180 | 1.352 | 9.796 |
| Cisco k20 | 4.924 | 0.327 | 1.369 | 9.801 |
| Fat tree k3 | 7.883 | 1.026 | 1.363 | 9.862 |
| Fat tree k20 | 27.453 | 2.348 | 1.399 | 9.801 |

Warmed inner calls favor this Julia implementation by approximately **7.7–15.1×**. New-process results favor Python; Julia's first inner search alone includes approximately **0.69–0.74 seconds** of JIT/first-call work. The measured supervised Julia process takes about 9.8 seconds versus Python's 1.35–1.40 seconds.

These are combined implementation/representation/predicate-specialization/dependency effects, **not isolated language effects**. Julia used the frozen `--compiled-modules=no` validation configuration; this is not an optimized packaged/sysimage startup comparison. Whole-process totals include setup, provenance checks and output. A warm job's total contains warm-up plus all 20 calls and is not per-call latency. Cold means new process, not cleared OS caches. CPU affinity/quota does not make the host exclusive. Raw timings, IQR/min/max, allocations where available and checkpoint memory are in [benchmark results](Benchmark_Results.toml) and job records. Primary decision timings are descriptive/order/JIT-dependent, not a matched ranking of temporal controllers.

## 5. Adjustments, permissions and remaining boundaries

- The approved cache-backed Nix revision preserves all 14 checked artifact package pins; Python is 3.11.7, not the initially selected 3.11.6. Exact original patch/native-environment recovery is not claimed. No package source compilation, pip/uv/venv, global profile change or system rebuild was used. The combined `withPackages` wrapper remains intentionally unbuilt.
- Before any Stage 3 data, the first machine freeze was retained under `freeze-v1-pre-data/` and refined to put native Python/Julia semantic review before downstream experiments. No grid, seed, method, fallback, threshold or measurement was outcome-tuned.
- Every scientific process retained two-CPU quota, hard 2 GiB RAM, zero swap, 120-second ceiling and one local job at a time. No aggregate runtime ceiling was applied.
- **No further provisioning permission is needed for this completed study.** Changed package pins, package source builds, remote compute, system changes or deployment remain separately permissioned.
- General predicates, congestion, arbitrary offered load, shared packet buffers, in-switch holding, deployment faults and the full published CCG implementation remain outside the validated domain. The source's broad-prefix behavior is reproduced, not repaired into a general policy guarantee.

## 6. Next use of the evidence

The authorized computation is complete; do not rerun consumed primary cells or automatically expand the grid. The next step is manuscript integration and claim review using these tables: separate the historical continuous-service experiment from original-intent handover, state the k=3 sampling limitations and material native differences, and present cold/warm trade-offs without a pure-language or deployment-equivalence claim. No manuscript or new campaign is silently authorized by this completion report.
