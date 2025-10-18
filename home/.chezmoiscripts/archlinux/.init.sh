#!/usr/bin/env bash
set -euo pipefail

if ! command -v "rage" >/dev/null 2>&1; then
    echo "Installing rage..."
    sudo pacman -Sy --noconfirm "rage-encryption"
fi

PACKAGES=(rbw)

for pkg in "${PACKAGES[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        sudo pacman -S --noconfirm "$pkg"
    fi
done
