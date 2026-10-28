# Evidence register: SDN update safety

**24 October 2026. Active topic selected by the author.** Source IDs refer to [Focused_Literature_Review.md](Focused_Literature_Review.md). This is a claim-support record, not experimental results. Historical reassignment versions are preserved in the [pre-SDN snapshot](../../Archive/2026-10-24-pre-sdn-pivot/README.md).

| Claim | Primary support and actual inspection | Supported conclusion | Boundary |
| --- | --- | --- | --- |
| E01: distributed updates need an explicit consistency property | S1, definitions and property preservation; previous primary review | Old/new processing consistency has a formal scope | Not immediate revocation or correctness for arbitrary model/implementation. |
| E02: selective verification with heavier fallback is existing work | S2, §§3–5.3; supervisor primary inspection | CCG verifies, schedules/buffers and can invoke suitable CU/SWAN fallback | Generic hybrid mechanism is not our novelty. Guarantees depend on model/property/fallback. |
| E03: the general cost benefit is already evaluated | S2, §7 and limits §8; supervisor primary inspection | Comparative emulation, trace-driven and physical-testbed evidence exists | Numerical results are bounded, not universal ranking; some comparator implementations are partial. |
| E04: negative fast detection is not a safety certificate | S3, §5.5; primary inspected across prior review | Spotlight's fast method can miss temporal vulnerabilities | Finite no-violation observations cannot establish universal safe release. |
| E05: detector timing is not total update cost | S3, §6.2; A1 `detection()` / `detection_search()` inspected | Preprocessing and detection/search are separately measured | Integration, update completion and recomputation require their own account. |
| E06: the combined decision workflow is a posed question | S3, §7; supervisor primary inspection | Paper proposes mixed operation and a cost comparison | A published question can receive a new empirical answer; current novelty remains unconfirmed. |
| E07: intent reporting and flow behavior can disagree | S4, §§III–VI; supervisor primary inspection | Specific emulated ONOS cases and proposed mitigations | Not a current-version/universal vulnerability or matched defense evaluation. Threat assumptions differ. |
| E08: bundles have multiple atomicity meanings | D1, OpenFlow1.4 §6.8.1–6.8.4, printed pp.42–43; supervisor inspected for this update | Controller atomicity and optional packet atomicity/ordering are distinct | A bundle's local scope is not one network-wide transition; switch support matters. |
| E09: a practical implementation offers local atomic bundles | D2, OVS v3.5.0 manual, flow commands and `--bundle`; supervisor inspected for this update | Documented all-or-nothing transaction and packet before/after behavior for a switch | Not installed-version evidence, multi-switch atomicity or proof of a secure chosen sequence. |
| E10: production SDN/intent control is real context | S9, official USENIX record, primary front matter and abstract/introduction checked for this update | Google's 2021 Orion paper reports production Jupiter/B4 deployment | One historical first-party case; detailed results not audited and no deployment claim for CCG/Spotlight. |
| E11: alternative update approaches require closer technical inspection | S7–S8, verified identities; methods not inspected in focused follow-up | Relevant timed/in-place comparators exist | Access limits do not establish a gap or justify detailed algorithm/performance claims. |

## Proposed-study inferences, not existing findings

- Maintaining a forbidden reachability pair at both endpoints provides a candidate common invariant; the exact property/workload is not yet selected.
- A detector-guided procedure needs an action policy for both alert and negative cases. A sound negative-branch checker/fallback is a distinct variant whose cost must be included.
- A bounded packet/update interleaving model could expose missed risks; it is not yet built or validated.
- Emulation could measure real implementation costs but cannot establish production or universal guarantees.
- A source-backed decision table can be a worthwhile CA1 result without claiming a new mechanism or experiment.

These are methodological proposals developed from the cited distinctions. They are not reported source results, proofs or authorization to test.

## Source/verification record

The [focused index](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Paper_Index.json) preserves ten SDN paper records and per-paper labels. The [parent checks](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Parent_Checks.md) document corrections to DOI/title/authors, rejected alternate identifiers and the stronger CCG baseline. Raw delegated reports retain earlier errors as provenance; the corrected records and supervisor dispositions govern interpretation.

For the current topic update, additional primary retrievals were limited to Orion production context, OpenFlow1.4 bundle provisions and version-tagged OVS manual text. A failed OVS hosted-manpage URL was replaced with official repository manual source; no configuration changes or alternate research-agent runner were used. The full Orion/spec extractions were available, but only the stated passages were inspected. [Supporting source snapshots](SDN_Background_Sources/README.md) record this access separately from reading depth.

Current evidence does not certify a novel empirical result or complete recent literature coverage. No experiments, installed versions or reproduction are claimed. AI-assisted collection/synthesis and main-agent primary checks are not student verification. The methodological options remain proposals for author choice.
