# Prospective Cisco emulation comparison v1

This protocol becomes frozen only when `guard.py freeze` creates the source-bound manifest. No primary samples may precede it. The original frozen model study, Step-1/2 artifacts and archived first relay failure are separate and unchanged.

## Scientific question and finite grid

Compare ordinary, Q and V on the original Cisco rules and logical 22-node/28-edge graph, using the validated userspace wire realization of C10–C4 (one helper, 29 veth segments). The helper transparently forwards every frame to the opposite port after a fixed 250 ms minimum residence; it never selects a route or controller action by identity/destination. No congestion/background load, broad fault/topology population or hardware/TCAM claim is made.

`Parameters.json` fixes six cells, five repetitions per cell, cell order, timers and workloads: **30 primary episodes**. Each cell has one freshly started process/network and five warmed measured updates in that resident Julia/embedded-Python process. Five repetitions are not independent networks or a population-level safety estimate. Cell order is fixed, with procedure order reversed between scenarios; it is not a randomized causal experiment. There is no Python temporal-controller comparator.

One new request is offered at the update-request timestamp in every episode. Nominal has no old test traffic; inflight has one old H5 frame already admitted through C2/C10 and resident in the wire when the update is requested. The workload harness may inspect wire receipt to establish that initial condition; the controller does not see those observations. Stable IDs/bytes, original arrival, source admission and all-host receipts are retained. No source-slot overflow is silently treated as service.

## Actions and timers

Frozen `Handover.plan` supplies the ordinary/Q changed-switch commands and validates V phase membership. Ordinary serializes its one model phase in the returned frozen command order (C2 then C5): activate target ingress/new source at C2 and replace target egress at C5, each as one switch-local bundle. Release the source slot immediately after activation, not after all ordinary operations. This is one declared interleaving, not exhaustive scheduler coverage.

Q closes C2's old-source gate, waits **1 s from close/readback return**, replaces changed forwarding rows while both sources are closed, then opens H6 and admits the pending request. V stages tagged target rows using the unchanged validated adapter, commits gates/version locally at C2 and admits the pending request, waits **1 s from commit/readback return**, then removes old-version rows. No controller inspects delivery, wire occupancy or probe positions to decide these actions/waits.

These one-second waits are prospective experimental operating parameters with slack over the wire's configured 250 ms delay. They are neither derived from H=4 nor claimed hard lifetime bounds on a scheduled OS. Unmodelled scheduling delay beyond this assumed envelope remains possible and is an observed limitation/disagreement, not something the controller silently corrects by checking receipts. Switch-local bundle/readback is not global atomicity or a drain certificate.

Ordinary/Q have zero extra logical forwarding rows; V has one. Gate/helper flow overhead is counted separately from logical rows. Zero-allowance V refusal is a setup control, not an omitted service sample. No Q fallback substitutes for V.

## Warm-up and readiness

Before readiness, one sacrificial old frame primes packet/RPC/observation paths without making an update. Then run all six procedure/scenario combinations in the declared warm order, with full waits, source-slot admission, phase actions, instrumentation, capture classification and fixture restoration. Validate Q/V warm observations; retain ordinary warm violations without using them to tune the primary grid. Use distinct warm IDs, never primary samples.

Restore/read back the old fixture with no identified frame pending between episodes. Warm-up, reset and cold startup remain visible outside primary recurring-update measurements. Record launch-to-ready time and PIDs; do not guarantee that every conceivable unseen specialization was warmed. No optimized sysimage, restart/failover or production endurance is tested.

After freezing, perform exactly one validation-envelope job using Q/inflight, the same complete warm-up and five validation-only episodes. This assesses instrumentation/readiness and the whole-job envelope before primary execution. It does not change the frozen grid/timers or supply primary data. Any error or required correction stops for author review; no failed validation is silently tuned/retried under v1.

## Observations and qualification

Every episode's common application-observation deadline is **update request + 2.5 s**. Collection happens after this deadline, followed by a second drain after a fixed 20 ms tail interval; classify by each worker's monotonic application receive timestamp and retain late records and actual collection intervals. This is not a kernel/hardware arrival timestamp. Non-receipt is only unobserved by that deadline; report late/duplicate/wrong destination separately. No short sample is universal safety.

Expected destinations are H9 for old and H10 for new. Record old/new raw bytes, version, relay receive/release, new-request original arrival, actual emission and all-host receipts. Old and new request identity/authorization is not inferred from monitor labels. Inflight residency must be demonstrated at update request; synthetic internal injection is prohibited as a substitute.

Record operation/readback return, source emission, final-target/cleanup return and wait intervals separately. Controller completion means the last required action/readback returned; it is not a global packet-visible instant. Active/nonwait wall time subtracts the measured intentional wait intervals from request-to-completion; it still contains Julia bookkeeping, PythonCall, CLI process/IPC, OVS and readback, not isolated Julia compute. Report new service age from original arrival to receipt, not from gate opening. Show whole-job startup/warm-up/cleanup costs separately.

Controller code has no capture/occupancy API calls; monitoring and initial-state construction occur in the workload/analysis functions. The adapter object retains logs, so this is an audited code boundary, not a claim of a capability-security sandbox between controller and monitor.

## Attempts, integrity and stop policy

`guard.py begin` checks the frozen sources and consumes an exclusive attempt file **before namespace/network launch**. Validation and primary ledgers are separate. An attempted primary cell cannot be invoked again; expected duplicate refusal is tested after completion without starting another network. Retain errors, incomplete attempts, partial episode journals and unattempted cells. Never overwrite a failed/partial attempt or retrospectively promote validation/warm-up records.

A Q/V packet disagreement, unexpected pipeline/capture/cleanup failure, timeout or resource violation stops progression for review. Ordinary observed violations are scientific outcomes, not execution errors. A post-freeze correction requires a new explicitly amended study; v1's attempts/manifest remain preserved.

All jobs keep two CPUs, hard 2 GiB memory, zero swap, 120 s whole job, one local job at a time and no aggregate ceiling. No host networking, module loading, global service/system change, package source build or remote compute is authorized.

Only independently audited primary evidence may enter the single-file manuscript. Preserve model/emulation distinctions, report limitations and leave the final draft for author review, not submission. TeX compilation/page-count and outstanding author/student checks must not be claimed without evidence.
