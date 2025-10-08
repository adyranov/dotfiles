#!/usr/bin/env bash

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
  else
      eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

PACKAGES=(rage)

for pkg in "${PACKAGES[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        brew install "$pkg"
    fi
done
