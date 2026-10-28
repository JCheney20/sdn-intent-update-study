# Handover event semantics and derived bounds

**Proposed formalization v0.1, 25 October 2026.** Analytical derivation for the two pinned original-intent fixtures; not an executed model, independent-oracle result or primary experiment. Read with the [scientific contract](Scientific_Contract_Draft.md). Numerical inputs and arithmetic are recorded in [Handover_Bounds.toml](Handover_Bounds.toml).

## 1. What is being bounded

The raw original intent changes are materially simpler than the previous constructed continuous-service reroute. Their union of forwarding rules is acyclic at the packet level. That permits a packet bound independent of controller completion, avoiding a circular argument in which controller history expiry and packet lifetime are defined using each other.

The following are **proposed initial model restrictions**, not facts about deployed switches or the full published CCG system:

- Trusted stateless forwarding, exact physical-ingress/prefix matching, no congestion, crashes or lost commands.
- Every live admitted packet receives one forwarding opportunity per logical round. There is no in-switch packet holding; the one new-request buffer is at the admission boundary, before network admission.
- Ordinary intermediate rules come only from the old/target rule union. Versioned rules are copies of those triples with an actual tag match. No synthesized detour, arbitrary packet rewrite or extra permitted traffic class is silently added.
- Controller progress follows the finite action discipline in section 6. A controller that needs different actions or waits requires a different proof before comparison.

No assertion of bounded delivery follows merely from these termination bounds: a packet can terminate by DROP or at the wrong destination. Those remain service/isolation failures.

## 2. Round and event relation

Let boundary 0 be the update request. Round r occupies the interval between boundaries r−1 and r, for integer r ≥ 1.

1. At the opening boundary, the controller consumes acknowledgements already received and may issue commands enabled by that information. A dependent phase cannot start from an acknowledgement that has not yet occurred.
2. Every command issued at that boundary applies atomically at its own switch sometime in that round and is acknowledged by the closing boundary. This is a declared one-round application/acknowledgement assumption, not a measurement. Commands at different switches are not globally atomic.
3. Every live packet has one service event in the round. Its lookup uses the table at that event and actual incoming port/tag. A missing match is terminal DROP; arrival at a host is terminal delivery, checked against its historical authorization. A service event transfers directly to the next switch's lookup location or a terminal host; host-link transmission, propagation and inter-switch travel are not separate clock events.
4. The source's admission opportunity is its service event: when its gate is open and a request is present, admit/tag the packet and perform its first switch lookup in that event. When closed, a new request remains in its single pending slot; a post-closure old request is rejected. Thus a request arriving after a gate opens but after that round's service opportunity can wait until the following round.
5. Enumerate all legal interleavings of packet/admission events and distinct switch-batch applications within a round. Preserve causal order. Do not process every update before every packet by convention. A switch batch may atomically contain local gate, tag-assignment and rule changes only where that capability is explicitly declared.
6. Gate behavior changes at application, not at command issue or acknowledgement. Acknowledgement provides a conservative reference point for drainage.
7. At the closing boundary, complete acknowledgements and advance time/ages. Already admitted packets cannot stutter indefinitely: each subsequent round has their required service opportunity. A delayed or lost command is outside this model, not a schedule to ignore.

The boundary representation records packet age as the number of elapsed service rounds since admission; an admission/first-lookup event counts its first opportunity. Waiting before admission is separate. An old packet initially after i forwarding operations has historical age i, not age zero.

Requests arrive at declared boundaries. A request present at boundary a has an opportunity in round a+1. Same-round old admission versus closure, and new opening versus admission, are both covered by interleaving those events.

### Decision/checking delay

Let d be an explicitly supplied number of logical rounds used before the network action protocol begins. The numerical protocol examples below use **d=0**, an abstraction for validating the action protocol, not a claim that detector/guard computation takes no time. During any d>0 prefix, old forwarding remains active and a new request may already be waiting. Add d to opening/completion/request-wait bounds; do not add it to an admitted packet's rank bound.

Measure actual detector/guard CPU/elapsed work separately. Without a justified mapping from that computation to network rounds, these numbers are not real end-to-end controller response times. A method with interleaved checking delays must include their declared total in its completion argument; it cannot hide them as free network time in a deployment claim.

## 3. Source-derived forwarding ranks

