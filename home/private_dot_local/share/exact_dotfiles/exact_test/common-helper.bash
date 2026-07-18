#!/usr/bin/env bash
common_setup() {
  bats_require_minimum_version 1.12.0
  load 'bats-support/load.bash'
  load 'bats-assert/load.bash'
  load 'bats-file/load.bash'

  # shellcheck source=/dev/null
  source "$HOME"/.config/shell/exports.sh
}

# Parse strict JSON and JSONC with one test command. JSONC comments are only
# stripped at line start; generated configs keep comments on their own lines.
jsoncJq() {
  local file="${!#}"
  if [[ $file == *.jsonc ]]; then
    local -a args=("${@:1:$#-1}")
    sed -E '/^[[:space:]]*\/\//d' "$file" | jq "${args[@]}"
  else
    jq "$@"
  fi
}
