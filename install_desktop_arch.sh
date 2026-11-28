#!/bin/bash
# ==============================================================================
# Arch Linux Wayland (Hyprland) 桌面环境一键安装脚本
# ==============================================================================
# 该脚本将根据 ~/.config/ 下的配置清单，自动安装:
# Hyprland, Waybar, Anyrun, Kitty, Fcitx5, 音频控制, 中文字体等必要组件。
# 请确保已配置好 Arch Linux 基础网络并安装了 yay。
# ==============================================================================

set -euo pipefail

# -------------------- 颜色与日志工具 --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error() { echo -e "${RED}[ERROR]${NC}   $*" >&2; }
step() { echo -e "\n${CYAN}${BOLD}▸ $*${NC}"; }

# -------------------- 权限与环境检查 --------------------
if [ "$(id -u)" = "0" ]; then
	error "请不要使用 root 或 sudo 运行此脚本，yay 需要普通用户权限！"
	exit 1
fi

if ! grep -qx "ID=arch" /etc/os-release; then
	error "此脚本仅适用于 Arch Linux"
	exit 1
fi

if ! command -v yay &>/dev/null; then
	error "未找到 yay！请先运行 install_arch.sh 安装基础环境及其依赖。"
	exit 1
fi

if [ ! -f "$HOME/.config/hypr/hyprland.lua" ]; then
	error "未找到 ~/.config/hypr/hyprland.lua；请先运行 install_arch.sh 应用 dotfiles。"
	exit 1
fi

# 确保 /usr/bin 优先，防止用户态 Python 管理器 (mise, linuxbrew 等)
# 遮蔽系统 Python，导致 AUR 构建时系统 C 绑定 (如 _gi 模块) 加载失败
export PATH="/usr/bin:$PATH"

# -------------------- 桌面组件清单 --------------------

step "正在整理 Hyprland 桌面环境及依赖组件..."

# 1. 核心 Wayland 与 Hyprland 组件
HYPR_CORE=(
	hyprland                    # 核心混成器
	waybar                      # 状态栏
	swaybg                      # 桌面壁纸
	hypridle                    # 空闲管理 (锁屏/息屏逻辑)
	hyprlock                    # 现代锁屏
	pciutils                    # lspci: GPU 检测与 Waybar GPU 脚本依赖
	polkit-gnome                # GUI 提权认证弹窗
	xdg-desktop-portal-hyprland # Hyprland XDG Portal (屏幕共享/文件选择)
	xdg-desktop-portal-gtk      # GTK 文件选择对话框 Portal 后端
)

# 2. 应用启动器与通知
GUI_TOOLS=(
	anyrun-git    # 极速 Rust 应用启动器 (启动器 + 剪贴板历史 UI)
	grimblast-git # Hyprland 官方截图脚本 (支持 --freeze 冻结屏幕)
	wtype         # Wayland 下模拟键盘输入 (剪贴板自动粘贴)
	mako          # 轻量级通知守护进程
	libnotify    # notify-send 命令 (截图/通知消息)
	wlogout      # 登出与电源选项菜单
	grim         # Wayland 截图工具
	slurp        # 截图区域选择
	wl-clipboard # Wayland 剪贴板后端
	cliphist     # 剪贴板历史管理
)

# 3. 基础应用程序
APPS=(
	kitty                 # 现代通过 GPU 加速的终端
	thunar                # 文件管理器
	thunar-archive-plugin # Thunar 压缩包支持
	google-chrome         # 浏览器 (配合 chrome-flags.conf)
	clash-verge-rev-bin   # 代理客户端 (预编译版，无构建依赖)
)

# 4. 音频、媒体与系统控制
MEDIA_SYSTEM=(
	pipewire       # 现代音频底层
	pipewire-audio # Pipewire 音频支持
	pipewire-pulse # PulseAudio 兼容层
	pipewire-alsa  # ALSA 兼容层
	wireplumber    # 音频会话管理器
	pavucontrol    # 图形化音量控制
	playerctl      # 媒体播放控制
	brightnessctl  # 屏幕背光与键盘灯控制
	qt5-wayland    # Qt5 应用 Wayland 支持
	qt6-wayland    # Qt6 应用 Wayland 支持
)

# 5. 输入法环境 (Fcitx5)
IME=(
	fcitx5                # 输入法基础框架
	fcitx5-gtk            # GTK 架构支持 (Firefox, GNOME 应用等)
	fcitx5-qt             # Qt 架构支持 (KDE 应用, OBS 等)
	fcitx5-configtool     # 图形化配置界面
	fcitx5-chinese-addons # 中文拼音/双拼扩展
	fcitx5-pinyin-zhwiki  # 维基百科中文词库
	fcitx5-material-color # Material Color 主题 (美化)
)

