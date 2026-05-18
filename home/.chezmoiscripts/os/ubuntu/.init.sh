#!/usr/bin/env bash
set -euo pipefail

if ! command -v rage >/dev/null 2>&1; then
  echo "Installing rage..."
  ARCH=$(dpkg --print-architecture)
  curl_opts=(-fsSL)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_opts+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl_opts+=(-H "X-GitHub-Api-Version: 2022-11-28")
  fi
  LATEST=$(curl "${curl_opts[@]}" https://api.github.com/repos/str4d/rage/releases/latest | grep -Po '"tag_name": "\K[^"]+')
  VERSION="${LATEST#v}"
  URL="https://github.com/str4d/rage/releases/download/${LATEST}/rage-musl_${VERSION}-1_${ARCH}.deb"
  curl -fsSL -o /tmp/rage.deb "$URL"
  sudo dpkg -i /tmp/rage.deb || sudo apt -f install -y
  rm -f /tmp/rage.deb
fi
