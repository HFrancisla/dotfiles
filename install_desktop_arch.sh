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

if ! command -v yay &>/dev/null; then
	error "未找到 yay！请先运行 install.sh 安装基础环境及其依赖。"
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
	hypridle                    # 空闲管理 (锁屏/息屏逻辑)
	hyprlock                    # 现代锁屏
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
	yay -S --needed --noconfirm "${to_install[@]}" || {
		warn "部分包可能在批量安装时遇到问题，尝试逐个安装回退..."
		for pkg in "${to_install[@]}"; do
			yay -S --needed --noconfirm "$pkg" || warn "安装失败: $pkg (请稍后手动检查)"
		done
	}
fi

success "桌面级程序安装阶段完成！"

# -------------------- 检测 GPU 并安装对应驱动 + 生成本地配置 --------------------
step "检测 GPU 类型并配置驱动..."

LOCAL_CONF="$HOME/.config/hypr/local.conf"
mkdir -p "$(dirname "$LOCAL_CONF")"

# 初始化本地配置文件
cat >"$LOCAL_CONF" <<'HEADER'
# ==========================================
# Hyprland 机器本地配置 (自动生成)
# 由 install_desktop.sh 根据当前硬件自动检测并生成
# 请勿手动编辑此文件，重新运行 install_desktop.sh 将覆盖
# ==========================================
HEADER

GPU_DETECTED=false

# 辅助函数：过滤已安装的 GPU 相关包
install_gpu_packages() {
	local missing=()
	for p in "$@"; do
		if ! pacman -Qi "$p" &>/dev/null; then
			missing+=("$p")
		fi
	done
	if [ ${#missing[@]} -gt 0 ]; then
		yay -S --needed --noconfirm "${missing[@]}" || warn "驱动包安装失败: ${missing[*]}"
	fi
}

# --- Intel 核显 ---
if lspci | grep -qiE 'VGA.*Intel|Display.*Intel|3D.*Intel'; then
	info "检测到 Intel 核显，安装 VA-API iHD 驱动..."
	install_gpu_packages intel-media-driver
	echo "" >>"$LOCAL_CONF"
	echo "# Intel 核显 VA-API 驱动" >>"$LOCAL_CONF"
	echo "env = LIBVA_DRIVER_NAME,iHD" >>"$LOCAL_CONF"
	GPU_DETECTED=true
	success "Intel GPU 驱动配置完成。"
fi

# --- AMD 独显/核显 ---
if lspci | grep -qiE 'VGA.*AMD|Display.*AMD|3D.*AMD'; then
	info "检测到 AMD 显卡，安装 VA-API 驱动..."
	install_gpu_packages libva-mesa-driver mesa-vdpau
	echo "" >>"$LOCAL_CONF"
	echo "# AMD 显卡 VA-API 驱动 (radeonsi)" >>"$LOCAL_CONF"
	echo "env = LIBVA_DRIVER_NAME,radeonsi" >>"$LOCAL_CONF"
	GPU_DETECTED=true
	success "AMD GPU 驱动配置完成。"
fi

# --- NVIDIA 独显 ---
if lspci | grep -qiE 'VGA.*NVIDIA|Display.*NVIDIA|3D.*NVIDIA'; then
	info "检测到 NVIDIA 显卡，清理可能引起冲突的遗留包..."
	sudo pacman -Rdd --noconfirm libva-nvidia-driver-git 2>/dev/null || true
	info "安装 NVIDIA 驱动与 VA-API 兼容层..."
	install_gpu_packages linux-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver

	echo "" >>"$LOCAL_CONF"
	echo "# NVIDIA 显卡 Hyprland 优化" >>"$LOCAL_CONF"
	# 如果已经检测到 Intel，默认 VA-API 还是用 Intel (iHD) 比较稳，NVIDIA 仅用于渲染
	if ! lspci | grep -qiE 'VGA.*Intel|Display.*Intel|3D.*Intel'; then
		echo "env = LIBVA_DRIVER_NAME,nvidia" >>"$LOCAL_CONF"
	else
		echo "# 检测到混合显卡，默认维持 Intel Va-api (iHD)，如需硬解切到 NVIDIA 请修改下方" >>"$LOCAL_CONF"
		echo "# env = LIBVA_DRIVER_NAME,nvidia" >>"$LOCAL_CONF"
	fi
	echo "env = GBM_BACKEND,nvidia-drm" >>"$LOCAL_CONF"
	echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia" >>"$LOCAL_CONF"
	echo "env = __NV_PRIME_RENDER_OFFLOAD,1" >>"$LOCAL_CONF"
	GPU_DETECTED=true
	success "NVIDIA GPU 驱动配置完成。"
fi

if ! $GPU_DETECTED; then
	info "未检测到已知 GPU 类型 (Intel/AMD/NVIDIA)，跳过驱动安装。"
	echo "" >>"$LOCAL_CONF"
	echo "# 未检测到特定 GPU，无需额外配置" >>"$LOCAL_CONF"
fi

success "GPU 检测与本地配置生成完成: $LOCAL_CONF"

# -------------------- 检查音频服务 --------------------
step "检查并激活 Pipewire 音频服务"
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service || true
success "音频服务配置完成。"

# -------------------- Fcitx5 环境变量提示 --------------------
step "环境检查结束"

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║      🎉 Hyprland 桌面环境安装完毕！            ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

exit 0
