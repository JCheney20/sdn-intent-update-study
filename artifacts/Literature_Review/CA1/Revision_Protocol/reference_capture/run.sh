#!/usr/bin/env bash
# Reference-only capture/replay; aggregate accounting is documentary, not a stop.
set -euo pipefail
cd -- "$(dirname -- "$0")"
mode=${1:-}
case "$mode" in
  capture) ;;
  replay) [[ $# == 2 && -f "$2/trace.toml" ]] || { echo 'replay requires a capture run directory' >&2; exit 2; } ;;
  *) echo 'Usage: bash run.sh capture | replay CAPTURE_DIRECTORY' >&2; exit 2 ;;
esac
exec 9>../validation/.run.lock
flock -n 9 || { echo 'Another revision job is active.' >&2; exit 2; }
verify_seal() {
  python3 -I -B - <<'PY'
import hashlib,json
from pathlib import Path
base=Path('../../../../SDN_Model_Comparison')
p=base/'Delivery_Manifest.json'
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert h(p)=='b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb'
m=json.loads(p.read_text())
for section,count in [('files',194),('external_context_snapshots',2)]:
 assert len(m[section])==count
 for name,want in m[section].items():assert h(base/name)==want,name
PY
}
verify_seal
unit="cos738-reference-$mode-$(date +%s%N)"
run="$(pwd)/runs/$unit"
mkdir -p "$run"
sha256sum run.sh capture.py Capture_Plan.toml sources/*.py \
  ../reference_environment/run_reference.py ../reference_environment/Setup_Status.toml \
  ../reference_environment/flake.nix ../reference_environment/flake.lock \
  ../reference_environment/referenceComponents.json > "$run/source.sha256"
if [[ "$mode" == capture ]]; then
  command=(python3 -I -B ../reference_environment/run_reference.py "$(pwd)/capture.py" "$run")
else
  source_run=$(realpath "$2")
  sha256sum replay.jl ../../../../SDN_Model_Comparison/source_fidelity/detector.jl "$source_run/trace.toml" >> "$run/source.sha256"
  command=(env JULIA_PKG_OFFLINE=true JULIA_LOAD_PATH=@stdlib JULIA_DEPOT_PATH="$(pwd)/../validation/depot:"
    OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
    julia --startup-file=no --history-file=no --compiled-modules=no --threads=1 --gcthreads=1
    replay.jl "$source_run" "$run")
fi
set +e
timeout --signal=TERM --kill-after=1s 120s \
  systemd-run --user --scope --quiet --expand-environment=no --unit="$unit" \
  -p MemoryMax=2147483648 -p MemorySwapMax=0 -p CPUQuota=200% \
  timeout --signal=TERM --kill-after=1s 118s taskset -c 0,1 "${command[@]}" \
  > "$run/output.log" 2>&1
code=$?
set -e
systemctl --user kill --kill-whom=all "$unit.scope" 2>/dev/null || true
printf '%s\n' "$code" > "$run/process_exit_code"
# Never accept successful-looking output after input/seal drift.
sha256sum --check "$run/source.sha256" > "$run/source_check.log" || code=1
verify_seal || code=1
printf '%s\n' "$code" > "$run/exit_code"
printf 'Run: %s\nExit: %s\n' "$run" "$code"
exit "$code"