Paths follow the pinned generator insertion order and original `shortest_path` preparation. They agree with the previously frozen pilot's literal checks, but have not been recaptured from an executed Python reference in this revision.

| Fixture | Old path | New path |
| --- | --- | --- |
| Cisco | H5–C2–C10–C4–C5–H9 | H6–C2–C10–C4–C5–H10 |
| Fat tree fk=4 | H0-0-0–E0-0–A0-0–C0–A3-0–E3-1–H3-1-1 | H0-0-1–E0-0–A0-0–C0–A3-0–E3-0–H3-0-0 |

Assign rank zero to terminal outcomes. On switches with possible union rules:

- Cisco: C2=4, C10=3, C4=2, C5=1.
- Fat tree: E0-0=5, A0-0=4, C0=3, A3-0=2, E3-0=1, E3-1=1.
- Other switches have no union rule and terminate by DROP at their first lookup; assign rank one there.

Every permitted union-row forwarding operation strictly decreases rank; a missing rule or wrong-prefix/tag match terminates immediately. Tags select or disable these edges; they do not create new forwarding destinations. Hence, under the stated no-holding service opportunities:

**H_Cisco=4 and H_fat4=5 forwarding rounds suffice for every admitted packet to terminate**, including a wrong-delivery/drop outcome, under every allowed intermediate table subset and switch-event ordering.

This is a union-rank proof, **not** merely the observation that endpoint paths have four/five switches. It does not transfer to the old constructed P reroute, synthesized routes, packet buffering or an arbitrary topology. In these original fixtures, a legal transient forwarding loop is structurally absent. A deliberately introduced looping rule violates the union/rank precondition and must be rejected/detected rather than assigned this bound.

For an old packet initially at rank k after i operations on its old path, remaining lifetime is at most k and historical age is retained. With atomic admission/first lookup, the nonterminal already-admitted boundary positions have i=1,…,L_old−1; the destination after L_old operations is already terminal. Do not additionally label a never-processed source request as a grandfathered packet. Source admission/first lookup, including the first-switch case, is instead covered by enumerating old launches in every round up to actual closure.

### Coverage reduction, with a proof obligation

Only the old/new source hosts can match a first-hop rule anywhere in the raw union; every other host has a different physical ingress and fails its first lookup. Every union edge into a host targets either the old or new destination. Verify both facts independently from raw triples, including dual-homed hosts; they are not a destination-aware admission filter. The snapshot detector still keeps its original full host-pair alarm domain.

Single-packet projections suffice for universal packet properties **only when** controller decisions depend on acknowledged rules/timers, not probe locations or deliveries; forwarding does not change gates/tables; and there is no congestion or shared packet buffer. Under those conditions each packet's projection is a legal single-probe execution of the same control trace. A bad multi-packet execution therefore contains a bad single projection. Check old/new simultaneous probes as a reduction sanity control. If those independence conditions fail, retain joint packet state; do not apply the reduction.

## 4. Two explicit safe-control constructions

These are mathematical candidate controls to validate, not experimental PASS records. All enabled independent switch commands in a phase are issued together; every command is still a separately counted switch-local batch. Parallel application is bounded by the one-round assumption, while within-round order is adversarial.

### Q: quiesce, drain, replace, open

1. Close old admission; acknowledge by boundary 1.
2. Preserve all old tables for H complete following rounds, through boundary 1+H. Every old packet admitted before closure has terminated at its authorized old destination: old rules remain intact, their path is valid, and their rank decreases.
3. In round H+2, replace only changed switch tables with their target contents. Both source admissions are closed and no old packet remains. Other-host probes cannot enter the union by the first-hop lemma.
4. In round H+3, open new admission, acknowledged by boundary H+3. New packets then follow the unchanged target path. No obsolete table remains.

Thus **A_Q=C_Q=H+3**, where A is new-opening acknowledgement and C is full controller completion. A pending boundary-0 request is admitted by A_Q+1 and delivered by A_Q+1+H. These are conservative inclusive-round bounds, not claims of exact latency.

For each switch, atomic replacement keeps row occupancy at or below its larger endpoint table: **zero extra forwarding rows** are needed. The two admission states and one source-side pending slot are separate, explicit resources. This demonstrates feasibility of a zero-extra-forwarding-row control under this new handover model; it does not overturn the old continuous-service results or prove a deployed system guarantee.

### V: versioned stage, commit, drain, clean

