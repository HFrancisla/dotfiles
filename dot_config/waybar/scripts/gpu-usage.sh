#!/bin/bash
# =============================================================================
# Waybar GPU 使用率检测脚本 (自动适配 NVIDIA / AMD / Intel)
# =============================================================================
# 自动检测显卡类型并读取真实 busy/utilization 指标。
# 不再用 GPU 当前频率 / 最大频率冒充使用率；没有真实 busy counter 时输出 "N/A"。
# =============================================================================

get_nvidia_usage() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null |
        awk '{ sum += $1; count += 1 } END { if (count > 0) printf "%.0f\n", sum / count; else exit 1 }'
}

get_sysfs_usage() {
    local expected_vendor="$1"
    local device vendor_file busy_file
    for device in /sys/class/drm/card*/device; do
        vendor_file="$device/vendor"
        busy_file="$device/gpu_busy_percent"
        if [ -r "$vendor_file" ] && [ -r "$busy_file" ] &&
            [ "$(cat "$vendor_file")" = "$expected_vendor" ]; then
            cat "$busy_file"
            return 0
        fi
    done
    return 1
}

# 按优先级检测 GPU 类型
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    usage=$(get_nvidia_usage)
elif lspci 2>/dev/null | grep -qiE 'VGA.*AMD|Display.*AMD|3D.*AMD'; then
    usage=$(get_sysfs_usage 0x1002)
elif lspci 2>/dev/null | grep -qiE 'VGA.*Intel|Display.*Intel|3D.*Intel'; then
    usage=$(get_sysfs_usage 0x8086)
fi

# 如果获取失败，输出 N/A
if [ -n "${usage:-}" ]; then
    printf '%s%%\n' "$usage"
else
    printf 'N/A\n'
fi
