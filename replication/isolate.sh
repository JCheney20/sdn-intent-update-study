#!/usr/bin/env bash
# Restore only configured /tmp inputs after the unchanged sandbox hides host /tmp.
set -euo pipefail
sandbox=${1:?original sandbox required}; shift
args=()
count=0
while IFS=$'\t' read -r mode path; do
  [[ -n "$path" ]] || continue
  [[ "$mode" == ro || "$mode" == rw ]]
  [[ "$path" == /tmp/* && -d "$path" ]]
  exec {fd}<"$path"
  args+=("$fd" "$mode" "$path")
  count=$((count+1))
done <<< "${SDN_REPLICATION_TMP_BINDS:-}"
# All mount operations are inside the existing unshare mount/user namespace.
# The original sandbox still verifies namespaces/uid mapping and protects sysfs/proc-sys.
exec bash "$sandbox" bash -c '
set -euo pipefail
count=$1; shift
parent=$$
for ((i=0;i<count;i++)); do
  fd=$1; mode=$2; path=$3; shift 3
  [[ "$fd" =~ ^[0-9]+$ && "$path" == /tmp/* ]]
  mkdir -p -- "$path"
  # libmount must not canonicalize the descriptor back to its now-hidden /tmp name.
  mount --no-canonicalize --bind "/proc/$parent/fd/$fd" "$path"
  if [[ "$mode" == ro ]]; then
    mount -o remount,bind,ro,nosuid,nodev "$path"
  else
    [[ "$mode" == rw ]]
  fi
  exec {fd}<&-
done
exec "$@"
' replication-restore "$count" "${args[@]}" "$@"
