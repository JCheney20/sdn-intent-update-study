# Stage 1 progress and reference-environment prerequisite report

**Historical interim report. Current update, 26 October 2026:** provisioning, source-slot/controller integration, independent controller validation, executed Python replay and all authorized Stage 3 jobs are now complete on the bounded domain. See [the completion report](study/Completion_Report.md). The prerequisite blockers, open integration items and next-work list below describe the earlier checkpoint and are retained for provenance, not current obligations. General deployment/load/predicate guarantees remain out of scope.

25 October 2026. This is an interim update, not completion of all three stages. Authority and prospective stage design: [Three_Stage_Execution_Plan.md](Three_Stage_Execution_Plan.md). The aggregate runtime ceiling is removed; earlier reservation totals remain documentary only. The hard per-process resource contract remains enforced.

## Key findings

### 1. Actual joint Q/V comparison passes on the targeted domain

The earlier 120 joint cases ran only in the standalone checker. New [`lifecycle.jl`](lifecycle.jl) independently enumerates two packet events interleaved with switch commands using the numeric candidate adapter. [`validation/lifecycle_checks.jl`](validation/lifecycle_checks.jl) compares its complete per-round joint packet-edge sets, boundary-packet sets and acknowledged tables with the raw string-row oracle's causally nested views.

| Fixture | Joint Q/V cases | Joint boundary-state visits | Per-round joint packet edges | Lifecycle assertions, including component controls |
| --- | ---: | ---: | ---: | ---: |
| Cisco | 56 | 7,620 | 7,564 | 21,229 |
| Fat tree k=4 | 64 | 14,172 | 14,108 | 39,710 |

**60,939 lifecycle assertions passed.** Both ordinary-update joint negative controls retain wrong old-packet delivery. The same process reran and passed the previous 198,972 single-probe differential assertions and 2,592 standalone assertions. Counts include repeat states/terminal self-loops and are not independent statistical samples.

This covers the previously declared targeted old/new position/arrival combinations, not every possible pair of request arrival times or all controller event microstates. The numeric joint engine shares its own forwarding primitive with the numeric single-probe engine; its expected transitions come from the separate raw-row oracle, not that primitive.

### 2. The source-side slot is now explicit

The new component stores one pending request with an explicit identity, original arrival and immutable packet record. An additional outstanding request receives an explicit `outside_domain` disposition; it neither overwrites the first request nor counts as admitted/delivered service. Admission releases the slot once and preserves the original arrival and authorization history. Duplicate identities and the wrong physical source are rejected.

Controls distinguish lost pending requests, arrival reset, duplicate admission and a monitor-destination/authorization-aware withholding mutation. The physically identical request's authorization metadata cannot alter its admission/tag assignment. These are bounded component tests against independent raw-packet expectations, not an arbitrary-load queue/throughput guarantee. Queue unit tests use closed/open table frames; the full queue object is not yet integrated into every controller/interleaving trace. Keep that remaining integration obligation visible.

### 3. Removed-edge history is now a lifecycle component

The new component records actual tag-0 row removals at acknowledgement and retains each `(switch, incoming, outgoing)` edge through H complete subsequent rounds. Tests independently reconstruct removals from oracle row differences throughout both Q/V plans, check every opening-boundary expiry state, distinguish one-round-early expiry and require eventual empty history.

This extends the previous scalar expiry check. It does **not** mean a full CCG-inspired scheduler has been independently validated. Its use of this history to admit work, its progress/blocked behavior and its controller traces remain to implement/check.

### 4. Original Python replay is blocked by prerequisites, not by the new runtime policy

The metadata-only environment inspection ran inside the verified scope, in Python isolated mode. It imported no third-party packages and executed no artifact code.

| Requirement | Required by pinned artifact inputs | Inspected default environment |
| --- | --- | --- |
| Python | 3.11 series in Dockerfile and Nix flake | 3.15.0rc2 |
| NumPy | 1.26.2 | Missing |
| NetworkX | 3.2.1 | Missing |
| Matplotlib | 3.8.2; imported by unmodified detector | Missing |

The artifact does not pin an exact Python patch in these files. A provisioned 3.11 patch/build must therefore be explicitly frozen and disclosed, not described as a recovered exact original interpreter. Transitive distributions/import compatibility remain to verify. No suitable Python 3.11 was found on PATH or in the inspected local interpreter cache/store locations; this is not a claim that every filesystem location was searched.

The environment job's top-level `PASS` means the inspection and resource/seal checks succeeded. Its scientific prerequisite result is **`BLOCKED_PREREQUISITES`**, not a successful Python replay or even successful reference imports.

