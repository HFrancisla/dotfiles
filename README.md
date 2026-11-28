# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

The canonical local source is the development repository at
`~/workspace/personal/dotfiles`. On a fresh machine, bootstrap runs
`chezmoi init --source ~/workspace/personal/dotfiles <repo>`, so chezmoi clones
the repository directly to that path and the generated config records the actual
source directory. After initialization, plain
`chezmoi diff`, `chezmoi apply`, and `chezmoi update` use this repository
directly; no second clone under `~/.local/share/chezmoi` is required.

## Stack

| Category | Tools |
|---|---|
| Shell | Zsh · Oh My Zsh · Starship |
| Editor | Neovim (LazyVim) |
| Terminal | tmux · yazi · fzf · zoxide |
| CLI | eza · bat · fd · ripgrep · mise |
| DB clients | psql · pgcli · mycli · iredis · pspg |
| Desktop | Hyprland · Waybar · kanata (Arch only) |
| Package mgr | Homebrew · apt · pacman/yay |

## Structure

```
.
├── dot_config/        → ~/.config/
├── private_dot_ssh/   → ~/.ssh/ (private permissions)
├── dot_zshenv         → ~/.zshenv
├── install_arch.sh        # Arch Linux bootstrap
├── install_desktop_arch.sh
└── install_ubuntu_wsl.sh  # Ubuntu/WSL bootstrap
```

SSH 的通用默认值由 chezmoi 管理在 `~/.ssh/config.d/10-dotfiles.conf`。
`~/.ssh/config` 使用 chezmoi 的 `modify_` 机制只维护文件末尾的共享 Include，
不会整体接管主配置，因此机器私有 Host 配置可以继续保留并优先于共享默认值。

## 部署及安全策略

- Ubuntu / WSL 使用 `bash install_ubuntu_wsl.sh`；Arch 基础环境使用
  `bash install_arch.sh`。两个 bootstrap 保留独立入口，支持从 raw URL 单独运行，
  已存在的开发仓库不自动执行 pull/rebase；更新由开发者自行管理。
- Arch 的键盘重映射为可选项：`bash install_arch.sh --kanata`。
  Kanata 需要读取输入设备及写入 uinput，仅在明确选择时安装并启用。
- Arch 桌面需要 Hyprland 0.57+。执行 `bash install_desktop_arch.sh`；
  NVIDIA 机器默认保留现有驱动，没有驱动时应根据硬件选择
  `NVIDIA_DRIVER_PACKAGE`（例如支持开放内核模块的显卡使用
  `NVIDIA_DRIVER_PACKAGE=nvidia-open-dkms bash install_desktop_arch.sh`）。
  不自动卸载其他驱动；混合 GPU 不全局强制 GLX/VA-API，Chrome 默认自动选择后端。
  机器特殊配置放在 `~/.config/hypr/local.lua`。
- `gnuke` 和 `dprune` 必须确认后才执行清理；AGY 默认保留权限审批，
  多账号 profile 只隔离配置与凭据，不构成文件系统安全沙箱。
  Git HTTPS 凭据默认仅在内存缓存一小时，旧的明文凭据文件不由本仓库删除。
- `proxy` 自动识别 WSL mirrored / NAT 网络，也支持 `proxy <host>`；
  `unproxy` 清除大小写代理变量。`reload` 启动全新的 Zsh 配置链，
  不向子进程导出 ZDOTDIR。tmux 前缀为 Ctrl+B，避免 Fcitx5 输入法冲突。
  Ctrl+H/J/K/L 的跨 tmux/Neovim 导航及 OSC 52 剪贴板同步为有意保留的交互策略。
- LazyVim 插件版本锁继续由各机器独立管理；历史 Vim 配置仅作为仓库文档归档，
  不再部署到家目录（`docs/legacy/vimrc`）。

## 回归验证

安装基础工具后，在仓库目录执行：

```bash
bash scripts/check.sh
```

检查 Bash/Zsh/Lua/TOML/JSON/JSONC/YAML 语法、ShellCheck、mise 配置、Ubuntu/Arch
隔离 chezmoi 部署与权限、SSH 有效配置、Starship 环境模块、Git 模板转义、GPU
模拟数据、代理、gpall、Neovim、GDB 项目配置加载和 tmux。
测试只使用临时目标目录、临时 Git 仓库、模拟设备数据及独立 tmux socket，
不需要 root，不执行实际软件安装、Docker 清理、数据库连接或硬件操作。
Arch 桌面的驱动、Wayland、Kanata 用户服务及音频等仍需在目标机器上验收。

修改配置模板后，实际部署前先执行 `chezmoi init`，再预览 `chezmoi diff`，
最后按需执行 `chezmoi apply`。
