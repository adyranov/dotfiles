#!/usr/bin/env bash
set -euo pipefail

arch="$(uname -m)"

if [[ "${arch}" == "x86_64" ]]; then
  sudo dnf copr -y enable jackyzy823/rust-rage
else
  echo "Skipping jackyzy823/rust-rage COPR enable on ${arch} (unsupported chroot)."
fi

sudo dnf copr -y enable jdxcode/mise

PACKAGES=(mise rage util-linux-script)

for pkg in "${PACKAGES[@]}"; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    echo "Installing ${pkg}..."
    if ! sudo dnf -y install "$pkg"; then
      echo "Skipping ${pkg}; package is unavailable for ${arch}." >&2
    fi
  fi
done
