# Independent replication layer

This layer creates **new experiments and new evidence**, separate from the frozen original `artifacts/`. It does not renew the original attempts or rewrite the original results. Read [PROTOCOL.md](PROTOCOL.md) before execution.

Implementation status: clean-checkout validation is in progress; no completed replication is claimed in this candidate revision.

## Prerequisites

Use an isolated x86_64 Linux test host with CPUs 0 and 1 available, cgroup v2, systemd user scopes, and unprivileged user/network/PID/mount namespaces. Scientific jobs are serialized and enforce two CPUs, hard 2 GiB RAM, zero swap and 120 seconds per whole job. Missing isolation is a blocker; there is no unbounded or sudo fallback. Do not use a production network host.

Both routes require Julia **1.13.1**. Supply its real executable with `--julia`; do not rely on a wrapper that loads unrelated packages. Native tools include OVS **3.2.1**, `mnexec` compatible with the supplied Mininet **2.3.1b4** source, iproute2, tcpdump, net-tools, iputils, util-linux, ethtool, procps, psmisc and which. Installed binaries are not vendored. Runtime paths and executable/library hashes are recorded in the environment configuration.

Python **3.11.7** and the 14 exact distribution versions in `requirements.txt` are checked before execution. The pinned Julia package runtime sources and Mininet Python source are included under `vendor/`; configuration uses those content-checked sources and disables automatic Conda/Pkg installation.

## Nix-resolved cached components

From a clean checkout, using Python 3.11+ for the configuration tool and Nix with flakes:

```sh
python3 -I -B replication/configure.py \
  --route nix \
  --julia /path/to/julia-1.13.1/bin/julia \
  --output /path/outside/checkout/nix-environment.json \
  --realise
```

The tool evaluates the retained pinned Nix flakes, resolves the recorded Python and native tool components, and can retrieve missing outputs with cache-only realization (`--max-jobs 0`). It does not permit local native builds or install a global profile. Unavailable cache outputs stop setup. The recorded Julia 1.13.1 executable remains an explicit prerequisite; the older Nixpkgs pin used for Python/tools does not supply that Julia version.

## Native environment without invoking Nix

With Python **3.11.7** already installed, create an environment outside the checkout:

```sh
python3.11 -m venv /path/outside/checkout/python-env
/path/outside/checkout/python-env/bin/python -m pip install \
  --only-binary=:all: pip==23.2.1 setuptools==65.5.0 wheel==0.41.3
/path/outside/checkout/python-env/bin/python -m pip install \
  --require-hashes --no-build-isolation \
  --only-binary=numpy,networkx,matplotlib,contourpy,cycler,fonttools,kiwisolver,packaging,pillow,pyparsing,python-dateutil,six,defusedxml \
  -r replication/requirements-linux-x86_64.lock
```

The lock contains the checked CPython 3.11/x86_64 Linux distribution hashes. All native Python extensions must come from wheels. Olefile 0.46 is distributed upstream only as a pure-Python source ZIP; its hash is locked and pip packages it with the pinned setuptools/wheel tools, without native compilation. Other Python/platform combinations are not automatically accepted by this lock.

Provide the required native Linux tools and exact OVS version through PATH or explicit prefixes, then configure:

```sh
python3 -I -B replication/configure.py \
  --route native \
  --python /path/outside/checkout/python-env/bin/python3.11 \
  --julia /path/to/julia-1.13.1/bin/julia \
  --tool-prefix openvswitch=/path/to/ovs-3.2.1 \
  --tool-prefix mininet=/path/to/mininet-mnexec \
  --output /path/outside/checkout/native-environment.json
```

Other overrides use `--tool-prefix NAME=/prefix`; run `configure.py --help` for the interface. Native mode performs no Nix evaluation or realization. Prefixes may point to compatible user-local or distribution installations. Configuration checks versions, Python imports and the original NetworkX source fingerprints instead of accepting metadata alone.

On non-FHS systems such as NixOS, manylinux wheels can require explicit shared-library directories, for example `--library-path /prefix/zlib/lib --library-path /prefix/cxx/lib`. The configured directories and library hashes are recorded; no system library paths are modified. Standard Linux installations generally resolve those libraries without this option. The same configuration is reused by every subprocess; an ambient `LD_LIBRARY_PATH` is not silently inherited.

A native-mode test on a NixOS host may still use Nix-built externally supplied Julia/Linux binaries. That demonstrates the Nix-free launcher/configuration route, not an independently provisioned clean non-Nix operating system. See the recorded environment provenance when interpreting a validation run.

## Run the complete studies

Choose a **non-existing output directory outside the checkout**. Keep it after failures; do not delete attempts and rerun a cell.

```sh
python3 -I -B replication/run.py \
  --environment /path/outside/checkout/nix-environment.json \
  --output /path/outside/checkout/nix-replication-001
```

For the native route use its environment JSON and a different fresh output path. The same script executes both routes. It runs resource preflight, oracle/lifecycle/controller validation, fresh original-reference capture and exact replay, a fresh model freeze/catalogue, the full sensitivity/benchmark/primary grid, original audit/coverage, then fresh emulation controls, timing, source freeze, envelope validation, six primary cells and the packet audit. Finally it compares deterministic scientific outcomes with the original evidence, not wall-clock timings.

Each child scientific job has its own 120-second ceiling; the complete serialized campaign takes longer than 120 seconds. There is no cumulative runtime cap. The coordinator does not launch concurrent jobs.

For inspection at stage barriers, use `--phase prepare`, then `--phase validation`, `--phase model`, `--phase emulation`, and `--phase compare`, always with the same environment/output pair. Each phase can be attempted once; prerequisites must have passed. `--phase all` is the default and requires a fresh directory. A failed phase is retained and cannot be silently renewed. After fixing a launcher/setup defect, start a new replication ID rather than selectively retrying its primary cell.

## Outputs and checks

- `environment.json`, `INPUTS.json`, `adaptations.json`: exact runtime bindings, original kernel identities and every launcher/provenance patch.
- `PHASES.json`, `commands.jsonl`, `coordinator/`: attempted phases and retained top-level stdout/stderr.
- `REFERENCE_BINDING.json`, `VALIDATION.json`: fresh reference/correspondence gate locations and compatibility fixture binding.
- `work/artifacts/...`: new workspaces, source freezes, catalogues, raw jobs, attempts, reports and audits. Original results/attempts are not reused as new observations.
- `audits/`: separately bounded audit receipts.
- `COMPARISON.json`, `REPLICATION_OUTPUTS.sha256`: final acceptance and hashes of retained source/scientific-output files, excluding mutable caches and installed-source symlinks.

The read-only original release check remains `python3 -I -B verify.py`. The small replication-boundary regression suite is `python3 -I -B replication/test_protocol.py`; its scope-refusal test must be run outside a replication-approved child scope.
