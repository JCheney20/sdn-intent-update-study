# Julia/Slurm revision: proposed validation protocol

**Draft v0.1, 25 October 2026. Planning only; not an execution approval.** SDN security–cost comparison remains primary. Julia adaptation and Slurm reproducibility support it. The completed 194-file package, twelve primary cells and original ledger remain frozen; this document neither consumes new attempts nor authorizes a campaign reset.

**Subsequent author decisions:** use Julia-native local laptop execution, with Slurm optional; bounded handover with a counted quiesce/drain control; one pending new request; and derived model bounds. The initial tiny-validation allowance is two CPU cores, hard 2 GiB RAM/zero swap, 120 seconds per process and 600 seconds cumulative, with no installations/downloads or sensitivity/benchmark/primary campaign. A separately pinned Python reference remains validation/baseline-only. See the current [scientific contract and resource decisions](Scientific_Contract_Draft.md), which supersede this v0.1 draft's mandatory-Slurm and wholly-unapproved-resource assumptions. Exact action semantics, bound derivations, environment/enforcement checks and the revised primary campaign remain open; this draft is not a primary execution approval.

**Latest execution authority and status, 26 October 2026:** the author approved all three revision stages and removed the aggregate runtime ceiling; all three have now completed on the declared bounded domain. [The three-stage plan](Three_Stage_Execution_Plan.md) supersedes this draft's earlier permission/budget restrictions, not its scientific gates. See [the completion report](study/Completion_Report.md): controller validation passed 227,590/601,999 assertions, executed reference replay passed 44,800, and the frozen study retained 576 sensitivity records, 48 benchmark jobs and all 12 one-attempt primary cells. Native k=3 adaptations materially change evaluated qualification; warmed Julia calls are faster here but startup/JIT is costly. No population equivalence, pure-language speedup or deployment guarantee is claimed. Hard per-process limits remain. Isolated cached Nix reference provisioning was separately approved; changed package pins, package source builds, remote compute and system changes still require permission. Earlier draft/checklist language below is historical; completed evidence is linked above.

Follow-on formalization: [event semantics and analytical bounds](Operational_Semantics_and_Bounds.md), with [derived TOML fixtures](Handover_Bounds.toml). These specify conditional bounds to validate, not executed gate results.

Source evidence: [provenance audit](Source_Provenance_Audit.md). The original Spotlight Python artifact is the port/reference target. Julia conventional/CCG-inspired procedures are labelled adaptations; the original CCG implementation was C++, not Python.

## 1. Separate the claims and workloads

| Track | Input and purpose | Claim boundary |
| --- | --- | --- |
| A: artifact fidelity | Pinned original topology/order, changing intents, rule differences, detector queries and events | Validate overlapping snapshot-detector behavior against actual Python; does not establish packet-service preservation |
| B: original-intent lifecycle | Same original endpoint changes, with an explicitly added admission/cutover/drain contract | Primary security–cost comparison under a declared temporal interpretation; the packet contract is our extension, not something supplied by Spotlight |
| C: continuous-service control | Previously constructed same-endpoint reroute | Separate controlled experiment illustrating uninterrupted-service requirements; not a replacement for the original changing intents |

Do not pool tracks or report ten repeated method/configuration rows as ten independent workloads. Historical results remain results of Track C's previous bounded model, not findings about the proposed Track B.

Initial fidelity targets are the archived Cisco graph and fk=4 fat tree. Their original pairs are listed in the audit. A role-derived eight-device internal graph is optional sensitivity work, not certified paper replication. It needs separate approval and cannot replace the ten-switch source graph. No Stanford expansion or larger topology grid is implicit here.

## 2. Gate A — source lock and reference observability

Before any reference execution, freeze:

- Exact artifact record/file hashes, Python version, NumPy 1.26.2, NetworkX 3.2.1, all other imported dependencies and installation provenance; confirm against the artifact's dependency files rather than resolving latest versions.
- Julia version, project/stdlib environment and all source/input hashes. Record architecture/OS and math-library environment relevant to ordering or numerics.
- Graph directedness, node/edge insertion order, adjacency order, host/switch query order, shortest-path output and tie handling; physical graph versus connector graph identities.
- Initial/target ingress triples and prefix matches, action order, changed-switch order, host-pair enumeration, early stopping and the detector's original alarm definition.
- Effective helper arguments, including topology parameter, Panther k, walk length and sample-size calculation. The Cisco CLI hardcodes k20: a claimed k3 comparison must prove the actual helper argument, not cite CLI flags alone.

