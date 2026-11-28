#!/bin/bash
# Arch Linux / Hyprland 桌面安装。需要已安装 yay。

set -euo pipefail

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

# 环境检查
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

# AUR 构建固定优先使用系统工具链。
export PATH="/usr/bin:$PATH"

# 软件包
step "正在整理 Hyprland 桌面环境及依赖组件..."

HYPR_CORE=(
	hyprland
	waybar
	swaybg
	hypridle
	hyprlock
	pciutils
	polkit-gnome
	xdg-desktop-portal-hyprland
	xdg-desktop-portal-gtk
)

GUI_TOOLS=(
	anyrun-git
	grimblast-git
	wtype
	mako
	libnotify
	wlogout
	grim
	slurp
	wl-clipboard
	cliphist
)

APPS=(
	kitty
	thunar
	thunar-archive-plugin
	google-chrome
	clash-verge-rev-bin
)

MEDIA_SYSTEM=(
	pipewire
	pipewire-audio
	pipewire-pulse
	pipewire-alsa
	wireplumber
	pavucontrol
	playerctl
	brightnessctl
	qt5-wayland
	qt6-wayland
)

IME=(
	fcitx5
	fcitx5-gtk
	fcitx5-qt
	fcitx5-configtool
	fcitx5-chinese-addons
	fcitx5-pinyin-zhwiki
	fcitx5-material-color
)

FONTS=(
	ttf-jetbrains-mono-nerd
	ttf-meslo-nerd
	noto-fonts-cjk
	ttf-lxgw-wenkai
	ttf-noto-nerd
)

ALL_PACKAGES=(
	"${HYPR_CORE[@]}"
	"${GUI_TOOLS[@]}"
	"${APPS[@]}"
	"${MEDIA_SYSTEM[@]}"
	"${IME[@]}"
	"${FONTS[@]}"
)

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

# GPU
step "检测 GPU 类型并配置驱动..."

LOCAL_CONF="$HOME/.config/hypr/local.lua"
mkdir -p "$(dirname "$LOCAL_CONF")"

# 驱动与配置验证成功后才原子更新 local.lua。
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

if $HAS_INTEL; then
	info "检测到 Intel 核显，安装 VA-API iHD 驱动..."
	install_gpu_packages mesa intel-media-driver libva-intel-driver
	success "Intel GPU 驱动配置完成。"
fi

if $HAS_AMD; then
	info "检测到 AMD 显卡，安装 VA-API 驱动..."
	install_gpu_packages mesa
	success "AMD GPU 驱动配置完成。"
fi

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
		# 运行中内核可能早于刚完成的系统升级，按已安装内核枚举 headers。
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
	# 让选定驱动包解析匹配的 userspace 依赖，不绕过依赖关系。
	install_gpu_packages "$driver_pkg"
	success "NVIDIA GPU 驱动配置完成。"
fi

# local.lua 只保存机器专属覆盖；GPU 后端由驱动和应用自行选择。
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

# 音频
step "检查并激活 Pipewire 音频服务"
systemctl --user start pipewire.service pipewire-pulse.service wireplumber.service
success "音频服务配置完成。"

# 验证
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

# 在临时 XDG 目录验证待生成的 local.lua。
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
