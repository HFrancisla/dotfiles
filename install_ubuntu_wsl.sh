#!/bin/bash
# ==============================================================================
# Dotfiles One-Click Deployment Script (chezmoi) — Ubuntu / WSL2
# ==============================================================================
# 支持的环境:
#   - Ubuntu 原生环境 (使用 Homebrew)
#   - Ubuntu on WSL2
#
# 用法:
#   curl -fsSL <raw_url>/install_ubuntu_wsl.sh | bash
#   或者 clone 后直接执行: bash install_ubuntu_wsl.sh
# ==============================================================================

set -Eeuo pipefail

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

# 安装过程中需要普通用户的 HOME 及配置；特权操作由 sudo 单独执行。
if (( EUID == 0 )); then
	error "请以普通用户运行安装脚本，不要使用 sudo bash"
	exit 1
fi

# -------------------- OS 检测 --------------------
detect_os() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		OS_ID="$ID"
	else
		OS_ID="unknown"
	fi

	if [ "$OS_ID" != "ubuntu" ]; then
		error "此脚本仅适用于 Ubuntu（原生或 WSL），检测到: $OS_ID"
		exit 1
	fi

	IS_WSL=false
	if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
		IS_WSL=true
	fi

	info "检测到操作系统: ${BOLD}${OS_ID}${NC}"
	if $IS_WSL; then
		info "检测到 WSL 环境"
	fi
}

