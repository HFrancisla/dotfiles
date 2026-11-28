#!/usr/bin/env bash
# Non-destructive checks: test actual rendered configs in an isolated destination.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/home-arch" "$tmp/bin" "$tmp/drm"
cat >"$tmp/chezmoi.toml" <<'TOML'
[data]
name = 'A # B "quoted" \ path'
email = 'test@example.invalid'
TOML
cm=(chezmoi --config "$tmp/chezmoi.toml" --persistent-state "$tmp/state.db" --cache "$tmp/cache" --source "$root")
ubuntu=( "${cm[@]}" --destination "$tmp/home" --override-data '{"chezmoi":{"osRelease":{"id":"ubuntu"}}}' )
arch=( "${cm[@]}" --destination "$tmp/home-arch" --override-data '{"chezmoi":{"osRelease":{"id":"arch"}}}' )

echo '[1] syntax and static analysis'
for f in install*.sh scripts/check.sh dot_config/waybar/scripts/*.sh; do bash -n "$f"; done
sh -n private_dot_ssh/modify_private_config
shellcheck -S warning install*.sh scripts/check.sh dot_config/waybar/scripts/*.sh
for installer in install_arch.sh install_ubuntu_wsl.sh; do
    grep -Eq '^[[:space:]]*shellcheck[[:space:]]*(#.*)?$' "$installer"
done
for f in dot_zshenv dot_config/zsh/dot_zshrc dot_config/zsh/dot_zprofile; do zsh -n "$f"; done
while IFS= read -r -d '' f; do luac -p "$f"; done < <(find dot_config -name '*.lua' -print0)
python3 - <<'PY'
import json, pathlib, tomllib
for path in pathlib.Path('dot_config').rglob('*.toml'):
    with path.open('rb') as f: tomllib.load(f)
for path in pathlib.Path('dot_config').rglob('*.json'):
    json.loads(path.read_text())

path = pathlib.Path('dot_config/waybar/config.jsonc')
s = path.read_text()
out = []
i = 0
in_string = False
escaped = False
while i < len(s):
    c = s[i]
    if in_string:
        out.append(c)
        if escaped:
            escaped = False
        elif c == '\\':
            escaped = True
        elif c == '"':
            in_string = False
        i += 1
        continue
    if c == '"':
        in_string = True
        out.append(c)
        i += 1
        continue
    if c == '/' and i + 1 < len(s) and s[i + 1] == '/':
        i += 2
        while i < len(s) and s[i] not in '\r\n':
            i += 1
        continue
    if c == '/' and i + 1 < len(s) and s[i + 1] == '*':
        i += 2
        while i + 1 < len(s) and not (s[i] == '*' and s[i + 1] == '/'):
            i += 1
        if i + 1 >= len(s):
            raise ValueError(f'unterminated block comment in {path}')
        i += 2
        continue
    out.append(c)
    i += 1
json.loads(''.join(out))
PY
for f in dot_config/eza/theme.yml dot_config/conda/dot_condarc_*; do yq eval '.' "$f" >/dev/null; done
mise config explain --file dot_config/mise/config.toml >/dev/null

echo '[2] render and apply to temporary homes'
"${ubuntu[@]}" apply
"${arch[@]}" apply
u="$tmp/home"
a="$tmp/home-arch"
for dest in "$u" "$a"; do
    zsh -n "$dest/.config/zsh/alias.zsh"
    test "$(git config --file "$dest/.config/git/config" user.name)" = 'A # B "quoted" \ path'
    test "$(git config --file "$dest/.config/git/config" user.email)" = test@example.invalid
    test "$(git config --file "$dest/.config/git/config" --get-all credential.helper | tail -n 1)" = "cache --timeout=3600"
    test "$(readlink "$dest/.config/pip/pip.conf")" = pip.ini
    test "$(stat -c %a "$dest/.ssh/config")" = 600
    test "$(stat -c %a "$dest/.ssh/config.d/10-dotfiles.conf")" = 600
    test "$(grep -c 'Include.*10-dotfiles.conf' "$dest/.ssh/config")" = 1
    grep -q '^table_format = psql_unicode$' "$dest/.config/pgcli/config"
done
test ! -e "$u/.config/hypr"
test -x "$a/.config/waybar/scripts/gpu-usage.sh"
test -f "$a/.config/wallpapers/lock.jpg"
test ! -e "$a/.config/wallpapers/lock.png"
test "$(file -b --mime-type "$a/.config/wallpapers/lock.jpg")" = image/jpeg
grep -q 'wallpapers/lock.jpg' "$a/.config/hypr/hyprlock.conf"
grep -q 'wallpapers/wallpaper.png' "$a/.config/hypr/hyprland.lua"
grep -Fq 'hl.env("XMODIFIERS", "@im=fcitx")' "$a/.config/hypr/hyprland.lua"
grep -Fq 'hl.env("QT_IM_MODULE", "fcitx")' "$a/.config/hypr/hyprland.lua"
"${ubuntu[@]}" apply
"${arch[@]}" apply
test "$(grep -c 'Include.*10-dotfiles.conf' "$a/.ssh/config")" = 1
"${cm[@]}" execute-template --init < .chezmoi.toml.tmpl > "$tmp/rendered.toml"
python3 - "$tmp/rendered.toml" "$u/.config/starship/starship.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    data = tomllib.load(f)['data']
assert data['name'] == 'A # B "quoted" \\ path'
with open(sys.argv[2], 'rb') as f: tomllib.load(f)
PY
STARSHIP_CONFIG="$u/.config/starship/starship.toml" all_proxy=socks5h://127.0.0.1:7890 starship prompt --right | grep -q 'socks5h://127.0.0.1:7890'
ssh_effective=$(ssh -G -F "$a/.ssh/config" example.invalid 2>/dev/null)
grep -q '^serveraliveinterval 60$' <<<"$ssh_effective"
grep -q '^serveralivecountmax 3$' <<<"$ssh_effective"
grep -q '^controlmaster auto$' <<<"$ssh_effective"

echo '[3] GPU counters and fallback'
cat >"$tmp/bin/nvidia-smi" <<'SH'
#!/bin/sh
printf '%s\n' "$GPU_MOCK"
exit "${GPU_MOCK_RC:-0}"
SH
chmod +x "$tmp/bin/nvidia-smi"
gpu="$a/.config/waybar/scripts/gpu-usage.sh"
export GPU_SYSFS_ROOT="$tmp/drm"
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=$'20\n40\nN/A\n150' "$gpu")" = '30%'
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=N/A "$gpu")" = 'N/A'
mkdir -p "$tmp/drm/card0/device" "$tmp/drm/card1/device"
printf '0x1002\n' >"$tmp/drm/card0/device/vendor"
printf '0x1002\n' >"$tmp/drm/card1/device/vendor"
printf '20\n' >"$tmp/drm/card0/device/gpu_busy_percent"
printf '80\n' >"$tmp/drm/card1/device/gpu_busy_percent"
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=N/A "$gpu")" = '50%'
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=99 GPU_MOCK_RC=1 "$gpu")" = '50%'
printf 'N/A\n' >"$tmp/drm/card0/device/gpu_busy_percent"
printf '101\n' >"$tmp/drm/card1/device/gpu_busy_percent"
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=N/A "$gpu")" = 'N/A'
printf '0x8086\n' >"$tmp/drm/card1/device/vendor"
printf '42\n' >"$tmp/drm/card1/device/gpu_busy_percent"
test "$(PATH="$tmp/bin:$PATH" GPU_MOCK=N/A "$gpu")" = '42%'

echo '[4] Zsh PATH, proxy and Git workflow'
zsh -f -c '
  source "$1"
  first=$PATH
  source "$1"
  [[ "$PATH" == "$first" ]] || { print -u2 "PATH not idempotent"; exit 1; }
  [[ ${#path} == ${#${(u)path}} ]] || exit 1
' _ "$root/dot_zshenv"
# A child shell must read ~/.zshenv again, not inherit an exported ZDOTDIR.
mkdir -p "$tmp/zhome/.config/zsh"
cp dot_zshenv "$tmp/zhome/.zshenv"
printf '%s\n' 'export DOTFILES_ENV_LOADED=1' >>"$tmp/zhome/.zshenv"
env -u ZDOTDIR HOME="$tmp/zhome" zsh -c '
    [[ "$DOTFILES_ENV_LOADED" == 1 && "$ZDOTDIR" == "$HOME/.config/zsh" ]] || exit 1
    [[ -z "$(command env | command grep "^ZDOTDIR=")" ]] || exit 1
    unset DOTFILES_ENV_LOADED
    zsh -c "test \"\$DOTFILES_ENV_LOADED\" = 1"
'
sed -n '/^proxy() {/,/^# conda 镜像切换/p' dot_config/zsh/dot_zshrc >"$tmp/proxy.zsh"
# Synthetic WSL + NAT/mirrored, regardless of the host running this test.
cat >"$tmp/bin/grep" <<'SH'
#!/bin/sh
case "$*" in *'/proc/version'*) exit 0;; esac
exec /usr/bin/grep "$@"
SH
cat >"$tmp/bin/wslinfo" <<'SH'
#!/bin/sh
printf '%s\n' "$WSL_MODE"
SH
cat >"$tmp/bin/ip" <<'SH'
#!/bin/sh
printf '%s\n' 'default via 172.20.0.1 dev eth0'
SH
chmod +x "$tmp/bin/"{grep,wslinfo,ip}
PATH="$tmp/bin:$PATH" zsh -f -c '
    source "$1"
    export WSL_MODE=mirrored
    proxy >/dev/null && [[ "$http_proxy" == http://127.0.0.1:7890 && "$HTTP_PROXY" == "$http_proxy" ]] || exit 1
    export WSL_MODE=nat
    proxy >/dev/null && [[ "$http_proxy" == http://172.20.0.1:7890 ]] || exit 1
    proxy 192.0.2.1 >/dev/null && [[ "$all_proxy" == socks5h://192.0.2.1:7890 ]] || exit 1
    unproxy >/dev/null
    [[ -z "${http_proxy+x}${HTTP_PROXY+x}${all_proxy+x}${ALL_PROXY+x}" ]]
' _ "$tmp/proxy.zsh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
git init -q --bare --initial-branch=main "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/producer"
git -C "$tmp/producer" commit -qm initial --allow-empty
git -C "$tmp/producer" push -qu origin main
git clone -q "$tmp/remote.git" "$tmp/repo"
git init -q "$tmp/repo/nested"
git -C "$tmp/producer" commit -qm update --allow-empty
git -C "$tmp/producer" push -q
# Ignore the nested repository for the dirty-worktree test; it must never be traversed.
printf '/nested/\n' >"$tmp/repo/.git/info/exclude"
setsid --wait zsh -f -c '
    source "$1"
    out=$(gpall -n 2 "$2") || exit 1
    [[ "$out" == *"命中 1 个仓库"* && "$out" == *"updated +1 commits"* ]] || { print -r -- "$out"; exit 1; }
    out=$(gpall -n 2 "$2") || exit 1
    [[ "$out" == *"already up to date"* ]] || exit 1
    touch "$2/untracked"
    out=$(gpall "$2") || exit 1
    [[ "$out" == *"skipped: uncommitted changes"* ]] || exit 1
    rm "$2/untracked"
    git -C "$2" commit --quiet --allow-empty -m ahead
    out=$(gpall "$2") || exit 1
    [[ "$out" == *"local branch ahead by 1 commits"* ]] || exit 1
    out=$(gpall -n 2>&1); rc=$?
    [[ $rc == 2 && "$out" != *"shift"* ]] || exit 1
    # A competing upstream commit must fail fast-forward without touching local HEAD.
    git -C "$3" commit --quiet --allow-empty -m diverged
    git -C "$3" push --quiet
    before=$(git -C "$2" rev-parse HEAD)
    out=$(gpall "$2"); rc=$?
    [[ $rc == 1 && "$out" == *"diverged from upstream"* && "$(git -C "$2" rev-parse HEAD)" == "$before" ]] || exit 1
    cd "$2"
    touch do-not-delete
    gnuke </dev/null >/dev/null 2>&1
    [[ $? == 1 && -f do-not-delete ]] || exit 1
    alias gnuke="false"
    source "$1"
    [[ "$(whence -w gnuke)" == "gnuke: function" ]] || exit 1
' _ "$u/.config/zsh/alias.zsh" "$tmp/repo" "$tmp/producer"

echo '[5] Neovim, GDB and tmux configuration'
cat >"$tmp/nvim-check.lua" <<'LUA'
dofile(vim.env.DOTFILES_AUTOCMDS)
vim.api.nvim_exec_autocmds("BufEnter", {})
assert(#vim.fn.getmatches() == 1, "missing whitespace highlight")
vim.cmd("enew")
vim.bo.buftype = "nofile"
vim.api.nvim_exec_autocmds("BufEnter", {})
assert(#vim.fn.getmatches() == 0, "highlight leaked to special buffer")
vim.bo.buftype = ""
vim.api.nvim_exec_autocmds("BufEnter", {})
assert(#vim.fn.getmatches() == 1, "highlight not restored")
vim.api.nvim_exec_autocmds("ColorScheme", {})
assert(vim.api.nvim_get_hl(0, { name = "ExtraWhitespace" }).bg == 0xff0000)
vim.bo.filetype = "lua"
assert(vim.bo.shiftwidth == 2)
LUA
DOTFILES_AUTOCMDS="$root/dot_config/nvim/lua/config/autocmds.lua" nvim --headless -u NONE -i NONE -l "$tmp/nvim-check.lua"
# Project-local .gdbinit is enabled only inside the trusted ~/workspace tree.
mkdir -p "$tmp/gdb-home/.config/gdb" "$tmp/gdb-home/.local/state/gdb" "$tmp/gdb-home/workspace/project"
cp dot_config/gdb/gdbinit "$tmp/gdb-home/.config/gdb/gdbinit"
printf '%s\n' 'set history size 12345' >"$tmp/gdb-home/workspace/project/.gdbinit"
gdb_output=$(
    cd "$tmp/gdb-home/workspace/project"
    HOME="$tmp/gdb-home" XDG_CONFIG_HOME="$tmp/gdb-home/.config" gdb -q --batch -ex 'show auto-load safe-path' -ex 'show history size' 2>&1
)
grep -q 'The size of the command history is 12345.' <<<"$gdb_output"
# Skip plugin bootstrap; verify all native tmux settings using a private socket.
sed '/run.*plugins\/tpm\/tpm/d' dot_config/tmux/tmux.conf >"$tmp/tmux.conf"
tmux -S "$tmp/tmux.sock" -f "$tmp/tmux.conf" new-session -d
test "$(tmux -S "$tmp/tmux.sock" show-option -gv prefix)" = C-b
tmux -S "$tmp/tmux.sock" kill-server
echo 'All dotfiles regression checks passed.'
