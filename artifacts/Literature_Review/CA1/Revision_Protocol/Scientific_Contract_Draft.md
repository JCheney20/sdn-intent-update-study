# Original-intent handover: scientific contract

**Execution update, 26 October 2026:** all three authorized stages are complete on the declared bounded fixtures/domain. See [the completion report](study/Completion_Report.md) for independent controller checks, executed Python observability/44,800-assertion replay, native sensitivity, matched costs and the 12-cell primary comparison. The draft/pending-work language below records the earlier specification checkpoint; it is not current execution status. The contract's assumptions remain limits: no general deployment equivalence, arbitrary-load guarantee or native-RNG/population equivalence is established. No aggregate runtime ceiling applies; hard per-process limits remain.

**Draft v0.2, 25 October 2026.** This records the author's selected policies. The proposed [event semantics and analytical bounds](Operational_Semantics_and_Bounds.md) and [derived TOML fixtures](Handover_Bounds.toml) now instantiate the next formalization step. Their assumptions and adapter obligations still require complete implementation/independent validation. Subsequent limited execution is reported separately in [Tiny_Validation_Results.md](Tiny_Validation_Results.md); the standalone PASS does not close the production-equivalence gate.

## 1. Decisions and authority

**Latest authority, 25 October 2026:** the author subsequently approved all three stages—remaining correctness, pinned Python reference replay, and sensitivity/benchmarks/revised primary comparison—and removed the aggregate runtime ceiling. See [Three_Stage_Execution_Plan.md](Three_Stage_Execution_Plan.md) and [the authority record](validation/Three_Stage_Authorization.toml). Earlier cumulative ceilings and stage-permission restrictions below are historical and superseded. The hard two-CPU/2-GiB/zero-swap/120-second per-process limits, no-install/download boundary, historical seal and scientific acceptance gates remain. Current progress and the reference-provisioning blocker are in [the detailed interim report](Stage_1_Progress_and_Reference_Prerequisites.md).

Selected by the author:

- SDN security–cost comparison remains primary; use the artifact's original changing endpoint pairs.
- Bounded handover, preserving admitted old packets and bounding new activation/waiting.
- Include a counted quiesce/drain control; continuous-service rerouting remains a separate experiment.
- One pending new-intent request, with waiting measured from request arrival.
- Derived model bounds, not an invented application SLA or a logical-round-to-milliseconds mapping.
- Julia-native execution on this laptop; Slurm is optional future portability, not a required installation. The pinned Python reference remains validation/baseline-only.

The initial local environment/tiny-correctness validation allowance was **at most two CPU cores, hard 2 GiB RAM, zero swap, 120 seconds per process and 600 seconds cumulative runtime**. The author subsequently authorized **another 2,000 core-seconds**, making the cumulative reservation ceiling **2,600 core-seconds**, without resetting earlier charges. See [the additive approval record](validation/Budget_Approval.toml). CPU/RAM/swap/per-process limits and the conservative no-refund accounting remain unchanged. No installation/download is authorized by this allowance. Sensitivity campaigns, performance benchmarks and primary comparisons remain outside it. The old campaign and its remaining allowance are not reset or reopened.

Before executing, record the aggregate-runtime charging convention, CPU/thread enforcement and effective RAM/swap proof. Track both elapsed and CPU time; include startup/compilation, failed attempts and validation subprocesses. Start with sequential test processes rather than assuming that two permitted cores require parallel trials.

This note supersedes the earlier planning documents' mandatory-Slurm and wholly-unapproved-resource assumptions. It does not mean that every detail below has independently received author approval or that validation gates have passed.

## 2. Source inputs and observable identity

| Topology | Old intent | New intent |
| --- | --- | --- |
| Cisco artifact | H5 → H9 | H6 → H10 |
| Fat tree fk=4 | H0-0-0 → H3-1-1 | H0-0-1 → H3-0-0 |

Retain the pinned graph/order, original path selection, ingress/egress rules and broad IP-prefix matches. The source assigns identical host IPs; do not introduce unique addresses to make the experiment easier. See the [source audit](Source_Provenance_Audit.md).

Admission must use declared observable information, such as physical source ingress and actual version tags supported by a method. An oracle's knowledge of an intended destination cannot become a magic gate that prevents the very cross-delivery being tested.

An admitted packet's **authorization history** and a method's **forwarding tag** are separate concepts. The oracle retains whether a packet was admitted under the old or new intent. That metadata is not automatically a free field available to ordinary forwarding. If versioned updating uses actual tags, charge its tag assignments and additional forwarding rows.

## 3. Proposed operational state

Represent explicitly:

- Old/new ingress-admission state and actual application/acknowledgement events.
- Concrete switch rule tables, pending control commands and method-specific forwarding tags.
- One pending new request, including its arrival time and whether it has entered the network.
- Located packet probes, physical incoming port, admission history, age and terminal outcome.
- Controller phase, drainage justification, cleanup state and completion condition.

All procedures receive the same admission-control capability and request-buffer assumptions. Count gate changes, acknowledgements, batches and control mutations. State where gate state and the one-request buffer reside and report their storage separately from forwarding-row peaks; do not silently claim them to be free TCAM or unlimited queue capacity.

Proposed monotone admission lifecycle: old admission closes once; new admission opens once, no earlier than old closure. One atomic close/open operation is possible only if the modeled switch-local capability supports it, with both mutations counted. A quiescent gap is permitted and measured. Already admitted old packets may coexist with new packets after opening.

