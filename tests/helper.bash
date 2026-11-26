# Shared helpers for repo-only dotfiles Bats suites.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

fail() {
  printf '%s\n' "$*" >&2
  return 1
}

assert_file_exists() {
  [ -f "$1" ] || fail "expected file to exist: $1"
}

assert_symlink_resolves() {
  local link="$1" expected="$2" actual
  [ -L "$link" ] || fail "expected symlink: $link"
  [ -e "$link" ] || fail "dangling symlink: $link"
  actual="$(readlink -f "$link")"
  [ "$actual" = "$(readlink -f "$expected")" ] || fail "symlink $link -> $actual (want $expected)"
}

# Render a chezmoi source template against an optional host/profile override JSON.
render_with_data() {
  local src="$1" out="$2" override="${3:-}"
  if [ -n "$override" ]; then
    chezmoi --source "$REPO_ROOT" execute-template --override-data "$override" -f "$src" >"$out"
  else
    chezmoi --source "$REPO_ROOT" execute-template -f "$src" >"$out"
  fi
}

# Render a chezmoi modify_ template with sample existing file content on stdin.
render_modify_with_stdin() {
  local src="$1" stdin_data="$2" out="$3" override="${4:-}"
  if [ -n "$override" ]; then
    printf '%s' "$stdin_data" | chezmoi --source "$REPO_ROOT" execute-template --with-stdin --override-data "$override" -f "$src" >"$out"
  else
    printf '%s' "$stdin_data" | chezmoi --source "$REPO_ROOT" execute-template --with-stdin -f "$src" >"$out"
  fi
}

# Return 0 if the named toolchain is enabled in chezmoi data, 1 otherwise.
toolchain_enabled() {
  local name="$1"
  [ "$(chezmoi --source "$REPO_ROOT" data | jq -r --arg t "$name" '.toolchains[$t] // false')" = "true" ]
}

# Require a CLI binary: fail in CI when its toolchain is enabled (or no toolchain
# gate is given); skip locally when absent.
require_cmd() {
  local bin="$1" tc="${2:-}"
  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  if [ -n "${CI:-}" ] && { [ -z "$tc" ] || toolchain_enabled "$tc"; }; then
    fail "$bin is required in CI but not found on PATH"
  fi
  skip "$bin not installed"
}
