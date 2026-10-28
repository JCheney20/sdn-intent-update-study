#!/usr/bin/env bash
set -euo pipefail
[[ "$(readlink /proc/self/ns/net)" != "$HOST_NETNS" ]]
[[ "$(readlink /proc/self/ns/mnt)" != "$HOST_MNTNS" ]]
[[ "$(readlink /proc/self/ns/pid)" != "$HOST_PIDNS" ]]
read -r inside outside count < /proc/self/uid_map
[[ "$inside" == 0 && "$outside" != 0 && "$count" == 1 ]]
# Private mounts prevent Mininet's /tmp cleanup and global sysctl tuning from affecting the host.
mount --make-rprivate /
mount -t tmpfs -o size=128m,mode=1777,nosuid,nodev tmpfs /tmp
mount -t sysfs -o ro,nosuid,nodev,noexec sysfs /sys
mount --bind /proc/sys /proc/sys
mount -o remount,bind,ro /proc/sys
exec "$@"