Use the pinned later detector. Keep original files read-only. Any Python trace wrapper/instrumentation is separately hashed and restricted to validation/benchmarking, with no production Julia dependency.

**Observability check:** uninstrumented and instrumented reference executions with identical complete initial RNG states must yield the same normal outputs and final RNG state. Recording must not draw extra randomness, reseed between queries, reorder iteration or change early stopping. If instrumentation changes behavior, repair it before using its traces.

No original reference execution has occurred during this planning phase. A successful import or a matching hand-transcribed fixture will not count as this gate.

## 3. Gate B — deterministic replay, not seed-name equivalence

The implemented comparison is Julia's explicit MersenneTwister versus NetworkX's module-level NumPy RandomState calls. It is not default Xoshiro versus default_rng/PCG64. Equal generator-family names or integer seeds do not establish equal draws.

### Trace schema

One reference trace per complete cache construction must identify:

1. Manifest hash, ordered nodes/edges, exact query order and initial RNG state/seed policy.
2. Per query: effective parameters, sample count, ordered sampled walks including starting vertices, and RNG state checkpoints.
3. Per query/node: path-membership sets or equivalent exact co-occurrence counts. Repeated visits within one walk must not become extra shared paths.
4. Reference score arithmetic and ranking indices, especially the kth boundary, tied candidates, selected tie members, result order and conditional removal of the query node.
5. Selected caches, tested/skipped switch subsets and host pairs, connector-path results, packet-prefix matching decisions, alarm/event sets and first-event/witness under the declared stopping order.

Validate trace integrity before replay: endpoints/order belong to the declared graph; every walk step follows a physical edge; lengths/counts agree with parameters; boundary selections are eligible; no duplicate/missing queries or fabricated count entries are accepted.

### Comparison layers

- **Walk replay:** feed recorded walks to Julia; require exact sample counts, per-walk visited sets and co-occurrence counts. Do not merely compare the final alarm bit.
- **Ranking replay:** require exact non-tied rankings. Supply only the reference's eligible tie decisions where the library contract leaves boundary order unspecified; verify tied scores/candidates independently. Do not override the whole cache and thereby hide incorrect counts or ranking.
- **Natural tie behavior:** separately record the cache/decision differences when Julia uses its declared native tie policy. Forced tie replay validates downstream logic, not native tie equivalence.
- **Detector replay:** with the resulting reference-compatible cache, require exact relevant tested/skipped domains, canonical event sets and decisions. If deterministic iteration/stopping is preserved, require matching first event and witness too; do not silently sort away a behaviorally relevant first-alarm difference.
- **Rule/path replay:** independently compare original shortest paths, generated rule differences and connector representation before interpreting detector agreement.

Integers, memberships, graph identities and decisions must match exactly. For floating scores, reproduce the pinned operation order and compare bit patterns where feasible; otherwise freeze a justified ULP tolerance before testing and permit **no** tolerance-induced ranking/tie/decision change. Timings and allocation counts are not equality fields.

Required small checks: repeated vertices in walks; top-k boundary ties and all-zero candidate ties; query-node inclusion/removal; k=1, k=N and reference handling of k>N; topology/neighbor-order changes; hyphenated physical names versus connectors; source/destination prefix and ingress mismatches; unchanged/no-op updates and early stopping. Use inputs accepted by the reference or explicitly compare expected rejection behavior—do not invent supported isolated-node behavior.

The trace hooks must also reject deliberately corrupted walks/counts/tie selections. **Gate:** no unexplained semantic replay mismatch. A reference bug may be faithfully reproduced and labelled, but must not be promoted to a safety guarantee.

## 4. Gate C — proposed changing-intent service contract

This section is a contract proposal requiring author approval, not a retroactive interpretation of the old packet model.

Let `I_old=(s_old,d_old)` and `I_new=(s_new,d_new)` be the original source pairs. Treat intent activation and packet admission separately from forwarding-table updates.