## Adjustments made

- Recorded the author's three-stage authorization separately, preserving earlier approval records. Removed the cumulative accounting stop; retained immutable documentary limit tickets and measured CPU/elapsed/memory fields for reproducibility.
- Preserved the old launcher/entry point under SHA-named snapshots, then passed a new effective-limit preflight before the changed jobs.
- Added the numeric joint engine, explicit source slot and complete removed-edge history component rather than treating the previous standalone/scalar checks as sufficient.
- Wrote a prospective sensitivity/primary/benchmark design before those outcomes. The study remains on the two original-intent artifact fixtures; no eight-switch reconstruction or topology expansion. Native-RNG sensitivity is descriptive, not a population-equivalence claim.
- No scientific repair was required after these new checks: the added lifecycle suite passed on its first bounded invocation. No primary/sensitivity/benchmark jobs have started.

## Evidence

- [New-authority preflight receipt](validation/runs/cos738-revision-1792952421595315587/receipt.toml).
- [Environment inspection receipt](validation/runs/cos738-revision-1792952428981839853/receipt.toml) and [dependency metadata](validation/runs/cos738-revision-1792952428981839853/reference_environment.toml).
- [Joint/lifecycle receipt](validation/runs/cos738-revision-1792952659335178875/receipt.toml) and [execution log](validation/runs/cos738-revision-1792952659335178875/output.log).

The lifecycle process took 23.55 seconds including startup; scope CPU was 23.013001 seconds and checkpoint memory peak 311,005,184 bytes. Effective limits remained two CPUs/quota plus affinity, hard 2 GiB, zero swap and one Julia worker, with a 120-second process ceiling. These are validation observations, not matched performance results. Historical sources/results remain sealed.

## Provisioning decision — subsequent update

The author has now approved isolated reference provisioning and explicitly selected **a Nix flake instead of uv**. The earlier proposal below is retained for scope/history; the uv implementation choice is superseded. See [the Nix setup](reference_environment/README.md) and [provisioning authority](reference_environment/Provisioning_Approval.toml). The flake is initialized/locked and all 12 checked package-version pins match. The full cache-availability dry run hit the 120-second limit. Subsequent bounded requests now confirm that the exact NumPy/NetworkX/Matplotlib outputs are absent from all six configured caches and locally; Python is advertised in the official cache. The author subsequently selected a cache-backed revision search. A matching January 2024 revision now supplies all 16 runtime components from cache; Python 3.11.7 and real imports/all 14 checked package pins passed in a bounded process, with no source builds. The two additional checked pins are propagated Pillow dependencies already pinned by the artifact. The default combined wrapper remains unbuilt; an explicit bounded Nix-path launcher uses the same dependency expansion. See [the current setup report](reference_environment/README.md) and [the retained original cache evidence](reference_environment/cache_probes/README.md). Artifact observability/replay is still pending. No source compilation, global profile change or artifact run occurred.

Originally proposed scope:

- A project-local managed Python 3.11 interpreter and virtual environment, with the exact patch/build/hash recorded before reference execution.
- NumPy 1.26.2, NetworkX 3.2.1, Matplotlib 3.8.2 and their required transitive dependencies pinned from the artifact requirements; record wheel/source provenance and hashes. Do not install the artifact's unrelated Jupyter/notebook environment by default.
- **Superseded method:** use the already installed `uv` tool. **Selected replacement:** project Nix flake with immutable inputs/lock and standard Nix-store downloads; no root/system rebuild/global profile changes or modifications to originals. Download interpreter/package artifacts only; no remote compute or publication.
- Stop and ask if a required pin cannot be obtained compatibly without source compilation, changing a pin or widening the dependency scope. Experimental reference runs remain offline after provisioning.

## Next work, in order

1. Integrate the explicit slot/history components with actual controller traces. Implement and independently check the ordinary lifecycle, progress/blocked outcomes and the declared CCG-inspired scheduler; then guard-only and detector-guided/guarded decisions with counted fallbacks and capacity refusals. Stage 1 remains open until this is done.
2. If provisioning is approved, establish and freeze the isolated reference environment while Stage 1 work continues. Then capture uninstrumented/instrumented reference behavior, verify observability, and implement strict walk/count/tie/detector replay with corruption controls.
3. Only after correctness and replay gates pass, freeze machine-readable stage-3 sources, grid, seeds, attempt policy and exact timed calls. Execute the authorized descriptive sensitivity, matched overlapping-component benchmarks and revised primary comparison. Retain all failed/incomplete attempts and report qualification before cost.
