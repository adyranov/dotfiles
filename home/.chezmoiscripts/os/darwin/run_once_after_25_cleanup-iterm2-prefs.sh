#!/usr/bin/env sh
# Clear retired iTerm2 custom preferences folder pointer (~/.config/iterm2 was removed).
set -eu

defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true
defaults delete com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || true
