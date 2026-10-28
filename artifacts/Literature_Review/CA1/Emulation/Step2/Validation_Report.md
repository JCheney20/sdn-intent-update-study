# Step 2: Cisco adapter validation

26 October 2026. **PASS on the declared adapter controls.** Julia/PythonCall/Mininet/OVS can represent the original Cisco topology, ingress-sensitive forwarding, one pending new request and old/new versions. This is not a timed ordinary/Q/V comparison, a safe-drainage result or a deployment guarantee.

## Scope and decision

Use this validated adapter as the basis for the prospective emulation protocol. The original frozen model study and Step-1 evidence remain unchanged. Do not use these controls as the emulation comparison's primary samples or as proof that an arbitrary handover is safe.

The source and checks are retained in [CiscoAdapter.jl](CiscoAdapter.jl), [validate.jl](validate.jl), [packet_worker.py](packet_worker.py), the prior [validation plan](Validation_Plan.md) and the separately implemented [read-only audit](audit.py). [Validated_Source_Manifest.sha256](Validated_Source_Manifest.sha256) binds the accepted implementation and pinned Step-1 environment.

## What passed

| Area | Executed controls and limits |
|---|---|
| Original physical topology | 10 switches, 12 isolated hosts and all 28 physical edges; both links of H2 and H7 retained |
| Actual wiring and ports | Linux veth peer relationships checked independently of Mininet labels; OVS ofports and Mininet mappings agree with the explicit adjacency-based map |
| Old/target behavior | Real H5→H9 and H6→H10 packet delivery; closed legitimate-source gates and other physical ingresses drop the identified test frames |
| Prefix/monitor boundary | Wrong source/destination prefixes drop; a payload claiming a different authorized destination does not change physical-source admission or routing |
| Source-side slot | One immutable identity/frame/original arrival waits before emission; overflow is OUTSIDE_DOMAIN, duplicates/wrong source are rejected, admission occurs once after opening |
| Queue fault controls | Pending loss, arrival reset and byte replacement are detected; failed emission is visible and cannot silently retry |
| Queue/version interaction | A request buffered through staging is released after commit, reaches H10 with VLAN 101 and retains its original identity/arrival |
| Version separation | Client-supplied tags are normalized; old and new rows coexist; only the configured version forwards at internal test positions |
| Local commit | Gates/tag assignment change at C2 only; the staged forwarding rows elsewhere do not change |
| Capacity and phase discipline | Zero-extra-row staging is refused before network work; staged peak is one extra logical forwarding row per shared path switch; premature/repeated phase operations are rejected |
| Cleanup | Old-version rows removed, old synthetic input subsequently drops, new version remains usable; every accepted job removes interfaces, reaps nodes and stops private OVS daemons |

The three accepted jobs contain **32 uniquely identified packet controls**: 19 static, one queue case and 12 version cases. Additional API/defect assertions are engineering controls, not independent workloads or probability estimates. The independently written Python audit passes **800 checks**, reconstructing expected rules from the original executed source, decoding actual OVS dumps and captured bytes, checking kernel links and distinguishing flow classes. Deliberately corrupted prefix/IPv4 records are rejected in memory without changing stored data.

## Accepted evidence and resources

| Mode | Final accepted run | Driver checks | Whole command | Checkpoint peak |
|---|---|---:|---:|---:|
| Static | [1793019493516907649](../runs/cos738-ovs-cisco-static-1793019493516907649/adapter_validation.json) | 67 | 65.122 s | 764,710,912 B |
| Queue | [1793019558819216870](../runs/cos738-ovs-cisco-queue-1793019558819216870/adapter_validation.json) | 20 | 62.628 s | 635,805,696 B |
| Version | [1793019621615437691](../runs/cos738-ovs-cisco-version-1793019621615437691/adapter_validation.json) | 65 | 64.857 s | 683,778,048 B |

Every job retained the two-CPU quota/affinity, hard 2 GiB memory, zero swap, 120-second whole-job ceiling and single-local-job lock. Startup and Julia compilation are included in these totals. They are not comparative method-performance measurements. All accepted jobs have successful interface, node and daemon cleanup; no active COS738 scope remains after verification.

[Audit.json](Audit.json) records the independent audit, including actual helper/gate/forwarding-flow counts. [verification/audit.txt](verification/audit.txt) retains its output. Unbounded Step-2 invocation is deliberately refused before namespace/network setup; the refusal logs are under `verification/unbounded.*`.

## Representation and preservation checks

### Physical topology

The adapter reads the **executed original Python capture**, checking its frozen hash, and cross-checks raw old/new rows against the validated handover fixture. It does not independently regenerate a convenient smaller topology. Numeric switch ports are explicitly assigned from recorded neighbor order (starting at one); host interface indices start at zero. These are adapter-assigned numbers, not claimed original hardware port numbers.

All 28 edges are checked against actual Linux veth information. Same-namespace peers are represented by names in `ip` JSON; cross-namespace peers use interface indices. The checker handles both forms and requires reciprocal identities. All 12 host namespaces are distinct; switches remain in the private parent network namespace.

### Forwarding, gates and actual costs

