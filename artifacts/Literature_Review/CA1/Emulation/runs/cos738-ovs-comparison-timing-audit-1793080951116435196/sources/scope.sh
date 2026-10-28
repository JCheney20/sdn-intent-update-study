#!/usr/bin/env bash
# Feasibility/provisioning only; not an unfrozen primary-experiment launcher.
set -euo pipefail
cd -- "$(dirname -- "$0")"
label=${1:?job label required}; shift
[[ "$label" =~ ^[a-z0-9-]+$ && $# -gt 0 ]] || exit 2
exec 9>../Revision_Protocol/validation/.run.lock
flock -n 9 || { echo 'Another local revision/emulation job is active.' >&2; exit 2; }
unit="cos738-ovs-$label-$(date +%s%N)"
run="$(pwd)/runs/$unit"
mkdir -p "$run/sources"
for source in *.py *.sh *.nix *.lock Components.json; do
  [[ ! -f "$source" ]] || cp -- "$source" "$run/sources/"
done
if [[ -d Interop ]]; then
  mkdir -p "$run/sources/Interop"
  find Interop -maxdepth 1 -type f \( -name '*.jl' -o -name '*.py' -o -name '*.sh' -o -name '*.toml' -o -name '*.json' -o -name '*.nix' -o -name '*.lock' \) -exec cp -- {} "$run/sources/Interop/" \;
fi
printf '%q ' "$@" > "$run/command.txt"
printf '\n' >> "$run/command.txt"
set +e
timeout --signal=TERM --kill-after=1s 120s \
  systemd-run --user --scope --quiet --expand-environment=no --unit="$unit" \
  -p MemoryMax=2147483648 -p MemorySwapMax=0 -p CPUQuota=200% \
  timeout --signal=TERM --kill-after=1s 118s taskset -c 0,1 \
  env OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 COS738_OVS_RUN_DIR="$run" \
  python3 -I -B "$(pwd)/scope_entry.py" "$run/receipt.json" "$@" > "$run/output.log" 2>&1
code=$?
set -e
systemctl --user kill --kill-whom=all "$unit.scope" 2>/dev/null || true
printf '%s\n' "$code" > "$run/exit_code"
printf 'Run: %s\nExit: %s\n' "$run" "$code"
exit "$code"
