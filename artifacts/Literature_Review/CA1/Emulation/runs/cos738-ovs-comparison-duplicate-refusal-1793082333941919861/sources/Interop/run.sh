#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mode=${1:?bridge or network required}
[[ "$mode" == bridge || "$mode" == network ]]
[[ -n ${COS738_OVS_RUN_DIR:-} ]]
grep -q 'cos738-ovs-' /proc/self/cgroup
export INTEROP_DIR="$PWD"
export JULIA_LOAD_PATH="$PWD/Packages:$PWD:@stdlib"
export JULIA_DEPOT_PATH="$PWD/depot:"
export JULIA_PKG_OFFLINE=true JULIA_CONDAPKG_BACKEND=Null JULIA_CONDAPKG_OFFLINE=true
export JULIA_PYTHONCALL_EXE=/nix/store/asiphbpiy2gmidfm3xbwcikayhs66289-python3-3.11.7/bin/python3.11
export JULIA_PYTHONCALL_LIB=/nix/store/asiphbpiy2gmidfm3xbwcikayhs66289-python3-3.11.7/lib/libpython3.11.so
export MININET_PYTHON_SOURCE=/nix/store/djc2z0dr4aisxn26grjvvjmma4hp6h32-mininet-2.3.1b4-py/lib/python3.11/site-packages
export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1
unset PYTHONHOME PYTHONPATH PYTHON
export PATH="$(python3 -I -B -c 'import json,os;from pathlib import Path;p=Path.cwd();print(":".join(v["path"]+"/bin" for f in [p/"Components.json",p.parent/"Components.json"] for v in json.loads(f.read_text()).values())+":"+os.environ["PATH"])')"
# The system Julia wrappers force @PyCall/Python 3.14; use their existing underlying 1.13.1 binary.
julia=/nix/store/a2bpphzl20l866cp62i8ja35mbsprs66-julia-1.13.1/bin/julia
args=(--project="$PWD" --startup-file=no --history-file=no --compiled-modules=no --threads=1 --gcthreads=1)
if [[ "$mode" == bridge ]]; then
  exec "$julia" "${args[@]}" "$PWD/bridge_smoke.jl"
fi
export HOST_NETNS="$(readlink /proc/self/ns/net)" HOST_MNTNS="$(readlink /proc/self/ns/mnt)" HOST_PIDNS="$(readlink /proc/self/ns/pid)"
exec unshare --user --map-root-user --net --pid --mount --fork --mount-proc \
  bash "$PWD/sandbox.sh" "$julia" "${args[@]}" "$PWD/network_smoke.jl"
