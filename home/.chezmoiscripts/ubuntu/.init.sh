#!/usr/bin/env bash
set -euo pipefail

if ! command -v rage >/dev/null 2>&1; then
  echo "Installing rage..."
  ARCH=$(dpkg --print-architecture)
  LATEST=$(curl -fsSL https://api.github.com/repos/str4d/rage/releases/latest | grep -Po '"tag_name": "\K[^"]+')
  VERSION="${LATEST#v}"
  URL="https://github.com/str4d/rage/releases/download/${LATEST}/rage-musl_${VERSION}-1_${ARCH}.deb"
  curl -fsSL -o /tmp/rage.deb "$URL"
  sudo dpkg -i /tmp/rage.deb || sudo apt -f install -y
  rm -f /tmp/rage.deb
fi
