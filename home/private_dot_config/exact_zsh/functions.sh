# shellcheck shell=sh
FUNCTIONS_D_DIR="$XDG_CONFIG_HOME/zsh/functions.d"
if [ -d "$FUNCTIONS_D_DIR" ]; then
  for FUNCTIONS_FILE in "$FUNCTIONS_D_DIR"/*; do
    [ -r "$FUNCTIONS_FILE" ] || continue
    # shellcheck source=/dev/null
    . "$FUNCTIONS_FILE"
  done
  unset FUNCTIONS_FILE
fi
unset FUNCTIONS_D_DIR

_clipcopy() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  elif command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  else
    printf 'clipboard utility not found\n' >&2
    return 1
  fi
}

copypath() {
  _target=""
  if [ -z "${1:-}" ]; then
    _target="$PWD"
  elif [ -e "$1" ]; then
    _target="$(cd "$(dirname "$1")" && printf '%s/%s' "$PWD" "$(basename "$1")")"
  else
    printf 'copypath: %s: No such file or directory\n' "$1" >&2
    unset _target
    return 1
  fi
  printf '%s' "$_target" | _clipcopy
  unset _target
}

copyfile() {
  if [ -z "${1:-}" ] || [ ! -r "$1" ]; then
    printf 'usage: copyfile <file>\n' >&2
    return 1
  fi
  _clipcopy <"$1"
}
