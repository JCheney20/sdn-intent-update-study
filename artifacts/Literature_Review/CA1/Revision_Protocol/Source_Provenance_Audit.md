# Spotlight source/provenance audit

**25 October 2026 — source-reading evidence, not an executed replication.** This note and its reading inputs are outside the sealed SDN research package. No downloaded implementation was imported or executed; no installation, simulation, Slurm access or submission occurred. The original results and ledger remain historical.

## Findings

### 1. Two public Spotlight records contain the same topology generator

The captured [Zenodo versions response](inputs/zenodo-versions.json) lists:

| Record | Creation date | `fattree.py` SHA-256 |
| --- | --- | --- |
| [11642350](https://zenodo.org/records/11642350) | 13 June 2024 | `db8906f77813eb1a6b968b982b857ef43754ec9c716ee65453cf61a815e9d823` |
| [12735280](https://zenodo.org/records/12735280), currently pinned | 12 July 2024 | Same |

Both downloaded generators are byte-identical and match the frozen reading copy. `create_cisco()` declares **C1–C10, H1–H12, and 28 unique undirected edges**: 22 vertices, of which ten have `type="core"`. None of these ten is distinguished as a router in Spotlight's generator or switch-object construction.

This excludes a generator change **between these two archived records** as the explanation. It does not exclude an unpublished evaluation version, a different evaluation input, or a reporting/counting issue. Zenodo metadata revision numbers are not additional software releases.

### 2. The extra two nodes have identifiable upstream roles

The NetViews paper explicitly gives its implementation repository, [netviews/ss-netviews](https://github.com/netviews/ss-netviews). Its Cisco JSON is also present in [netviews/ms-netviews](https://github.com/netviews/ms-netviews). The captured repository trees point to the same Git blob:

`019bfbe7c491ae430f1af87010c4919b570ee4d0`

Reading copy: [netviews-cisco-topology.json](inputs/netviews-cisco-topology.json), SHA-256 `3f1e57f22c88802c2ce4b1af220369e94754967e50a39d546cd9348159b20378`.

Its `switches` array has ten entries, with these descriptions:

| NetViews names | Spotlight names under the verified mapping | JSON description |
| --- | --- | --- |
| s7, s8 | **C7, C8** | **router** |
| s9, s10 | C9, C10 | firewall |
| s1–s5 | C1–C5 | switch |
| s6 | C6 | ap |

The complete mapping is `s_i → C_i`, `h1–h4 → H1–H4`, and `sv1–sv8 → H5–H12`. Under that mapping, the two **simple undirected graphs have exactly the same vertex and edge sets**. This was checked by parsing source literals and JSON, without running NetworkX, Mininet or Spotlight.

Important qualification: the JSON has 29 link records, including a duplicate `s2–sv3` record; there are 28 unique undirected edges. The equality claim deliberately concerns a simple-graph abstraction. It does not establish parallel-port equivalence, bandwidth equivalence, firewall behavior or reproduction of an emulated NetViews installation. The captured Git trees identify the inspected source objects, not proof of the precise historical paper-experiment commit.

**Interpretation:** eight non-router forwarding devices plus two routers is an evidence-based accounting/boundary hypothesis. It is not yet proof that this explains Spotlight's evaluation input. In particular, calling the routers something else does not remove them from the artifact's 22-node sampling graph.

### 3. The publications really do report different counts

Primary-source reading copies are retained in `inputs/`; the quoted locations can be checked against their original PDFs.

| Primary source | Location | What it reports |
| --- | --- | --- |
| [Spotlight, CCS 2024](https://web.mit.edu/ha22286/www/papers/CCS24.pdf) | §6.1.3, Table 2 | Twelve hosts and eight switches |
| Same | §6.2 | Cisco “contains 20 nodes” |
| [NetViews, SACMAT 2022](https://enck.org/pubs/anjum-sacmat22.pdf) | Figure 6(c), Table 2, §7.1 | Cisco: 12 devices, 10 switches; figure labels s1–s10 |
| [MSNetViews, SACMAT 2023](https://bradreaves.net/publication/asr%2B23/asr%2B23.pdf) | Figure 6 and caption | Cisco: 12 devices, 10 switches; labels s1–s10 |
| [PSI, NDSS 2017](https://www.ndss-symposium.org/wp-content/uploads/2017/09/ndss201702A-2YuPaper.pdf) | Figure 12(c), Table I | `pix-cisco`: 14 “Devices”, 8 “Switches” |

Spotlight cites NetViews, MSNetViews and PSI in its topology discussion. PSI's table is **not** an eight-switch/twelve-host adjacency specification: its reported device count differs too. Do not equate the papers' “Devices” columns with a verified common host model.

The text extraction includes figure labels, but the PDF figures have **not been visually checked** in this audit. The graph equality above rests on actual source data, not inferred figure edges or search-provider summaries.

### 4. What an eight-device sensitivity case could legitimately mean

The source roles now support a reproducible **internal-boundary sensitivity proposal**: retain the induced graph on all hosts and C1–C6/C9/C10, excluding the two explicitly identified upstream routers C7/C8. It would have 20 vertices and 23 unique edges. This is a role-based boundary choice, not an arbitrary selection of two inconvenient nodes.

However, it remains a **derived sensitivity graph, not a recovered Spotlight paper input**. It must have a separate name, manifest and author-approved rationale before execution. Do not replace the ten-switch artifact or retroactively reinterpret its results.

Removing the routers changes the random-walk state space, edge-based sample-size calculation and top-k coverage, even though the original Cisco intent paths do not use them. Relabelling them without removing them leaves the 22-node sampling graph unchanged. Neither operation is merely a cosmetic count correction. Keep the original graph's insertion order when defining any approved derived input; do not renumber the retained C9/C10 as though they were different source devices.

**Disposition:** artifact topology identified; upstream graph/roles identified; exact paper twenty-node evaluation input still unresolved.

## Original intent and version fidelity

The two archived `detector.py` files are **not** interchangeable:

- Earlier SHA-256: `04133cb3ce0e7bdf9282ee82593d84567b58b4de4cb334ce130d8cf58d3c5ee6`.
- Pinned later SHA-256: `c4530e74d33c5d64b32a68be613135c4e4b8be020bbe03448ce8cb5732019595`; matches the frozen reading copy.
- Top-level source-function comparison finds changes to `is_connector_node_str`, `calculate_devices_on_path`, and `do_packets_match`, plus main-program/CLI changes. In particular, connector classification changes from a hyphen test to membership in `device_dict`. Physical fat-tree names themselves contain hyphens; this is a substantive fidelity issue to preserve, not a reason to substitute the older version.
- `prep_trial_cisco` and `prep_trial` have identical parsed function bodies across the two records.

The pinned source's actual changing endpoint pairs are:

| Topology | Initial permitted intent | Final permitted intent |
| --- | --- | --- |
| Cisco | H5 → H9 | H6 → H10 |
| Fat tree, fk=4 | H0-0-0 → H3-1-1 | H0-0-1 → H3-0-0 |

Both preparations derive paths with NetworkX `shortest_path`, generate ingress/egress rules, and construct removal/addition differences. Preserve graph insertion order because shortest-path ties can affect the resulting rules. Do not substitute a same-endpoint reroute or choose an alternative path after seeing outcomes.

All host objects in these preparations use `10.0.0.0`, and rules use source/destination `10.0.0.0/8` matches. Device identities, physical ingress and connector semantics therefore matter. Do not silently assign unique host IPs and call it the same artifact experiment.

**CLI trap:** in the pinned main program, Cisco and Stanford calls explicitly pass `panther_k=20`, even inside the loop over `args.panther_k`. Thus `--topo cisco --panther-k 3` does not establish a k3 reference run. A future validation wrapper must record the actual helper arguments and distinguish the original default k20 experiment from a declared k3 parameterized comparison. No such wrapper has been executed here.

## Author clarification draft — not sent

> We are validating the archived Spotlight implementation. Both public records 11642350 and 12735280 contain the same Cisco generator: 12 hosts plus C1–C10, 22 vertices and 28 undirected edges. Its simple adjacency matches the NetViews Cisco JSON, whose s7/s8 nodes are described as routers. Your Table 2/§6.1.3 report eight switches and twelve hosts, and §6.2 states twenty total nodes. Could you provide the exact node/edge list and preprocessing input used for that evaluation? Were the two router nodes excluded from Panther's graph, or is the difference reporting/device-role accounting? Which archived version and effective k/query settings reproduce those results?

Contacting the original authors remains an author action, not something already performed.

## Evidence and limitations

- [Source receipt](inputs/Source_Receipt.json): URLs, byte counts and SHA-256 fingerprints of reading inputs. Extracted Markdown hashes identify the extracted text, **not the original PDF bytes**.
- [Machine-readable topology findings](Topology_Audit_Findings.json): source-literal vertex/edge sets, insertion order, role mapping and comparison results.
- Public API/source downloads and stdlib text/AST/JSON analysis only. No third-party imports or downloaded-code execution; `.py.txt` files are reading copies, not delivered runtime dependencies.
- A whole-repository Git tree exceeded a bounded read cap; it was discarded. Only relevant repository subtrees/blobs were subsequently retained. No repositories were cloned.
- These are assistant-performed checks, not a claim of student verification, independent review or paper-level replication.

Next: apply the [revision validation protocol](Revision_Validation_Protocol.md), after its open decisions and execution envelope are approved.
