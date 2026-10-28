# SDN update safety: background and focused literature review

**Active CA1 review — 24 October 2026.** The author selected SDN update safety in place of tenant reassignment. This review synthesizes the completed SDN investigation and adds narrowly checked standards, implementation and production context. It is supporting research, not a manuscript, experimental result or exhaustive survey.

## 1. Domain: intent, control and distributed forwarding

Software-defined networking separates forwarding behavior from the software that computes and manages it. A logically centralized controller still operates distributed switches. Intent-based networking adds an abstraction: an operator specifies a desired outcome and the controller compiles it into lower-level rules. Google's Orion is a concrete production SDN example: its 2021 paper describes deployment in Jupiter/B4 and an intent-based, distributed control platform [S9, abstract/introduction]. This is one historical production report, not evidence that all operators use its architecture or the prototypes below.

A network update is consequently a transition, not an instantaneous replacement of a whole network. Switches can receive/apply updates at different times while packets continue to traverse them. A packet can encounter a mixture of configurations. Correct steady-state policies therefore do not alone establish correctness during deployment [S1; S2].

The relevant research connects four areas: consistent network updates, invariant verification and scheduling, intent-security analysis, and operational observability. The active problem is preserving a declared security property during a transition at an acceptable operational cost. It is not the former Linux connection-state/tenant-reassignment question.

## 2. Problem and candidate contribution

**Working question:** Under a specified security invariant and intent-update workload, how do conventional consistent updates, verification-guided scheduling and Spotlight-guided checking trade transient unauthorized reachability, update completion and total operational cost?

A candidate common invariant is that an unauthorized source must remain unable to reach a protected destination while permitted connectivity is rerouted. Both old and new configurations should satisfy the invariant. Legitimate-flow service and successful update completion must also be measured or analyzed: stopping all forwarding is not a useful update strategy.

The unresolved study-design question is whether a detector-guided procedure yields additional, decision-relevant evidence beyond established scheduling/enforcement approaches. **The literature does not establish novelty for this comparison.** CCG already combines verification with heavier fallback and evaluates costs [S2]. A defensible increment must be more precise than “selectively apply consistency” or “compare security and performance.”

## 3. How practical systems and research address the problem

### 3.1 Practical primitives: ordering and local transactions

OpenFlow 1.4 defines bundles that group switch modifications. Its specification distinguishes **controller atomicity** from optional **packet atomicity**: `OFPBF_ATOMIC` requests the latter, and support depends on the switch [D1, §6.8.4]. It also defines ordered application through `OFPBF_ORDERED`. A bundle is scoped to a controller connection and switch. Bundles support coordination but do not, by themselves, establish one atomic packet-processing transition across every switch.

The Open vSwitch **v3.5.0** manual documents `ovs-ofctl --bundle` as an OpenFlow 1.4 atomic transaction for a switch's flow tables, including all-or-nothing failure and before/after behavior for packets on that switch [D2, `--bundle`]. This is a concrete available implementation mechanism, not merely a proposed paper technique. It does not imply simultaneous commitment at multiple switches or assurance that the controller chose a secure overall sequence.

These distinctions prevent a weak problem statement: the domain is not missing transaction mechanisms. The question is how local mechanisms, distributed scheduling and the desired invariant fit together.

### 3.2 Conventional consistency: prevent harmful mixtures

Reitblatt et al. formalize per-packet consistency: each packet experiences an old or new configuration rather than an arbitrary mixture [S1]. Their property-preservation result applies to appropriate properties satisfied by both endpoint configurations. Per-flow consistency is a different requirement and need not be required for every security invariant.

This supplies a strong reference abstraction, with resource/update-protocol costs that must be counted. It is not automatically the least expensive way to preserve a particular weaker invariant. Nor is it a proof of immediate revocation when old policy permits something new policy forbids; that is outside the initially proposed common invariant.

Timed updates [S7] and more recent in-place updates [S8] provide alternative approaches, but their different timing/resource assumptions matter. The focused investigation verified their identities, not all primary technical details. No detailed ranking of their performance or suitability follows from abstracts.

### 3.3 CCG: selective checking plus heavier fallback already exists

Zhou et al.'s **Customizable Consistency Generator** turns update scheduling into a sequence of verification decisions [S2, §§3–5]. It releases an update if the modeled invariant remains satisfied, buffers it otherwise, and can invoke a heavier fallback when needed. Its uncertainty model accounts for distributed rule application and packets already in flight. An acknowledgement is not treated as a magical erasure of all packet history.

For suitable segment-independent properties, the greedy scheduling approach finds an appropriate ordering under its model. For more general cases, the guarantee depends on a suitable fallback; its best-effort discussion without one is not equivalent to guaranteed preservation. The implementation includes CU and SWAN fallback examples [S2, §5.3].

CCG also evaluates the architecture: microbenchmarks, emulated update completion and rule-space comparisons, enterprise-snapshot transitions, and physical-testbed observations [S2, §7]. It therefore already answers the general proposition that verification-guided/hybrid operation can reduce unnecessary update overhead under evaluated conditions.

