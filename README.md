# SDN intent-update study

Research artifacts for **Qualifying SDN Intent Updates: Bounded Handover, Sampled Detection, and Operational Cost**, by Justin Marc Cheney.

This repository makes two previously unpublished study artifacts inspectable. It contains code, fixed experiment definitions, retained results, raw records, validation evidence and selected research notes. It does **not** contain the course manuscript, manuscript iterations, assessment instructions, editorial conversations or student contact details. Public availability is not a claim of course approval, peer review or independent replication.

## The two studies

| Artifact | Start here | Source freeze | Output seal |
|---|---|---|---|
| Bounded original-intent model comparison | [Results](artifacts/Literature_Review/CA1/Revision_Protocol/study/Results.md), [protocol](artifacts/Literature_Review/CA1/Revision_Protocol/study/Protocol.md), [source](artifacts/Literature_Review/CA1/Revision_Protocol/) | [`Manifest.toml`](artifacts/Literature_Review/CA1/Revision_Protocol/study/Manifest.toml) | [628-file manifest](artifacts/Literature_Review/CA1/Revision_Protocol/study/Output_Manifest.sha256) |
| Separate Cisco packet emulation | [Results](artifacts/Literature_Review/CA1/Emulation/Comparison/Results.md), [protocol](artifacts/Literature_Review/CA1/Emulation/Comparison/Protocol.md), [source](artifacts/Literature_Review/CA1/Emulation/) | [`Manifest.json`](artifacts/Literature_Review/CA1/Emulation/Comparison/Manifest.json) | [2,041-file manifest](artifacts/Literature_Review/CA1/Emulation/Comparison/Output_Manifest.sha256) |

The model study contains 12 primary cells / 92 rows, 576 sampling-sensitivity records and 48 benchmark jobs. The later emulation contains six primary cells / 30 episodes / 45 packets. These are separate evidence domains, not pooled trials. Failure and partial records required by their seals remain included.

Under the specified bounded-handover contract, Q permits admission waiting without extra forwarding rows; V needs temporary row space and opens new service earlier. Sampled detector negatives do not establish safe release. The fixed fixtures, one-request workload, logical-time assumptions and experimental userspace datapath limit the conclusions. See the linked protocols and results for the full conditions.

## Verify the distributed evidence

Python 3.11 or newer, standard library only:

```sh
python3 -I -B verify.py
```

This reads the frozen source/output manifests and export inventory, checks file hashes and fixed result counts, and performs no experiment, network setup, package installation or privileged action. A passing check establishes integrity and internal accounting, not correctness of every scientific claim.

For original execution requirements and the limits of portable reproduction, read [REPRODUCIBILITY.md](REPRODUCIBILITY.md). In particular, the original launchers intentionally retain their original historical-seal and machine/environment gates. This is a **source-and-evidence release**, not a tested one-command portable replication package.

## Repository map

- `artifacts/Literature_Review/CA1/Revision_Protocol/`: model implementation, controller validation, reference capture/replay and frozen campaign.
- `artifacts/Literature_Review/CA1/Emulation/`: Mininet/PythonCall/OVS implementation and separately sealed packet evidence.
- `artifacts/SDN_Model_Comparison/source_fidelity/`: the required earlier detector module and attributed upstream source snapshots, not the entire earlier study.
- Selected [literature review](artifacts/Literature_Review/CA1/Focused_Literature_Review.md), [evidence register](artifacts/Literature_Review/CA1/Evidence_Register.md) and [reading guide](artifacts/Literature_Review/CA1/Reading_Guide.md).
- `EXPORT.json`: exact exported file inventory, original relative locations, sizes and hashes.
- `SHA256SUMS`: release-file checksums, excluding itself and Git metadata.

The original relative directory layout is retained inside `artifacts/` because frozen sources refer to it. Files are not renamed or silently repaired to make the tree look simpler. Historical reports retain their execution-time status and may reference local-only material; the top-level documents describe this public release.

## Citation and version identity

Repository: <https://github.com/JCheney20/sdn-intent-update-study>. Cite each study separately using its manifest identity and a fixed release/commit URL, not only the moving `main` branch. Suggested study titles are those in the table above. The public artifact does not make either study an independently published or peer-reviewed result.

## Rights and provenance

Original code is MIT-licensed; original writing and original study records are CC BY 4.0, **subject to the third-party exceptions in [LICENSING.md](LICENSING.md)**. Spotlight sources and adaptations retain CC BY 4.0 attribution; NetworkX-derived material retains its BSD-3-Clause conditions. These licenses do not relicense third-party material. Full third-party papers without confirmed redistribution permission, local tool caches and Nix-store package symlinks are excluded.

AI coding models assisted implementation, bounded execution, analysis and documentation. Retained independent-implementation checks are engineering controls, not a claim of independent human replication.
