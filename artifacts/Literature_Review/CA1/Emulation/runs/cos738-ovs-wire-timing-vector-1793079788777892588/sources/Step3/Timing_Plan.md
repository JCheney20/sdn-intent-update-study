# Userspace wire timing-validation gate

Prospective setup validation only. The author approved a transparent userspace relay after read-only preflight found netem/ingress/IFB to be unloaded kernel modules. No kernel-module loading is permitted. Stop on an execution error or failed gate; preserve the attempt and seek review before correction/continuation.

## Wire realization

Start and verify the unmodified Step-2 Cisco adapter, with no test traffic. Before configuring forwarding, replace only the direct C10–C4 Mininet veth link with two Mininet veth links via one helper host `wire` in the private parent network namespace. Keep the original switch interface names and numeric ofports. The helper is a transparent virtual-cable realization, not another Cisco forwarding element. Record both the original graph and expanded kernel realization: 22 Cisco nodes/28 logical edges, plus one helper and 29 veth edges. Verify every expanded edge, namespace and switch ofport after replacement.

A Python standard-library AF_PACKET helper forwards every received Ethernet frame to its opposite interface with an immutable **250 ms minimum residence delay**, in both directions and FIFO order. It never chooses an output based on packet identity, addresses, desired destination, controller method or monitor epoch. Identified packets are logged only for observation, after scheduling. VLAN RX offload metadata is explicitly reconstructed before retransmission; raw and canonical bytes are retained. Finite queue/event ceilings fail explicitly, not silently drop.

## Declared checks

1. Pure helper self-check: delayed eligibility, ordering, bytes/direction preservation and invalid-delay rejection. No network for this check.
2. Three unique old H5-admitted frames must pass C2/C10, enter the helper, remain present at a recorded update-request marker, and reach H9 untagged after their scheduled release.
3. Stage/commit the original new tagged path without modifying the adapter. Three unique H6 frames must reach H10 with VLAN 101 and the same IP/payload/MAC bytes. A pending request buffered across commit retains identity/arrival and emits once.
4. Each identified helper release must occur no earlier than receive+250 ms and within receive+1 s. For old-source in-flight construction, the workload marker must lie between receive and release; post-commit new-source cases check residence/bytes but are not initial-condition markers. The harness may observe the helper to construct this initial condition; no Q/V controller is running or receives these observations in this gate.
5. Receivers have a common application-observation deadline at source-emission+1.5 s; records are classified by monotonic application receive time, with actual collection intervals and late records retained. This is not a kernel/hardware timestamp or a universal lifetime bound.
6. All identified frames must have exactly one expected host receipt, no wrong host/duplicate, correct VLAN, and valid IPv4 bytes. Retain exact raw/canonical relay byte evidence.
7. Original cgroup/isolation constraints and normal cleanup, including helper node/process/interfaces. The unmodified Step-2 source manifest and earlier seals remain valid.

No primary grid or fixed Q/V drainage policy is frozen by this setup test. Passing supports the mechanism only under this tiny load; failure is a stop/review condition, not permission to adjust delay/thresholds and silently retry. No H=4-round-to-millisecond conversion is made.
