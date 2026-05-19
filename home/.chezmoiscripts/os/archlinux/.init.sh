#!/usr/bin/env bash
set -euo pipefail

retry() {
  local attempt=0 max=3 delay=2
  while [ $attempt -lt $max ]; do
    if "$@"; then return 0; fi
    attempt=$((attempt + 1))
    if [ $attempt -lt $max ]; then
      echo "  ↳ Retrying ($attempt/$max) in ${delay}s..." >&2
      sleep $delay
      delay=$((delay * 2))
    fi
  done
  return 1
}

if ! pacman -Qi bash >/dev/null 2>&1 || ! pacman -Qi git >/dev/null 2>&1 || ! pacman -Qi curl >/dev/null 2>&1 || ! pacman -Qi unzip >/dev/null 2>&1 || ! pacman -Qi zsh >/dev/null 2>&1 || ! pacman -Qi rage-encryption >/dev/null 2>&1; then
  echo "📦 Installing prerequisites (bash, curl, git, rage-encryption, unzip, zsh)..."
  retry sudo pacman -Sy --noconfirm bash curl git rage-encryption unzip zsh
  echo "  ✅ Prerequisites installed."
fi
