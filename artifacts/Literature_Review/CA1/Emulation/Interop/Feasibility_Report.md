# Step 1: Julia → PythonCall → Mininet → OVS

26 October 2026. **PASS for the declared feasibility controls on this isolated userspace backend.** The author approved Step 1 of the agreed plan. No Cisco adapter, ordinary/Q/V comparison or new primary experiment was executed.

## Decision

Use the Julia-led Mininet route for the next adapter-validation stage. A separate Julia-direct topology fallback is not presently needed. This decision concerns orchestration feasibility and reproducibility, not which implementation is faster. Mininet remains Python internally; Julia owns the top-level lifecycle and invokes its actual API through PythonCall.

## Environment and provisioning

| Component | Pin / source |
|---|---|
| Julia | Existing underlying Nix binary, 1.13.1 |
| PythonCall | 0.9.37, immutable commit/NAR hash in `flake.lock` |
| CondaPkg | 0.2.38, forced **Null/offline** |
| Python | Existing Nix Python 3.11.7 |
| Mininet | Nix Mininet 2.3.1b4, including its separate `py` output |
| Open vSwitch | Existing pinned 3.2.1, `datapath_type=netdev` |
| Other native tools | Pinned entries in `Components.json`, supplied by signed Nix cache |

The child [flake](flake.nix) leaves the original emulation/reference pins unchanged. Linux binaries and Mininet's Python output were copied from the official cache with signatures required, empty builders and `max-jobs=0`. Julia package **source** trees were fetched as explicit Nix flake inputs, not misrepresented as signed binary-cache outputs. Sixteen source trees are locked by commit and NAR hash in [flake.lock](flake.lock); [JuliaSources.json](JuliaSources.json) records their store paths. Normal Julia JIT is used, but no native package source build or global package/profile change occurred.

A standard Julia package-directory environment (`Packages/`, first on `JULIA_LOAD_PATH`) exposes those exact source trees. `Project.toml` supplies exported preferences, including the Null backend. No `Pkg.add`, `Pkg.instantiate`, pip, Conda environment, uv or automatic interpreter installer is used. Inactive optional MicroMamba/Pixi backends are not provisioned or imported; assertions check they were not loaded. Package/source GC roots are retained under `gc_roots/`. This is a deliberately restricted runtime, not an unrestricted general Julia package environment.

## Executed checks

| Check | Observed result / evidence |
|---|---|
| Real embedding and module import | [Bridge smoke](../runs/cos738-ovs-pythoncall-import-1793014645892112702/bridge_smoke.toml): actual PythonCall 0.9.37, pinned Python, real Mininet module, Null backend and repeated calls in one interpreter |
| Topology creation through Julia | Julia calls `Mininet`, `addHost`, `addSwitch`, `addLink`, `build` and `start`; one switch and two real hosts, not stand-in topology objects |
| Host isolation | Distinct host network namespaces, separate from the switch's private parent namespace; outer user, PID and mount namespaces are also private |
| OVS backend | Readback confirms `netdev`; private OVSDB and foreground ovs-vswitchd, no host service or kernel module |
| Readiness | Imports, topology setup and an actual ping/command warm-up finish before the prototype's readiness marker |
| Packet forwarding after readiness | Actual Mininet ping succeeds in both directions, 2/2 received; Julia and embedded Python remain in the same process |
| Gate/drop control | An OpenFlow 1.4 bundle installs DROP; a subsequent ping reports zero received; restoring forwarding restores connectivity |
| Tag and packet observation | A uniquely identified Ethernet frame crosses the Mininet-created link and arrives in h2's namespace with VLAN ID 101; raw bytes and receive metadata retained |
| Normal cleanup | Mininet interfaces removed, node shell processes reaped, private OVS daemons exited |
| Failure-path cleanup | Deliberate post-readiness exception leaves the result **FAIL**, but confirms interface removal, node reaping and daemon exit |
| Unbounded invocation | `run.sh` refuses before executing the network entry point; logs retained under `verification/unbounded.*` |
| Integrity/resources | Read-only verifier passes **122 checks**, including source bindings, pins, GC roots, expected dispositions and hard limits |

The first complete network pass is [run 1793015266155977570](../runs/cos738-ovs-mininet-network-1793015266155977570/network_smoke.toml). After adding explicit failure-path verification, the final positive is [run 1793015519428636501](../runs/cos738-ovs-mininet-network-1793015519428636501/network_smoke.toml), with [resource receipt](../runs/cos738-ovs-mininet-network-1793015519428636501/receipt.json): **58.012 seconds** whole command, **465,674,240 bytes** checkpoint peak, quota 200000/100000, affinity 0,1, 2 GiB maximum and zero swap. No timeout extension was used.

The intentional negative is [run 1793015577639407271](../runs/cos738-ovs-mininet-cleanup-negative-1793015577639407271/network_smoke.toml): expected exit 1 after readiness, with all three cleanup checks true. This remains a failure record rather than being rewritten as a passing network job. A successful feasibility verdict requires distinguishing this deliberate control from unexpected failures.

`packet_io.py` performs only raw packet send/receive inside a Mininet host. It does not create the topology, choose update phases or substitute a Python controller. Linux packet AUXDATA preserves VLAN evidence when receive offload strips an inline tag.

## Isolation and retained limitations

The launcher uses unprivileged user + network + PID + mount namespaces. UID zero inside maps only to host UID 1000. A private tmpfs protects `/tmp`; private sysfs reflects the private network; `/proc/sys` is read-only. No `mn -c`, global killall, host interfaces/routes/firewall, sudo or host-root access is used. Normal and injected-error paths were checked; the enclosing scope also kills residual descendants on termination. No active COS738 scope remains after the checks.

