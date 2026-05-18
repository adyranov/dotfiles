#!/usr/bin/env bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
PACKAGE_BATS=(
  test-system-packages.bats
  test-mise-packages.bats
  test-helm-plugins.bats
  test-krew-plugins.bats
)

usage() {
  cat <<'EOF'
Usage: check-dotfiles [OPTIONS] [TOOL...]

Run Bats tests for installed dotfile packages and configuration.

With no arguments, runs all tests (package suites plus test-config.bats).
Pass one or more package keys (as in packages.toml, e.g. openssh-client,
kubectl) to run only matching package-suite tests (not test-config.bats).

Options:
  -h, --help    Show this help
  -l, --list    List package tool test names and exit

Examples:
  check-dotfiles
  check-dotfiles openssh-client
  check-dotfiles kubectl helm k9s
  check-dotfiles --list
EOF
}

packageKeyFromTestName() {
  sed -E 's/ \([^)]*\)$//'
}

listPackageTestNames() {
  local file
  for file in "${PACKAGE_BATS[@]}"; do
    [ -f "${DIR}/${file}" ] || continue
    grep -E '^@test "' "${DIR}/${file}" |
      sed -E 's/^@test "([^"]+)".*/\1/'
  done
}

listTools() {
  local file test_name tool
  for file in "${PACKAGE_BATS[@]}"; do
    [ -f "${DIR}/${file}" ] || continue
    printf '%s:\n' "${file}"
    while IFS= read -r test_name; do
      tool=$(printf '%s' "$test_name" | packageKeyFromTestName)
      printf '  %s\n' "$tool"
    done < <(grep -E '^@test "' "${DIR}/${file}" | sed -E 's/^@test "([^"]+)".*/\1/')
  done
}

testNameMatchesTool() {
  local test_name=$1
  local tool=$2
  [[ $test_name == "$tool" || $test_name == "${tool} ("* ]]
}

toolExists() {
  local tool=$1 test_name
  while IFS= read -r test_name; do
    if testNameMatchesTool "$test_name" "$tool"; then
      return 0
    fi
  done < <(listPackageTestNames)
  return 1
}

validateTools() {
  local tool
  for tool in "$@"; do
    if ! toolExists "$tool"; then
      printf 'check-dotfiles: unknown tool: %s (see --list)\n' "$tool" >&2
      exit 1
    fi
  done
}

buildFilterRegex() {
  local tools=("$@")
  local parts=() tool escaped
  for tool in "${tools[@]}"; do
    escaped=$(printf '%s' "$tool" | sed 's/[][(){}.^$*+?|\\]/\\&/g')
    parts+=("$escaped")
  done
  local joined
  joined=$(
    IFS='|'
    printf '%s' "${parts[*]}"
  )
  printf '^(%s)($| )' "$joined"
}

bootstrapBats() {
  git clone --depth=1 https://github.com/bats-core/bats-core.git "$DIR"/bats 2>/dev/null || true
  git clone --depth=1 https://github.com/bats-core/bats-assert.git "$DIR"/bats-assert 2>/dev/null || true
  git clone --depth=1 https://github.com/bats-core/bats-support.git "$DIR"/bats-support 2>/dev/null || true
  git clone --depth=1 https://github.com/bats-core/bats-file.git "$DIR"/bats-file 2>/dev/null || true
}

cleanupBats() {
  rm -rf "$DIR"/bats "$DIR"/bats-assert "$DIR"/bats-support "$DIR"/bats-file
}

main() {
  local tools=()
  local do_list=false

  while [ $# -gt 0 ]; do
    case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -l | --list)
      do_list=true
      shift
      ;;
    --)
      shift
      tools+=("$@")
      break
      ;;
    -*)
      printf 'check-dotfiles: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      tools+=("$1")
      shift
      ;;
    esac
  done

  if [ "$do_list" = true ]; then
    if [ ${#tools[@]} -gt 0 ]; then
      printf 'check-dotfiles: unexpected arguments with --list\n' >&2
      usage >&2
      exit 1
    fi
    listTools
    exit 0
  fi

  if [ ${#tools[@]} -gt 0 ]; then
    validateTools "${tools[@]}"
  fi

  bootstrapBats
  trap cleanupBats EXIT

  local bats_args=()
  local bats_files=()

  if [ ${#tools[@]} -gt 0 ]; then
    bats_args=(-f "$(buildFilterRegex "${tools[@]}")")
    local file
    for file in "${PACKAGE_BATS[@]}"; do
      [ -f "${DIR}/${file}" ] && bats_files+=("${DIR}/${file}")
    done
  else
    bats_files=("${DIR}"/*.bats)
  fi

  "${DIR}"/bats/bin/bats "${bats_args[@]}" "${bats_files[@]}"
}

main "$@"
