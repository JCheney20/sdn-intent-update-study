# Userspace wire timing gate: complete

27 October 2026. The approved native Julia vector correction (`collect(PyList{Py}(raw))`, then `only`) passed the full relay runtime without changing package pins or the sealed Step-2 adapter. The later audit-launcher correction explicitly adds the absolute source directory while retaining Python `-I`.

## Preserved history

The original first-attempt status, code, receipts and 70-file seal remain under `history/attempt1/Emulation/Step3/`, with unchanged manifest bytes and relative-path contents. `Previous_Attempt_Archive.json` records the relocation. The failed independent audit launcher remains under its original run and the separate 29-file `Comparison/Audit_Launch_Failure_Manifest.sha256`.

## Accepted runtime and independent audit

Runtime `cos738-ovs-wire-timing-vector-1793079788777892588` passed 79 checks: three old H5-admitted resident frames, three new H6/tagged frames, one warm frame, correct destinations/versions, expanded kernel wiring/ofports and successful normal cleanup. Whole job 74.917922 s, checkpoint peak 650,756,096 B, original two-CPU/2 GiB/zero-swap limits. The 62-file run-snapshot seal is `Timing_Vector_Attempt_Manifest.sha256`.

Corrected standalone audit `cos738-ovs-comparison-timing-audit-import-1793081331461933495` passed **211 independent checks**. This certifies the declared setup cases, not arbitrary-load safety, real-time bounds or hardware behavior.

The separate comparison subsequently froze its source/grid, passed its envelope validation, executed all six primary cells and passed its final independent audit. See [comparison completion report](../Comparison/Completion_Report.md). No timing/parameter correction or primary retry occurred after the comparison freeze. Manuscript integration is a separate final deliverable for author review.
