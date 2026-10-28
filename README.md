# SDN intent-update study

**Qualifying SDN Intent Updates: Bounded Handover, Sampled Detection, and Operational Cost**  
Justin Marc Cheney · research source and evidence · 2026

## Contents

1. [Research overview](#research-overview)
2. [What is in this repository](#what-is-in-this-repository)
3. [Study 1: bounded model comparison](#study-1-bounded-model-comparison)
4. [Study 2: Cisco packet emulation](#study-2-cisco-packet-emulation)
5. [Verification and independent reruns](#verification-and-independent-reruns)
   - [Verify the published evidence](#verify-the-published-evidence)
   - [Nix environment route](#nix-environment-route)
   - [Environment route without Nix](#environment-route-without-nix)
   - [Experimental rerun sequence](#experimental-rerun-sequence)
6. [How to cite](#how-to-cite)
7. [Licenses and attribution](#licenses-and-attribution)

## Research overview

A logically centralized SDN controller does not update every switch simultaneously. While forwarding rules change, packets can encounter a mixture of old and new configurations. Even when both endpoint configurations are correct, an admitted packet can reach the wrong destination during the transition. Detecting temporary connectivity alone does not establish safe delivery, useful service or completed cleanup.

This research compares update procedures under a **bounded-handover contract**: packets admitted under the old intent must retain their authorized destination, while a new request may wait before admission but must receive bounded service. It asks which procedures meet that contract and what admission delay, temporary forwarding space and operational cost distinguish the qualified choices.

Two separate studies address that question. A bounded model comparison evaluates seven procedures on fixed Cisco and fat-tree fixtures, checks reference-detector fidelity, and measures sampling sensitivity and snapshot-search costs. A later Cisco emulation examines ordinary updates, quiesce-and-drain (Q) and versioning (V) using real packets through Mininet and Open vSwitch.

The main result is conditional rather than a universal ranking. **Q qualifies without extra logical forwarding rows when admission waiting is acceptable. V needs one extra row but opens new service earlier. Ordinary updates violate the admitted-old-packet obligation. A sampled detector negative cannot certify safe release.** The model and finite emulation observations remain distinct; logical rounds, component computation and packet-service milliseconds are not interchangeable.

## What is in this repository

The repository contains the two studies' source, prospective protocols, frozen manifests, validation evidence, retained raw records, results and selected supporting research. It does not include the course manuscript, paper iterations, assessment instructions, editorial conversations or student contact details.

| Location | Contents |
|---|---|
| [`Revision_Protocol/`](artifacts/Literature_Review/CA1/Revision_Protocol/) | Bounded handover implementation, lifecycle/controller logic, independent validation, reference capture/replay and model campaign. |
| [`Revision_Protocol/study/`](artifacts/Literature_Review/CA1/Revision_Protocol/study/) | Model protocol, source freeze, primary CSV, sensitivity/benchmark summaries, raw jobs, attempt records and output seal. |
| [`Emulation/`](artifacts/Literature_Review/CA1/Emulation/) | Julia/PythonCall/Mininet/OVS integration, Cisco adapter, transparent relay and validation material. |
| [`Emulation/Comparison/`](artifacts/Literature_Review/CA1/Emulation/Comparison/) | Separately frozen ordinary/Q/V protocol, parameters, results, audits and consumed-attempt records. |
| [`Emulation/runs/`](artifacts/Literature_Review/CA1/Emulation/runs/) | Retained run records and source snapshots required by the emulation output seal. |
| [`source_fidelity/`](artifacts/SDN_Model_Comparison/source_fidelity/) | Required earlier detector module and attributed upstream source snapshots; not the full earlier study. |
| [Focused literature review](artifacts/Literature_Review/CA1/Focused_Literature_Review.md) | Research background and comparison of existing approaches. |
| [Evidence register](artifacts/Literature_Review/CA1/Evidence_Register.md) / [reading guide](artifacts/Literature_Review/CA1/Reading_Guide.md) | Supporting claim/source notes and suggested reading. |
| [`verify.py`](verify.py), [`EXPORT.json`](EXPORT.json), [`SHA256SUMS`](SHA256SUMS) | Read-only verification, export provenance and release checksums. |
| [`REPRODUCIBILITY.md`](REPRODUCIBILITY.md) / [`LICENSING.md`](LICENSING.md) | Execution boundaries and rights/provenance details. |
| [`CITATION.cff`](CITATION.cff) | Machine-readable citation for the repository as a whole. |
| [`replication/`](replication/README.md) | Validated new Nix/native launchers, hash-locked Python setup, vendored Julia/Mininet sources and declared replication protocol. |
| [`replication-results/`](replication-results/README.md) | Frozen successful comparisons, retained failure index, per-file inventories and full-record release downloads. |

The directory layout inside `artifacts/` preserves relative paths used by frozen sources. Repeated run snapshots remain where required by a seal. Historical reports retain their execution-time wording and may link to local-only material; the top-level documents describe the public release.

## Study 1: bounded model comparison

### Question and method

Which procedures preserve old-packet authorization, provide legitimate new service and finish within declared logical bounds? The study uses the original artifact's Cisco fixture (10 forwarding nodes, 12 hosts) and parameter-four fat tree (20 switches, 16 hosts), with one intent change per fixture and one outstanding new request.

Seven procedures are compared: ordinary replacement, Q, V, a conservative CCG-inspired scheduler, guard-only, detector-guided and guarded detector. An independently implemented raw-input packet oracle checks a numeric Julia engine. The unchanged Python detector is captured and replayed in Julia before native sampling variants are compared.

The frozen campaign contains **12 primary cells / 92 rows**, **576 sensitivity records** and **48 benchmark jobs**. Reusing an exact validated plan is evidence reuse, not an additional independent safety replication.

### Main findings

- Ordinary replacement has wrong-destination witnesses on both fixtures.
- Q qualifies with zero or one extra logical row. Its opening/completion bounds are 7/8 rounds for Cisco/fat tree.
- V is capacity-blocked at zero extra rows. With one extra row it opens at round two and completes at 7/8 rounds.
- The narrower CCG-inspired scheduler qualifies without extra rows but completes at 11/13 rounds. This is not a performance result for the full published CCG system.
- All primary detector seeds alert and select V. Negative-release and guard-rescue behavior comes from separate sensitivity/control evidence, not those primary seeds.
- At cache size three, native weighted Julia changes alert/qualification decisions on 13/32 Cisco and 10/32 fat-tree labels; neighbor sampling changes 14/32 and 12/32. Equal integer labels are not common random draws.
- Warm matched full-snapshot searches favor this Julia implementation by approximately 7.7–15.1×; fresh-process totals favor Python. These are combined implementation effects, not an isolated language effect.

### Full research and records

- [Complete study report and findings](artifacts/Literature_Review/CA1/Revision_Protocol/study/Completion_Report.md)
- [Generated results and numeric tables](artifacts/Literature_Review/CA1/Revision_Protocol/study/Results.md)
- [Operational semantics and finite bounds](artifacts/Literature_Review/CA1/Revision_Protocol/Operational_Semantics_and_Bounds.md)
- [Frozen protocol](artifacts/Literature_Review/CA1/Revision_Protocol/study/Protocol.md), [primary CSV](artifacts/Literature_Review/CA1/Revision_Protocol/study/Primary_Results.csv), [coverage report](artifacts/Literature_Review/CA1/Revision_Protocol/study/Coverage_Results.md)
- [Source manifest](artifacts/Literature_Review/CA1/Revision_Protocol/study/Manifest.toml): SHA-256 `7ca19f71f0d88d709e4e415e9b4b28e4ba013fd3d73d45f066ddbc1aff6a915e`
- [628-file output seal](artifacts/Literature_Review/CA1/Revision_Protocol/study/Output_Manifest.sha256): SHA-256 `6fce85fb4d814da41aad396c3a27c0ee889a97e8d3e514ebcd3a38e14327d9c5`

## Study 2: Cisco packet emulation

### Question and method

Does the admission-versus-capacity distinction appear in a real software forwarding pipeline? A separately frozen study compares ordinary, Q and V on the same logical Cisco fixture, with nominal and old-packet-inflight scenarios and five warmed updates per cell.

Julia 1.13.1 calls Mininet 2.3.1b4 through PythonCall. OVS 3.2.1 uses userspace `netdev` forwarding and switch-local OpenFlow 1.4 bundles/readbacks. A transparent relay adds at least 250 ms residence on C10–C4 to establish the inflight condition. Q and V use fixed one-second waits. The experiment retains **six primary cells / 30 episodes / 45 packets**, separate from the model campaign.

### Main findings

All 30 new requests reach H10. Q and V each deliver their five old inflight packets to H9; ordinary redirects all five to H10. No primary packet is late, duplicated or unobserved under the declared observation procedure.

Inflight medians:

| Measure | Ordinary | Q | V |
|---|---:|---:|---:|
| New admission wait (ms) | 9.247 | 1042.612 | 46.881 |
| New service age from original arrival (ms) | 262.038 | 1294.880 | 298.798 |
| Completion including waits/readback (ms) | 18.150 | 1042.753 | 1087.716 |
| Switch-local bundle submissions | 2 | 4 | 9 |
| Extra logical forwarding rows per shared switch | 0 | 0 | 1 |

V opens new service earlier than Q but does not finish retirement/cleanup earlier. Ordinary's short completion does not make it qualified when an old admitted packet is present. These finite observations, artificial delay and shared experimental userspace datapath do not establish a hardware timing bound, production endurance or an SLA.

### Full research and records

- [Complete emulation report and findings](artifacts/Literature_Review/CA1/Emulation/Comparison/Completion_Report.md)
- [Results and interpretation](artifacts/Literature_Review/CA1/Emulation/Comparison/Results.md), [CSV](artifacts/Literature_Review/CA1/Emulation/Comparison/Results.csv), [machine-readable results](artifacts/Literature_Review/CA1/Emulation/Comparison/Results.json)
- [Frozen protocol](artifacts/Literature_Review/CA1/Emulation/Comparison/Protocol.md) and [parameters](artifacts/Literature_Review/CA1/Emulation/Comparison/Parameters.json)
- [Source manifest](artifacts/Literature_Review/CA1/Emulation/Comparison/Manifest.json): SHA-256 `906476a7eae8e12d97737c3715f5d7b38f39a7ce284f37d937f05d6b1456ee1b`
- [2,041-file output seal](artifacts/Literature_Review/CA1/Emulation/Comparison/Output_Manifest.sha256): SHA-256 `a3985df2da943e066f8ee4484d36e91149cf6eeb529be4ab9919ca09de65017d`

## Verification and independent reruns

**v2.0.0 adds validated new replication entry points.** Separate clean-checkout Nix and native campaigns reproduced the original non-timing scientific outcomes: 92 primary model rows, 576 sensitivity records and six packet cells / 30 episodes / 45 packets. See [frozen replication evidence](replication-results/README.md) for results, tested commits, complete raw-record downloads and retained failures.

Use [`replication/README.md`](replication/README.md) for the executable setup/run instructions, not the historical launchers inside `artifacts/`. The original source, results, seals and consumed attempts remain unchanged. The new layer binds public scientific dependencies, configured runtime paths, fresh outputs and new manifests. It supplies 16 pinned Julia package runtime subsets, Mininet Python sources and a hashed native Python lock; Julia/Python interpreters and Linux tool binaries remain external prerequisites.

**Validation boundary:** both routes passed on the recorded NixOS host. Native mode performs no Nix configuration/evaluation commands but may use externally supplied Nix-built runtimes. This is not a demonstrated clean non-Nix OS, arbitrary-machine or independent human reproduction. Timing equality is not claimed.

### Verify the published evidence

With Git and Python 3.11 or newer:

```sh
git clone https://github.com/JCheney20/sdn-intent-update-study.git
cd sdn-intent-update-study
python3 -I -B verify.py
```

No third-party Python packages, Julia, Nix, network namespaces or elevated privileges are needed for this check. It verifies both source freezes, all 628 + 2,041 sealed output entries, the exported-file inventory and fixed study accounting. It performs no experiment or package installation. A passing result establishes integrity and accounting, not independent replication or correctness of every claim.

For a fixed evidence version, use `git checkout b05a1e02c40ea57f0b9ccb6112607c3e5f9cf305` before verification. That commit contains the original public artifact export; later README revisions do not change its scientific files.

### Nix environment route

The retained flakes pin Nixpkgs to `dddccde11a6c6be45f58a76828a5f48d58262e9a`. The emulation flakes target **x86_64 Linux**. From the repository root, with Nix and flakes enabled:

```sh
MODEL=./artifacts/Literature_Review/CA1/Revision_Protocol
EMU=./artifacts/Literature_Review/CA1/Emulation

# Inspect the pinned Python versions without building the environment.
nix eval --json "$MODEL/reference_environment#referenceVersions.x86_64-linux"

# Inspect the pinned OVS/Linux tools, Mininet tools and Julia package sources.
nix eval --json "$EMU#emulationComponents.x86_64-linux"
nix eval --json "$EMU/Interop#components.x86_64-linux"
nix eval --json "$EMU/Interop#juliaSources.x86_64-linux"
```

The output metadata identifies exact store paths and versions. Individual cached tools can be requested without permitting a local source build, for example:

```sh
nix build --no-link --max-jobs 0 "$EMU#openvswitch"
```

This succeeds only if the required outputs are already present or available from configured substituters. Missing cache outputs are a setup blocker, not permission to substitute versions. The original reference environment used cached component paths rather than building its combined `python.withPackages` wrapper. A `nix develop` invocation alone is therefore not a verified reproduction procedure.

Julia **1.13.1** remains an explicit prerequisite; these flakes do not provision that recorded executable. The [Nix setup instructions](replication/README.md#nix-resolved-cached-components) use `replication/configure.py --route nix --julia /path/to/julia --output /outside/checkout/environment.json --realise`. Cache-only realization permits no local native builds. Configuration checks actual imports and versions; the new workspace reconstructs package links and runtime/provenance bindings. Follow the [complete study command](replication/README.md#run-the-complete-studies) after setup.

### Environment route without Nix

Evidence verification is already Nix-free. For a new experiment, use the [complete native setup](replication/README.md#native-environment-without-invoking-nix), which was validated with a separate hash-locked Python environment. Match these versions rather than assuming current distribution packages are equivalent:

| Component | Recorded version / requirement |
|---|---|
| Julia | 1.13.1 |
| Python reference | 3.11.7 |
| NumPy / NetworkX / Matplotlib | 1.26.2 / 3.2.1 / 3.8.2 |
| Mininet / OVS | 2.3.1b4 / 3.2.1 |
| PythonCall / CondaPkg | 0.9.37 / 0.2.38 |
| Linux facilities | Network/user/mount/PID namespaces, veth, cgroup v2, working systemd user scopes and CPU affinity controls. |

Create the Python **3.11.7** virtual environment outside the checkout, install the pinned packaging tools, then use [`requirements-linux-x86_64.lock`](replication/requirements-linux-x86_64.lock) with `pip --require-hashes` as shown in the [native instructions](replication/README.md#native-environment-without-invoking-nix). The lock covers all 14 checked distributions; installing only NumPy, NetworkX and Matplotlib is insufficient. Native extensions use wheels, not local compilation. Olefile uses its hash-locked pure-Python source ZIP. Python patch version and Julia RNG/tie behavior matter.

For emulation, obtain matching Mininet/OVS versions and Linux utilities from suitable upstream/distribution sources in an isolated Linux test environment. A similarly named PyPI package or a newer OVS release is not automatically equivalent to the recorded Nix packages. Bind PythonCall to the selected Python interpreter/shared library, use the pinned Julia packages, and retain the null/offline CondaPkg behavior after dependencies are prepared. Do not run these network experiments on a production host or infer a need to change host networking from a failed setup check.

The frozen launchers still retain their original paths and gates. **Use the included new `replication/configure.py --route native` and `replication/run.py`**, with explicit tool/runtime prefixes and fresh output paths. Those entry points were validated without invoking Nix, on the recorded NixOS host; no clean non-Nix operating-system validation is claimed.

### Experimental rerun sequence

After configuring either environment, run the complete campaign from the checkout with a **non-existing output directory outside it**:

```sh
python3 -I -B replication/run.py \
  --environment /path/outside/checkout/environment.json \
  --output /path/outside/checkout/replication-001
```

The coordinator runs an early real embedded-Python/network doctor, then the stages below and a deterministic final comparison. Links identify the preserved source implementations, **not commands to run over sealed results**.

| Order | Required stage | Original implementation |
|---|---|---|
| 1 | Validate packet/lifecycle/controller semantics and expected unsafe/blocked outcomes. | [`validation/run.sh`](artifacts/Literature_Review/CA1/Revision_Protocol/validation/run.sh), [`validation/entry.jl`](artifacts/Literature_Review/CA1/Revision_Protocol/validation/entry.jl) |
| 2 | Execute the original Python reference; capture choices and check exact Julia replay. | [`reference_capture/run.sh`](artifacts/Literature_Review/CA1/Revision_Protocol/reference_capture/run.sh) |
| 3 | Declare a new source/environment freeze and attempt ledger; run sensitivity, semantic review, matched benchmarks and primary cells. | [`study/run_all.sh`](artifacts/Literature_Review/CA1/Revision_Protocol/study/run_all.sh), [`study/Protocol.md`](artifacts/Literature_Review/CA1/Revision_Protocol/study/Protocol.md) |
| 4 | Audit the model outputs and derive fixed-event coverage. | [`study/verify_artifacts.jl`](artifacts/Literature_Review/CA1/Revision_Protocol/study/verify_artifacts.jl), [`study/coverage.jl`](artifacts/Literature_Review/CA1/Revision_Protocol/study/coverage.jl) |
| 5 | Separately validate Julia/PythonCall/Mininet, the Cisco adapter and real inflight timing. | [`Interop/run.sh`](artifacts/Literature_Review/CA1/Emulation/Interop/run.sh), [`Step2/run.sh`](artifacts/Literature_Review/CA1/Emulation/Step2/run.sh), [`Step3/run.sh`](artifacts/Literature_Review/CA1/Emulation/Step3/run.sh) |
| 6 | Freeze a new emulation protocol; validate the envelope; execute the six ordinary/Q/V cells and audit raw packets. | [`Comparison/run.sh`](artifacts/Literature_Review/CA1/Emulation/Comparison/run.sh), [`Comparison/audit.py`](artifacts/Literature_Review/CA1/Emulation/Comparison/audit.py) |

The original limits were **two CPUs, hard 2 GiB RAM, zero swap, 120 seconds per whole job, and one local job at a time**. New emulation jobs use an explicitly authorized **130-second** ceiling after a retained Nix timeout; model deadlines remain unchanged. All other resource constraints, packet observation windows and scientific methods remain unchanged. Resource-audit threshold changes are explicitly recorded and checked. Treat an unexplained failure as a stop condition. Keep failed/partial records, warm-ups and primary observations distinct. Do not pool a new replication with the original rows or treat matched seed labels as identical draws.

See [REPRODUCIBILITY.md](REPRODUCIBILITY.md) for the distinction between original integrity verification, demonstrated new scientific-outcome replication and untested clean-OS portability. Full successful and failed records are separately frozen in the [v2.0.0 release](https://github.com/JCheney20/sdn-intent-update-study/releases/tag/v2.0.0).

## How to cite

GitHub's **Cite this repository** menu uses [`CITATION.cff`](CITATION.cff) for an overall citation. Choose the citation that matches what you used:

- **Both artifacts or integration code:** cite this repository, author and a fixed commit URL.
- **Model findings:** cite the bounded-handover artifact separately, including its source-manifest identity.
- **Packet-emulation findings:** cite the Cisco emulation artifact separately, including its different source-manifest identity.
- **Spotlight or the underlying consistency mechanisms:** cite their original authors/papers as well; this repository does not replace those sources.

Suggested plain-text repository citation:

> Cheney, J. M. (2026). *SDN intent-update study: bounded handover and Cisco emulation* (v2.0.0) [Source code, frozen research artifacts and replication evidence]. GitHub. https://github.com/JCheney20/sdn-intent-update-study/releases/tag/v2.0.0

BibTeX options for the two studies:

```bibtex
@misc{cheney2026boundedhandover,
  author = {Cheney, Justin Marc},
  title = {Bounded Original-Intent SDN Handover: Validation and Comparison Artifact},
  year = {2026},
  howpublished = {GitHub research artifact},
  url = {https://github.com/JCheney20/sdn-intent-update-study/tree/b05a1e02c40ea57f0b9ccb6112607c3e5f9cf305/artifacts/Literature_Review/CA1/Revision_Protocol},
  note = {Source manifest SHA-256 begins 7ca19f71f0d88d70; not independently peer reviewed}
}

@misc{cheney2026ciscohandover,
  author = {Cheney, Justin Marc},
  title = {Cisco SDN Handover Emulation: Frozen Protocol and Packet Evidence},
  year = {2026},
  howpublished = {GitHub research artifact},
  url = {https://github.com/JCheney20/sdn-intent-update-study/tree/b05a1e02c40ea57f0b9ccb6112607c3e5f9cf305/artifacts/Literature_Review/CA1/Emulation/Comparison},
  note = {Source manifest SHA-256 begins 906476a7eae8e12d; not independently peer reviewed}
}
```

No DOI has been minted for this repository or either local study. The DOI `10.5281/zenodo.12735280` identifies **Weintraub et al.'s upstream Spotlight artifact**, not this work. Repository publication makes the records locatable; it does not turn them into independently peer-reviewed results.

## Licenses and attribution

- **Original code, scripts and configuration:** [MIT](LICENSES/MIT.txt).
- **Original writing and original study records:** [CC BY 4.0](LICENSES/CC-BY-4.0.txt).
- **Spotlight sources and adaptations:** retain their CC BY 4.0 attribution and terms.
- **NetworkX source/derived Panther and BFS material:** retain the [BSD-3-Clause notices](artifacts/SDN_Model_Comparison/source_fidelity/sources/networkx-license-3.2.1.txt).
- External software dependencies and quoted/copied third-party material retain their own licenses. The author's grants do not relicense them.

Read [LICENSING.md](LICENSING.md) for file families, upstream provenance, modifications and distribution exclusions. The export omits third-party reading copies without confirmed redistribution permission, installed binaries, caches and Nix-store package trees.

AI coding models assisted implementation, bounded execution, analysis and documentation. Independent-implementation checks are engineering controls, not a claim of independent human experimental replication. The course manuscript and editorial records remain local.
