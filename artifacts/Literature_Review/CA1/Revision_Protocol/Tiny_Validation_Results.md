# Local tiny validation results

25 October 2026. The initial completed run was recovered after the preceding pi session stopped responding. A subsequent bounded run tested additional joint-packet and observable-admission checks. Results below distinguish the standalone checker versions and the subsequent candidate Q/V differential comparison. No historical-engine or all-method production-equivalence result is claimed.

**Subsequent update, 26 October 2026:** this report covers the initial five bounded runs. Its remaining-budget, missing-prerequisite and open-coverage statements are historical, not current status. All three subsequently authorized stages have completed: [controller validation](Controller_Validation_Report.md), [executed reference replay](reference_capture/Reference_Replay_Report.md), and [576-record sensitivity/48-job benchmark/12-cell primary completion](study/Completion_Report.md). The aggregate runtime ceiling is removed; hard per-process resource limits and the historical seal remain unchanged. This early evidence is retained rather than rewritten as later results.

## Executed evidence

Runner: [`validation/run.sh`](validation/run.sh); resource/seal entry point: [`validation/entry.jl`](validation/entry.jl); standalone checker: [`validation/oracle.jl`](validation/oracle.jl).

| Run | Result | Elapsed including startup | Scope CPU | Memory peak at checkpoint | Reserved core-seconds |
| --- | --- | ---: | ---: | ---: | ---: |
| [Preflight receipt](validation/runs/cos738-revision-1792942039062268133/receipt.toml) | PASS | 3.74 s | 3.534515 s | 233,148,416 B | 64 |
| [Initial oracle receipt](validation/runs/cos738-revision-1792942363694887668/receipt.toml) | PASS, initial 1,855 checks | 10.36 s | 9.626668 s | 300,130,304 B | 244 |
| [Strengthened oracle receipt](validation/runs/cos738-revision-1792943161034225970/receipt.toml) | PASS, restricted scope below | 10.47 s | 10.328760 s | 208,781,312 B | 244 |
| [Extended-budget preflight](validation/runs/cos738-revision-1792943406010592697/receipt.toml) | PASS | 5.44 s | 5.334115 s | 179,171,328 B | 64 |
| [Candidate Q/V differential receipt](validation/runs/cos738-revision-1792943567987355352/receipt.toml) | PASS, candidate scope below | 18.51 s | 18.300111 s | 275,857,408 B | 244 |

Effective inherited cgroup limits were 2,147,483,648 bytes RAM, zero swap and CPU quota 200,000/100,000; task affinity was restricted to CPUs 0 and 1. Julia 1.13.1 ran with one Julia worker, one GC thread and math-library thread limits of one. These are validation resource observations, not a matched benchmark or a Julia speedup result. Memory peaks are checkpoints, not an independently sampled whole-system peak.

Accounting uses immutable full two-core time-limit reservations plus two seconds of wrapper margin, including startup and failures, with no refunds. The author explicitly authorized **another 2,000 core-seconds**, recorded in [Budget_Approval.toml](validation/Budget_Approval.toml). The cumulative ceiling is now 2,600, retaining all initial reservations. **860/2,600 core-seconds are reserved; 1,740 remain.** This is not actual CPU consumption. The historical campaign's ledger is separate and unchanged. Reservations describe the five bounded validation invocations, not all interactive agent activity. The changed bootstrap and approval hash passed a new preflight before differential execution. No refunds, installations/downloads or sensitivity/benchmark/primary permission follow from this extension.

## Standalone checker findings

The checker imports no historical/production transition helpers. It derives ordered paths, concrete ingress/egress triples and forwarding-union ranks from pinned raw source-reading inputs, then compares them with the declared TOML fixtures. Cisco graph literals are parsed; the fat-tree graph is an independent closed-form expansion restricted to the pinned k=4 generator. Neither operation executes the original Python artifact.

| Fixture | Checks attributed to fixture | Probe cases | Boundary-state visits | H | Conditional controller envelope | Observation horizon |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Cisco | 1,058 | 166 | 14,281 | 4 | 75 | 80 |
| Fat tree k=4 | 1,525 | 270 | 37,435 | 5 | 126 | 132 |

