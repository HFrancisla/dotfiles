#!/bin/bash
# Arch Linux bootstrap。可在仓库中直接执行，也可从 raw URL 管道执行。

set -Eeuo pipefail

if ((BASH_VERSINFO[0] < 4)); then
	echo -e "\033[0;31m[ERROR]\033[0m 此脚本需要 Bash 4.0+，当前版本: $BASH_VERSION" >&2
	exit 1
fi

trap 'echo -e "\033[0;31m[ERROR]\033[0m 安装过程中发生错误 (行 $LINENO)，请检查输出信息" >&2; exit 1' ERR

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

if (( EUID == 0 )); then
	error "请以普通用户运行安装脚本，不要使用 sudo bash"
	exit 1
fi

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

	# AUR 构建固定优先使用系统工具链。
	export PATH="/usr/bin:$PATH"

	info "检测到操作系统: ${BOLD}${OS_ID}${NC}"
}

install_prerequisites() {
	step "检查基础依赖 (git, curl, zsh, base-devel)"

	info "同步软件源并升级系统..."
	sudo pacman -Syu --noconfirm

	local missing=()
	for pkg in git curl zsh base-devel gnupg bind strace ltrace bpftrace bcc-tools bubblewrap less unzip; do
		if ! pacman -Qi "$pkg" &>/dev/null; then
			missing+=("$pkg")
		fi
	done

	if [ ${#missing[@]} -gt 0 ]; then
		info "安装缺失的基础依赖: ${missing[*]}"
		sudo pacman -S --needed --noconfirm "${missing[@]}"
	fi

	if ! command -v yay &>/dev/null; then
		warn "未检测到 yay，正在安装..."
		install_yay
	fi

	success "基础依赖已就绪"
}

install_yay() (
	info "从源码编译安装 yay..."
	local yay_dir
	yay_dir=$(mktemp -d)
	trap 'rm -rf "$yay_dir"' EXIT
	git clone https://aur.archlinux.org/yay.git "$yay_dir/yay"
	(cd "$yay_dir/yay" && makepkg -si --noconfirm)
	rm -rf "$yay_dir"
	trap - EXIT
	success "yay 安装完成"
)

install_packages() {
	step "安装核心工具包"

	local CORE_PACKAGES=(
		chezmoi
		neovim
		tmux
		starship
		fzf
		yazi
	)

	local MODERN_CLI_PACKAGES=(
		eza
		zoxide
		bat
		ripgrep
		fd
		sd
		dust
		duf
		procs
		gping
		tealdeer
	)

	local MONITOR_PACKAGES=(
		btop
		htop
		bottom
		fastfetch
		gdu
		ncdu
		bandwhich
		trippy
		mtr
		progress
	)

	local DEV_PACKAGES=(
		llvm
		clang
		mise
		gdb
		shellcheck
		github-cli
		lazygit
		serpl
		jq
		yq
		dasel
		xmlstarlet
		diff-so-fancy
		git-delta
		sqlite
		uv
		dive
		trivy
	)

	local DB_PACKAGES=(
		postgresql-libs
		pgcli
		mycli
		iredis
		pspg
	)

	local PREVIEW_PACKAGES=(
		ffmpeg
		imagemagick
		poppler
		glow
	)

	local UTIL_PACKAGES=(
		dos2unix
		pandoc-cli
		pv
	)

	local ALL_PACKAGES=(
		"${CORE_PACKAGES[@]}"
		"${MODERN_CLI_PACKAGES[@]}"
		"${MONITOR_PACKAGES[@]}"
		"${DEV_PACKAGES[@]}"
		"${DB_PACKAGES[@]}"
		"${PREVIEW_PACKAGES[@]}"
		"${UTIL_PACKAGES[@]}"
		7zip
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
		if ! yay -S --needed --noconfirm "${to_install[@]}"; then
			warn "部分包可能安装失败，尝试逐个安装..."
			local failed=()
			for pkg in "${to_install[@]}"; do
				if ! yay -S --needed --noconfirm "$pkg"; then
					failed+=("$pkg")
				fi
			done
			if [ ${#failed[@]} -gt 0 ]; then
				error "以下核心包安装失败: ${failed[*]}"
				return 1
			fi
		fi
	fi

	success "核心工具包安装完成"
}

setup_hyprland_local_lua() {
	step "初始化 Hyprland local 配置占位文件"

	local HYPR_DIR="$HOME/.config/hypr"
	mkdir -p "$HYPR_DIR"
	touch "$HYPR_DIR/local.lua"

	success "Hyprland local.lua 已就绪"
}

setup_runtime_dirs() {
	step "准备运行时目录"

	mkdir -p "$HOME/.local/state/gdb" "$HOME/.local/state/postgresql" "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	success "运行时目录已就绪"
}

setup_mise() {
	step "初始化 mise 运行时和 CLI 工具"

	if ! command -v mise &>/dev/null; then
		error "mise 未安装，无法初始化运行时和 CLI 工具"
		return 1
	fi

	# 激活 mise 到当前 bootstrap Bash 进程。
	eval "$(mise activate bash)"

	# 全局配置只有静态 tools/settings，不需要 trust；直接安装所有配置工具。
	info "安装 mise 配置的运行时和 CLI 工具..."
	if ! MISE_NODE_VERIFY=true MISE_NODE_GPG_VERIFY=true mise install --yes; then
		error "mise 工具安装失败"
		return 1
	fi
	mise reshim
	# mise 自带 LuaRocks，校验其解释器版本，避免系统 LuaRocks 指向其他 Lua。
	if [[ "$(mise exec -- lua -e 'print(_VERSION)')" != "Lua 5.1" ]] ||
	   [[ "$(mise exec -- luarocks config lua_version)" != "5.1" ]]; then
		error "mise Lua 与 LuaRocks 版本不一致"
		return 1
	fi

	success "mise 工具环境初始化完成"
}

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

	if [ -f "$CARGO_ENV" ]; then
		# shellcheck source=/dev/null
		source "$CARGO_ENV"
	fi

	if command -v rustup &>/dev/null; then
		info "确保核心组件已安装 (clippy, rust-analyzer)..."
		rustup component add clippy rust-analyzer
	fi
}

setup_neovim_providers() {
	step "配置 Neovim 运行环境 (Python)"

	# options.lua 固定使用该虚拟环境作为 Python provider。
	local NVIM_VENV="$HOME/.virtualenvs/nvim-python"

	if ! command -v uv &>/dev/null; then
		error "uv 未安装，无法配置 Neovim Python provider"
		return 1
	fi

	info "使用 uv 创建 Neovim 专属 Python 虚拟环境: $NVIM_VENV"
	if [ ! -d "$NVIM_VENV" ]; then
		uv venv "$NVIM_VENV" -q
	fi
	info "安装 pynvim 到虚拟环境..."
	uv pip install -p "$NVIM_VENV" pynvim -q
	success "Python 虚拟环境配置完成"
}

install_oh_my_zsh() {
	step "检查 Oh My Zsh"

	local OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"

	if [ -r "$OMZ_DIR/oh-my-zsh.sh" ]; then
		info "Oh My Zsh 已安装"
	elif [ -e "$OMZ_DIR" ]; then
		error "Oh My Zsh 目录存在但不完整: $OMZ_DIR，请检查后重试"
		return 1
	else
		info "正在安装 Oh My Zsh..."
		# 不启动 Zsh、不切换默认 shell，也不覆盖现有 .zshrc。
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" \
			--unattended --keep-zshrc
		success "Oh My Zsh 安装完成"
	fi

	install_zsh_plugins
}

install_zsh_plugins() {
	step "安装 Zsh 第三方插件"

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
		yay -S --needed --noconfirm "${to_install[@]}"
	else
		info "所有 Zsh 插件均已安装，跳过"
	fi

	# zsh-shift-select: AUR 中没有此包，统一安装到 OMZ custom 目录
	local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
	local shift_select_dir="$ZSH_CUSTOM/plugins/zsh-shift-select"

	if [ -r "$shift_select_dir/zsh-shift-select.plugin.zsh" ]; then
		info "插件已存在: zsh-shift-select (跳过)"
	elif [ -e "$shift_select_dir" ]; then
		error "插件目录存在但不完整: $shift_select_dir"
		return 1
	else
		info "克隆插件: zsh-shift-select (Shift+Arrow 文本选择)"
		mkdir -p "$(dirname "$shift_select_dir")"
		git clone --depth 1 https://github.com/jirutka/zsh-shift-select.git "$shift_select_dir"
	fi

	success "Zsh 插件安装完成"
}

install_tpm() {
	step "检查 Tmux Plugin Manager (TPM)"

	local TPM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tpm"

	if [ -x "$TPM_DIR/tpm" ]; then
		info "TPM 已安装"
	else
		info "正在安装 TPM..."
		if [ -e "$TPM_DIR" ]; then
			error "TPM 目录存在但不完整: $TPM_DIR，请检查后重试"
			return 1
		fi
		mkdir -p "$(dirname "$TPM_DIR")"
		git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
		success "TPM 安装完成"
	fi
}

apply_dotfiles() {
	step "使用 chezmoi 应用 dotfiles"

	local CHEZMOI_SOURCE="$HOME/workspace/personal/dotfiles"
	local DOTFILES_REPO="https://github.com/HFrancisla/dotfiles.git"

	# 开发仓库本身就是唯一的 chezmoi source，不再维护 ~/.local/share/chezmoi 的第二份 clone。
	if [ ! -e "$CHEZMOI_SOURCE/.git" ]; then
		info "正在克隆 dotfiles 开发仓库到: $CHEZMOI_SOURCE"

		# 如果存在非 Git 目录，先备份以防冲突
		if [ -d "$CHEZMOI_SOURCE" ]; then
			local backup_name
			backup_name="${CHEZMOI_SOURCE}.bak.$(date +%Y%m%d%H%M%S)"
			warn "发现已存在的非 Git 目录，正在备份到: $backup_name"
			mv "$CHEZMOI_SOURCE" "$backup_name"
		fi

		mkdir -p "$(dirname "$CHEZMOI_SOURCE")"
		chezmoi init --source "$CHEZMOI_SOURCE" "$DOTFILES_REPO"
		success "dotfiles 开发仓库已由 chezmoi 初始化"
	else
		info "使用已有 dotfiles 开发仓库；不自动 pull/rebase 或修改 Git 工作区"
		git -C "$CHEZMOI_SOURCE" rev-parse --is-inside-work-tree >/dev/null
		# 重新渲染 chezmoi 配置，确保 sourceDir 与当前开发仓库一致。
		chezmoi init --source "$CHEZMOI_SOURCE"
		success "已绑定现有本地 dotfiles 仓库"
	fi

	if [ "$(chezmoi source-path)" != "$CHEZMOI_SOURCE" ]; then
		error "chezmoi sourceDir 未正确指向开发仓库: $(chezmoi source-path)"
		return 1
	fi
	success "chezmoi source 已绑定到开发仓库"

	info "对比本地配置与仓库差异 (chezmoi diff)..."

	info "应用 dotfiles (diff 预览)..."
	local diff_output
	if ! diff_output=$(chezmoi diff 2>&1); then
		error "chezmoi diff 失败，停止部署以避免基于无效配置继续执行"
		echo "$diff_output" >&2
		return 1
	fi

	if [ -z "$diff_output" ]; then
		info "没有检测到差异 (当前配置已经是最新的)"
		chezmoi apply -v
		success "Dotfiles 已成功应用 (无新变更)"
	else
		echo "$diff_output"
		echo ""
		echo -e "${YELLOW}${BOLD}即将应用以上更改到家目录。${NC}"
		read -rp "是否继续? [y/N] " confirm </dev/tty || return 1

		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			chezmoi apply -v
			success "Dotfiles 已成功应用"
		else
			error "已取消 dotfiles 应用；后续步骤依赖已应用的配置，因此停止部署"
			return 1
		fi
	fi
}

install_yazi_plugins() {
	step "安装 Yazi 插件"

	if ! command -v ya &>/dev/null; then
		error "ya 命令未找到，无法安装 Yazi 插件"
		return 1
	fi

	info "正在安装 Yazi 插件包..."
	ya pkg install

	success "Yazi 插件安装完成"
}

setup_kanata() {
	step "配置 Kanata 键盘映射工具"

	if ! pacman -Qi kanata-bin &>/dev/null; then
		info "使用 yay 安装 kanata-bin..."
		yay -S --needed --noconfirm kanata-bin
		success "kanata-bin 安装完成"
	else
		info "kanata-bin 已安装"
	fi

	# 先解析配置，再申请输入设备权限。
	/usr/bin/kanata --check --cfg "$HOME/.config/kanata/kanata.kbd"

	# Kanata 需要 input 读权限和 uinput 写权限。
	info "配置 uinput 权限..."

	if ! getent group uinput &>/dev/null; then
		info "创建 uinput 系统组..."
		sudo groupadd --system uinput
	fi

	if ! id -nG "$USER" | grep -qw input; then
		info "将 $USER 添加到 input 组..."
		sudo usermod -aG input "$USER"
	fi
	if ! id -nG "$USER" | grep -qw uinput; then
		info "将 $USER 添加到 uinput 组..."
		sudo usermod -aG uinput "$USER"
	fi

	local UDEV_RULE='/etc/udev/rules.d/99-dotfiles-kanata.rules'
	local UDEV_CONTENT='KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"'
	if [ ! -f "$UDEV_RULE" ] || ! grep -Fxq "$UDEV_CONTENT" "$UDEV_RULE"; then
		info "创建 udev 规则: $UDEV_RULE"
		echo "$UDEV_CONTENT" | sudo tee "$UDEV_RULE" >/dev/null
		sudo udevadm control --reload-rules
		sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput
	else
		info "udev 规则已存在"
	fi

	if [ ! -e /dev/uinput ]; then
		info "加载 uinput 内核模块..."
		sudo modprobe uinput
	fi

	local MODULES_LOAD='/etc/modules-load.d/dotfiles-kanata.conf'
	if [ ! -f "$MODULES_LOAD" ] || ! grep -Fxq uinput "$MODULES_LOAD"; then
		info "配置 uinput 模块开机自动加载..."
		echo 'uinput' | sudo tee "$MODULES_LOAD" >/dev/null
	fi

	local SERVICE_FILE="$HOME/.config/systemd/user/kanata.service"
	if [ -f "$SERVICE_FILE" ]; then
		info "启用 Kanata systemd 用户服务..."
		systemctl --user daemon-reload
		systemctl --user enable kanata.service
		# 新增组权限可能要重新登录后才生效。
		systemctl --user start kanata.service 2>/dev/null ||
			warn "Kanata 服务启动失败 (可能需要重新登录以生效用户组权限)"
		success "Kanata systemd 服务已启用 (开机自启)"
	else
		error "Kanata systemd 服务文件不存在: $SERVICE_FILE"
		return 1
	fi

	success "Kanata 键盘映射配置完成"
}

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

install_tmux_plugins() {
	step "安装 Tmux 插件"

	local TPM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tpm"

	if [ ! -x "$TPM_DIR/bin/install_plugins" ]; then
		error "TPM 安装脚本未找到: $TPM_DIR/bin/install_plugins"
		return 1
	fi

	info "正在安装 Tmux 插件..."
	"$TPM_DIR/bin/install_plugins"

	success "Tmux 插件安装完成"
}

post_install_check() {
	step "安装验证"

	local all_ok=true
	local tools=(
		chezmoi git zsh nvim tmux
		starship fastfetch btop htop btm fzf
		eza zoxide fd bat rg sd
		dust duf procs gping tldr
		diff-so-fancy delta yazi lazygit serpl jq yq dasel xmlstarlet gh
		gdu ncdu bandwhich trip mtr progress
		clang luarocks sqlite3 uv dive trivy shellcheck
		ffmpeg pdftotext glow pandoc dos2unix pv less unzip
		gdb psql pgcli mycli iredis pspg
		mise node npm pnpm tree-sitter lua python3 java go
		neovim-node-host mmdc opencode pi voyager paseo
		rustup cargo rustc clippy-driver rust-analyzer
	)

	if $INSTALL_KANATA; then tools+=(kanata); fi

	# 验证可能因发行版版本不同而改名的命令。
	local tools_with_alt=(
		"magick|convert" # ImageMagick v7 vs v6
		"7zz|7z"         # 7zip vs p7zip
	)

	echo ""
	printf "  %-18s %s\n" "工具" "状态"
	printf "  %-18s %s\n" "──────────────────" "──────"

	for tool in "${tools[@]}"; do
		local resolved
		resolved=$(command -v "$tool" 2>/dev/null) || resolved=""
		if [[ "$resolved" == */mise/shims/* ]]; then
			resolved=$(mise which "$tool" 2>/dev/null) || resolved=""
		fi
		if [[ -n "$resolved" && -x "$resolved" ]]; then
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
		error "安装验证失败：仍有必需工具未检测到"
		return 1
	fi
}

print_summary() {
	echo ""
	echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}${BOLD}║         🎉 Dotfiles 部署完成!                   ║${NC}"
	echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
	echo ""
	echo -e "  ${BOLD}后续操作:${NC}"
	echo -e "  1. 重新登录或执行 ${GREEN}exec env -u ZDOTDIR zsh${NC} 以加载新配置"
	echo -e "  2. 打开 nvim 将自动安装/同步 LazyVim 插件"
	echo -e "  3. 执行 ${GREEN}tldr --update${NC} 更新 tealdeer 缓存"
	echo -e "  4. 如需 Hyprland 桌面，执行 ${GREEN}./install_desktop_arch.sh${NC}"
	if $INSTALL_KANATA; then
		echo -e "  5. Kanata 如未启动，重新登录后运行 systemctl --user status kanata.service"
	else
		echo -e "  5. Kanata 为可选组件，如需要，使用 --kanata 参数安装"
	fi
	echo ""
	echo -e "  ${BOLD}常用命令:${NC}"
	echo -e "  • ${GREEN}chezmoi edit <file>${NC}  编辑配置"
	echo -e "  • ${GREEN}chezmoi diff${NC}         查看变更"
	echo -e "  • ${GREEN}chezmoi apply${NC}        应用配置"
	echo -e "  • ${GREEN}chezmoi cd${NC}           进入 source 目录"
	echo ""
}

main() {
	INSTALL_KANATA=false
	case "${1:-}" in
		--kanata) INSTALL_KANATA=true; shift ;;
	esac
	if (( $# )); then
		error "用法: bash install_arch.sh [--kanata]"
		return 2
	fi
	echo ""
	echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}${BOLD}║      🚀 Dotfiles 一键部署脚本 (Arch Linux)      ║${NC}"
	echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
	echo ""

	detect_os
	install_prerequisites
	install_packages
	setup_runtime_dirs
	# 后续步骤依赖已部署的 mise/Yazi 配置。
	apply_dotfiles
	setup_hyprland_local_lua
	setup_mise
	install_rustup
	setup_neovim_providers
	install_oh_my_zsh
	install_tpm
	install_yazi_plugins
	if $INSTALL_KANATA; then setup_kanata; fi
	install_tmux_plugins
	set_default_shell
	post_install_check
	print_summary
}

main "$@"
