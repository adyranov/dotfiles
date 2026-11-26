#!/usr/bin/env sh
# Print one-time XDG migration hints when a legacy dotdir exists and its XDG
# target does not. Prints hints only; never moves files automatically.
set -eu

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

hint_if_legacy() {
  src="$1"
  dst="$2"
  if [ -d "$src" ] && [ ! -L "$src" ] && [ ! -e "$dst" ]; then
    printf 'ℹ️  XDG migration hint: mv %s %s\n' "$src" "$dst"
  fi
}

hint_if_legacy "$HOME/.gnupg" "$data_home/gnupg"
hint_if_legacy "$HOME/.cargo" "$data_home/cargo"
hint_if_legacy "$HOME/.rustup" "$data_home/rustup"
hint_if_legacy "$HOME/.docker" "$config_home/docker"
hint_if_legacy "$HOME/.m2" "$data_home/maven"
hint_if_legacy "$HOME/.lima" "$data_home/lima"
