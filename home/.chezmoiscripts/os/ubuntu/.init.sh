#!/usr/bin/env bash
set -euo pipefail

ARCH="$(dpkg --print-architecture)"

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

if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  echo "📦 Installing prerequisites (bash, curl, gnupg, git, unzip, zsh)..."
  sudo apt-get update -qq
  retry sudo apt-get install -y -qq bash curl gnupg git unzip zsh
  echo "  ✅ Prerequisites installed."
fi

if ! locale -a 2>/dev/null | grep -qi 'en_US.utf8'; then
  echo "🌐 Generating en_US.UTF-8 locale..."
  sudo apt-get install -y -qq locales
  echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen >/dev/null
  sudo locale-gen >/dev/null
  echo "  ✅ Locale generated."
fi

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v mise >/dev/null 2>&1; then
  echo "📦 Installing mise..."
  retry sh -c "curl -fsSL https://mise.run/ | GITHUB_TOKEN='${GITHUB_TOKEN:-}' sh"
  echo "  ✅ mise installed."
fi

if ! command -v rage >/dev/null 2>&1; then
  echo "🔐 Installing rage (encryption tool)..."
  curl_opts=(-fsSL)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_opts+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl_opts+=(-H "X-GitHub-Api-Version: 2022-11-28")
  fi
  # shellcheck disable=SC2016
  latest=$(retry bash -c 'curl "${@}" https://api.github.com/repos/str4d/rage/releases/latest | grep -Po '\''"tag_name": "\K[^"]+'\''' -- "${curl_opts[@]}")
  version="${latest#v}"
  echo "  ↳ Downloading version ${latest}..."
  url="https://github.com/str4d/rage/releases/download/${latest}/rage-musl_${version}-1_${ARCH}.deb"
  retry curl -fsSL -o /tmp/rage.deb "${url}"
  sudo dpkg -i /tmp/rage.deb || sudo apt-get -f install -y
  rm -f /tmp/rage.deb
  echo "  ✅ rage installed."
fi