# 6. 必不可少的字体 (Nerd 字体与中文字体)
FONTS=(
	ttf-jetbrains-mono-nerd # 代码与终端经典字体
	ttf-meslo-nerd          # Starship 可能会用到的 Nerd 字体
	noto-fonts-cjk          # 基础中日韩字体防乱码方块
	ttf-lxgw-wenkai         # 极佳的中文字体 (霞鹜文楷)
	ttf-noto-nerd           # 提供补充性的图标
)

# 合并所有包
ALL_PACKAGES=(
	"${HYPR_CORE[@]}"
	"${GUI_TOOLS[@]}"
	"${APPS[@]}"
	"${MEDIA_SYSTEM[@]}"
	"${IME[@]}"
	"${FONTS[@]}"
)

# -------------------- 开始安装 --------------------
step "同步软件源并升级系统..."
yay -Syu --noconfirm

to_install=()
for pkg in "${ALL_PACKAGES[@]}"; do
	if ! pacman -Qi "$pkg" &>/dev/null; then
		to_install+=("$pkg")
	fi
done

if [ ${#to_install[@]} -eq 0 ]; then
	step "所有 ${#ALL_PACKAGES[@]} 个桌面级程序包均已安装，跳过"
else
	step "开始通过 yay 安装 ${#to_install[@]} 个缺失的桌面级程序包..."

	# 使用 --needed 避免重复安装，--noconfirm 自动确认
	if ! yay -S --needed --noconfirm "${to_install[@]}"; then
		warn "部分包可能在批量安装时遇到问题，尝试逐个安装回退..."
		failed=()
		for pkg in "${to_install[@]}"; do
			if ! yay -S --needed --noconfirm "$pkg"; then
				failed+=("$pkg")
			fi
		done
		if [ ${#failed[@]} -gt 0 ]; then
			error "以下桌面包安装失败: ${failed[*]}"
			exit 1
		fi
	fi
fi

success "桌面级程序安装阶段完成！"

# -------------------- 检测 GPU 并安装对应驱动 + 生成本地配置 --------------------
step "检测 GPU 类型并配置驱动..."

LOCAL_CONF="$HOME/.config/hypr/local.lua"
mkdir -p "$(dirname "$LOCAL_CONF")"

# 仅在驱动安装与配置验证成功后原子更新 local.lua。
GPU_INFO=$(lspci)
HAS_INTEL=false
HAS_AMD=false
HAS_NVIDIA=false

if grep -qiE 'VGA.*Intel|Display.*Intel|3D.*Intel' <<<"$GPU_INFO"; then
	HAS_INTEL=true
fi
if grep -qiE 'VGA.*AMD|Display.*AMD|3D.*AMD' <<<"$GPU_INFO"; then
	HAS_AMD=true
fi
if grep -qiE 'VGA.*NVIDIA|Display.*NVIDIA|3D.*NVIDIA' <<<"$GPU_INFO"; then
	HAS_NVIDIA=true
fi

# 辅助函数：过滤已安装的 GPU 相关包
install_gpu_packages() {
	local missing=()
	for p in "$@"; do
		if ! pacman -Qi "$p" &>/dev/null; then
			missing+=("$p")
		fi
	done
	if [ ${#missing[@]} -gt 0 ]; then
		if ! yay -S --needed --noconfirm "${missing[@]}"; then
			error "驱动包安装失败: ${missing[*]}"
			return 1
		fi
	fi
}

# --- Intel 核显 ---
if $HAS_INTEL; then
	info "检测到 Intel 核显，安装 VA-API iHD 驱动..."
	install_gpu_packages mesa intel-media-driver libva-intel-driver
	success "Intel GPU 驱动配置完成。"
fi

# --- AMD 独显/核显 ---
if $HAS_AMD; then
	info "检测到 AMD 显卡，安装 VA-API 驱动..."
	install_gpu_packages mesa
	success "AMD GPU 驱动配置完成。"
fi

# --- NVIDIA 独显 ---
if $HAS_NVIDIA; then
	info "检测到 NVIDIA 显卡：保留已有驱动，不自动切换 GPU 驱动系列。"
	driver_pkg="${NVIDIA_DRIVER_PACKAGE:-}"
	if [[ -z "$driver_pkg" ]]; then
		driver_pkg=$(pacman -Qq | awk '/^nvidia(-open)?(-dkms|-lts)?$/ || /^nvidia-[0-9]+xx(-dkms|-lts)?$/ { if (!found++) print }')
	fi
	if [[ ! "$driver_pkg" =~ ^nvidia(-open|-[0-9]+xx)?(-dkms|-lts)?$ ]]; then
		error "请按显卡架构选择 NVIDIA 驱动，例如 NVIDIA_DRIVER_PACKAGE=nvidia-open-dkms bash install_desktop_arch.sh"
		error "旧显卡可能需要 legacy 驱动，参见 https://wiki.archlinux.org/title/NVIDIA"
		exit 1
	fi
	if [[ "$driver_pkg" == *-dkms ]]; then
		# 系统升级后运行中的 uname -r 可能已过期；按已安装内核枚举 headers。
		headers=()
		for pkgbase in /usr/lib/modules/*/pkgbase; do
			[[ -r "$pkgbase" ]] || continue
			read -r kernel_pkg <"$pkgbase" || continue
			pacman -Q "$kernel_pkg" >/dev/null 2>&1 || continue
			if ! pacman -Si "${kernel_pkg}-headers" >/dev/null 2>&1 &&
			   ! pacman -Qi "${kernel_pkg}-headers" >/dev/null 2>&1; then
				error "未找到 $kernel_pkg 对应的 headers，需手动安装后重试"
				exit 1
			fi
			headers+=("${kernel_pkg}-headers")
		done
		if (( ${#headers[@]} == 0 )); then
			error "未找到已安装内核的 headers，停止 DKMS 驱动安装"
			exit 1
		fi
		install_gpu_packages "${headers[@]}"
	fi
	# 由选定驱动包声明相匹配的 userspace 依赖；不使用 pacman -Rdd。
	install_gpu_packages "$driver_pkg"
	success "NVIDIA GPU 驱动配置完成。"
fi

# Hyprland / Chrome / VA-API 默认按硬件和驱动自动选择，不全局强制 GPU。
# 保留 local.lua 作为机器专属覆盖点；只替换旧脚本生成的内容。
if [[ -s "$LOCAL_CONF" ]] && ! grep -Fq 'Hyprland 机器本地配置 (自动生成)' "$LOCAL_CONF"; then
	info "保留手动维护的 $LOCAL_CONF"
else
	GENERATED_DIR=$(mktemp -d)
	trap 'rm -rf -- "$GENERATED_DIR"' EXIT
	mkdir -p "$GENERATED_DIR/hypr"
	cat >"$GENERATED_DIR/hypr/local.lua" <<'HEADER'
-- Hyprland 机器本地配置 (自动生成)
-- 默认由应用及驱动选择 GPU；仅在确认机器需要特殊设置时添加覆盖。
HEADER
fi

# -------------------- 检查音频服务 --------------------
step "检查并激活 Pipewire 音频服务"
systemctl --user start pipewire.service pipewire-pulse.service wireplumber.service
success "音频服务配置完成。"

# -------------------- 最终验证 --------------------
step "验证桌面环境"

DESKTOP_COMMANDS=(
	Hyprland start-hyprland waybar hypridle hyprlock swaybg
	anyrun grimblast wtype mako wlogout grim slurp wl-copy cliphist
	kitty thunar clash-verge
	wpctl pavucontrol playerctl brightnessctl fcitx5
)

missing_commands=()
for cmd in "${DESKTOP_COMMANDS[@]}"; do
	if ! command -v "$cmd" &>/dev/null; then
		missing_commands+=("$cmd")
	fi
done

if [ ${#missing_commands[@]} -gt 0 ]; then
	error "以下桌面命令未检测到: ${missing_commands[*]}"
	exit 1
fi

if [ ! -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
	error "polkit-gnome authentication agent 未找到"
	exit 1
fi

hypr_version=$(pacman -Q hyprland | awk '{print $2}')
if (( $(vercmp "$hypr_version" 0.57.0) < 0 )); then
	error "此配置需要 Hyprland >= 0.57.0，已安装 $hypr_version"
	exit 1
fi

# 用临时 XDG 配置目录验证待生成的 local.lua，不覆盖现有配置。
if [[ -n "${GENERATED_DIR:-}" ]]; then
	if ! XDG_CONFIG_HOME="$GENERATED_DIR" Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua"; then
		error "Hyprland 配置验证失败；保留现有 local.lua"
		exit 1
	fi
	LOCAL_TMP=$(mktemp "$LOCAL_CONF.XXXXXX")
	cp "$GENERATED_DIR/hypr/local.lua" "$LOCAL_TMP"
	mv -f -- "$LOCAL_TMP" "$LOCAL_CONF"
else
	Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua"
fi

success "Hyprland 配置与桌面命令验证通过。"

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║      🎉 Hyprland 桌面环境安装完毕！            ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

exit 0
