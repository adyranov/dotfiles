#!/usr/bin/env sh
# HISTFILE moved to ~/.local/share/zsh/history. z4h kept history at
# $ZDOTDIR/.zsh_history and pre-z4h at ~/.zsh_history; merge both in front of
# the new file (older first) and prune the sources. Never overwrite.
set -eu

dst_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
for src in "${ZDOTDIR:-$HOME/.config/zsh}/.zsh_history" "$HOME/.zsh_history"; do
  [ -f "$src" ] || continue
  mkdir -p "$dst_dir"
  if [ ! -f "$dst_dir/history" ]; then
    mv "$src" "$dst_dir/history"
  elif [ -s "$src" ]; then
    tmp="$dst_dir/history.tmp.$$"
    (
      umask 077
      cat "$src" "$dst_dir/history" >"$tmp"
    ) && mv "$tmp" "$dst_dir/history" && rm -f "$src"
  else
    rm -f "$src"
  fi
done