| Phase | Obligation |
| --- | --- |
| Initial | Old intent active; its admitted packets must reach the old destination under their declared deadline |
| Transition requested | New intent must activate within a common finite activation/completion bound; staging may begin, but does not itself grant packet admission |
| Old admission closes | No new old-intent packet is admitted after the acknowledged closure; packets accepted before closure retain their old delivery obligation |
| New admission opens | New-intent packets may enter only with a valid target behavior; any delayed new admission/activation is charged and bounded |
| Drain/cleanup | Preserve forwarding needed by every still-live admitted old packet; retire it only after justified drainage, then require the exact target state and completion |

Old closure and new opening may be one atomic ingress operation if supported and counted, or separated by a bounded quiescence interval. **Do not impose uninterrupted same-endpoint service on an intent explicitly being withdrawn.** Conversely, rejecting or never admitting all traffic cannot manufacture a service PASS: old packets already accepted must drain, new activation must meet its bound, and eligible new requests have a specified bounded waiting obligation.

Before implementation, make the waiting/admission mechanism concrete: where requests wait, finite capacity/representative packet scope, what admission acknowledgement means, which operations change it, how they consume control work/state, and the start point of every deadline. No free external oracle may close a source or declare drainage. Do not imply queue capacity, arbitrary load or throughput guarantees from a one-packet abstraction.

An admitted old packet is authorized only for `d_old`; an admitted new packet only for `d_new`. Cross pairs `s_old→d_new` and `s_new→d_old` remain forbidden unless a separately specified policy grants them. A packet's historical authorization cannot be erased at cutover to conceal a drop, nor extended to the other intent's destination. New old-intent requests after revocation are explicit admission rejections, not loss of already admitted permitted packets.

The state/coverage domain must include old and new admission epochs, already-in-flight packets, relevant launch positions and cross-pair probes—not only the previous single F/P representative. This expands the old model's bounded domain and may require different rank/horizon bounds; **do not inherit H=5 and 79 rounds without a new derivation**. Retain the stateless/trusted-input limits unless broader scope is explicitly approved.

### Fair controls under this contract

- Keep versioned consistent updating as a named reference, with explicit staging, ingress commitment and drainage costs.
- Consider an explicitly named **quiesce/drain/update/activate control**, if the bounded admission contract permits it. Excluding a suitable low-row control would bias the original-changing-intent comparison toward a continuous-service assumption. This is a proposed comparison control, not an implemented or authorized extra primary cell.
- Preserve ordinary, CCG-inspired and detector/guard procedures only with their actual supported lifecycle behavior and comparable counted actions. If a method cannot meet the contract, report that result; do not grant it an uncharged fallback or a different deadline.
- For Track C, keep the distinct continuous-service requirement; a quiescence method cannot be credited there under a different service definition.

Report isolation, admitted-packet delivery, admission waiting/activation, completion, peak rows, control work and checking cost separately before any joint qualification. Admission denials and intended withdrawal must remain visible. Freeze any baseline additions and the full experiment grid before outcomes.

## 5. Gate D — independent Julia oracle and trace checker

Implement the smallest separate bounded checker, not a second production framework. It must not import production transition, matching, drainage, completion or safety helpers, nor use the guard's result as its expected answer.

Independence requirements:

- Shared **raw** graph/intents/contracts are allowed. Independently derive expected ingress/egress tables and epoch obligations from those raw inputs; do not consume only production-generated tables, since both engines could then validate the same mistaken fixture.
- Use a structurally different representation, e.g. literal located packets and string-keyed concrete rule tables with separately enumerated action applications. Independently implement ingress/prefix/tag matching, default DROP, packet aging, controller acknowledgements, admission and cleanup.
- Enumerate the bounded asynchronous state graph independently. Record legal transitions and terminal outcomes; normalize states through an explicit comparison map. Prove or bound the horizon/rank and distinguish a real permanent cycle from an allowed finite wait. A truncated search is not PASS.
- Independently replay production witnesses and action traces against raw rules and contract obligations. Replaying only counterexamples does not certify a PASS; compare complete reachable behavior on the approved tiny cases and validate complete coverage claims.

