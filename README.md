# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

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
