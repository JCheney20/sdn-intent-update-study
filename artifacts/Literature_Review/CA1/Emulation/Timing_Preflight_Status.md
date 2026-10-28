# Timing-mechanism preflight: review required

After completion of Step 2, the author authorized proceeding through the remaining planned gates and manuscript integration, conditional on stopping for errors or required corrections. The final manuscript is to await review, not submission.

**Preflight decision resolved:** the author approved the userspace relay, the researched Julia-vector correction and the explicit local audit import. Runtime, independent timing audit and the subsequent separately frozen comparison passed. See [Step-3 timing status](Step3/Timing_Status.md). No primary emulation attempt was launched, no scientific freeze was made and no manuscript findings were added.

## Read-only observations

- `/proc/config.gz` reports `CONFIG_NET_SCH_NETEM=m`, `CONFIG_NET_SCH_INGRESS=m` and `CONFIG_IFB=m`.
- `/sys/module/sch_netem`, `/sys/module/sch_ingress` and `/sys/module/ifb` are absent. The existing `veth` module is visible.
- No active COS738 scope was present during preflight.
- No `tc` qdisc was installed and no module-loading command was run. In particular, Mininet TCLink was not invoked in a way that might trigger automatic host module loading.

## Consequence and proposed route

The ordinary Mininet/netem route cannot be assumed available under the continuing no-kernel-module-loading restriction. Even if netem were available, its effect on OVS userspace packet I/O would still require actual packet validation.

The proposed alternative is a **transparent userspace link relay**, entirely within the private namespace. It would delay raw frames on the declared logical edge without choosing forwarding destinations or consulting controller/probe outcomes. It must preserve the logical Cisco endpoints, physical switch ingress ports and bytes. Its additional wire-realization interfaces/helper must be explicit, with the expanded kernel wiring independently checked; the original Step-2 source/seal must remain unchanged.

Before any primary freeze, validate real H5-admitted packet residence/delay, unchanged forwarding/version behavior, timing origins/observation cutoffs, controller/monitor separation and cleanup. Do not use synthetic internal injection as prior-admission evidence. The exact relay design and parameter policy are not yet frozen or validated.

All setup corrections received author approval and passed. The subsequent comparison is complete; see [comparison completion](Comparison/Completion_Report.md). Existing limits remain two CPUs, hard 2 GiB memory, zero swap, 120 seconds per whole job and one local job at a time. No host module loading, new privilege, source build or remote compute is authorized by this status record.
