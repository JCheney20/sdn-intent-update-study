# Isolated OVS handover extension

27 October 2026. **The timing gate and separately frozen Cisco ordinary/Q/V comparison are complete: 30 primary episodes, 45 packets and 3,707 independent audit checks.** See the [comparison completion report](Comparison/Completion_Report.md), [results](Comparison/Results.md) and [source-bound protocol](Comparison/Protocol.md). Steps 1 and 2 established Julia → PythonCall → Mininet → private OVS and the full Cisco topology/ports/rules, source buffer and version controls. See the [Step-2 validation report](Step2/Validation_Report.md): 32 packet controls, an independent 800-check audit and a [773-file Step-2 artifact seal](Step2/Step2_Artifact_Manifest.sha256). The [Step-1 feasibility report](Interop/Feasibility_Report.md), 122-check verifier and [310-file Step-1 artifact seal](Interop/Step1_Artifact_Manifest.sha256) remain unchanged. The earlier single-bridge primitive below remains separate supporting evidence. [Prospective protocol](Protocol.md). This is a separate extension; the frozen model study is unchanged. Its results must not be pooled with the emulation's primary episodes.

## Realized environment

The project-local [flake](flake.nix) and [lock](flake.lock) pin Nixpkgs `dddccde11a6c6be45f58a76828a5f48d58262e9a`, reusing the already available source revision without changing the original reference environment.

| Component | Version |
|---|---|
| Open vSwitch | 3.2.1 |
| iproute2 | 6.6.0 |
| tcpdump | 4.99.4 |
| Python standard-library tooling | 3.11.7 |

Exact store paths are in [Components.json](Components.json); [Environment_Manifest.sha256](Environment_Manifest.sha256) binds the flake, lock and component metadata. [Closure.json](Closure.json) records 35 closure paths, all with official-cache signatures. The retained closure log includes a Nix JSON-format deprecation warning; only its separate JSON line was parsed, with the original warning retained. The [cache-copy job](runs/cos738-ovs-cache-copy-1793004628507307470/output.log) copied 14 previously absent paths from the official signed cache, using `require-sigs=true`, `max-jobs=0` and empty builders. No source build, package-pin change to the frozen reference, global profile update or system rebuild occurred. Project-local indirect GC roots retain the four tool closures. No Mininet or Python dependency framework was added: the primitive harness uses standard-library sockets and explicit private links.

The flake exposes package and development-shell descriptions, but an uncached combined `mkShell` wrapper was not built or entered. Cached component binaries are invoked directly. Do not treat `nix develop` as permission for a source build or an unbounded network experiment.

## Isolation and actual packet evidence

Unprivileged user/network namespaces work on this host. Root inside the child maps only to host UID 1000; the child initially contains just loopback and has a different network-namespace identity. Existing TUN/TAP support permits the `netdev` userspace datapath without loading an OVS kernel module.

The [passing smoke receipt](runs/cos738-ovs-netdev-smoke-1793005064569421260/receipt.json) records two-CPU quota/affinity, hard 2 GiB memory, zero swap, **1.741 s** command elapsed and **33,099,776 B** checkpoint peak. A private OVSDB and foreground ovs-vswitchd operated only on private virtual links/sockets, with one handler/revalidator configured. Actual Ethernet observations are retained in [packet_smoke.json](runs/cos738-ovs-netdev-smoke-1793005064569421260/packet_smoke.json):

- Before replacement: the test frame reaches receiver h2, not h3.
- After an OpenFlow 1.4 bundle replacement: the next frame reaches h3, not h2.
- Closed gate: the identified frame is not observed during the fixed 0.3-second observation window. This is a finite drop control, not a universal absence proof or the modeled source request queue.
- VLAN action: receiver h3 observes VLAN ID 101. The capture supports Linux packet AUXDATA, so stripped receive-offload metadata is not mistaken for an absent tag.

Frame hex, identities, timestamps, installed flows, port feature/readback and command outputs are retained. This is real userspace OVS forwarding over virtual links, **not `dummy` mode** and not just `ofproto/trace` output. It is a primitive control, not Cisco emulation, a concurrency stress test or proof of bundle atomicity for every schedule.

No sudo, host routes/interfaces/firewall, global service, kernel-module change or remote connection was used. Daemons were stopped; the bounded scope and network namespace ended. The earlier [failed smoke](runs/cos738-ovs-netdev-smoke-1793004993963998292/output.log) is retained: the initial launcher assumed `/sbin`, while the Nix package places both OVS daemons in `/bin`. It failed before starting a daemon; the shared path was corrected and the old source was retained. No scientific grid or result was selected by that packaging fix.

## Important backend distinction

OVS 3.2.1's own [userspace documentation](https://github.com/openvswitch/ovs/blob/v3.2.1/Documentation/intro/install/userspace.rst) describes `datapath_type=netdev`, requires TUN/TAP on Linux and warns that userspace without DPDK is experimental. This is the chosen **unprivileged feasibility backend**, not validated kernel OVS, DPDK, physical switching or TCAM behavior. A kernel-backend comparison would require a separate capability/isolation decision; no host module will be loaded automatically.

Upstream [testing documentation](https://github.com/openvswitch/ovs/blob/v3.2.1/Documentation/topics/testing.rst) explains that dummy mode substitutes Unix sockets for physical/virtual networks and is imperfect. It was not silently substituted here. The version-matched [ovs-ofctl manual](https://github.com/openvswitch/ovs/blob/v3.2.1/utilities/ovs-ofctl.8.in) documents bundle and packet operations; actual acceptance/readback/frames, not documentation alone, passed the primitive check. These sources were inspected on 26 October 2026.

## Reproduction and next gate

`scope.sh LABEL COMMAND...` is a bounded **feasibility/provisioning** launcher, not a scientific primary runner. It shares the existing revision lock, snapshots local code, retains command/resource/exit records and kills remaining scope members. `scope_entry.py` refuses an unbounded invocation before running the supplied command; the intentional negative check and nonzero exit are retained in `verification/outside-scope.*`. All network commands must additionally be isolated by fresh user/network namespaces.

The [Cisco adapter gate passed](Step2/Validation_Report.md), followed by the approved transparent-wire timing mechanism and its independent audit. The [comparison](Comparison/Completion_Report.md) then froze all sources/timers/grid before full procedure outcomes, passed the envelope job and ran each primary cell once. A duplicate attempt was refused before network launch. All jobs remained within the original resource envelope with normal cleanup. The verified results are now integrated separately into [the manuscript](../main.tex), which awaits author review. There is no submission, rendered-page-count pass or production-readiness claim.

The manuscript's persistent-Julia paragraph remains a conditional deployment interpretation. The initial primitive harness below used Python tooling; the subsequent [Step-1 integration](Interop/Feasibility_Report.md) now demonstrates a resident Julia process calling real Mininet through PythonCall, with readiness and actual packet/control operations in one embedded interpreter. It does **not** establish a complete Cisco controller, sustained production performance or a Python temporal-controller comparator. Startup/restart costs and unseen-path compilation remain explicit.
