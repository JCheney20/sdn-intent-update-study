# Cisco emulation comparison: prospective design draft

**Historical planning document.** The later [source-bound protocol](Comparison/Protocol.md) was frozen and executed; see the [completion report](Comparison/Completion_Report.md). The draft statements below describe the earlier planning checkpoint, not current execution status.

26 October 2026. **DRAFT — NOT FROZEN; NO PRIMARY EPISODES RUN.** Step 2's [adapter validation](Step2/Validation_Report.md) has passed. This document records the remaining design gates; it is not permission to substitute validation packets for scientific outcomes.

## Question and retained scope

On the original Cisco fixture, how do ordinary, Q and V differ in observed destination correctness/loss, new-request admission waiting, update completion and implementation work under a declared finite workload? Preserve the frozen model's rules, physical-source semantics and procedure dependency order. Emulation tests implementation realism; it does not replace the exhaustive model argument or extend it to arbitrary traffic.

Use the pinned Julia/PythonCall/Mininet/userspace-OVS route and the validated Step-2 source manifest. Keep two CPUs, hard 2 GiB RAM, zero swap, 120 seconds per whole job and one local job at a time. No aggregate runtime ceiling is imposed. No new privileges, host-network changes, native package source builds or backend change are implied.

## A. Additional validation required before scientific freeze

1. **A real controlled in-flight mechanism.** Demonstrate that a test frame emitted/admitted at H5 genuinely remains in the emulated network across update initiation. A synthetic internal injection is not a substitute. Choose and validate a bounded delay/holding mechanism on the relevant link, with actual arrival/release observations. Do not assume Mininet `TCLink`/netem delay applies to userspace OVS's packet-I/O path. Any alternative packet relay must be explicit, preserve physical ingress and raw bytes, and avoid replacing OVS forwarding with a routing oracle.
2. **Harness/controller separation.** The workload harness may construct a declared in-flight initial condition. It must not let Q/V inspect probe positions, receipts or desired destinations to choose admission, updates or drainage. Controllers see only their declared phase/clock/control-plane inputs. Monitors are read only for analysis.
3. **Wall-clock waiting policy.** Declare a fixed Q drainage wait and V old-version retirement wait, their assumptions, the timing origin and timeout handling. Validate the mechanism under the intended tiny workload. A chosen observation-supported wait is not a universal real-time bound. H=4 logical rounds must never be converted into milliseconds, and bundle acknowledgement/barrier is not a drainage certificate.
4. **Resident warm-up/readiness.** Warm every relevant ordinary/Q/V phase, flow compiler/CLI call, slot branch, packet parser and instrumentation path before readiness, on sacrificial state. Restore/read back the exact old fixture, empty source slots and remove warm-up packet observations. Keep the same Julia/embedded-Python process through the measured updates; record PIDs and cold startup/warm-up/reset separately. New-specialization/failure/restart costs remain visible.
5. **Measurement boundaries and envelope.** Demonstrate the complete warmed batch, capture handling and cleanup within the existing whole-job ceiling. Receiver observations need explicit per-worker cutoffs/late-packet treatment; a settling sleep followed by sequential drains is not an exact common deadline. If the batch cannot fit, reduce the batch size prospectively—not the ceiling and not after primary outcomes.

These are setup/adapter/timing validation jobs and must be labelled accordingly. Preserve all failures and source snapshots. None becomes a primary repetition. Any adapter edit requires relevant revalidation and a new source-bound acceptance record; do not rewrite the accepted Step-2 seal.

## B. Candidate finite workload (proposal, not a frozen grid)

A small first comparison would use **three procedures × two scenarios × five repetitions = 30 episodes**:

- **Nominal:** one declared update and one new-source request, without deliberately retained old traffic.
- **Controlled in flight:** one identified old request admitted before update initiation, plus one new request that arrives at the declared update-request time and remains in the source-side slot until admission.
- Ordinary/Q use zero extra logical forwarding rows; V uses one. V with zero allowance is a separately reported preflight refusal, not a delivered-service sample or silently omitted failure.
- No continuing background load, congestion population, arbitrary fault distribution, extra requests or expanded topology study is inferred. One pending new request is the supported domain; overflow remains OUTSIDE_DOMAIN.

Subject to the timing/envelope gate, each procedure/scenario batch would keep one warmed process across its five updates, restoring the same starting state between episodes. Freeze batch order, episode IDs, exact action/dependency order, link-delay parameters and scheduling timestamps before execution. Do not tune ordinary's schedule or delay to obtain a desired violation. It need not fail in every schedule, and unexpected Q/V observations must be retained.

The proposal may change during setup validation for a documented reason, before primary outcomes. The final machine-readable manifest—not this draft—must identify the accepted grid, order and source hashes.

## C. Measurements to define in the freeze

- Update request, original new-request arrival, actual source emission/admission and per-host receipt times on the same monotonic clock.
- New service age measured from the original request, not from gate opening. Pending requests are not packets lost by a closed gate.
- Packet identity, expected destination, all actual destinations/duplicates, actual VLAN/raw bytes and late/unobserved status. Report absence only within the declared finite window; distinguish lost/late/invalid/outside-domain.
- Update/readiness/completion/retirement timestamps, with explicit definitions. Report return from CLI, bundle acknowledgement and packet-visible observations separately; none implies network-wide atomicity.
- Logical forwarding-row peak, gate/tag/helper flow counts, actual submitted switch-local transactions/CLI operations and available readback. Do not label CLI count as OpenFlow wire-message count or logical rows as physical TCAM usage.
- Cold startup, full warm-up/reset, recurring controller/CLI work, intentional waits and packet service latency separately. This is a combined implementation measurement, not pure Julia-versus-Python speed or a Python temporal-controller comparison.
- Effective resources, whole-job elapsed/peak memory, cleanup and every timeout/failure. Validation job totals are not comparative method timings.

## D. Primary attempt and integrity policy

Before any primary episode, seal the environment, fixture/adapter/controller/harness sources, timing assumptions, grid/order, finite repetition count, counters and output schema. Provide a machine-readable consumed-attempt ledger that refuses another primary invocation of an attempted cell before launching a network.

Use one attempt per declared batch/cell with no selective retries. Retain partial output, infrastructure/timeout failures, model/implementation disagreements and unattempted cells. A post-freeze fix requires an explicitly separate amended study, not overwriting or relabelling an unfavorable attempt. The historical model's consumed attempts and seals are independent and remain unchanged.

## Exit condition

Only after A passes and B–D are concretely frozen should the ordinary/Q/V primary comparison execute. Then independently audit captures and measurements before manuscript integration. Until that point, the supported statement is **Cisco adapter validation passed; timed procedure comparison and drainage policy remain untested**.
