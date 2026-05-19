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

if ! xcode-select -p >/dev/null 2>&1; then
  echo "🛠️  Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "  ↳ Waiting for installation to complete..."
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  echo "  ✅ Xcode Command Line Tools installed."
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "🍺 Installing Homebrew..."
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ "${ARCH}" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  echo "  ✅ Homebrew installed."
fi

if ! command -v rage >/dev/null 2>&1; then
  echo "🔐 Installing rage (encryption tool)..."
  retry brew install rage
  echo "  ✅ rage installed."
fi
