# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Stack

| Category | Tools |
|---|---|
| Shell | Zsh · Oh My Zsh · Starship |
| Editor | Neovim (LazyVim) |
| Terminal | tmux · yazi · fzf · zoxide |
| CLI | eza · bat · fd · ripgrep · mise |
| DB clients | pgcli · mycli · pspg |
| Desktop | Hyprland · Waybar · kanata (Arch only) |
| Package mgr | Homebrew · pacman/yay |

## Install

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply HFrancisla/dotfiles
```

> Prompts for your Git name and email on first run — nothing is hardcoded.

## Structure

```
.
├── dot_config/        → ~/.config/
├── dot_ssh/           → ~/.ssh/
├── dot_zshenv         → ~/.zshenv
├── install_arch.sh        # Arch Linux bootstrap
├── install_desktop_arch.sh
└── install_ubuntu_wsl.sh  # Ubuntu/WSL bootstrap
```
