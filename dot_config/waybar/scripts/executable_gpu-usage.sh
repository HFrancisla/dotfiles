#!/bin/bash
# Waybar: 优先 NVIDIA，其次 AMD / Intel，无法读到真实计数器时显示 N/A。
set -o pipefail

average_usage() {
    awk '$1 ~ /^[0-9]+([.][0-9]+)?$/ && $1 >= 0 && $1 <= 100 {
        sum += $1; count++
    } END { if (count) printf "%.0f\n", sum / count; else exit 1 }'
}

get_nvidia_usage() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null |
        average_usage
}

get_sysfs_usage() {
    local device vendor busy
    for device in "${GPU_SYSFS_ROOT:-/sys/class/drm}"/card*/device; do
        [[ -r "$device/vendor" && -r "$device/gpu_busy_percent" ]] || continue
        read -r vendor <"$device/vendor" || continue
        [[ "$vendor" == "$1" ]] || continue
        read -r busy <"$device/gpu_busy_percent" || continue
        printf '%s\n' "$busy"
    done | average_usage
}

if usage=$(get_nvidia_usage) ||
   usage=$(get_sysfs_usage 0x1002) ||
   usage=$(get_sysfs_usage 0x8086); then
    printf '%s%%\n' "$usage"
else
    printf 'N/A\n'
fi