Initial path rows match tag 0. Stage a tag-1 copy of every target path row during round 1, including otherwise unchanged triples; do not assume free wildcard sharing. If the row capacity does not permit this, report RESOURCE_BLOCKED before starting, not PASS.

In round 2, atomically close old admission, set the new ingress tag assignment to 1 and open new admission. The two source hosts attach to the same ingress switch in each fixture (C2 or E0-0), so this is one declared local batch, not a network-wide commit. Count two gate mutations and the tag-assignment mutation.

Preserve all tag-0 rows for H full rounds after the commit acknowledgement. Clean them in round H+3. Every old packet retains its tag-0 path; every new packet uses the already installed tag-1 path.

Thus **A_V=2, C_V=H+3**. A boundary-0 pending request is admitted by 3 and delivered by 3+H. Peak extra forwarding occupancy is **one row at each shared path switch** and zero elsewhere, relative to each switch's larger untagged endpoint table. Final targets are method-specific tag encodings of the same raw forwarding behavior; require exact declared encoding plus the common behavior, not arbitrary leftover versions.

| Derived quantity, d=0 | Cisco | Fat tree fk=4 |
| --- | ---: | ---: |
| H, old/new path switch count | 4 | 5 |
| Distinct switches in either path, u | 4 | 6 |
| Changed untagged tables, m | 2 | 4 |
| Q opening/full completion bound | 7 | 8 |
| Q pending-request waiting bound | 8 | 9 |
| Q request-to-delivery bound | 12 | 14 |
| V opening bound | 2 | 2 |
| V pending-request waiting bound | 3 | 3 |
| V request-to-delivery bound | 7 | 8 |
| V full completion bound | 7 | 8 |
| Q extra forwarding-row peak | 0 | 0 |
| V extra forwarding-row peak | 1 | 1 |

Control-accounting checks, not optimized lower bounds:

| Control | Cisco batches / row inserts / row removals | Fat-tree batches / row inserts / row removals |
| --- | --- | --- |
| Q | 4 / 2 / 2 | 6 / 3 / 3 |
| V | 9 / 4 / 4 | 11 / 5 / 5 |

Q counts close + m changed-table batches + open. V counts one stage per target-path switch + commit + one cleanup per old-path switch. No empty cleanup command is issued. Row replacement removals/insertions are one atomic batch, not two rounds. Gate/tag mutations and simultaneous switch batches are reported separately; batch count is not elapsed rounds.

## 5. History expiry without a circular lifetime assumption

For any CCG-inspired removed-edge history restricted to this same packet domain, an edge removed during round r may still have been used before removal that round. Retain its possible packet history through **all H subsequent rounds**, and discard no earlier than the opening of round r+H+1.

The rank proof gives H independently of controller completion, including under intermediate ordinary updates. No packet can keep that removed-edge history live longer without violating the declared service-opportunity or union-rule assumptions. A dropped packet is still a service failure, not successful delivery. A history expiry bound does not certify the scheduler's admission choices or packet semantics.

This justifies a candidate retention duration for these fixtures; the complete CCG-inspired scheduler still needs an independently checked transition/rank argument. The frozen implementation's H=5 and old completion bound are not silently imported. In-switch packet buffering from a fuller CCG implementation would require new bounds and a separately stated scope.

## 6. Common finite controller envelope — conditional on adapter discipline

A common bound can be derived before outcomes for adapters with these explicit restrictions:

- At each of u path-union switches, at most one in-place target replacement, one target-version staging action, and one obsolete-version cleanup action. No rollback, repeated restaging, extra version or unbounded retry. Actions not needed by a procedure are skipped, not charged as network no-ops.
- At most two admission-control batches; the optional tag assignment is part of the declared local commit batch. Control on switches outside the union is absent.
- After an acknowledged progress event, at most H full rounds may pass before the controller issues another enabled progress action. A history timer must expire under section 5. If no legal progress/fallback exists then, return an explicit PROGRESS_BLOCKED or RESOURCE_BLOCKED result, not an endless wait or false completion.
- Every issued command is acknowledged within its round. A final drainage/decision interval is bounded in the same way. Pending controller computation adds the separately declared d; it is not silently included in H.

There are at most **N=3u+2** work actions. A progress interval costs at most H waiting rounds plus one command/acknowledgement round. A final interval costs at most H+1. Therefore:

**C*=(N+1)(H+1)=(3u+3)(H+1)**

