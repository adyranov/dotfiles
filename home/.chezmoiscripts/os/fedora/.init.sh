#!/usr/bin/env bash
set -euo pipefail

ARCH="$(uname -m)"

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

if ! rpm -q dnf5-plugins >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v script >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  echo "📦 Installing prerequisites (bash, curl, dnf5-plugins, git, unzip, util-linux-script, zsh)..."
  retry sudo dnf5 -y install bash curl dnf5-plugins git unzip util-linux-script zsh
  echo "  ✅ Prerequisites installed."
fi

if ! locale -a 2>/dev/null | grep -qi 'en_US.utf8'; then
  echo "🌐 Installing en_US.UTF-8 locale..."
  retry sudo dnf5 -y install glibc-langpack-en
  echo "  ✅ Locale installed."
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "📦 Installing mise..."
  retry sudo dnf5 copr -y enable jdxcode/mise
  retry sudo dnf5 -y install mise
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
  case "${ARCH}" in
  x86_64) rage_arch="x86_64" ;;
  aarch64) rage_arch="arm64" ;;
  *)
    echo "  ❌ Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
  esac
  echo "  ↳ Downloading version ${latest} for ${rage_arch}..."
  url="https://github.com/str4d/rage/releases/download/${latest}/rage-v${version}-${rage_arch}-linux.tar.gz"
  retry curl -fsSL "${url}" | sudo tar -xz -C /usr/local/bin/ --strip-components=1
  echo "  ✅ rage installed."
fi