**Implication:** CCG is an essential nearest baseline, not a footnote. A new comparison must explain what additional property/workload result it contributes. Its historical hardware choices, heuristic scheduling optimality and partial Dionysus reimplementation limit transfer of numerical results; they do not erase its prior contribution.

### 3.4 Spotlight: predicting temporal security risk is not enforcing safety

Weintraub et al. demonstrate transient unauthorized connectivity in a specific ONOS setup and present Spotlight [S3]. Their fast method searches selectively and explicitly does not guarantee finding every temporal vulnerability [S3, §5.5]. The headline first-detection time excludes preprocessing [S3, §6.2].

Section 7 proposes checking updates and reserving consistent enforcement for selected cases, and asks about the relative costs and frequency of risky updates. That is an explicitly posed question, not evidence that it is still unanswered. A first credible empirical answer could contribute, but it must account for CCG and subsequent work rather than treating hybrid operation as new.

The artifact's inspected `detection()`/`detection_search()` functions separately time preprocessing and search, supporting the measurement-boundary interpretation [A1]. They do not establish an integrated controller release/enforcement policy. Thus a “Spotlight strategy” in a study requires specifying what happens after both an alert and a negative result.

A negative heuristic result cannot certify an update safe. If it releases an ordinary update, the strategy has weaker assurance than a sound enforcing scheduler. If a sound checker or complete fallback protects negative results, its additional costs belong in the comparison. This is the central methodological issue—not a detail to hide behind average detection speed.

### 3.5 Related intent assurance: meaningful, but a different question

Intender uses intent-state-guided fuzzing to find problematic behavior [S6]. Cicero combines secure transactional updates under its own distributed/security assumptions [S5]. Neither should be described as the same mechanism as a temporal detector, nor should published latency figures be ranked across unrelated workloads.

Yan et al.'s SecDev 2025 paper demonstrates discrepancies between intent status and underlying flow state, then proposes monitoring, stronger intent/flow coupling and failure-state handling [S4, §§III–VI]. The demonstrations concern emulated ONOS cases, and some attacks require application/API authority. The paper does not comparatively evaluate the proposed defenses or answer Spotlight's detector/enforcement cost question. Its description of a Docker image as “latest” does not pin current ONOS behavior.

Together, these studies reinforce the need to distinguish a requested intent, an installed rule, a reported status and actual packet behavior. They do not justify silently expanding this study to malicious-controller or application-compromise defenses.

## 4. Comparative synthesis

| Approach | Primary role | Assurance/cost issue for our comparison |
| --- | --- | --- |
| OpenFlow/OVS bundles [D1–D2] | Group switch-local changes | Useful primitive; scope, flags and switch support do not establish network-wide preservation. |
| Conventional consistent updates [S1] | Prevent old/new processing mixtures | Stronger abstractions may impose unnecessary work for a particular invariant; count resources and completion conditions. |
| CCG [S2] | Verify and schedule with suitable fallback | Established hybrid design/evaluation; model and fallback assumptions matter. |
| Spotlight [S3, A1] | Detect a class of temporal risks | Fast method is incomplete; preprocessing and detector-to-action policy must be included. |
| Cicero [S5] | Secure transactional updates | Different trust/coordination assumptions; justify its role rather than treating it as interchangeable. |
| Intender / intent-flow analysis [S4, S6] | Discover or expose intent-assurance failures | Adjacent evidence, not a common enforcement benchmark or proof of current controller behavior. |

“Industry has tried to address it” therefore has three evidence levels: **standardized primitives**, **documented implementations and reported production systems**, and **research mechanisms**. Orion is production evidence; OVS is implementation evidence; CCG and Spotlight are research artifacts. This review does not claim CCG/Spotlight are widely deployed or that the industry lacks existing safety controls.

## 5. Desired answer and methodology implications

The desired output is a bounded **decision rule**: under which invariant/workload/resource conditions is a strategy justified, and where does selective checking cease to offer acceptable assurance or useful savings?

A suitable result might show a selective procedure reduces cost within an explicitly stated assurance contract. An equally legitimate outcome is that verification-guided scheduling is preferable, or that detector incompleteness makes selective release unsuitable. No finding, novelty or universal optimum is promised.

[Methodology_Options.md](Methodology_Options.md) develops three alternatives: bounded model-based comparison, controlled emulation, and structured architecture/evidence analysis. The author endorses a local bounded model comparison as the preferred method, with an algorithm-suitability map as the objective. Emulation is optional future validation, not required completion. The methods must match properties and action granularity, include positive controls, distinguish timing boundaries and count total cost. Simulation and emulation establish different claims.

## 6. Evidence status and limitations

This narrative synthesis reuses the [ten-record focused SDN investigation](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/SDN_Review.md). New checks for this update cover Orion's official publication/front matter and abstract/introduction, OpenFlow 1.4 §6.8, and the OVS v3.5.0 manual's bundle provisions. Orion's detailed performance evaluation was not independently reviewed; no production performance figure is imported.

