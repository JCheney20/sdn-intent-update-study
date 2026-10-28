# Verification and reproduction boundaries

## 1. Verify the frozen original evidence

Run `python3 -I -B verify.py` with Python 3.11+. No experiment, installation, Julia, Nix or network isolation is needed. It checks the two original source freezes and every declared input; the model's **628-entry** and emulation's **2,041-entry** output seals; all **2,954** exported scientific files; vendored-source and release checksums; and fixed original study accounting. It also checks the published replication comparison summaries. Integrity is not independent replication or a general correctness proof.

The original model used Julia 1.13.1 and Python 3.11.7, including NumPy 1.26.2 and NetworkX 3.2.1. The packet study used Mininet 2.3.1b4, OVS 3.2.1 userspace forwarding, PythonCall 0.9.37 and CondaPkg 0.2.38. Original jobs were serialized with two CPUs, hard 2 GiB memory, zero swap and 120-second whole-job limits. No original file, failure, consumed attempt or seal was changed for this release.

## 2. Execute new replications

Use the new [`replication/README.md`](replication/README.md) instructions and [declared protocol](replication/PROTOCOL.md). Do not execute historical launchers over frozen results or delete their attempt ledgers.

The new layer supplies:

- The actually imported public historical detector dependency and attributed upstream snapshots. It replaces reliance on a full earlier 194-file package and two private assessment-context snapshots with an explicitly labelled public dependency manifest, not a counterfeit original delivery manifest.
- Pinned runtime subsets of 16 Julia packages, including required package data, and Mininet Python sources/notices; `VENDOR.json` hashes every included file.
- A hash-locked CPython 3.11/x86_64 Linux package environment and Nix-resolved pinned component route, with actual version/import checks. Nix cache realization forbids local native builds. Native Python extensions come from wheels; Olefile's pure-Python source ZIP is separately hash-locked.
- Explicit interpreter, shared-library and native-tool bindings; external executable/library hashes; fresh outputs, source freezes, manifests, phases and attempt records. Runtime binaries remain external prerequisites, not bundled software.
- Private network/user/PID/mount namespaces, read-only sysfs/proc-sys, and actual path/packet doctor controls. A namespace-local descriptor binding restores declared temporary-directory inputs without removing the original private-`/tmp` boundary.
- New model/controller validation, capture/replay, catalogue, sensitivity/benchmark/primary grid, packet controls/timing/envelope/primary cells, audits, duplicate refusal and final non-timing comparison. No selective primary retry or unbounded fallback exists.

All launcher/provenance changes are recorded as source hashes and diffs. Computation, packet handling, waits, observation windows and measurement logic remain unchanged. After a retained Nix timeout, the author approved **130 seconds for new emulation jobs**. The wrapper reserves cleanup time using a 125-second process deadline, 128-second shell deadline, and TERM at 129 seconds followed by KILL one second later. Resource-audit predicates change from 120 to 130 seconds only; the protected packet auditor is otherwise required to match byte-for-byte. Two CPUs, hard 2 GiB, zero swap and serialization remain unchanged. Original model-job deadlines remain at 120 seconds or less. This is a declared replication-profile difference, not reproduction of the original timing budget.

## 3. What has actually passed

Separate clean-checkout **native 005** (120-second profile) and **Nix 006** (new 130-second emulation profile) campaigns completed on the same recorded NixOS host. Each reproduced **92 non-timing model rows**, **576 sensitivity records**, fixed-event coverage, **16 plan identities**, **48 benchmark jobs**, **44,800 replay checks**, **227,590 / 601,999 controller checks**, and all **six emulation cells / 30 episodes / 45 packets**, with the **3,707-check packet audit** and duplicate refusal. The public-provenance model audits report 1,760 checks; the original 1,762-check audit remains distinct. Timings were not required to be identical and were not pooled with original measurements.

See [`replication-results/`](replication-results/README.md) for the frozen comparisons, tested coordinator commits and exact archive/member hashes. Full successful and failed records are [v2.0.0 release assets](https://github.com/JCheney20/sdn-intent-update-study/releases/tag/v2.0.0). `replication-results/verify_archives.py` checks downloaded files without extracting or executing them.

The native route used a separately installed hash-locked Python environment and no Nix evaluation/realization commands, but externally supplied Julia/Linux binaries could still be Nix-built. **No clean non-Nix OS, arbitrary hardware, independent human replication or one-command dependency provisioning has been demonstrated.** Both routes require a compatible x86_64 Linux host, exact runtimes, working cgroup v2/systemd user scopes, CPUs 0/1 and unprivileged namespaces. Cache/runtime unavailability or an unsupported host is a blocker, not permission to change versions or resource controls.

## Interpretation and archive policy

Bounded model coverage, native sampling, warm snapshot searches, cold process totals, logical rounds and finite packet-service measurements are different evidence domains. Matched seed labels are not common random draws. Exact-plan reuse is not an independent safety trial. Artificial residence, fixed Q/V waits and userspace OVS establish no hardware timing bound, production endurance, arbitrary-congestion guarantee or SLA. Timing variability does not establish that Nix itself caused a slowdown.

The public release excludes manuscript drafts, editorial/prompt records, course instructions, student contact details, mutable depots/caches and installed-software symlinks. Scientific snapshots remain in their sealed locations even when repeated. Full new-record archives omit only runtime caches/installed links, preserve source/scientific outputs and retain failures as failures. Historical absolute paths are provenance, not required future paths. Third-party works remain subject to their own attribution and redistribution rights; this repository does not replace their original publications.