A gate changes behavior when its action applies; an acknowledgement confirms the application. Drainage measured from the acknowledgement is conservative if application was earlier. Explicitly specify the acknowledgement bound and enumerate relevant same-round application/admission/forwarding orders. Do not erase that ordering by treating a controller's request as an instantaneous network-wide change.

## 4. Requests, admission and grandfathered packets

- The old intent is active initially. Cover packets already in flight at the update request and packets admitted subsequently up to actual old-gate closure.
- Closing old admission rejects later old requests, but cannot cancel packets already admitted. Those packets must reach the old destination under the declared packet-lifetime bound.
- A new request arriving before opening occupies the single explicit pending slot. Opening is insufficient by itself: the pending request must be admitted and then delivered within the relevant bounds.
- A new request arriving after opening follows the normal admitted-packet obligation.
- Waiting starts at request arrival. It is not reset when the packet is admitted or when the controller changes phase.
- One outstanding new request is a bounded workload abstraction. Do not discard later arrivals and claim arbitrary offered-load service; they are outside this domain unless a separate policy/model is approved.

Use a monitor that can observe an old packet and the pending/new packet together where needed. Enumerate old launch positions/times, admissible initial ages and new-request arrival times. Any reduction from multiple packets to representative probes needs an independence argument based on stateless forwarding, no congestion and the controller's declared drainage information—not merely an assumption that one packet was enough in the previous model.

## 5. Safety and liveness obligations

**Isolation:** each admitted old packet may terminate only at its old authorized destination; each admitted new packet only at its new authorized destination. Wrong-host delivery is forbidden, including either cross-intent destination. Keep forbidden reachability probes distinct from legitimate-request delivery obligations; requesting an unauthorized destination does not create a service entitlement.

**Old delivery:** every covered packet admitted before old closure must arrive correctly. Dropping it, losing its history or declaring it revoked at cutover is not successful drainage.

**New service:** opening/admission occurs within the declared bound, and the pending request is delivered. Never admitting requests cannot produce a vacuous PASS. Intended rejection of post-closure old requests is visible but is not loss of an already admitted packet.

**Completion:** require acknowledged target forwarding/admission state, justified old-packet drainage, removal of obsolete state and no unresolved command obligations. A controller flag alone is insufficient.

An early wrong-delivery/drop/deadline witness may establish FAIL. PASS requires complete relevant coverage. Timeouts, exhausted search limits and missing proof obligations are INCOMPLETE, not safe results.

## 6. Three logical clocks and bound derivation

Keep separate:

1. Request waiting: arrival to admission.
2. Admitted-packet lifetime: admission to authorized delivery.
3. Controller completion: update request to final acknowledged target state and cleanup.

Report total request-to-delivery latency too. Preserve pre-update age for packets already in flight. Specify forwarding opportunities per logical round and how controller events interleave with them; fairness cannot permit an adversary to suspend a packet forever without consuming its deadline.

Derive bounds **before comparison outcomes**, independently of wall-clock execution ceilings:

- Derive endpoint path-processing lengths from raw rules, with an explicit launch/delivery convention.
- State the admitted intermediate forwarding behaviors and any allowed finite loops, buffering or stuttering. A longest endpoint path is not automatically a bound on every intermediate execution.
- Bound acknowledgement delays, command phases, admission opening, required drainage and final cleanup. Supply a progress/rank argument or complete finite-state coverage argument as appropriate.
- Instantiate a common per-topology contract across procedures. A method lacking a bound does not get an arbitrary larger horizon after failing.
- Separate model service deadlines from the horizon needed to decide their satisfaction. A sufficient search horizon is not by itself a real-world service requirement.
- If cost trade-offs are evaluated under additional deadlines later, freeze those thresholds or a declared frontier analysis before the campaign. Do not choose a cutoff that makes a preferred method win.

Do not inherit H=5 or the old 79-round bound. A transient finite loop is neither automatically acceptable nor automatically a permanent-loop witness: test it against the declared delivery requirement. The [new derivation](Operational_Semantics_and_Bounds.md) finds a packet-level union rank of 4/5 for these original fixtures and a conditional common controller envelope of 75/126 rounds. This is a fresh, restricted-domain argument, not a result for the old constructed reroute or all CCG implementations.

## 7. Next deliverable and gates

The [formalization](Operational_Semantics_and_Bounds.md) now specifies event ordering, Q/V control phases, a packet-union rank, conditional controller bounds, and the tiny oracle/defect cases. The local resource/accounting preflight and initial standalone raw-input fixture/rank and Q/V event checks have completed; see [the results and remaining gaps](Tiny_Validation_Results.md). Next, complete outstanding coverage/defect checks and revised production/oracle transition correspondence under the remaining limited allowance. Keep the independent oracle separate from production transitions and derive its expected tables from raw inputs; the derived TOML is not an independent source of truth.

Reference snapshot replay can validate the overlapping detector behavior; it cannot validate the new admission/packet semantics. The controller must not gain free access to the independent oracle's live-packet state or safety verdict.

The remaining acceptance, source/RNG and independence requirements in the [validation protocol](Revision_Validation_Protocol.md) still apply. Its original Slurm-only deployment/resource passages are conditional future-portability guidance, superseded for this laptop by section 1 above. No sensitivity, benchmark or primary campaign follows automatically from successful tiny validation.