The underlying search is bounded and recent-work/forward-citation coverage incomplete. The in-place-update primary paper remains inaccessible through attempted sources. That is uncertainty, not a research gap. Per-paper reading levels, earlier citation corrections and artifact pins are preserved in the [focused index](../Network_Domain_Scan/2026-10-24/SDN_DNS_Deep_Dive/Paper_Index.json) and [evidence register](Evidence_Register.md). No new claim that all sources were fully read or independently reproduced is made.

No model, controller, switch, implementation or experiment is selected, installed or run. The author has selected the direction, not a completed argument. AI-assisted source work and supervisor checks are not student verification.

## 7. Source identities and priority passages

- **S1:** Reitblatt, Foster, Rexford, Schlesinger and Walker. 2012. *Abstractions for Network Update*. SIGCOMM, 323–334. [DOI](https://doi.org/10.1145/2342356.2342427). Definitions/property-preservation passages; primary reading reported in previous reviews.
- **S2:** Zhou, Jin, Croft, Caesar and Godfrey. 2015. *Enforcing Customizable Consistency Properties in Software-Defined Networks*. NSDI, 73–85. [Record](https://www.usenix.org/conference/nsdi15/technical-sessions/presentation/zhou); [PDF](https://www.usenix.org/system/files/conference/nsdi15/nsdi15-paper-zhou.pdf). Supervisor inspected design, model, fallback, implementation, evaluation and limits, §§1–9.
- **S3:** Weintraub et al. 2024. *Exploiting Temporal Vulnerabilities for Unauthorized Access in Intent-Based Networking*. CCS, 3630–3644. [DOI](https://doi.org/10.1145/3658644.3670301); [PDF](https://web.mit.edu/ha22286/www/papers/CCS24.pdf). Selected primary sections inspected; especially §§5.5, 6–7.
- **S4:** Yan, Kim, Ujcich and Tian. 2025. *Exploiting Intent-Flow State Vulnerabilities in Intent-Based Networking*. SecDev, 169–175. [DOI](https://doi.org/10.1109/SecDev66745.2025.00028); [PDF](https://kjw6855.github.io/assets/pdf/secdev25_yan.pdf). Supervisor inspected primary threat model, demonstrations, mitigations and discussion.
- **S5:** Lembke, Ravi, Roman and Eugster. 2020. *Consistent and Secure Network Updates Made Practical*. Middleware, 149–162. [DOI](https://doi.org/10.1145/3423211.3425694). Prior investigation reports primary protocol/evaluation reading; no fresh reproduction.
- **S6:** Kim, Ujcich and Tian. 2023. *Intender: Fuzzing Intent-Based Networking with Intent-State Transition Guidance*. USENIX Security, 4463–4480. [Official record](https://www.usenix.org/conference/usenixsecurity23/presentation/kim-jiwon). Prior primary inspection reported; no numerical ranking used here.
- **S7 — comparator lead:** Mizrahi, Saat and Moses. 2016. *Timed Consistent Network Updates in Software-Defined Networks*. IEEE/ACM ToN. [DOI](https://doi.org/10.1109/TNET.2016.2529058). Identity verified; primary methods not inspected in the focused follow-up.
- **S8 — comparator lead:** Namjoshi, Gheissi and Sabnani. 2024. *Algorithms for In-Place, Consistent Network Update*. SIGCOMM, 244–257. [DOI](https://doi.org/10.1145/3651890.3672266). Identity verified; primary technical details uninspected because attempted full-text retrieval failed.
- **S9 — production context:** Andrew D. Ferguson et al., Google. 2021. *Orion: Google's Software-Defined Networking Control Plane*. NSDI, 83–98. [Official record](https://www.usenix.org/conference/nsdi21/presentation/ferguson); [PDF](https://www.usenix.org/system/files/nsdi21-ferguson.pdf). Supervisor checked front matter and abstract/introduction, not detailed methods/results.
- **D1:** Open Networking Foundation. *OpenFlow Switch Specification*, version 1.4.0, 2013. [Primary PDF](https://opennetworking.org/wp-content/uploads/2014/10/openflow-spec-v1.4.0.pdf), §6.8, especially §6.8.4. Selected primary provisions inspected for this update.
- **D2:** Open vSwitch, **v3.5.0** `ovs-ofctl` manual. [Version-tagged source](https://raw.githubusercontent.com/openvswitch/ovs/v3.5.0/utilities/ovs-ofctl.8.in), Flow Table Commands / `--bundle`. Selected primary provisions inspected; not installed-version evidence.
- **A1:** *Spotlight: CCS Artifact*, inspected Zenodo record **12735280**, version DOI [10.5281/zenodo.12735280](https://doi.org/10.5281/zenodo.12735280). Selected detector functions and record documentation inspected; no execution or whole-code correctness audit.