Required defect controls include wrong/missing ingress matching, wrong prefix/tag, lost packet history, uncharged admission changes, premature drainage/cleanup, wrong old/new destination, false completion, missed cycles/deadlines, and partial coverage labelled PASS. Each deliberately faulty variant must be rejected; retain its evidence. Exercise both known-safe and known-unsafe cases, not just agreement on negatives.

The original Python detector is useful for Track A overlap. It cannot validate the new temporal service semantics it does not model. Agreement between a guard and evaluator that share transitions remains correlated evidence, even if both are Julia.

**Gate:** independent verdict/transition agreement on the frozen bounded cases, independently valid counterexamples, complete PASS coverage and successful defect rejection. This reduces shared implementation error; it is not a general formal proof or production validation.

## 6. Gate E — native-RNG sensitivity and materiality

Run only after deterministic replay and the independent semantic gate pass. Freeze topology/k configurations, source versions, seed-generation rule/list, sample counts, stopping rules and analysis before execution. Retain every attempt, including failures; prohibit outcome-driven graph/k/seed tuning.

Separate:

1. Pinned Python's native RNG/sampling/ties.
2. Julia's declared source-faithful sampling/ranking adaptation.
3. Any optimized Julia adjacency-based sampler/tie policy, clearly labelled as a changed implementation.

Reference walk/tie replay isolates downstream correctness; it does not establish native stochastic equivalence. Full-node weighted choice and uniform-neighbor sampling may have the same distribution on unweighted inputs but different draw consumption/order/boundary behavior. Any stream-controlled sampler ablation must state its uniform/integer conversion and boundary rules. Equal integer seed labels are identifiers, not proof of common random numbers.

Per trial retain alarm/event coverage against the exhaustive snapshot baseline, cache fingerprints, ordinary/fallback decisions, independent isolation/service/completion verdicts and resulting resource qualification. Aggregate repeated configurations without treating seed-independent repeats as independent evidence.

### Predeclared interpretation

- **Assurance correctness:** any claimed joint PASS contradicted by the independent oracle is material and blocks acceptance. It cannot be averaged away.
- **Case-level sensitivity:** a changed unsafe-release outcome, loss of qualification or changed architecture recommendation is material for that case. Report it even if a population-rate comparison is inconclusive. A detector negative alone is not proof of a packet leak; check the temporal contract.
- **Descriptive bounded result:** matching decisions over a small fixed seed set supports only “no qualification change observed in these cases.” It does not establish inconsequential adaptation effects or estimate a network-population detection probability.
- **Optional rate-equivalence claim:** proposed margin is ±5 percentage points for alarm/fallback proportions, separately within each declared topology/k condition. This substantive margin still requires author approval. Use simultaneous 95% intervals for the difference under a frozen method and prespecified multiplicity correction; the full interval must lie within the approved margin. Choose fixed sample counts prospectively from attainable precision and the approved budget. Non-significance, an interval spanning zero, insufficient precision or a timeout means **inconclusive**, not equivalent. Confidence concerns the declared seed experiment, not arbitrary enterprise networks.

An equivalence-rate study is optional; do not expand a small correctness gate into thousands of trials without approval. Do not claim native equivalence if that optional study is unaffordable or if a material case-level difference occurs.

## 7. Julia production boundary and matched costs

The revised delivered pipeline must use Julia for input/manifest validation, sampling, simulation, tests, evidence verification, analysis, tables and durable budget accounting. Existing Python launch/verifier/audit helpers remain historical artifacts, not hidden production dependencies. The separate pinned Python reference is the approved validation/baseline exception only.

Use one thin Slurm batch entry and initially one CPU/thread per execution. MPI, distributed Julia and a custom Slurm scheduler are unnecessary. Arrays are a later optional mechanism subject to an aggregate concurrency/resource allowance.

For performance, compare matched components/algorithms, validated inputs, k/parameters, stopping behavior, output obligations and CPU/thread/RAM allocations. Name whether the benchmark includes cache construction, detector search, packet checking or the entire workflow. There is no original Python full-CU/CCG baseline to invent.

Measure separately:

