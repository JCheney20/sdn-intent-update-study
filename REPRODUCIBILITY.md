# Verification and reproduction boundaries

## What can be checked from this repository

Run `python3 -I -B verify.py` with Python 3.11 or newer. It verifies:

1. The two source-freeze identities and every input hash declared by those manifests.
2. Every file in the model's 628-entry output seal and emulation's 2,041-entry output seal, including relative paths into retained emulation runs.
3. Every exported file against `EXPORT.json`, with no unlisted files inside `artifacts/`.
4. The model's 92 primary rows, 12 cells and 576 sensitivity / 48 benchmark accounting; emulation's six cells, 30 episodes, 45 packets and recorded packet outcomes.

No run is launched. No source, result, manifest or attempt record is rewritten. Integrity checking is not independent experimental replication, proof of deployed-switch fidelity, or certification that every claim is correct.

## Original execution environment

The model used Julia 1.13.1 and a pinned Python 3.11.7 reference environment, including NumPy 1.26.2 and NetworkX 3.2.1. The separate packet study used Mininet 2.3.1b4, OVS 3.2.1 userspace forwarding and PythonCall 0.9.37. The retained manifests, lock files, setup reports and receipts document the exact versions and boundaries. Original jobs were local, serialized, limited to two CPUs, hard 2 GiB memory, zero swap and 120 seconds per whole job.

The original launchers intentionally enforce one-attempt primary execution and environment/source gates. They are not instructions to overwrite or retry the recorded primary cells. New replications need new output locations and a separately declared protocol. No replication was run to prepare this export.

## Why the original launcher is not a portable entry point

- Model/reference launchers verify an earlier 194-file study plus two course-context snapshots. This release includes the required earlier detector module and its upstream provenance, not that entire earlier package. The private context includes assessment identifiers and is deliberately not published. The original historical-seal gate will therefore refuse execution here. It has not been weakened or silently patched.
- Original manifests and runtime checks include machine-specific Nix-store paths, cgroup properties, namespace assumptions and saved absolute execution paths. Saved paths identify the original run, not paths guaranteed to exist on another machine.
- Installed packages, mutable caches and Nix-store symlinks are not vendored. The original Julia/PythonCall package-directory links must be reconstructed from their pinned sources if a new execution environment is prepared.
- Some historical audit routines expect original absolute attempt locations or write their reports beside frozen inputs. Do not run them over the distributed evidence merely to inspect it. The read-only top-level verifier avoids those operations.

Consequently this is an inspectable source-and-evidence release, **not a demonstrated clean-machine or one-command reproduction**. Its missing private historical context does not prevent independent inspection of the two current studies' declared sources, retained raw outputs and seals. A future portable replication wrapper must be identified as new code and must not be confused with the frozen experiment code.

## Interpreting the evidence

The model's bounded packet exploration and finite emulation observations have different scope. Cache-construction seed labels do not identify common random draws between implementations. Reusing a validated exact-plan fingerprint is not an independent safety replication. Warm full-snapshot search, cold process totals, logical rounds and packet-service milliseconds are distinct quantities.

The Cisco emulation has artificial residence time and fixed Q/V waits, a shared host and experimental userspace forwarding. It does not establish a hardware timing bound, production endurance, an SLA or correctness under arbitrary congestion. Failure/partial records are retained rather than rewritten as successes.

## Archive and distribution policy

The public tree excludes paper drafts, rendered paper copies, editorial/prompt records, obsolete typesetting attempts, TeX caches and unrelated proposals. Required sealed code/result snapshots remain, even when repeated, because deduplicating their paths would invalidate the original output manifests. Git can store identical file contents efficiently; visual tidiness does not justify changing scientific seals.

The original local workspace is the historical archive. Its earlier status notes and absolute paths remain historical, not current publication instructions. Public files are byte-preserving copies; `EXPORT.json` records their original relative locations. No local frozen artifact was deleted or edited by export preparation.