The strengthened run has **2,592 assertions**: 2,583 fixture assertions and nine shared input/reduction/rank assertions. The 436 single-probe cases are bounded deterministic coverage cases, not independent statistical trials. Boundary-state visits include repeated states across rounds/cases and are not unique global-state counts.

Additionally, 56 Cisco and 64 fat-tree joint Q/V cases pair every covered initial old position and old launch at boundaries 0–3 with new arrivals at 0, immediately before opening, at opening, and C*. They visit 7,620 and 14,172 joint boundary states respectively. These **120 targeted joint cases** preserve one common table trace using causally nested event masks. Their complete terminal projections match the corresponding single-probe terminal sets, with valid delivery and request clocks. Two additional ordinary-update joint negative controls retain the old wrong-delivery witnesses. This is a targeted reduction sanity check, not enumeration of every pair of arrival times or comparison with an independent production engine.

For the fixed Q and V schedules, the checker covers every nonterminal pre-update old-path position with its historical age, old request arrivals at boundaries 0–3, and new request arrivals at every boundary through the common controller envelope. Within each round it enumerates table views corresponding to every subset of commuting distinct-switch batches around one probe's service event. Controller acknowledgements are implicit at round boundaries under the declared reliable one-round assumption.

Observed checks include:

- Correct authorized delivery of admitted old/new probes, explicit post-closure old-request rejection, bounded new waiting measured from arrival and request-to-delivery bounds.
- Exact final tables/gates/tags; controller schedules settled before completion; fixed-plan action/row/gate/tag accounting; Q zero-extra-row and V one-extra-row peaks.
- Both ordinary unversioned cross-delivery witnesses: Cisco old H5 traffic can reach H10 instead of H9; fat-tree old H0-0-0 traffic can reach H3-0-0 instead of H3-1-1. A separate raw-row suffix checker confirms the witnesses and rejects forged epoch/ingress/age claims.
- Controls exposing omitted ingress/prefix/tag matching, premature old-version cleanup, incomplete staging, never opening admission, incorrect final admission/tables, outstanding future commands and search truncation incorrectly treated as PASS.
- A synthetic forwarding-union cycle invalidates the rank proof. A scalar history-retention check distinguishes expiry one round too early.
- Literal permutations agree with the nested-view reduction for two probe events and zero through five independent switch applications, covering the largest fixed-plan batch phase.
- Explicit raw-row verification that every host egress is an old/new destination, complementing other-host first-hop exclusion.
- Admission now selects gates/tags using the physical source ingress, not monitor-only authorization epoch. A forged epoch cannot evade old closure or change the new source's tag; a seeded epoch-aware gate variant is distinguished. Unknown request ingress is rejected. This repairs an implementation shortcut in the initial checker; legitimate original probes gave the same results because their epochs and sources agreed. It does not change the frozen contract or rescue the ordinary negative cases.
- Both single and joint searches refuse coverage claims on search-cap exhaustion, including single-search overflow at the final boundary.

## Candidate Q/V adapter differential comparison

The new [`handover.jl`](handover.jl) is a candidate adapter for this revised contract, not a modification or validation of the sealed historical engine. It independently derives tables from declared paths, encodes switch/port/tag lookup as dense numeric arrays, derives the union rank by bottom-up sink elimination, and constructs its Q/V action schedules. Its event recursion literally reorders switch commands and the packet event, unlike the oracle's subset-view exploration. No oracle helper is imported by the adapter; the standalone oracle finishes before the adapter is loaded.

[`validation/differential.jl`](validation/differential.jl) supplies an explicit normalization map. For all 436 single-probe cases it compares complete reachable boundary-packet sets, legal packet-edge sets at each round and final acknowledged tables/gates/tags through the frozen horizon. It also requires exact final target encoding and the oracle's packet obligations. This compares boundary-level packet transitions and acknowledged table frames, not every internal controller-event microstate.

| Fixture | Differential assertions | Single-probe cases | Boundary-state visits | Per-round packet edges |
| --- | ---: | ---: | ---: | ---: |
| Cisco | 54,315 | 166 | 14,281 | 14,115 |
| Fat tree k=4 | 144,657 | 270 | 37,435 | 37,165 |

