#!/usr/bin/env bash
set -euo pipefail

arch="$(uname -m)"

# Ensure `dnf config-manager` is available before any bootstrap template uses it.
# dnf4 exposes the plugin via `dnf-plugins-core`; dnf5 needs `dnf5-plugins`.
PLUGIN_PACKAGES=(dnf-plugins-core)
if command -v dnf5 >/dev/null 2>&1 || rpm -q dnf5 >/dev/null 2>&1; then
  PLUGIN_PACKAGES+=(dnf5-plugins)
fi
sudo dnf -y install "${PLUGIN_PACKAGES[@]}"

if [[ ${arch} == "x86_64" ]]; then
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
