# Step 2: Cisco adapter validation controls

26 October 2026. The author approved Step 2. This is adapter validation, **not** a measured ordinary/Q/V campaign or permission to bypass the later scientific freeze. The existing two-CPU/2-GiB/zero-swap/120-second job limit and private user/net/PID/mount isolation remain unchanged. Step-1 files and earlier study seals must remain intact.

## Fixed inputs and representation

- Read the original executed Cisco capture: 22 nodes (10 switches, 12 hosts), 28 physical edges, ordered adjacency and raw ingress/egress/prefix rows. Verify the frozen source hash before use and cross-check old/new rows against the independently validated handover fixture. Preserve the dual-homed H2 and H7 links.
- Assign switch port numbers 1..degree in recorded adjacency order; host interface numbers start at zero. These are explicit adapter-assigned numeric ports, not claimed original hardware port numbers. Validate Mininet and actual OVS port readback.
- Use two OpenFlow tables. Table 0 contains helper traversal and physical-source admission/tag-assignment rules. Table 1 contains exact ingress, IPv4-prefix and version forwarding rows, plus default DROP. Distinct cookies identify helpers, gates and logical forwarding rows. Count these separately.
- Logical version 0 is untagged; version 1 is VLAN 101. Ingress normalizes client-supplied VLANs before assigning the configured version. The monitor's destination/authorization metadata is never an OpenFlow match or admission input.
- A single-switch flow replacement is an OpenFlow 1.4 bundle with readback, never a network-wide atomic update. No wall-clock interpretation is assigned to H=4 model rounds.
- Raw IPv4 frames carry a test identity in payload and retain the broad source/destination 10/8 matching semantics. Host packet workers do only I/O/capture; Julia calls Mininet and controls adapter state. Observe all hosts, including both interfaces on dual-homed hosts. Internal-position injection, when used, is explicitly a synthetic adapter control, not proof that a packet was previously admitted.

## Validation modes fixed before execution

Separate bounded jobs may exercise `static`, `queue` and `version` controls. Each includes full topology setup and cleanup. These are named test groups, not retries/splits of a primary cell.

### Static topology and rule controls

- All node/edge/adjacency/port mappings agree with source and actual OVS readback.
- Old unversioned state forwards H5 to H9; target unversioned state forwards H6 to H10.
- Closed legitimate source gates do not forward raw probes. Other physical hosts (including both dual-home interfaces) cannot enter the forwarding path.
- Wrong source/destination prefixes drop. Changes to payload-only monitor labels cannot alter admission/routing.
- Read back logical rows and helper/gate counts. The semantic checker reconstructs expected tuples from raw source rows independently of generated flow strings.

### Source-slot controls

- One immutable request identity/frame/arrival is buffered **before physical emission** while the new source gate is closed.
- A second outstanding request is explicit OUTSIDE_DOMAIN and cannot overwrite the first. Duplicate identity and wrong source are rejected.
- Closed-gate admission calls emit nothing. After actual gate installation/readback, the pending request is emitted at most once and delivered to H10, preserving original arrival/identity/bytes.
- Repeated admission does not duplicate the packet. A failed emission is visible/incomplete and cannot silently retry. Queue tests are not an offered-load guarantee or arbitrary-size queue.

### Version and local transaction controls

- Staged old/new logical rows coexist with at most one extra forwarding row per shared path switch, excluding gate/helper overhead.
- Before commit, old-source traffic retains old behavior and new source remains closed. A client-supplied new tag cannot choose new authorization.
- Commit changes old/new gates and new tag assignment at C2 only; staged rows elsewhere are unchanged.
- After commit, new source reaches H10 with VLAN 101; old source is closed. Explicit internal-position controls distinguish untagged old rows, tagged new rows and invalid tags.
- Cleanup removes old-version rows; subsequent synthetic old-version input drops while the new version still forwards. These static controls do not establish safe timing of drainage/cleanup for in-flight packets.

## Packet observation and disposition

Use fixed small observation windows and unique identities, retaining raw frames, namespaces, flow dumps, source-arrival/emission timestamps and outcomes. A finite no-receive observation is not a universal absence proof. Do not tune observation windows or topology after a favorable method comparison; unexpected validation mismatches require diagnosis and retained dispositions.

Do not execute timed Q/V handover, choose a traffic population, infer packet lifetime from observed delivery, or call a barrier a drain certificate at this stage. Controlled-delay design, repetitions, capacities, failure handling, warm-up/readiness, process lifetime and exact measurement boundaries remain for the later scientific manifest.

## Exit gate

Step 2 may pass only when raw-source/port/rule correspondence, real packet controls, queue conservation, version separation, resource bounds and normal cleanup pass with retained evidence. Otherwise report the open mismatch. Only then prepare the prospective emulation experiment freeze; do not insert Cisco comparison findings into the manuscript yet.