**198,972 differential assertions passed**, in addition to the unchanged 2,592 standalone assertions in the same process. Edge/visit counts include terminal self-loops and repeats across rounds/cases, not unique global transitions or independent trials. Separate ordinary-update negative comparisons retain both wrong-delivery witnesses. Repeated action slots, excessive progress waits and nonlocal gate mutations are rejected. A tag-matching fault injected only into the adapter changes its physical transition and is distinguished by the independent expected transition.

The adapter has no access to probe delivery when constructing plans. Its progress checker validates the bounded command envelope for the supplied schedules, not a full CCG scheduler or every admissible controller. Literal factorial enumeration is deliberately limited to these tiny validation cases; no production scaling or speed claim follows.

## What has not passed

**The candidate Q/V transition comparison above passes on its declared domain; the complete all-method Gate D remains open.** The nested standalone receipt retains its original standalone-only scope flags, while the separate differential receipt records `candidate_Q_V_transition_agreement = true`, `historical_production_engine_validated = false` and `all_method_gate_D_complete = false`.

Remaining distinctions matter:

1. The revised Q/V candidate has the single-probe correspondence reported above. Ordinary, detector/guard and CCG-inspired lifecycle adapters, joint adapter/oracle correspondence and independent replay of general controller-generated witnesses remain open. The historical production model has a different contract and has not been validated by this comparison.
2. Joint Q/V packet exploration is now present for the targeted cases above; it shares the standalone service primitive with single-probe exploration. It is not independent transition validation. General single-probe factorization still relies on the documented controller/packet independence premises.
3. Fixed Q/V plan compliance and repeated-action/excessive-wait rejection are now tested. A general controller's actual progress timers, blocked-result behavior and all admissible plans through C* are not executed. The common-bound formula remains conditional on each additional adapter's compliance.
4. History expiry is a scalar boundary control, not an implemented CCG history lifecycle. The cycle control rejects an invalid union; it does not establish a general temporal cycle detector.
5. The one-request domain does not implement a shared queue or test second-new-request overflow, pending-request loss/reset mutations or offered-load service. The joint cases contain one old probe and one new request, not two competing new requests.
6. First-hop exclusion, the host-egress lemma and physical-ingress/epoch separation are now checked. A separate destination-aware cheating mutation and the complete originally requested defect checklist remain unfinished.
7. No pinned Python import, instrumentation-observability check, random-walk/tie capture, deterministic replay or native-RNG sensitivity was executed. Source-derived agreement is not reference-execution equivalence.
8. No full CCG implementation, in-switch buffering, real-world SLA, deployment assurance, throughput claim or language performance conclusion follows.

## Integrity and next step

All five runs check the historical seal before and after their work. The 194 sealed file hashes and two external context snapshots remain unchanged; the delivery manifest SHA-256 remains `b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb`. The initial oracle is preserved byte-for-byte in [`validation/snapshots/oracle-e5e57cab4a61fe4fb8cda8f12537d1194de648a3eea1200282ccac60bc72b51c.jl`](validation/snapshots/oracle-e5e57cab4a61fe4fb8cda8f12537d1194de648a3eea1200282ccac60bc72b51c.jl); its hash matches the initial receipt. The current oracle SHA-256 is `058b65397b0382474174d0d9d69ba220b255f8260bbfb04ca4416dca6978f2c5`, matching the strengthened receipt. The analytical semantics and TOML fixtures remain byte-identical across runs. The original bootstrap is preserved by SHA-named files under `validation/snapshots/`; the extended bootstrap and approval file are hashed in the new preflight/differential receipts. The candidate and comparison files are hashed before their differential execution. Originals and historical logs were not edited.

Next correctness work is to close the remaining defect/buffer/history gaps and extend the candidate comparison to additional lifecycle adapters and appropriate joint/controller traces. Keep all work inside the remaining 1,740 core-seconds; no obligation exists to exhaust it. Do not start a replacement primary campaign or reset the ledger. Reference-environment inspection/provisioning and actual Python replay remain separate work; missing packages require installation/download approval, not an unpinned substitute. Any future reference execution needs a bounded runner and its own reservation.

**No sensitivity, benchmark or primary campaign is authorized by these PASS receipts.** All remaining acceptance requirements in [Revision_Validation_Protocol.md](Revision_Validation_Protocol.md) continue to apply.
