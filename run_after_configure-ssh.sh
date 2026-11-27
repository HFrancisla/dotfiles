#!/bin/sh
set -eu

ssh_dir="$HOME/.ssh"
config_dir="$ssh_dir/config.d"
config_file="$ssh_dir/config"
include_line='Include ~/.ssh/config.d/10-dotfiles.conf'
marker='# dotfiles: shared SSH defaults'

mkdir -p "$config_dir" "$ssh_dir/sockets"
chmod 700 "$ssh_dir" "$config_dir" "$ssh_dir/sockets"

if [ -f "$config_file" ] &&
    grep -Fqx "$marker" "$config_file" &&
    grep -Fqx "$include_line" "$config_file"; then
    chmod 600 "$config_file"
    exit 0
fi

tmp_file=$(mktemp "$ssh_dir/config.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT HUP INT TERM

{
    if [ -f "$config_file" ]; then
        # Canonicalize a partial/older managed block before appending it at the
        # bottom, where Host-specific settings in the user's config take precedence.
        awk -v marker="$marker" -v inc="$include_line" '
            $0 == marker { managed_host = 1; next }
            managed_host && $0 == "Host *" { managed_host = 0; next }
            $0 == inc { next }
            { managed_host = 0; print }
        ' "$config_file"
        printf '\n'
    fi
    printf '%s\nHost *\n%s\n' "$marker" "$include_line"
} >"$tmp_file"

chmod 600 "$tmp_file"
mv "$tmp_file" "$config_file"
trap - EXIT HUP INT TERM
