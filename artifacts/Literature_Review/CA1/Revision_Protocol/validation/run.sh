#!/usr/bin/env bash
# Native bootstrap only: reserve a hard upper bound before Julia starts.
set -euo pipefail
cd -- "$(dirname -- "$0")"
case "${1:-}" in
  preflight|environment) seconds=30 ;;
  oracle|differential|lifecycle|controllers-cisco|controllers-fat4) seconds=120 ;;
  *) echo 'Usage: bash run.sh preflight|environment|oracle|differential|lifecycle|controllers-cisco|controllers-fat4' >&2; exit 2 ;;
esac
mkdir -p runs depot
exec 9>.run.lock
flock -n 9 || { echo 'A revision validation already owns the budget.' >&2; exit 2; }
total=0
for ticket in runs/*/reserved.core_seconds; do
  [[ -f "$ticket" ]] || continue
  read -r reserved < "$ticket"
  [[ "$reserved" =~ ^[0-9]+$ ]] || exit 2
  total=$((total + reserved))
done
charge=$((2 * (seconds + 2)))  # also reserve wrapper termination/bookkeeping margin
# Author removed the aggregate ceiling for the three-stage revision.
# Existing limit-reservation accounting is documentary only, not an execution gate.
# ponytail: immutable limit tickets retain startup/failure provenance; never delete old receipts.
unit="cos738-revision-$(date +%s%N)"
run="$(pwd)/runs/$unit"
mkdir "$run"
printf '%s\n' "$charge" > "$run/reserved.core_seconds"
printf '%s\n' "$1" > "$run/mode"
printf '%s\n' "$seconds" > "$run/process_limit_seconds"
read -r uptime _ < /proc/uptime
printf '%s\n' "$uptime" > "$run/start.uptime"
set +e
timeout --signal=TERM --kill-after=1s "${seconds}s" \
  systemd-run --user --scope --quiet --unit="$unit" \
  --property=MemoryMax=2147483648 --property=MemorySwapMax=0 --property=CPUQuota=200% \
  timeout --signal=TERM --kill-after=1s "$((seconds - 2))s" \
  taskset -c 0,1 env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  JULIA_PKG_OFFLINE=true JULIA_LOAD_PATH=@stdlib JULIA_DEPOT_PATH="$(pwd)/depot:" \
  julia --startup-file=no --history-file=no --compiled-modules=no --threads=1 --gcthreads=1 \
  entry.jl "$1" "$run" > "$run/output.log" 2>&1
code=$?
set -e
printf '%s\n' "$code" > "$run/exit_code"
# Kill any remaining scope members even if the outer wrapper was interrupted.
systemctl --user kill --kill-whom=all "$unit.scope" 2>/dev/null || true
printf 'Run: %s\nExit: %s\nDocumentary limit-reservation total: %s core-seconds (no aggregate ceiling)\n' "$run" "$code" "$((total + charge))"
exit "$code"
