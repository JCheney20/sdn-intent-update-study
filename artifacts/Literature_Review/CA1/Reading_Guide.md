# Reading guide: SDN update safety

**24 October 2026.** The author selected SDN as the active direction. Source IDs below refer to the [active literature review](Focused_Literature_Review.md), not the previous Linux reassignment bibliography.

## 1. Establish the existing solution: CCG [S2]

Read [CCG](https://www.usenix.org/system/files/conference/nsdi15/nsdi15-paper-zhou.pdf), §§3–5 and §§7–8. [Offline text](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Primary_Extracts/ccg-nsdi2015.md).

Answer: What is checked before releasing an update? How are uncertain application and in-flight packets modeled? When is fallback required, and what happens without a suitable fallback? What comparisons have already been performed?

**Produce:** a half-page description of the strongest existing baseline and one precise result a new comparison would need to add. Do not describe verification plus fallback as our invention.

## 2. Define consistency: Reitblatt et al. [S1]

Read [Abstractions for Network Update](https://doi.org/10.1145/2342356.2342427), the per-packet/per-flow definitions and property-preservation conditions. An existing PDF is in the [earlier reading pack](Reading_Material/README.md), whose original manifest remains unchanged.

Answer: What must hold in both endpoint configurations? Is our candidate invariant weaker than full per-packet consistency? What does a consistent-update implementation need to do, and what resource assumptions follow?

**Produce:** one plain-language security invariant and one allowed-traffic/completion requirement. Keep strict access revocation outside this proposed common property.

## 3. Understand the detector and its missing action policy: Spotlight [S3, A1]

Read [Spotlight](https://web.mit.edu/ha22286/www/papers/CCS24.pdf), §§5.5, 6–7. [Offline paper text](../Network_Domain_Scan/2026-10-24/Primary_Extracts/exploiting-temporal-vulnerabilities-for-unauthorized-access-in-intent-based-networking.md); [pinned source reading copies](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Artifact_Excerpts/README.md).

Answer: What can the fast heuristic miss? Which costs are outside first-detection time? What happens after an alert or a negative result? Which combined system is proposed rather than evaluated?

**Produce:** a two-branch detector-to-action policy. Label its assurance honestly. Explain why a negative result does not certify safety and how any additional checker/fallback would affect cost. Read source text only; no execution is authorized.

## 4. Separate practical primitives from network-wide guarantees [D1–D2]

Read OpenFlow 1.4 §6.8, especially §6.8.4, and the OVS v3.5.0 manual's `--bundle` provision. Links are in the review.

Answer: What differs between controller atomicity, packet atomicity, ordering on one switch, and preservation across the network? Does a local bundle acknowledgement establish the final invariant?

**Produce:** a boundary table stating what each primitive guarantees and what still requires coordination/verification. The documentation is evidence, not permission to issue switch commands.

## 5. Check context and counterarguments [S4–S9]

- **SecDev 2025 [S4], §§III–VI:** [offline text](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Primary_Extracts/intent-flow-secdev2025.md). Distinguish intent status from flow state and compare attacker assumptions with the proposed trusted-controller study. Its mitigation suggestions are not comparative defense results.
- **Cicero [S5]:** check whether its coordination/trust assumptions make it a useful direct baseline or architectural context.
- **Intender [S6]:** understand bug discovery versus update enforcement; do not rank unrelated performance figures.
- **Timed/in-place updates [S7–S8]:** close-comparator leads with incomplete primary inspection. Resolve technical details before relying on or dismissing them.
- **Orion [S9], abstract/introduction:** one production SDN example, not evidence of industry-wide adoption of CCG or Spotlight.

**Produce:** the strongest counterargument to the proposed study. Identify which evidence could show the comparison is already answered or the detector has no acceptable advantage.

## 6. Choose a method before implementation

Read [Methodology_Options.md](Methodology_Options.md). Bring back:

1. Bounds and resource budgets for the author-preferred local model comparison; emulation is optional, not a required stage.
2. One invariant/update class and the assurance level needed.
3. The comparator and result that could actually change an operator's decision.
4. One reason the result could merely repeat prior work.

The former [Reading_Material](Reading_Material/README.md) pack and root reassignment diagrams are retained historical resources, not the new SDN lab design. No experiments, installations or manuscript drafting are approved. Student verification is still pending.
