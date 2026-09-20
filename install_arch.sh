#!/bin/bash
# ==============================================================================
# Dotfiles One-Click Deployment Script (chezmoi) — Arch Linux
# ==============================================================================
# 支持的环境:
#   - Arch Linux (使用 yay)
#
# 用法:
#   curl -fsSL <raw_url>/install_arch.sh | bash
#   或者 clone 后直接执行: bash install_arch.sh
# ==============================================================================

set -euo pipefail

# -------------------- 环境检查 --------------------
if ((BASH_VERSINFO[0] < 4)); then
	echo -e "\033[0;31m[ERROR]\033[0m 此脚本需要 Bash 4.0+，当前版本: $BASH_VERSION" >&2
	exit 1
fi

trap 'echo -e "\033[0;31m[ERROR]\033[0m 安装过程中发生错误 (行 $LINENO)，请检查输出信息" >&2; exit 1' ERR

# -------------------- 颜色与日志工具 --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error() { echo -e "${RED}[ERROR]${NC}   $*" >&2; }
step() { echo -e "\n${CYAN}${BOLD}▸ $*${NC}"; }

# -------------------- OS 检测 --------------------
detect_os() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		OS_ID="$ID"
	else
		OS_ID="unknown"
	fi

	if [ "$OS_ID" != "arch" ]; then
		error "此脚本仅适用于 Arch Linux，检测到: $OS_ID"
		exit 1
	fi

	# Arch Linux: 确保 /usr/bin 优先，防止用户态 Python 管理器 (mise, linuxbrew 等)
	# 遮蔽系统 Python，导致 AUR 构建时系统 C 绑定 (如 _gi 模块) 加载失败
	export PATH="/usr/bin:$PATH"

	info "检测到操作系统: ${BOLD}${OS_ID}${NC}"
}