Mininet's upstream `fixLimits()` prints a resource-tuning warning because its generic sysctl tuning is not allowed through the protected mount. The warning is retained, not suppressed. The actual inherited CPU/memory/swap/time limits are independently checked by the scope entry and receipt. This does not establish tuned throughput or load performance; later traffic experiments must account for default buffers and the enforced resource envelope. The Node/Mininet library source is unchanged.

OVS userspace without DPDK is upstream-labelled **experimental**, and the pinned Mininet version is a beta-labelled release. The passing test is real forwarding over virtual links, not kernel OVS, hardware/TCAM validation or a guarantee over all schedules. Bundle acceptance and packet readback do not prove universal concurrent packet atomicity. This remains a feasibility test on a tiny topology, not the Cisco experiment.

## Adjustments and unsuccessful attempts

All unsuccessful jobs are retained under `../runs/`:

1. `pythoncall-import-1793014376898207509`: an explicit Julia project shadowed the package-directory source environment. It reported PythonCall not installed. Putting the locked package directory first, while retaining the project for preferences, fixes source lookup without downloading through Pkg.
2. `pythoncall-import-1793014423546013501`: the system Julia launcher **overwrites** `JULIA_PYTHONCALL_EXE` with `@PyCall`, injects Python 3.14 environment settings and appends a global depot. A diagnostic confirmed the override; it was not a missing reason to install PyCall. The new launcher uses the existing underlying Julia 1.13.1 binary with explicit pinned Python/libpython and scrubbed Python variables. No system wrapper was edited.
3. `mininet-network-1793015131511241384`: real topology, ping, drop and recovery worked, but Mininet's `popen` rejects a Julia list wrapper where it explicitly requires a Python list. The API boundary now uses `pylist`. The harness was also moved into a function to remove Julia soft-scope ambiguity and ensure the cleanup handlers retain their actual objects. The failed job remains retained; the enclosing scope/namespace provided teardown.

These were environment/API/harness corrections before any scientific experiment freeze. No topology population, seed, ordinary/Q/V algorithm or scientific result was selected or tuned by them. Julia standard-library Markdown binding warnings are also retained in logs.

## Warm-start interpretation

The feasibility run demonstrates an actual resident Julia process with an embedded Python interpreter surviving topology setup, warm-up, packet/control calls and teardown. In the final run, first imports took **42.860 seconds** under `--compiled-modules=no`; this is a startup observation, not a latency benchmark. The earlier warmed snapshot component benchmark remains a different measurement.

Warm-up before readiness is therefore implementable in this route. It still does not establish sustained production performance or that every future controller branch is warm. The full Cisco adapter's relevant paths, readiness, process lifetime, update timing and restart costs must be declared before its experiment freeze. Do not use tiny repeated bridge-call timings or this smoke test to claim PythonCall overhead is negligible for every workload.

## Reproduce or verify

From the enclosing `Emulation` directory, using the already provisioned pins:

```sh
bash scope.sh pythoncall-import bash "$PWD/Interop/run.sh" bridge
bash scope.sh mininet-network bash "$PWD/Interop/run.sh" network
```

Both are feasibility invocations, not primary attempts. `run.sh` refuses an unbounded direct invocation. To regenerate the package-directory links on an already provisioned copy, link each name in `JuliaSources.json` into `Packages/`; do not invoke an automatic package installer. Reproduction on another host requires the same isolation/capability checks and tool realization, not only these shell commands.

Read-only artifact verification, from `Interop`:

```sh
python3 -I -B verify_step1.py
```

[Environment_Manifest.sha256](Environment_Manifest.sha256) binds the current source/pin configuration; [verification/step1_checks.txt](verification/step1_checks.txt) retains the verifier output. Per-job snapshots preserve earlier code and logs. The original 628-file model-study output seal and its 194+2 historical context entries were rechecked successfully by `CA1/check_manuscript.py` and remain unchanged.

## Next authorized-plan boundary

Step 1 is complete. The next activity is **Step 2: Cisco adapter validation** using the selected Julia/PythonCall/Mininet route. Import and check the original physical topology, ingress-sensitive rules, source queue and version/gate encodings before any scientific grid is frozen. Keep the 120-second job ceiling; the current small-topology run fitting does not promise the full adapter will fit without review. No Cisco method result or new emulation performance claim enters the manuscript at this stage.

## Primary references inspected

- [PythonCall guide: existing Python / Null backend](https://juliapy.github.io/PythonCall.jl/stable/pythoncall/#If-you-already-have-Python-and-required-Python-packages-installed), plus pinned v0.9.37 `Project.toml` and `src/C/context.jl`.
- [PythonCall v0.9.37 release](https://github.com/JuliaPy/PythonCall.jl/releases/tag/v0.9.37), pinned in the flake rather than using an unversioned dependency.
- [Mininet source](https://github.com/mininet/mininet/tree/2.3.1b4), especially `net.py`, `node.py` (`OVSSwitch` user datapath and `popen`) and `util.py` (`fixLimits`). Installed source was inspected for the actual pinned version.
- [Nixpkgs Mininet derivation](https://github.com/NixOS/nixpkgs/blob/dddccde11a6c6be45f58a76828a5f48d58262e9a/pkgs/tools/virtualization/mininet/default.nix): separate native and Python outputs.
- Version-matched OVS userspace limitations remain linked in the enclosing [README](../README.md).