Table 0 contains traversal helpers and physical-source gates/tag assignment. Table 1 contains exact ingress, 10/8 IPv4 source/destination and version matches, plus default DROP. Cookies distinguish logical forwarding rows, gates and helpers. Logical version zero is untagged; version one is VLAN 101. No monitor authorization label or desired destination is used to admit a packet.

OpenFlow 1.4 requires a VLAN-present match before `pop_vlan`. Each open source therefore has a tagged-input normalization branch and an untagged branch. A closed source has one catch-all DROP rule. Client-supplied tags cannot select the authorization/version; the source phase assigns it.

This overhead is visible rather than treated as free logical forwarding space. For example:

- C2 old state: **one logical forwarding row + three gate flows + two helpers = six OVS flows**.
- C2 staged state: **two logical forwarding rows + three gate flows + two helpers = seven OVS flows**.
- Other shared path switches: one/two logical forwarding rows plus two helpers.
- Inactive switches still have two helper/default flows.

Consequently, “one extra forwarding row” is not one extra total OVS flow, physical TCAM cell or a measured memory-capacity guarantee. The staging refusal is the adapter's logical-budget check, not an experimentally enforced ASIC limit.

### Source queue and clocks

The pending record is immutable, and the queue emits nothing while the physical-source gate is closed. The test opens the actual gate with a local bundle, then emits exactly once and observes delivery. The original arrival is retained across that transition; monotonic emission/receipt order is checked. Overflow and duplicate requests are not counted as delivered service.

The retained queue wait includes deliberate validation settling, command/readback and harness work. It is **not** Q's admission-latency result or an application SLA. Packet observation uses a 0.12-second settling interval followed by sequential host drains, not identical instantaneous observation cutoffs. Finite absence observations are not universal drop/safety proofs.

### Versions and synthetic internal positions

The staging test preserves old untagged forwarding and adds the new tagged path. A client at H5 cannot choose the new path by supplying VLAN 101. After commit, a client at H6 is assigned VLAN 101 even if it supplies another tag.

Internal-position probes are clearly labelled synthetic: the harness injects a frame on the actual C10→C4 interface to test a forwarding state beyond admission. An untagged synthetic old frame still reaches H9 after commit while the old endpoint is closed; after old-row cleanup it drops. A tagged new frame reaches H10. This demonstrates version separation at real ports, **not evidence that the synthetic frame was admitted before a timed update**.

The cleanup primitive checks committed phase state but has no drainage-timer certificate. We intentionally test its static effect; the safe real-time condition for calling it belongs to the next protocol gate. No model H=4 round bound was converted into milliseconds.

## Corrections and retained history

The validation was iterative; unsuccessful and superseded jobs remain under `../runs/`, with source snapshots. No scientific grid was reset or method selected for favorable performance.

1. **OF1.4 action consistency:** initial run [1793017767039706796](../runs/cos738-ovs-cisco-static-1793017767039706796/output.log) rejected an unconditional VLAN pop. Offline parser controls showed that the masked untagged match was supported, but the unconditional pop restricted usable protocols to older/NXM formats. The compiler now conditions stripping on a present tag and leaves untagged input alone. OpenFlow was not downgraded. Diagnostic flow files/logs are retained under `diagnostics/` and parser jobs.
2. **Harness errors:** a missing predicate lambda and an unexported PythonCall helper reference were corrected. The affected run [1793018038939792558](../runs/cos738-ovs-cisco-static-1793018038939792558/output.log) is retained. The outer scope/namespace tore down failed runs; final accepted jobs additionally prove normal library cleanup.
3. **Kernel audit representation:** [1793018659108627308](../runs/cos738-ovs-cisco-static-1793018659108627308/output.log) exposed that same-namespace veth JSON uses peer names rather than `link_index`. The audit was corrected to interpret the actual API, without altering topology.
4. **Coverage refinement:** explicit kernel-peer checks, pending-through-version-commit delivery, source-slot defect controls and phase-order rejection were added before final acceptance. All three groups were re-executed on the final identical core source. Earlier passing jobs are supporting history, not the accepted final-source evidence.

The protected-sysctl Mininet tuning warning and Julia Markdown warnings remain visible. No upstream library, system wrapper, host networking or frozen study source was patched. OVS remains the experimental userspace `netdev` backend, with the beta-labelled pinned Mininet version; this does not validate kernel OVS or hardware.

## Verify without rerunning networks

From `Step2`:

```sh
python3 -I -B audit.py
sha256sum --check Validated_Source_Manifest.sha256
```

The audit writes only its derived report; it does not launch Mininet or rewrite captured runs. [audit.py](audit.py) is separate from the Julia adapter and does not call its rule generator. Runtime driver's source hashes match the retained snapshots and current accepted core.

The prior Step-1 310-file seal and the model study's 628-file output seal plus 194+2 historical entries were rechecked unchanged. There is no new Cisco result table in `main.tex` yet.

## Next gate

Step 2 is complete for the declared adapter checks. Before a scientific comparison, still validate the controlled in-flight/delay mechanism, specify drainage assumptions without consulting probe delivery, fix exact warm-up/readiness and measurement boundaries, and freeze the finite grid/repetition/attempt/failure manifest. Only then run the prospective ordinary/Q/V comparison and integrate its results. See the separately labelled [experiment-design draft](../Experiment_Protocol_Draft.md); it is not an execution freeze or empirical result.