# -------------------- 基础依赖检查与安装 --------------------
install_prerequisites() {
	step "检查基础依赖 (git, curl, zsh, build-essential)"

	local missing=()
	for pkg in git curl zsh build-essential procps file dnsutils gnupg strace ltrace bpftrace bpfcc-tools bubblewrap gdb postgresql-client less unzip; do
		if [[ "$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null)" != "install ok installed" ]]; then
			missing+=("$pkg")
		fi
	done
	if [ ${#missing[@]} -gt 0 ]; then
		info "安装缺失的基础依赖: ${missing[*]}"
		sudo apt-get update -qq
		sudo apt-get install -y -qq "${missing[@]}"
	fi

	success "基础依赖已就绪"
}

# -------------------- 安装 Homebrew --------------------
install_homebrew() {
	step "检查 Homebrew"

	if command -v brew &>/dev/null; then
		info "Homebrew 已安装"
		return 0
	fi

	info "正在安装 Homebrew..."
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# 加载 Homebrew 到当前 shell
	if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi

	success "Homebrew 安装完成"
}

# -------------------- 安装核心工具包 --------------------
install_packages() {
	step "安装核心工具包"

	info "更新 Homebrew 软件源..."
	brew update --quiet

	# ---- 1. 核心终端增强 ----
	local CORE_PACKAGES=(
		chezmoi  # dotfiles 管理
		git      # OpenSSL 版 git (替代 Ubuntu 系统的 GnuTLS 版，避免 WSL TLS 握手失败)
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
		mise          # 多语言版本管理 (Node/Lua/Python/Java/Go + CLI)
		shellcheck    # Shell 静态分析 (scripts/check.sh 依赖)
		gh            # GitHub CLI (Homebrew 包名)
		lazygit       # Git TUI (LazyVim 集成)
		serpl         # 项目级搜索替换 TUI (tmux 快捷键依赖)
		jq            # JSON 处理
		yq            # YAML/XML/TOML 处理
		dasel         # 多格式数据查询/修改 (JSON/YAML/TOML/CSV/XML)
		xmlstarlet    # XML 处理工具
		repren        # 多模式批量重命名/替换
		diff-so-fancy # Git diff 美化
		git-delta     # Git diff 语法高亮分页器
		sqlite        # SQLite 库 (Neovim yanky.nvim sqlite.lua 依赖)
		uv            # Python 包/虚拟环境管理
		dive          # Docker 镜像分析工具
		trivy         # Docker 镜像漏洞扫描
	)

	# ---- 5. 数据库客户端 ----
	local DB_PACKAGES=(
		pgcli  # PostgreSQL 交互客户端
		mycli  # MySQL 交互客户端
		iredis # Redis 交互客户端
		pspg   # 表格 pager
	)

	# ---- 6. 文件预览依赖 (Yazi) ----
	local PREVIEW_PACKAGES=(
		ffmpeg      # 视频预览/处理
		imagemagick # 图片预览/处理
		poppler     # PDF 预览
		glow        # Markdown 渲染 (Yazi glow 插件依赖)
	)

	# ---- 7. 实用工具 ----
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
		"${DB_PACKAGES[@]}"
		"${PREVIEW_PACKAGES[@]}"
		"${UTIL_PACKAGES[@]}"
		sevenzip # Homebrew 包名
	)

	local to_install=()
	for pkg in "${ALL_PACKAGES[@]}"; do
		if ! brew list "$pkg" &>/dev/null; then
			to_install+=("$pkg")
		fi
	done

	if [ ${#to_install[@]} -eq 0 ]; then
		info "所有核心工具包已是最新，跳过安装"
	else
		info "使用 brew 安装 ${#to_install[@]} 个缺失的包..."
		if ! brew install "${to_install[@]}"; then
			warn "部分包可能安装失败，尝试逐个安装..."
			local failed=()
			for pkg in "${to_install[@]}"; do
				if ! brew install "$pkg"; then
					failed+=("$pkg")
				fi
			done
			if [ ${#failed[@]} -gt 0 ]; then
				error "以下 Homebrew 包安装失败: ${failed[*]}"
				return 1
			fi
		fi
	fi

	# llvm 是 Homebrew keg-only；让当前 bootstrap 进程立即可用，
	# 与 ~/.zshenv 中的长期 PATH 配置保持一致。
	local llvm_prefix
	llvm_prefix=$(brew --prefix llvm)
	export PATH="$llvm_prefix/bin:$PATH"

	success "核心工具包安装完成"
}

# -------------------- 准备运行时目录 --------------------
setup_runtime_dirs() {
	step "准备运行时目录"

	mkdir -p "$HOME/.local/state/gdb" "$HOME/.local/state/postgresql" "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	success "运行时目录已就绪"
}

# -------------------- 初始化 mise 运行时 --------------------
setup_mise() {
	step "初始化 mise 运行时和 CLI 工具"

	if ! command -v mise &>/dev/null; then
		error "mise 未安装，无法初始化运行时和 CLI 工具"
		return 1
	fi

	# 激活 mise 到当前 bootstrap Bash 进程。
	eval "$(mise activate bash)"

	# 使用系统 GnuPG，避免 Homebrew gpg 与系统 keyboxd 版本冲突。
	# 保留 mise 的 Node.js 签名校验，不设置 MISE_NODE_VERIFY=false。
	# 全局配置只有静态 tools/settings，不需要 trust；直接安装所有配置工具。
	info "安装 mise 配置的运行时和 CLI 工具..."
	if ! PATH="/usr/bin:$PATH" MISE_NODE_VERIFY=true MISE_NODE_GPG_VERIFY=true mise install --yes; then
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
		# shellcheck source=/dev/null
		source "$CARGO_ENV"
	fi

	if command -v rustup &>/dev/null; then
		info "确保核心组件已安装 (clippy, rust-analyzer)..."
		rustup component add clippy rust-analyzer
	fi
}

# -------------------- 配置 Neovim 运行环境 --------------------
setup_neovim_providers() {
	step "配置 Neovim 运行环境 (Python)"

	# Python 虚拟环境 (通过 uv)
	# 你的 ~/.config/nvim/lua/config/options.lua 已经指定了 python3_host_prog 路径
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
	# 使用 uv pip install 确保安装在指定的 venv 内
	uv pip install -p "$NVIM_VENV" pynvim -q
	success "Python 虚拟环境配置完成"
}

# -------------------- 安装 Oh My Zsh --------------------
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

	# 其他系统: clone 到 Oh My Zsh custom plugins 目录
	local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
	local plugins_dir="$ZSH_CUSTOM/plugins"
	mkdir -p "$plugins_dir"

	local -A ZSH_PLUGIN_REPOS=(
		[zsh-completions]="https://github.com/zsh-users/zsh-completions.git"
		[zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
		[zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
	)

	for plugin_name in "${!ZSH_PLUGIN_REPOS[@]}"; do
		local plugin_dir="$plugins_dir/$plugin_name"
		local plugin_entry
		case "$plugin_name" in
			zsh-completions) plugin_entry="$plugin_dir/src" ;;
			*) plugin_entry="$plugin_dir/$plugin_name.plugin.zsh" ;;
		esac
		if [ -e "$plugin_entry" ]; then
			info "插件已存在: $plugin_name (跳过)"
		elif [ -e "$plugin_dir" ]; then
			error "插件目录存在但不完整: $plugin_dir"
			return 1
		else
			info "克隆插件: $plugin_name"
			git clone --depth 1 "${ZSH_PLUGIN_REPOS[$plugin_name]}" "$plugin_dir"
		fi
	done

	# zsh-shift-select: 统一安装到 OMZ custom 目录
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

# -------------------- 安装 Tmux Plugin Manager (TPM) --------------------
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

# -------------------- 使用 chezmoi 应用 dotfiles --------------------
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

# -------------------- 安装 Yazi 插件 --------------------
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

	local TPM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tpm"

	if [ ! -x "$TPM_DIR/bin/install_plugins" ]; then
		error "TPM 安装脚本未找到: $TPM_DIR/bin/install_plugins"
		return 1
	fi

	info "正在安装 Tmux 插件..."
	"$TPM_DIR/bin/install_plugins"

	success "Tmux 插件安装完成"
}

# -------------------- 最终验证 --------------------
post_install_check() {
	step "安装验证"

	local all_ok=true
	local tools=(
		chezmoi git zsh nvim tmux
		starship fastfetch btop htop fzf
		eza zoxide fd bat rg sd
		dust duf procs gping tldr
		diff-so-fancy delta yazi lazygit serpl jq yq dasel xmlstarlet repren gh
		bandwhich trip mtr progress
		clang luarocks sqlite3 dive trivy shellcheck
		mise uv btm ncdu glow
		ffmpeg pdftotext pandoc dos2unix pv less unzip
		gdb psql pgcli mycli iredis pspg
		node npm pnpm tree-sitter lua python3 java go
		neovim-node-host mmdc opencode pi voyager paseo
		rustup cargo rustc clippy-driver rust-analyzer
	)

	# 有多个可能命令名的工具 (主命令|备选命令)
	local tools_with_alt=(
		"gdu|gdu-go"     # gdu vs gdu-go (Homebrew Linux 可能避免与 coreutils du 冲突)
		"magick|convert" # ImageMagick v7 vs v6
		"7zz|7z"         # 7zip vs p7zip
	)

	echo ""
	printf "  %-18s %s\n" "Tool" "Status"
	printf "  %-18s %s\n" "------------------" "------"

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

# -------------------- 打印安装摘要 --------------------
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
	echo -e "${CYAN}${BOLD}║      🚀 Dotfiles 一键部署脚本 (Ubuntu/WSL)      ║${NC}"
	echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
	echo ""

	detect_os
	install_prerequisites
	install_homebrew
	install_packages
	setup_runtime_dirs
	# 将 apply_dotfiles 提前，确保后续步骤能读取到配置 (如 config.toml, package.toml 等)
	apply_dotfiles
	setup_mise
	install_rustup
	setup_neovim_providers
	install_oh_my_zsh
	install_tpm
	install_yazi_plugins
	install_tmux_plugins
	set_default_shell
	post_install_check
	print_summary
}

main "$@"