- Cold process/startup/JIT plus workload and durable output.
- Warmed repeated execution with fixed warm-up and interleaved/randomized measurement order.
- Allocations and actual peak resident/job memory, using the same measurement boundary.
- Dependency setup, job launch/allocation and queue wait, distinguished from useful compute. Julia's long-lived warm execution and repeated Python subprocesses are not matched conditions.

First implement a faithful comparison; label sparse representations or altered sampling as combined adaptation/optimization effects rather than isolated language speedups. Delete old conventional no-op cleanup **before** the next frozen timing implementation; do not edit historical logs or call the analytical audit a measured rerun. Specify conservative CCG history/fallback rules prospectively, not after choosing the faster result.

## 8. Slurm/site and authorization gates

No target cluster is assumed. Obtain author decisions on site, access, provisioning source, dependency/network/download/storage allowance, CPU/thread/RAM/swap constraints, per-job limits, aggregate staged budget and allowed concurrency. Do not inherit permission from another project or spend the historical remaining 1,292 seconds automatically.

Slurm memory requests are insufficient evidence of hard enforcement. With site permission, inspect allocation/step placement, effective CPU constraints and cgroup RAM/swap limits; consult site configuration/policy for `ConstrainRAMSpace`/`ConstrainSwapSpace`. Do not alter cluster configuration or silently weaken zero-swap/hard-RAM requirements. An unavailable enforcement mechanism is a gate issue to resolve, not an excuse to launch unbounded work.

Proposed order, each with a separately approved ceiling and stop rule:

| Stage | Work | Stop before next stage unless |
| --- | --- | --- |
| 0 | Site/dependency/enforcement preflight and frozen manifests | Environment and resource contract are verified |
| 1 | Tiny reference capture/replay and independent-oracle defect checks | Gates A–D pass and the temporal contract is approved |
| 2 | Small declared native-RNG sensitivity pilot and cost calibration | Author reviews sensitivity, feasibility and remaining budget |
| 3 | Revised fixed SDN comparison; optional powered rate-equivalence and matched benchmarks | Final grid, claims, resource envelope and attempt policy are approved |

Keep the sensitivity pilot separate from confirmatory evidence. Its cost observations may inform an approved feasibility/sample-size calculation, but do not use its favorable outcomes to choose graphs, k values, seeds or methods. Any changed scientific scope needs a newly labelled exploratory rationale and approval, not a silent primary-grid revision.

Provisioning, imports, compilation, failed attempts, reference runs, oracle runs and reporting must appear in the agreed accounting boundary. A stage ceiling is not permission to exhaust a larger cluster allocation. No numerical stage budget, job script or approval manifest is issued by this draft.

## Acceptance checklist before a new primary campaign

- [ ] Author approves the lifecycle/waiting/admission contract, bounded domain and comparison controls.
- [ ] Source/topology/order manifests identify artifact versus derived sensitivity inputs; no unsupported twenty-node paper-replication claim.
- [ ] Executed original-reference observability and exact walk/tie/detector replay gates pass.
- [ ] Separate oracle/trace checks and defect controls pass; PASS coverage is complete.
- [ ] Native sensitivity design/materiality and any rate-equivalence margin/sample sizes are approved before observing results.
- [ ] Slurm site, provisioning, effective resource enforcement and staged aggregate budget are agreed and verified.
- [ ] Julia operational pipeline and matched performance protocol are frozen; Python remains reference-only.
- [ ] Revised primary grid/attempt policy has its own explicit approval; original sealed artifacts and ledger are unchanged.

**Current status, updated 25 October 2026:** effective preflights and the strengthened standalone oracle passed 2,592 checks, including 120 targeted joint-packet cases. A separate candidate Q/V adapter passed 198,972 differential assertions comparing single-probe packet-edge/boundary sets and acknowledged table frames on the two tiny fixtures. See [Tiny_Validation_Results.md](Tiny_Validation_Results.md) for receipts and coverage limits. Those runs preceded the subsequent three-stage authorization and removal of the aggregate runtime ceiling; their reservation totals are historical, not a current stop. All-method Gate D remains open: the historical engine and other lifecycle adapters are not validated, and buffer/history/defect obligations remain. Python observability/replay and native sensitivity remain unexecuted. No general equivalence claim or revised primary approval is established. Local Julia execution supersedes the draft's mandatory-Slurm requirement.
