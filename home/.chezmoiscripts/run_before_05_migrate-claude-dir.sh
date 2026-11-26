#!/usr/bin/env sh
# Preserve existing ~/.claude and ~/.config/claude data before chezmoi replaces
# real directories/files with symlinks on first apply.
set -eu

refuse_if_real() {
  path="$1"
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "❌ Refusing to overwrite real $path with a chezmoi symlink; back it up or remove it and re-run chezmoi apply." >&2
    exit 1
  fi
}

migrate_entry() {
  src="$1"
  dst="$2"
  [ -e "$src" ] && [ ! -L "$src" ] || return 0
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    for item in "$src"/* "$src"/.[!.]* "$src"/..?*; do
      [ -e "$item" ] || [ -L "$item" ] || continue
      base="$(basename "$item")"
      if [ ! -e "$dst/$base" ] && [ ! -L "$dst/$base" ]; then
        mv "$item" "$dst/$base"
      fi
    done
    rmdir "$src" 2>/dev/null || {
      echo "❌ Refusing to overwrite non-empty $src with symlink; merge into $dst manually and re-run chezmoi apply." >&2
      exit 1
    }
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    if [ ! -e "$dst" ]; then
      mv "$src" "$dst"
    else
      echo "❌ Refusing to overwrite $src with symlink ($dst already exists); merge manually and re-run chezmoi apply." >&2
      exit 1
    fi
  fi
}

cfg="$HOME/.config/claude"
state="$HOME/.local/state/claude"
share="$HOME/.local/share/claude"

# Refuse before moving anything if unmanaged skills, CLAUDE.md, or agents would be replaced or pruned.
refuse_if_real "$HOME/.claude/skills"
refuse_if_real "$HOME/.claude/CLAUDE.md"
refuse_if_real "$cfg/skills"
refuse_if_real "$cfg/CLAUDE.md"
if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ] && [ -d "$HOME/.claude/agents" ] && [ ! -L "$HOME/.claude/agents" ]; then
  for __agent in "$HOME/.claude/agents"/* "$HOME/.claude/agents"/.[!.]* "$HOME/.claude/agents"/..?*; do
    if [ -e "$__agent" ] || [ -L "$__agent" ]; then
      echo "❌ Refusing to migrate $HOME/.claude/agents into exact_-managed $cfg/agents; back up or remove unmanaged agents and re-run chezmoi apply." >&2
      exit 1
    fi
  done
fi

migrate_entry "$HOME/.claude" "$cfg"
migrate_entry "$cfg/backups" "$state/backups"
migrate_entry "$cfg/file-history" "$state/file-history"
migrate_entry "$cfg/history.jsonl" "$state/history.jsonl"
migrate_entry "$cfg/projects" "$state/projects"
migrate_entry "$cfg/plugins" "$share/plugins"