bounds either full completion **or an explicit blocked terminal result**. It does not promise that every adapter succeeds. A lexicographic progress measure is remaining action slots, then remaining interval timer; issuing/applying work cannot replenish a used slot, and waiting consumes the finite timer. Parallel work can only reduce this upper bound.

A controller which stops blocked is not jointly qualified. This is a bounded-controller definition, not a theorem that no other update algorithm could progress. Verify each adapter against the action discipline; any method outside it has **no bound from this formula**. The gate must flag that mismatch before tests, rather than stretching the deadline after a failure.

| Common envelope, d=0 | Cisco | Fat tree fk=4 |
| --- | ---: | ---: |
| N | 14 | 20 |
| C*, completion/blocked-result bound | 75 | 126 |
| Maximum pending-request waiting if opening succeeds by C* | 76 | 127 |
| T*=C*+1+H, complete packet-observation horizon | 80 | 132 |

For each covered new arrival at boundary a ≤ C*, an opening by C* permits admission by max(a,C*)+1 and termination within H further rounds. Arrivals after the controller has settled reduce to the stationary target case by time translation. Initial old packets and all old launches until closure are covered by their H bound. Thus T* is a sufficient observation horizon under the stated controller/packet premises.

**These are proposed common model bounds, not real-world SLAs or measured completion times.** Freeze them with the adapter obligations before validation. The tighter Q/V numbers explain their phase costs; they are not separate favorable qualification cutoffs. Added delays d shift controller/request bounds and T* by d. Resource exhaustion during exploration is still INCOMPLETE, not a proof that the logical controller exceeded C*.

## 7. Tiny oracle and defect cases to instantiate next

### Hand-derived ordinary-update negative fixtures

These use the original intents, not the constructed P reroute, and are **analytical witnesses to check**, not executed attacks/results:

- **Cisco:** an old H5 packet has completed three lookups and is at C5, incoming from C4, authorized for H9. Apply the unversioned target C5 row before its lookup. The same incoming port now forwards to H10. It reaches the wrong destination at age 4, even if old admission has already closed. Closing admission does not protect an already admitted packet.
- **Fat tree:** an old H0-0-0 packet is at A3-0, incoming from C0, age 3, authorized for H3-1-1. Install the target A3-0 and E3-0 rows before their respective lookups. It traverses E3-0 and reaches H3-0-0 at age 5. Both updates fit the larger endpoint tables without extra rows.

Each witness respects the rank bound: **bounded termination is not isolation**. Q prevents these schedules by preserving old tables until drainage; V preserves the old-tag path. The independent oracle must confirm those distinctions instead of accepting this narrative as its expected verdict.

### Coverage and defect checklist

- Every pre-update old path position/age; old launch before/after same-round closure; latest old admission before closure.
- New request at boundary 0, during a closed interval, at opening, and in stationary target state; missed same-round opportunity must count the next-round wait.
- Both application/packet orders at every affected switch; simultaneous old/new probes to check the factorization premise.
- Partial staging followed by premature opening; early old-tag cleanup; cleanup no-ops versus real work; wrong incoming port/prefix/tag; version bit available to the monitor but illegally read by ordinary forwarding.
- Destination-aware gate cheating; pending request dropped/reset; a second pending request explicitly rejected as outside this bounded domain, not silently counted as served.
- History expiry one round too early; clock age reset at cutover; false target/completion flag; repeated action slots, unlimited waiting or unbounded retry violating the adapter rank.
- Introduced forwarding cycle/out-of-union edge: invalidate the H proof and detect the fault; do not manufacture a PASS at the old bound.
- A forced low search/runtime cap produces INCOMPLETE with no PASS coverage claim.

The oracle must derive rows/ranks from raw inputs independently, not trust the TOML numbers or production helpers as its expected truth. This document supplies a specification to challenge, not an oracle implementation.

## 8. Evidence status and next gate

The paths and rule changes were inspected against the pinned source-reading copies and the frozen pilot's existing literal assertions. The new TOML is derived data, not an original-source receipt. Static data/link/hash checks are not model execution.

Still required: independent raw-input rank/row derivation, implementation of the event relation and controls, adapter-obligation checks, defect rejection, and an effective local resource/accounting preflight. No reference execution, simulation, new scientific PASS, equivalence claim or primary authorization is established here. The sealed historical package remains unchanged.