# -------------------- 基础依赖检查与安装 --------------------
install_prerequisites() {
	step "检查基础依赖 (git, curl, zsh, base-devel)"

	info "同步软件源并升级系统..."
	sudo pacman -Syu --noconfirm

	local missing=()
	for pkg in git curl zsh base-devel bind strace ltrace bpftrace bcc-tools; do
		if ! pacman -Qi "$pkg" &>/dev/null; then
			missing+=("$pkg")
		fi
	done

	if [ ${#missing[@]} -gt 0 ]; then
		info "安装缺失的基础依赖: ${missing[*]}"
		sudo pacman -S --needed --noconfirm "${missing[@]}"
	fi

	# 确保 yay 可用
	if ! command -v yay &>/dev/null; then
		warn "未检测到 yay，正在安装..."
		install_yay
	fi

	success "基础依赖已就绪"
}

# -------------------- 安装 yay (AUR Helper) --------------------
install_yay() {
	info "从源码编译安装 yay..."
	local yay_dir
	yay_dir=$(mktemp -d)
	trap 'rm -rf "$yay_dir"' EXIT
	git clone https://aur.archlinux.org/yay.git "$yay_dir/yay"
	(cd "$yay_dir/yay" && makepkg -si --noconfirm)
	rm -rf "$yay_dir"
	trap - EXIT
	success "yay 安装完成"
}

# -------------------- 安装核心工具包 --------------------
install_packages() {
	step "安装核心工具包"

	# ---- 1. 核心终端增强 ----
	local CORE_PACKAGES=(
		chezmoi  # dotfiles 管理
		neovim   # 编辑器
		tmux     # 终端复用器
		starship # Shell 提示符
		fzf      # 模糊搜索
		yazi     # 终端文件管理器
	)

	# ---- 2. 现代 CLI 替代 (coreutils 增强) ----
	local MODERN_CLI_PACKAGES=(
		eza      # ls 替代 (图标/颜色)
		zoxide   # cd 替代 (智能跳转)
		bat      # cat 替代 (语法高亮)
		ripgrep  # grep 替代 (极速搜索)
		fd       # find 替代
		sd       # sed 替代
		dust     # du 替代 (磁盘用量可视化)
		duf      # df 替代 (磁盘空间)
		procs    # ps 替代
		gping    # ping 替代 (图形化)
		tealdeer # tldr (命令速查)
	)

	# ---- 3. 系统监控 & 网络 ----
	local MONITOR_PACKAGES=(
		btop      # 系统资源监控 (TUI)
		htop      # 进程监控
		bottom    # 系统监控 (Rust)
		fastfetch # 系统信息展示
		gdu       # 磁盘空间分析 (Go)
		ncdu      # 磁盘空间分析 (ncurses)
		bandwhich # 网络带宽监控
		trippy    # 网络路由诊断
		mtr       # 网络诊断 (ping + traceroute)
		progress  # coreutils 命令进度监控
	)

	# ---- 4. 开发工具 ----
	local DEV_PACKAGES=(
		llvm          # 编译工具链 (.zshrc 中配置了 PATH)
		mise          # 多语言版本管理 (Node/Lua/Python/Java/Rust)
		luarocks      # Lua 包管理器
		lua-luarocks  # Lua 5.5 库文件 (luarocks 拆包后需要显式安装)
		github-cli    # GitHub CLI (Arch 包名)
		lazygit       # Git TUI (LazyVim 集成)
		jq            # JSON 处理
		yq            # YAML/XML/TOML 处理
		dasel         # 多格式数据查询/修改 (JSON/YAML/TOML/CSV/XML)
		xmlstarlet    # XML 处理工具
		diff-so-fancy # Git diff 美化
		git-delta     # Git diff 语法高亮分页器
		sqlite        # SQLite 库 (Neovim yanky.nvim sqlite.lua 依赖)
		uv            # Python 包/虚拟环境管理
		dive          # Docker 镜像分析工具
		trivy         # Docker 镜像漏洞扫描
	)

	# ---- 5. 文件预览依赖 (Yazi) ----
	local PREVIEW_PACKAGES=(
		ffmpeg      # 视频预览/处理
		imagemagick # 图片预览/处理
		poppler     # PDF 预览
		glow        # Markdown 渲染 (Yazi glow 插件依赖)
	)

	# ---- 6. 实用工具 ----
	local UTIL_PACKAGES=(
		dos2unix # 行尾转换 (WSL 常用)
		pandoc   # 文档格式转换
		pv       # 管道进度查看器
	)

	# 合并所有分类
	local ALL_PACKAGES=(
		"${CORE_PACKAGES[@]}"
		"${MODERN_CLI_PACKAGES[@]}"
		"${MONITOR_PACKAGES[@]}"
		"${DEV_PACKAGES[@]}"
		"${PREVIEW_PACKAGES[@]}"
		"${UTIL_PACKAGES[@]}"
		7zip # Arch 包名
	)

	local to_install=()
	for pkg in "${ALL_PACKAGES[@]}"; do
		if ! pacman -Qi "$pkg" &>/dev/null; then
			to_install+=("$pkg")
		fi
	done

	if [ ${#to_install[@]} -eq 0 ]; then
		info "所有核心工具包已是最新，跳过安装"
	else
		info "使用 yay 安装 ${#to_install[@]} 个缺失的包..."
		yay -S --needed --noconfirm "${to_install[@]}" || {
			warn "部分包可能安装失败，尝试逐个安装..."
			for pkg in "${to_install[@]}"; do
				yay -S --needed --noconfirm "$pkg" || warn "跳过: $pkg"
			done
		}
	fi

	success "核心工具包安装完成"
}

# -------------------- 初始化 Hyprland local.conf --------------------
setup_hyprland_local_conf() {
	step "初始化 Hyprland local 配置占位文件"

	local HYPR_DIR="$HOME/.config/hypr"
	mkdir -p "$HYPR_DIR"
	touch "$HYPR_DIR/local.conf"

	success "Hyprland local.conf 已就绪"
}

# -------------------- 初始化 mise 运行时 --------------------
setup_mise() {
	step "初始化 mise 运行时环境"

	if ! command -v mise &>/dev/null; then
		warn "mise 未安装，跳过运行时初始化"
		return 0
	fi

	# 激活 mise 到当前 shell (install.sh 是 bash)
	eval "$(mise activate bash)"

	# 信任全局配置并安装所有配置的运行时
	info "安装 mise 配置的运行时 (Node, Lua, Python...)..."
	mise trust --all 2>/dev/null || true
	mise install --yes || warn "部分运行时安装可能未成功"
	mise reshim || true

	# 启用 corepack (Node.js 内置，管理 pnpm/yarn)
	if command -v corepack &>/dev/null; then
		info "启用 corepack (pnpm, yarn)..."
		corepack enable 2>/dev/null || true
		success "corepack 已启用"
	else
		warn "corepack 未找到，可能 Node.js 尚未安装完成"
	fi

	success "mise 运行时环境初始化完成"
}

# -------------------- 安装 Rustup --------------------
install_rustup() {
	step "安装 Rustup (Rust 官方工具链)"

	local CARGO_ENV="$HOME/.cargo/env"

	if command -v rustup &>/dev/null || [ -f "$CARGO_ENV" ]; then
		info "Rustup 已安装"
	else
		info "正在安装 Rustup (使用 USTC 镜像加速)..."
		export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
		export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
		success "Rustup 安装完成"
	fi

	# 动态加载环境变量以便当前脚本后续命令可用
	if [ -f "$CARGO_ENV" ]; then
		source "$CARGO_ENV"
	fi

	if command -v rustup &>/dev/null; then
		info "确保核心组件已安装 (clippy, rust-analyzer)..."
		rustup component add clippy rust-analyzer 2>/dev/null || warn "Rust 组件安装可能未完全成功"
	fi
}

# -------------------- 配置 Neovim 运行环境 --------------------
setup_neovim_providers() {
	step "配置 Neovim 运行环境 (Python)"

	# Python 虚拟环境 (通过 uv)
	# 你的 ~/.config/nvim/lua/config/options.lua 已经指定了 python3_host_prog 路径
	local NVIM_VENV="$HOME/.virtualenvs/nvim-python"

	if ! command -v uv &>/dev/null; then
		warn "uv 未安装，跳过 Python 虚拟环境配置"
		return 0
	fi

	info "使用 uv 创建 Neovim 专属 Python 虚拟环境: $NVIM_VENV"
	if [ ! -d "$NVIM_VENV" ]; then
		uv venv "$NVIM_VENV" -q
	fi
	info "安装 pynvim 到虚拟环境..."
	# 使用 uv pip install 确保安装在指定的 venv 内
	uv pip install -p "$NVIM_VENV" pynvim -q
	success "Python 虚拟环境配置完成"
}

# -------------------- 安装 Oh My Zsh --------------------
install_oh_my_zsh() {
	step "检查 Oh My Zsh"

	local OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"

	if [ -d "$OMZ_DIR" ]; then
		info "Oh My Zsh 已安装"
	else
		info "正在安装 Oh My Zsh..."
		# --unattended: 隐含 RUNZSH=no 和 CHSH=no (不切换 shell、不启动 zsh)
		# --keep-zshrc: 不覆盖已有的 .zshrc
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" \
			--unattended --keep-zshrc
		success "Oh My Zsh 安装完成"
	fi

	# 安装 Zsh 第三方插件
	install_zsh_plugins
}

# -------------------- 安装 Zsh 第三方插件 --------------------
install_zsh_plugins() {
	step "安装 Zsh 第三方插件"

	# Arch 通过包管理器安装
	local ZSH_PKGS=(
		zsh-completions
		zsh-autosuggestions
		zsh-syntax-highlighting
	)
	local to_install=()
	for pkg in "${ZSH_PKGS[@]}"; do
		if ! pacman -Qi "$pkg" &>/dev/null; then
			to_install+=("$pkg")
		fi
	done

	if [ ${#to_install[@]} -gt 0 ]; then
		info "使用 yay 安装 ${#to_install[@]} 个缺失的 Zsh 插件..."
		yay -S --needed --noconfirm "${to_install[@]}" || true
	else
		info "所有 Zsh 插件均已安装，跳过"
	fi

	# zsh-shift-select: AUR 中没有此包，统一安装到 OMZ custom 目录
	local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
	local shift_select_dir="$ZSH_CUSTOM/plugins/zsh-shift-select"

	if [ -d "$shift_select_dir" ]; then
		info "插件已存在: zsh-shift-select (跳过)"
	else
		info "克隆插件: zsh-shift-select (Shift+Arrow 文本选择)"
		mkdir -p "$(dirname "$shift_select_dir")"
		git clone --depth 1 https://github.com/jirutka/zsh-shift-select.git "$shift_select_dir"
	fi

	success "Zsh 插件安装完成"
}

# -------------------- 安装 Tmux Plugin Manager (TPM) --------------------
install_tpm() {
	step "检查 Tmux Plugin Manager (TPM)"

	local TPM_DIR="$HOME/.tmux/plugins/tpm"

	if [ -d "$TPM_DIR" ]; then
		info "TPM 已安装"
	else
		info "正在安装 TPM..."
		git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
		success "TPM 安装完成"
	fi
}

# -------------------- 使用 chezmoi 应用 dotfiles --------------------
apply_dotfiles() {
	step "使用 chezmoi 应用 dotfiles"

	local CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
	local DOTFILES_REPO="https://github.com/HFrancisla/dotfiles.git"

	# 如果 source 目录不是一个完整的 Git 仓库，则进行初始化
	if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
		info "正在从远程仓库初始化 chezmoi: $DOTFILES_REPO"

		# 如果存在非 Git 目录，先备份以防冲突
		if [ -d "$CHEZMOI_SOURCE" ]; then
			local backup_name="${CHEZMOI_SOURCE}.bak.$(date +%Y%m%d%H%M%S)"
			warn "发现已存在的非 Git 目录，正在备份到: $backup_name"
			mv "$CHEZMOI_SOURCE" "$backup_name"
		fi

		# 标准初始化：这会自动 clone 仓库到 ~/.local/share/chezmoi
		chezmoi init "$DOTFILES_REPO"
		success "chezmoi 初始化完成"
	else
		info "chezmoi 特征目录已存在，正在拉取远程最新配置..."
		# 使用 chezmoi 的内建 git 命令拉取最新代码
		# --autostash 可以在你有未提交的本地更改时自动暂存，避免 pull 失败
		chezmoi git pull -- --autostash --rebase
		success "本地 dotfiles 仓库已更新"
	fi

	info "对比本地配置与仓库差异 (chezmoi diff)..."

	info "应用 dotfiles (diff 预览)..."
	local diff_output
	diff_output=$(chezmoi diff 2>&1) || true

	if [ -z "$diff_output" ]; then
		info "没有检测到差异 (当前配置已经是最新的)"
		chezmoi apply -v
		success "Dotfiles 已成功应用 (无新变更)"
	else
		echo "$diff_output"
		echo ""
		echo -e "${YELLOW}${BOLD}即将应用以上更改到家目录。${NC}"
		read -rp "是否继续? [Y/n] " confirm </dev/tty
		confirm=${confirm:-Y}

		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			chezmoi apply -v
			success "Dotfiles 已成功应用"
		else
			warn "已跳过 dotfiles 应用，你可以稍后执行: chezmoi apply"
		fi
	fi
}

# -------------------- 安装 Yazi 插件 --------------------
install_yazi_plugins() {
	step "安装 Yazi 插件"

	if ! command -v ya &>/dev/null; then
		warn "ya 命令未找到，跳过 Yazi 插件安装"
		warn "提示: 请确保 yazi 已正确安装，然后手动执行: ya pkg install"
		return 0
	fi

	info "正在安装 Yazi 插件包..."
	ya pkg install || warn "Yazi 插件安装可能未完全成功"

	success "Yazi 插件安装完成"
}

# -------------------- 配置 Kanata 键盘映射 --------------------
setup_kanata() {
	step "配置 Kanata 键盘映射工具"

	# 1. 安装 kanata-bin
	if ! pacman -Qi kanata-bin &>/dev/null; then
		info "使用 yay 安装 kanata-bin..."
		yay -S --needed --noconfirm kanata-bin || {
			warn "kanata-bin 安装失败，请手动检查"
			return 0
		}
		success "kanata-bin 安装完成"
	else
		info "kanata-bin 已安装"
	fi

	# 2. 配置 uinput 权限 (kanata 需要访问 input 和 uinput 子系统)
	info "配置 uinput 权限..."

	# 创建 uinput 组 (如果不存在)
	if ! getent group uinput &>/dev/null; then
		info "创建 uinput 系统组..."
		sudo groupadd --system uinput
	fi

	# 将当前用户添加到 input 和 uinput 组
	if ! id -nG "$USER" | grep -qw input; then
		info "将 $USER 添加到 input 组..."
		sudo usermod -aG input "$USER"
	fi
	if ! id -nG "$USER" | grep -qw uinput; then
		info "将 $USER 添加到 uinput 组..."
		sudo usermod -aG uinput "$USER"
	fi

	# 创建 udev 规则
	local UDEV_RULE='/etc/udev/rules.d/99-input.rules'
	local UDEV_CONTENT='KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"'
	if [ ! -f "$UDEV_RULE" ] || ! grep -q 'uinput' "$UDEV_RULE" 2>/dev/null; then
		info "创建 udev 规则: $UDEV_RULE"
		echo "$UDEV_CONTENT" | sudo tee "$UDEV_RULE" >/dev/null
		sudo udevadm control --reload-rules && sudo udevadm trigger
	else
		info "udev 规则已存在"
	fi

	# 确保 uinput 内核模块已加载
	if ! lsmod | grep -q uinput; then
		info "加载 uinput 内核模块..."
		sudo modprobe uinput
	fi

	# 确保 uinput 模块开机自动加载
	local MODULES_LOAD='/etc/modules-load.d/uinput.conf'
	if [ ! -f "$MODULES_LOAD" ]; then
		info "配置 uinput 模块开机自动加载..."
		echo 'uinput' | sudo tee "$MODULES_LOAD" >/dev/null
	fi

	# 3. 启用 systemd 用户服务 (服务文件由 chezmoi 管理)
	local SERVICE_FILE="$HOME/.config/systemd/user/kanata.service"
	if [ -f "$SERVICE_FILE" ]; then
		info "启用 Kanata systemd 用户服务..."
		systemctl --user daemon-reload
		systemctl --user enable kanata.service
		# 尝试启动服务 (如果组权限尚未生效可能会失败，重新登录后生效)
		systemctl --user start kanata.service 2>/dev/null ||
			warn "Kanata 服务启动失败 (可能需要重新登录以生效用户组权限)"
		success "Kanata systemd 服务已启用 (开机自启)"
	else
		warn "Kanata systemd 服务文件不存在: $SERVICE_FILE"
		warn "请先确认 chezmoi apply 已执行，然后手动运行:"
		warn "  systemctl --user daemon-reload && systemctl --user enable --now kanata.service"
	fi

	success "Kanata 键盘映射配置完成"
}

# -------------------- 设置默认 Shell 为 Zsh --------------------
set_default_shell() {
	step "检查默认 Shell"

	local current_shell
	current_shell=$(getent passwd "$USER" | cut -d: -f7)
	local zsh_path
	zsh_path=$(command -v zsh 2>/dev/null || echo "/usr/bin/zsh")

	if [ "$current_shell" = "$zsh_path" ]; then
		info "默认 Shell 已经是 Zsh"
		return 0
	fi

	# 确保 zsh 在 /etc/shells 中
	if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
		info "将 $zsh_path 添加到 /etc/shells ..."
		echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
	fi

	echo -e "${YELLOW}当前默认 Shell: ${current_shell}${NC}"
	read -rp "是否将默认 Shell 切换为 Zsh? [Y/n] " confirm </dev/tty
	confirm=${confirm:-Y}

	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		chsh -s "$zsh_path"
		success "默认 Shell 已切换为 Zsh (重新登录后生效)"
	else
		warn "已跳过 Shell 切换，你可以稍后执行: chsh -s $zsh_path"
	fi
}

# -------------------- 安装 Tmux 插件 --------------------
install_tmux_plugins() {
	step "安装 Tmux 插件"

	local TPM_DIR="$HOME/.tmux/plugins/tpm"

	if [ ! -x "$TPM_DIR/bin/install_plugins" ]; then
		warn "TPM 安装脚本未找到，跳过"
		return 0
	fi

	info "正在安装 Tmux 插件..."
	"$TPM_DIR/bin/install_plugins" || warn "部分 Tmux 插件安装可能未成功"

	success "Tmux 插件安装完成"
}

# -------------------- 最终验证 --------------------
post_install_check() {
	step "安装验证"

	local all_ok=true
	local tools=(
		chezmoi git zsh nvim tmux
		starship fastfetch btop fzf
		eza zoxide fd bat rg sd
		dust duf procs gping tldr
		diff-so-fancy delta yazi lazygit jq yq dasel xmlstarlet gh
		ffmpeg pandoc
		kanata
	)

	# 有多个可能命令名的工具 (主命令|备选命令)
	local tools_with_alt=(
		"magick|convert" # ImageMagick v7 vs v6
		"7zz|7z"         # 7zip vs p7zip
	)

	echo ""
	printf "  %-18s %s\n" "工具" "状态"
	printf "  %-18s %s\n" "──────────────────" "──────"

	for tool in "${tools[@]}"; do
		if command -v "$tool" &>/dev/null; then
			printf "  %-18s ${GREEN}✓ 已安装${NC}\n" "$tool"
		else
			printf "  %-18s ${RED}✗ 未检测到${NC}\n" "$tool"
			all_ok=false
		fi
	done

	for entry in "${tools_with_alt[@]}"; do
		IFS='|' read -ra cmds <<<"$entry"
		local found=false found_cmd=""
		for cmd in "${cmds[@]}"; do
			if command -v "$cmd" &>/dev/null; then
				found=true
				found_cmd="$cmd"
				break
			fi
		done
		if $found; then
			printf "  %-18s ${GREEN}✓ 已安装${NC}\n" "$found_cmd"
		else
			printf "  %-18s ${RED}✗ 未检测到${NC}\n" "${cmds[0]}"
			all_ok=false
		fi
	done

	echo ""
	if $all_ok; then
		success "所有工具已就绪！"
	else
		warn "部分工具未检测到，请检查以上列表"
	fi
}

# -------------------- 打印安装摘要 --------------------
print_summary() {
	echo ""
	echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}${BOLD}║         🎉 Dotfiles 部署完成!                   ║${NC}"
	echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
	echo ""
	echo -e "  ${BOLD}后续操作:${NC}"
	echo -e "  1. 重新登录或执行 ${GREEN}exec zsh${NC} 以加载新配置"
	echo -e "  2. 在 tmux 中按 ${GREEN}Ctrl+Space, I${NC} 安装 tmux 插件"
	echo -e "  3. 打开 nvim 将自动安装 LazyVim 插件"
	echo -e "  4. 执行 ${GREEN}ya pkg install${NC} 安装 Yazi 插件 (如未自动安装)"
	echo -e "  5. 执行 ${GREEN}tldr --update${NC} 更新 tealdeer 缓存"
	echo -e "  6. 如果 Kanata 服务未自动启动，重新登录后执行:"
	echo -e "     ${GREEN}systemctl --user status kanata.service${NC} 检查状态"
	echo ""
	echo -e "  ${BOLD}常用命令:${NC}"
	echo -e "  • ${GREEN}chezmoi edit <file>${NC}  编辑配置"
	echo -e "  • ${GREEN}chezmoi diff${NC}         查看变更"
	echo -e "  • ${GREEN}chezmoi apply${NC}        应用配置"
	echo -e "  • ${GREEN}chezmoi cd${NC}           进入 source 目录"
	echo ""
}

# ==================== 主流程 ====================
main() {
	echo ""
	echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}${BOLD}║      🚀 Dotfiles 一键部署脚本 (Arch Linux)      ║${NC}"
	echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
	echo ""

	detect_os
	install_prerequisites
	install_packages
	# 创建 SSH 连接复用 socket 目录 (ControlPath 依赖)
	mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets
	# 将 apply_dotfiles 提前，确保后续步骤能读取到配置 (如 config.toml, package.toml 等)
	apply_dotfiles
	setup_hyprland_local_conf
	setup_mise
	install_rustup
	setup_neovim_providers
	install_oh_my_zsh
	install_tpm
	install_yazi_plugins
	setup_kanata
	install_tmux_plugins
	set_default_shell
	post_install_check
	print_summary
}

main "$@"
