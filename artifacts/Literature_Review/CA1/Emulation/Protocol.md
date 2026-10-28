# Isolated OVS extension: prospective protocol and gates

26 October 2026. The author approved the focused emulation extension and provisioning necessary tools through a Nix flake. This extension is separate from the frozen Julia study and does not reset its attempts or alter its evidence.

## Authority and hard limits

- Start with the original Cisco fixture and **ordinary, Q and V**, not all seven procedures or a new topology population.
- Keep two-CPU quota/affinity, hard 2 GiB memory, zero swap, 120 seconds per whole job, one local job at a time, and no aggregate runtime ceiling.
- Project-local Nix flake and signed official-cache binary downloads are permitted. No package source compilation, global profile/system-service changes, remote execution or host-network configuration is inferred.
- Network setup must occur in a fresh unprivileged user + network namespace. The process may appear root **inside its namespace**, but must not use sudo or acquire host-root privileges. If that route fails, pause for a separate privilege/isolation decision.
- Never touch host interfaces/routes/firewall, start a global OVS service, load a kernel module or use external connectivity. Use private database/control sockets and private virtual links only. Scope termination kills all child daemons; namespace teardown removes links.

## A. Feasibility, not primary observations

1. Freeze the environment pin and retain package versions/store paths, signed-cache-copy receipts and effective resource limits.
2. Verify an empty isolated network namespace and existing TUN/TAP support, without host changes.
3. Start a private OVSDB and OVS userspace `netdev` datapath in that namespace; do not silently substitute `dummy` simulation for real virtual-link forwarding.
4. Pass actual tagged/test-identified Ethernet frames across private veth/TAP links. Check flow installation/readback, output-port observations, OpenFlow 1.4 bundle acceptance, and tag/gate primitives before claiming the model can be implemented.
5. Test cleanup and refusal outside the bounded scope. Retain failures and do not mistake CLI success alone for packet-visible behavior.

These are environment/adapter controls. No Cisco ordinary/Q/V scientific outcome is yet claimed. The upstream userspace-without-DPDK datapath is documented as experimental; record that limitation and the exact OVS version. It does not validate kernel OVS, hardware switches or physical TCAM performance.

## B. Model-to-implementation mapping before experiment freeze

- Import the frozen physical Cisco graph (10 forwarders, 12 hosts), old/new paths and exact ingress-sensitive rule intent. Preserve node/port mapping explicitly; do not replace it with the paper's reported eight-switch topology.
- Specify table/pipeline encodings for logical forwarding rows separately from ingress gate/tag flows. Real OVS flow counts and abstract extra forwarding-row allowance are not interchangeable.
- Keep a stable packet identity, requested arrival, actual admission, delivery identity/destination and packet trace. The pre-admission new-request slot is a real harness/source queue, not packets dropped by a closed gate. Gate decisions must depend on physical source/phase, not desired delivery or monitor epoch.
- Specify old/new version representation and tag assignment, and verify that staged rules cannot forward the wrong version. Count gate/tag/control operations separately.
- Use one atomic switch-local transaction only where OVS capabilities and the validated adapter support it. An OpenFlow barrier is not a packet-drain certificate or a globally atomic commit.
- Preserve the Q/V phase order and scope. No free network-wide switch, omitted cleanup or outcome-selected fallback.
- Choose a justified real-time drainage/service observation policy before measuring. The model's H=4 logical rounds is **not** four milliseconds or an empirical lifetime bound. Controlled link delay/packet holding used to expose an interleaving must be explicit and observable, not a hidden harness oracle.

## C. Scientific freeze and execution gate

After A/B validation, freeze a machine-readable source/fixture/adapter/grid/repetition/attempt/measurement manifest **before Cisco outcomes**. It must specify targeted in-flight-packet cases, old/new request identities, offered workload, delays, timeouts, actual bundle boundaries, capacities/counting, captures, loss/wrong-delivery criteria, readiness and completion observations. Use a finite prospective repetition count with no selective retries; retain failed/partial/unattempted cells.

Run ordinary as a diagnostic negative comparison and Q/V as the declared controls. Do not require ordinary to fail in every uncontrolled schedule, or tune delays/repetitions after seeing a favorable contrast. Unexpected implementation/model disagreement is a finding and stop/review condition, not permission to change the frozen model.

Report packet outcomes, admission waiting, update completion, rule/gate/tag work and wall-clock costs separately. Do not relabel a short no-loss sample as universal safety. The existing model proof and new emulation evidence remain distinct.

## Persistent Julia and the benchmark interpretation

The author intends a controller that warms relevant paths **before readiness** and remains running between updates. Under that architectural assumption, the existing persistent-process warmed snapshot calls are more representative of recurring component cost than launching Julia for every update. Retain startup/readiness/restart/failover costs, possible new-path/type compilation, cache construction and the absence of whole-controller steady-state measurements. Do not turn this plausible deployment argument into a measured deployed-controller or pure-language speedup claim.

The initial OVS adapter feasibility can be driven by standard-library tooling; that does not make it a Python temporal-controller comparator or validate a resident Julia integration. If persistent Julia is included in the scientific extension, freeze its startup warm-up, readiness signal, code paths, process lifetime and measurement boundaries explicitly. Both language comparisons must receive equivalent warm-up treatment.

## Julia/Mininet Step-1 decision

The author subsequently approved testing Julia → PythonCall → Mininet first, with Julia-direct Linux/OVS orchestration as fallback if unsuitable. [Step 1 passed](Interop/Feasibility_Report.md): pinned PythonCall/Mininet, real isolated hosts and OVS packets, readiness in a resident process, gate/tag controls and normal/injected-error cleanup. Use this route for the Cisco adapter-validation stage; no fallback implementation or speed comparison is needed merely to pick an orchestrator. Mininet is accessed through its actual Python API; Julia controls the experiment lifecycle. Record the protected sysctl tuning warning and userspace-backend limitations.

After Step 1, the author explicitly requested Step 2. [Cisco adapter validation has now passed](Step2/Validation_Report.md): full physical graph and actual kernel peers/ofports, ingress-sensitive rows, a real source-side pending slot, version assignment/staging, local commit, logical-capacity refusal and normal cleanup. These controls do not execute a timed ordinary/Q/V comparison. The subsequent timing-mechanism validation and scientific freeze remain separate gates.

## Current status

27 October 2026: all scientific gates are complete. After Step 2, the approved userspace relay and corrected independent timing audit passed; a source-bound [comparison protocol](Comparison/Protocol.md) was frozen before full procedure outcomes. Its separate validation-envelope job and all six single-attempt primary cells passed execution and independent verification: 30 episodes, 45 packets, 3,707 audit checks. The [completion report](Comparison/Completion_Report.md) distinguishes setup/warm-up/primary data, fixed waits, wrong-delivery observations and limits. The [earlier draft](Experiment_Protocol_Draft.md) is retained as history. The verified results are integrated separately into the manuscript and await author review, not submission. No hardware/real-time guarantee or compiled ten-page conformance is claimed.
