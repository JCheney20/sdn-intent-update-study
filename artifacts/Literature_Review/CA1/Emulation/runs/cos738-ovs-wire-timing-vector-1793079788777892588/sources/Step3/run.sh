#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
[[ ${1:-} == timing ]]
[[ -n ${COS738_OVS_RUN_DIR:-} ]]
grep -q 'cos738-ovs-' /proc/self/cgroup
here="$PWD"; interop="$(cd ../Interop && pwd)"
(cd ../Step2 && sha256sum --check Validated_Source_Manifest.sha256) > "$COS738_OVS_RUN_DIR/step2_source_check.txt"
mkdir -p "$COS738_OVS_RUN_DIR/sources/Step3"
cp -- *.jl *.py *.sh Timing_Plan.md "$COS738_OVS_RUN_DIR/sources/Step3/"
export JULIA_LOAD_PATH="$interop/Packages:$interop:@stdlib" JULIA_DEPOT_PATH="$interop/depot:"
export JULIA_PKG_OFFLINE=true JULIA_CONDAPKG_BACKEND=Null JULIA_CONDAPKG_OFFLINE=true
export JULIA_PYTHONCALL_EXE=/nix/store/asiphbpiy2gmidfm3xbwcikayhs66289-python3-3.11.7/bin/python3.11
export JULIA_PYTHONCALL_LIB=/nix/store/asiphbpiy2gmidfm3xbwcikayhs66289-python3-3.11.7/lib/libpython3.11.so
export MININET_PYTHON_SOURCE=/nix/store/djc2z0dr4aisxn26grjvvjmma4hp6h32-mininet-2.3.1b4-py/lib/python3.11/site-packages
export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1
unset PYTHONHOME PYTHONPATH PYTHON
export PATH="$(python3 -I -B -c 'import json,os;from pathlib import Path;p=Path.cwd();print(":".join(v["path"]+"/bin" for f in [p.parent/"Interop/Components.json",p.parent/"Components.json"] for v in json.loads(f.read_text()).values())+":"+os.environ["PATH"])')"
export HOST_NETNS="$(readlink /proc/self/ns/net)" HOST_MNTNS="$(readlink /proc/self/ns/mnt)" HOST_PIDNS="$(readlink /proc/self/ns/pid)"
exec unshare --user --map-root-user --net --pid --mount --fork --mount-proc \
  bash "$interop/sandbox.sh" /nix/store/a2bpphzl20l866cp62i8ja35mbsprs66-julia-1.13.1/bin/julia \
  --project="$interop" --startup-file=no --history-file=no --compiled-modules=no --threads=1 --gcthreads=1 \
  "$here/timing.jl"
