# Cisco emulation comparison: execution complete

27 October 2026. **All declared comparison gates completed.** This is a separately frozen emulation study, not a modification or extension of the model's exhaustive coverage. The next deliverable is an evidence-bound manuscript integration for author review; nothing is submitted automatically.

## Integrity and sequence

- Original Step-1/2 source, runs and seals are unchanged. The first relay failure was archived with its original 70-file relative-path seal. The author approved the researched Julia-side vector correction; the corrected runtime then passed 79 checks.
- A separate local audit import failure was retained, sealed and reported. The author approved explicit absolute-source-directory insertion while keeping Python `-I`. The corrected independent timing audit passed **211 checks** on the six strict timing cases.
- The prospective comparison was frozen **before full ordinary/Q/V warm-up or comparison outcomes**. Source manifest SHA-256: `906476a7eae8e12d97737c3715f5d7b38f39a7ce284f37d937f05d6b1456ee1b`. `Protocol.md`, `Parameters.json` and all executed controller/adapter/environment sources are bound.
- The one validation-envelope job and its five validation-only episodes passed: 100.206363 s, checkpoint peak 844,500,992 B. Its separate independent audit passed **648 checks**. These and all warm-ups are excluded from primary results.
- All six primary cells completed their single allowed attempt. The independent raw-fixture/kernel/OVS/frame/timing audit passed **3,707 checks** across **30 primary episodes and 45 primary packets**.
- Expected duplicate refusal `cos738-ovs-comparison-duplicate-refusal-1793082333941919861` returned exit 2 before namespace/network launch; the original consumed-attempt file was byte-identical before/after. This is a declared negative control, not another primary attempt.

## What was actually executed

The original Cisco logical topology has 10 forwarding nodes, 12 hosts and 28 edges. A transparent bidirectional userspace cable replaces only C10–C4 with two veth segments via one helper: 29 actual veth edges, 22 original logical nodes plus the helper. Actual kernel peers and original switch port numbers were checked. Mininet 2.3.1b4 is called through PythonCall by the resident Julia 1.13.1 controller; OVS 3.2.1 uses real `netdev` forwarding. No dummy datapath, host network, kernel-module change or routing oracle was substituted.

The wire forwards every frame to its opposite interface after a 250 ms minimum FIFO residence. IDs/desired destinations affect logging only. The harness observes receipt to construct a real old H5-admitted frame resident at the update request; controller execution does not inspect those observations. Nominal episodes have only a new request; inflight episodes have one old and one new request.

Ordinary applies the model's C2-then-C5 order, admitting the new request immediately after C2 activation/readback. Q waits a fixed one second after close/readback, then replaces and opens. V stages, commits and admits, waits a fixed one second after commit/readback, then cleans old rows. These clock parameters are experimental assumptions with slack over the wire delay, not H=4-to-time conversions or universal packet-lifetime bounds.

Each job primes cold I/O paths and runs all six method/scenario warm-ups before readiness, then performs five measured updates in the same Julia/embedded-Python process. Raw PIDs and all warm-up records are retained. Application receipt timestamps share a monotonic clock; the common deadline is update request+2.5 s, followed by a fixed 20 ms tail drain. Late/duplicate/unobserved results remain distinct. This is not kernel timestamping or an exclusive-host experiment.

## Main observations

All **30/30 new requests** reached H10 correctly. Q and V each delivered their **5/5 old inflight packets** to H9. Ordinary's **5/5 old inflight packets** reached H10 instead, all untagged: these are observed wrong destinations, not just version-label disagreements. There were no primary unobserved, late or duplicate packets within the declared application-observation procedure. Ordinary nominal has no old packet, so it is not a test of old-packet preservation.

The table in `Results.md` and machine-readable `Results.json`/`Results.csv` contain cell medians. In inflight episodes:

| Metric | Ordinary | Q | V |
|---|---:|---:|---:|
| New admission wait, ms | 9.247 | 1042.612 | 46.881 |
| New service age from original arrival, ms | 262.038 | 1294.880 | 298.798 |
| Controller completion/readback return, ms | 18.150 | 1042.753 | 1087.716 |
| Nonwait combined wall time, ms | 18.150 | 41.714 | 86.670 |
| Switch-local bundle submissions | 2 | 4 | 9 |
| Extra logical forwarding rows per shared switch | 0 | 0 | 1 |

V admits new service sooner than Q here but uses extra forwarding rows and more control work; its cleanup/retirement completion is not earlier. Ordinary's short completion does not qualify it when an admitted old packet is present. These observations support the intended admission/capacity distinction on this workload, not a general mechanism ranking.

Actual C2 peaks are six flows for ordinary/Q and seven for V, including three source-gate flows and two helpers. Other switches and exact flow sets remain in captures. Logical-row allowances are not total OVS flows, enforced hardware TCAM capacity or measured switch-memory use. Bundle counts are not OpenFlow wire-message counts; every install also performs a separate CLI readback.

## Resources and cost boundaries

Primary jobs took **98.949–107.323 s** each. Launch-to-ready including topology, compilation, priming, all six warm-ups and reset took **82.627–90.784 s**. Primary checkpoint peaks were **624,353,280–716,365,824 B**. All had two CPUs, hard 2 GiB memory, zero swap and successful node/interface/OVS cleanup, below the unchanged 120 s whole-job ceiling. Effective limits and raw process timings are in each receipt.

Recurring completion includes the intentional Q/V wait. Nonwait wall time subtracts measured deliberate waits but still includes controller bookkeeping, PythonCall, process/IPC, OVS and readback. It is not isolated Julia compute. No Python temporal-controller baseline, language-only speedup, production endurance, restart/failover or unseen-specialization performance was measured.

## Limits and evidence use

Only six cells on one fixed logical topology and a tiny constructed workload were run, with five updates per cell. Shared host scheduling, experimental userspace OVS, beta-labelled Mininet, artificial delay and finite application observation restrict generalization. The measurements do not establish congestion performance, arbitrary faults/traffic, real-time SLAs or hardware behavior. Mininet's original paper explicitly discusses shared-scheduler and performance-fidelity limits; version-matched OVS documentation calls userspace mode without DPDK experimental.

The model study's 12 cells/92 rows, 576 sensitivity records and component benchmarks remain distinct from these six cells/30 episodes. No emulated fat tree or seven-procedure network comparison was run. Hashes/assertion totals support reproducibility and engineering validation, not independent human review or statistical replications.

All failed and preliminary attempts remain in the evidence tree. No post-freeze code correction, parameter tuning, selective primary retry or promoted warm-up occurred. Preserve the frozen v1 sources and consumed attempt ledger when reviewing or extending this work.
