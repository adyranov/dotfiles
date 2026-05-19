#!/bin/sh
set -e

echo "🚀 Starting dotfiles installation..."

if [ ! "$(command -v chezmoi)" ]; then
  tmp_dir="$(mktemp -d)"
  chezmoi="$tmp_dir/chezmoi"
  trap 'rm -rf "$tmp_dir"' EXIT
  echo "📦 Downloading chezmoi..."
  if [ "$(command -v curl)" ]; then
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$tmp_dir"
  elif [ "$(command -v wget)" ]; then
    sh -c "$(wget -qO- https://get.chezmoi.io)" -- -b "$tmp_dir"
  else
    echo "❌ Error: curl or wget is required to install chezmoi." >&2
    exit 1
  fi
else
  chezmoi=chezmoi
  echo "✅ chezmoi is already installed."
fi

if [ -f "$0" ]; then
  # POSIX way to get script's dir
  script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
  echo "🔄 Initializing and applying dotfiles from $script_dir..."
  exec "$chezmoi" init --apply "--source=$script_dir" "$@"
else
  echo "🔄 Initializing and applying dotfiles from GitHub..."
  exec "$chezmoi" init --apply adyranov "$@"
fi
