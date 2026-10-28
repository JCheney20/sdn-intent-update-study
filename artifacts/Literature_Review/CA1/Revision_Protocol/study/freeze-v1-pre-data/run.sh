#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mode=${1:-}; index=${2:-0}; detail=${3:-none}
[[ "$index" =~ ^[0-9]+$ ]] || exit 2
case "$mode" in
  freeze) [[ ! -e Manifest.toml ]] || { echo 'Study already frozen.' >&2; exit 2; } ;;
  sensitivity-python|sensitivity-weighted|sensitivity-neighbors) ((index<6)) || exit 2 ;;
  benchmark-python|benchmark-julia) ((index<4)) && [[ "$detail" =~ ^(cold-[1-5]|warm)$ ]] || exit 2 ;;
  primary) ((index<12)) || exit 2 ;;
  analyze) ;;
  *) echo 'Unknown study mode.' >&2; exit 2 ;;
esac
exec 9>../validation/.run.lock
flock -n 9 || { echo 'Another revision job is active.' >&2; exit 2; }
if [[ "$mode" != freeze ]]; then
  sha256sum --check Manifest.sha256 >/dev/null
  sha256sum --check Sources.sha256 >/dev/null
fi
unit="cos738-study-$mode-$index-$(date +%s%N)"
run="$(pwd)/runs/$unit"
if [[ "$mode" == primary ]]; then
  mkdir -p attempts
  mkdir "attempts/primary-$index" || { echo 'Primary cell already attempted; no automatic retry.' >&2; exit 2; }
  printf '%s\n' "$run" > "attempts/primary-$index/run"
fi
mkdir -p "$run"
printf 'mode = "%s"\nindex = %s\ndetail = "%s"\n' "$mode" "$index" "$detail" > "$run/job.toml"
common=(env JULIA_PKG_OFFLINE=true JULIA_LOAD_PATH=@stdlib JULIA_DEPOT_PATH="$(pwd)/../validation/depot:"
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
  julia --startup-file=no --history-file=no --compiled-modules=no --threads=1 --gcthreads=1)
if [[ "$mode" == freeze ]]; then
  command=("${common[@]}" freeze.jl)
elif [[ "$mode" == sensitivity-python ]]; then
  command=(python3 -I -B ../reference_environment/run_reference.py "$(pwd)/python_study.py" sensitivity "$index" "$run/result.toml")
elif [[ "$mode" == benchmark-python ]]; then
  measurement=${detail%%-*}
  command=(python3 -I -B ../reference_environment/run_reference.py "$(pwd)/python_study.py" "$measurement" "$index" "$run/result.toml")
else
  entrymode=$mode
  [[ "$mode" == benchmark-julia ]] && entrymode=${detail%%-*}
  command=("${common[@]}" entry.jl "$entrymode" "$index" "$run/result.toml")
fi
start=$(date +%s%N)
set +e
timeout --signal=TERM --kill-after=1s 120s \
  systemd-run --user --scope --quiet --expand-environment=no --unit="$unit" \
  -p MemoryMax=2147483648 -p MemorySwapMax=0 -p CPUQuota=200% \
  timeout --signal=TERM --kill-after=1s 118s taskset -c 0,1 "${command[@]}" > "$run/output.log" 2>&1
code=$?
end=$(date +%s%N)
set -e
printf 'supervised_elapsed_nanoseconds = %s\n' "$((end-start))" >> "$run/job.toml"
printf '%s\n' "$code" > "$run/process_exit_code"
systemctl --user kill --kill-whom=all "$unit.scope" 2>/dev/null || true
if [[ "$mode" == freeze && "$code" == 0 ]]; then
  sha256sum Manifest.toml Sources.sha256 > Manifest.sha256
elif [[ "$mode" != freeze ]]; then
  sha256sum --check Manifest.sha256 > "$run/manifest_check.log" || code=1
  sha256sum --check Sources.sha256 > "$run/source_check.log" || code=1
fi
printf '%s\n' "$code" > "$run/exit_code"
printf 'Run: %s\nExit: %s\n' "$run" "$code"
exit "$code"
