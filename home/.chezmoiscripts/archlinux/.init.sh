#!/usr/bin/env bash
set -euo pipefail

if ! command -v "rage" >/dev/null 2>&1; then
    echo "Installing rage..."
    sudo pacman -S --noconfirm "rage-encryption"
fi
