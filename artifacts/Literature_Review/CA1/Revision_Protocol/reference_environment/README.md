# Nix reference environment

**Current status, 26 October 2026: cached runtime components/imports, original-artifact observability/replay and the authorized bounded three-stage study are complete.** See [the replay report](../reference_capture/Reference_Replay_Report.md) and [completion report](../study/Completion_Report.md). `Setup_Status.toml` remains the frozen provisioning/import checkpoint, not a live project-progress file. No source compilation, uv, pip, venv, global profile update or system rebuild was used.

## Selected environment and recorded adjustment

Initialized with the author's requested `nix flake init -t github:nix-community/templates#python`, template revision `f7c00bd957e47e349b45ba94ba6143163a82306f`. Removed the example application and automatic direnv hook; the template's Python 3.12/unstable defaults were not reference-compatible.

The first locked Nixpkgs revision matched the initial 12 package pins, but its exact native package outputs were not available from any of six configured caches. Those inputs and probe results are retained in `revision_search/original-7f7306271be20e53f3d9bdc0aafc3a93be4314f5/` and [cache_probes](cache_probes/README.md).

The author then selected **Find cache-backed revision**, preserving the artifact package versions. Selected revision: **`dddccde11a6c6be45f58a76828a5f48d58262e9a`**, 19 January 2024. This changes the chosen interpreter from **Python 3.11.6 to 3.11.7**, still within the artifact's specified 3.11 series. The source did not identify an exact original Python patch; neither patch is claimed to recover it.

- NumPy **1.26.2**, NetworkX **3.2.1**, Matplotlib **3.8.2** unchanged.
- The full Nix dependency expansion revealed two additional Pillow dependencies: **olefile 0.46** and **defusedxml 0.7.1**. Both also match the artifact requirements. The metadata/runtime checks now cover **14 package pins**, rather than the original 12.
- The expansion also includes Tkinter **3.11.7**, a Python standard-library component. There are **16 Nix runtime components** including Python and Tkinter, covered by the recorded **65-path store closure**.

All 16 exact component outputs were advertised by the official cache. `nix copy --from https://cache.nixos.org/` with `require-sigs = true` copied their runtime closures; no builder was invoked. Project-local indirect GC roots retain the Matplotlib and NetworkX closures, which together cover all 16 components. No new cache or trusted key was added.

## Runtime composition, not an uncached wrapper build

The flake still declares the normal `python.withPackages` environment/dev shell. Its combined wrapper derivation was **not built**. To avoid any build while retaining the identical expanded package list, `referenceComponents.json` records `requiredPythonModules` from the same Nixpkgs function that `withPackages` uses.

[`run_reference.py`](run_reference.py) launches the cached interpreter with Nixpkgs' own **`NIX_PYTHONPATH`**/`sitecustomize` mechanism and those exact component directories. It installs or mocks nothing. It checks frozen metadata hashes and actual cgroup CPU/RAM/swap/affinity constraints before execution, disables user/cwd package injection, fixes Python hash seed 0 and math-library thread settings, and keeps Matplotlib configuration under the project.

The actual reference process uses a scrubbed Python environment plus `-s -P -B`. It deliberately does **not** use `-I`, because `-I` would ignore `PYTHONHASHSEED`. Runtime checks confirm the intended flags, hash seed and import paths. The outer host-Python launcher may itself use `-I`; it only parses metadata and execs the locked interpreter.

**Do not infer that `nix develop`/the default combined package was built or that arbitrary daemon builds have resource limits.** Shared-daemon work does not automatically inherit client cgroups. Source compilation remains unauthorized. Binary cache copying and all reference test clients were scoped; the reference process itself verifies its inherited hard limits.

## Executed checks

- [`verify_versions.py`](verify_versions.py): frozen input hashes, selected Python/Tkinter series and all 14 package versions versus the sealed artifact requirements.
- [`check_runtime.py`](check_runtime.py), through the bounded launcher: real NumPy, NetworkX and `matplotlib.pyplot` imports; exact distribution versions; no ambient site-packages; Agg backend; a fixed RandomState/numeric check and a graph-path check. Result: **PASS**.
- Effective runtime limits: hard **2 GiB**, **zero swap**, CPU quota **200000/100000**, affinity **0,1**. Memory peak at the checkpoint: **142,860,288 bytes**. This is an import validation observation, not a benchmark.
- A launch outside a bounded COS738 scope was refused before the Nix interpreter ran.
- NumPy's `show_config()` emitted a non-fatal suggestion to install PyYAML for prettier output. The complete native configuration was recorded without installing that unnecessary formatting dependency.

Evidence: `realization/runtime_check.json`, `runtime_check.*.log`, `runtime_source.sha256`, `closure.json`, cache-copy logs and `revision_search/dddccde11a6c6be45f58a76828a5f48d58262e9a/cache.nixos.org/`. Native compiler/BLAS/platform information is retained. Nix-specific patches/native libraries are not claimed byte-identical to the artifact's original pip/Docker environment.

Metadata-only check:

```sh
python3 -I -B verify_versions.py
```

Example bounded runtime recheck, from this directory (one local job at a time):

```sh
timeout --kill-after=1s 120s systemd-run --user --scope \
  --unit="cos738-reference-$(date +%s)" \
  -p MemoryMax=2147483648 -p MemorySwapMax=0 -p CPUQuota=200% \
  timeout --kill-after=1s 118s taskset -c 0,1 \
  python3 -I -B run_reference.py "$PWD/check_runtime.py"
```

The scientific runner must keep its single-job lock and retain per-attempt receipts. This example is not primary-experiment authority or a replacement for capture/replay manifests.

## Subsequent executed gates

The unchanged original helper and instrumented capture agree; strict Julia replay passed 44,800 assertions and corruption controls. Controller validation subsequently passed, followed by the fixed native sensitivity, matched full-snapshot costs and 12 one-attempt primary cells. Native sampling/tie adaptation is **not** established equivalent: k=3 cases change decisions and qualification. No new provisioning is needed for these completed results, and the combined wrapper remains unbuilt. See [the current completion report](../study/Completion_Report.md).
