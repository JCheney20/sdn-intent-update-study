# Frozen replication evidence · v2.0.0

These are **new replication records**, not replacements for the original frozen evidence in [`artifacts/`](../artifacts/). The manuscript's original numeric results remain unchanged. Both successful campaigns used separate clean Git checkouts on the same recorded NixOS host; neither is an independent human or clean-OS replication.

| Campaign | Outcome | Emulation job ceiling | Largest recorded emulation job |
|---|---|---:|---:|
| [Native 005](native-run-005/COMPARISON.json) | PASS | 120 s | 101.215 s |
| [Nix 006](nix-run-006/COMPARISON.json) | PASS | 130 s | 102.709 s |

Both reproduce all **92 non-timing primary model rows**, **576 sensitivity records**, fixed-event coverage, **16 plan identities**, **48 benchmark jobs**, **44,800 replay checks**, and **227,590 Cisco / 601,999 fat-tree controller checks**. Their six packet cells match the original non-timing outcome/action/resource-row fields: **30 episodes / 45 packets**, with the **3,707-check packet audit** and actual duplicate refusal. The new public-provenance model audits report 1,760 checks; do not substitute that number for the original 1,762-check audit. All originally required scientific checks remain in the unchanged audit implementation; the new public source/provenance manifest differs.

Timing equality is neither required nor claimed. Wall-clock variability is not proof that Nix caused the earlier slowdown. The native route used a separately installed hash-locked Python environment without Nix evaluation or realization; supplied Julia/Linux binaries could still be Nix-built. A clean non-Nix operating system has **not** been validated. Tested coordinator commit IDs are recorded separately in [`INDEX.json`](INDEX.json); the successful native campaign preceded the later resource-profile amendment.

## Download and verify the complete records

The [v2.0.0 release](https://github.com/JCheney20/sdn-intent-update-study/releases/tag/v2.0.0) contains one `.tar.gz` asset per retained campaign, plus `SHA256SUMS`. Download all eight archives into a directory outside the checkout, then run:

```sh
python3 -I -B replication-results/verify_archives.py /path/to/downloaded-assets
```

[`INDEX.json`](INDEX.json) provides exact download URLs, archive sizes/hashes, per-file inventories, tested commits and status explanations. The verifier checks every archive and member without extracting or executing anything. Browse the two successful campaigns' comparison reports, primary model CSV, benchmark summary, model audit and packet results directly in their directories here. Full raw jobs, source snapshots, manifests, attempted phases, adaptations, environment bindings, stdout/stderr and audit receipts are in the release archives. Absolute paths in those records describe the execution host; they are provenance, not paths a new user must recreate.

Archives are byte-preserving copies. Mutable depots/runtime caches, Python caches and installed-package/runtime symlinks are excluded. All source and scientific-output files covered by each successful campaign's `REPLICATION_OUTPUTS.sha256` are retained. External runtime binaries are not included; versions/hashes and setup requirements are recorded, and pinned Julia/Mininet source dependencies are supplied in [`replication/vendor/`](../replication/vendor/).

## Retained failures and prepared-only workspaces

The archives also retain `native-run-001` (prepared only), `nix-run-001`, `nix-run-002`, `native-run-003`, `native-run-004` and `nix-run-005`. These are **not** successful replications. They document, respectively, an uncompleted initial workspace, a fresh-trace checksum binding error, a missing vendored MacroTools data file, private-`/tmp` visibility failures, and a 115-second inner-deadline timeout at the fifth packet primary cell. Later bridge-only diagnostics in Nix 005 are controls, not primary retries. The failed cell remains failed even though a partial result file exists.

The author approved a **130-second new emulation whole-job ceiling** after that timeout. Nix 006 used a new workspace, new manifests and a complete new campaign. Two CPUs, hard 2 GiB memory, zero swap and serialization were retained; original model deadlines remain unchanged. The sole protected audit-source change is its resource predicate from 120 to 130 seconds. The verifier normalizes exactly that predicate and rejects any other computational/measurement change. The original evidence and its 120-second profile remain untouched. See the [declared protocol](../replication/PROTOCOL.md) and Nix 006's [resource profile](nix-run-006/RESOURCE_PROFILE.json).

Repository [licensing and third-party rights](../LICENSING.md) apply to these archives as well. They contain research records, not the manuscript, course instructions or editorial conversations.
