#!/bin/bash
# =============================================================================
# Waybar GPU 使用率检测脚本 (自动适配 NVIDIA / AMD / Intel)
# =============================================================================
# 自动检测显卡类型并调用对应的命令获取 GPU 使用率
# 优先级: NVIDIA (nvidia-smi) > AMD (amdgpu_top/radeontop) > Intel (intel_gpu_top)
# 如果没有检测到对应工具，输出 "N/A"
# =============================================================================

get_nvidia_usage() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null
}

get_amd_usage() {
    # 方法1: 通过 sysfs 直接读取 (无需额外工具，最可靠)
    local busy_file
    for busy_file in /sys/class/drm/card*/device/gpu_busy_percent; do
        if [ -r "$busy_file" ]; then
            cat "$busy_file"
            return 0
        fi
    done
    return 1
}

get_intel_usage() {
    # 通过 sysfs 读取 Intel GPU 频率占比估算 (无需 root 权限)
    local freq_file="/sys/class/drm/card0/gt_cur_freq_mhz"
    local max_file="/sys/class/drm/card0/gt_max_freq_mhz"
    if [ -r "$freq_file" ] && [ -r "$max_file" ]; then
        local cur max
        cur=$(cat "$freq_file")
        max=$(cat "$max_file")
        if [ "$max" -gt 0 ] 2>/dev/null; then
            echo $(( cur * 100 / max ))
            return 0
        fi
    fi
    return 1
}

# 按优先级检测 GPU 类型
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    usage=$(get_nvidia_usage)
elif lspci 2>/dev/null | grep -qiE 'VGA.*AMD|Display.*AMD|3D.*AMD'; then
    usage=$(get_amd_usage)
elif lspci 2>/dev/null | grep -qiE 'VGA.*Intel|Display.*Intel|3D.*Intel'; then
    usage=$(get_intel_usage)
fi

# 如果获取失败，输出 N/A
echo "${usage:-N/A}"
