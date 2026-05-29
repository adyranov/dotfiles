#!/usr/bin/env bash
set -euo pipefail

SOURCE="$0"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
BATS_BIN="${DIR}/bats/bin/bats"

if [ ! -x "$BATS_BIN" ]; then
  printf 'check-dotfiles: bats not found at %s\nRun chezmoi apply to fetch test externals.\n' "$BATS_BIN" >&2
  exit 1
fi

PACKAGE_SUITES=(
  test-system-packages.bats
  test-mise-packages.bats
  test-helm-plugins.bats
  test-krew-plugins.bats
)

ALL_SUITES=(
  test-system-packages.bats
  test-mise-packages.bats
  test-helm-plugins.bats
  test-krew-plugins.bats
  test-config.bats
  test-ai.bats
)

usage() {
  cat <<'EOF'
Usage: check-dotfiles [OPTIONS] [TOOL...]

Run Bats validation suites for installed dotfile packages and configuration.

With no arguments runs every available suite. Pass any combination of the
selectors below to narrow down what runs.

Selectors:
  TOOL...                 Package key(s) from packages.toml (e.g. kubectl).
                          Restricts to package suites when --suite is not
                          given. Matches the `pkg:<key>` tag.
  --suite NAME[,NAME...]  One or more suite names. Recognized:
                          packages, system-packages, mise-packages,
                          helm-plugins, krew-plugins, config, ai, skills,
                          all
  --tag EXPR[,EXPR...]    Pass-through to bats `--filter-tags` (AND within
                          one expression, OR across repeated --tag flags).
                          Examples: --tag toolchain:kubernetes,
                                    --tag suite:ai,kind:permission
  --filter REGEX          Pass-through to bats `-f` to match @test names.

Options:
  -l, --list              List tests and exit (use with --by).
      --by FIELD          Grouping for --list: suite (default), toolchain,
                          tag, kind.
      --no-summary        Skip per-suite section headers and summary table.
                          Implicit when stdout is not a TTY (CI mode).
      --summary           Force per-suite headers + summary even on non-TTY.
  -h, --help              Show this help.

Examples:
  check-dotfiles
  check-dotfiles kubectl helm k9s
  check-dotfiles --suite config
  check-dotfiles --suite ai,skills
  check-dotfiles --tag toolchain:kubernetes
  check-dotfiles --tag suite:ai,kind:permission
  check-dotfiles --filter '^skill .* frontmatter'
  check-dotfiles --list --by toolchain
EOF
}

# ----- ANSI helpers -----------------------------------------------------------

setupColors() {
  if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_GRAY=$'\033[90m'
    C_RESET=$'\033[0m'
  else
    C_BOLD=
    C_DIM=
    C_RED=
    C_GREEN=
    C_YELLOW=
    C_BLUE=
    C_GRAY=
    C_RESET=
  fi
}

# ----- Suite resolution -------------------------------------------------------

suiteAlias() {
  case $1 in
  packages)
    printf '%s\n' "${PACKAGE_SUITES[@]}"
    ;;
  system-packages | system)
    printf '%s\n' test-system-packages.bats
    ;;
  mise-packages | mise)
    printf '%s\n' test-mise-packages.bats
    ;;
  helm-plugins | helm)
    printf '%s\n' test-helm-plugins.bats
    ;;
  krew-plugins | krew)
    printf '%s\n' test-krew-plugins.bats
    ;;
  config)
    printf '%s\n' test-config.bats
    ;;
  ai)
    printf '%s\n' test-ai.bats
    ;;
  all)
    printf '%s\n' "${ALL_SUITES[@]}"
    ;;
  *)
    return 1
    ;;
  esac
}

resolveSuites() {
  local raw=$1 name files=()
  local IFS_BACKUP=$IFS
  IFS=','
  read -r -a parts <<<"$raw"
  IFS=$IFS_BACKUP
  for name in "${parts[@]}"; do
    [ -n "$name" ] || continue
    local resolved
    if ! resolved=$(suiteAlias "$name"); then
      printf 'check-dotfiles: unknown suite: %s\n' "$name" >&2
      return 1
    fi
    while IFS= read -r f; do
      [ -n "$f" ] && files+=("$f")
    done <<<"$resolved"
  done
  printf '%s\n' "${files[@]}" | awk '!seen[$0]++'
}

suiteDisplayName() {
  basename "$1" .bats | sed 's/^test-//'
}

# ----- Test discovery (for --list and validation) -----------------------------

# Parses each .bats file in $DIR and emits TSV: suite \t test_name \t tags
discoverTests() {
  local f file_tags line prev_tags name all_tags
  for f in "${ALL_SUITES[@]}"; do
    [ -f "${DIR}/${f}" ] || continue
    file_tags=$({ command grep -E '^# bats file_tags=' "${DIR}/${f}" || true; } |
      head -n 1 | sed -E 's/^# bats file_tags=//')
    prev_tags=""
    while IFS= read -r line; do
      if [[ $line =~ ^\#[[:space:]]bats[[:space:]]test_tags=(.*)$ ]]; then
        prev_tags="${BASH_REMATCH[1]}"
      elif [[ $line =~ ^@test[[:space:]]\"([^\"]+)\" ]]; then
        name="${BASH_REMATCH[1]}"
        all_tags="$file_tags"
        if [ -n "$prev_tags" ]; then
          if [ -n "$all_tags" ]; then
            all_tags="${all_tags},${prev_tags}"
          else
            all_tags="$prev_tags"
          fi
        fi
        printf '%s\t%s\t%s\n' "$(suiteDisplayName "$f")" "$name" "$all_tags"
        prev_tags=""
      fi
    done <"${DIR}/${f}"
  done
}

# Extract the package key from a test name (strips a trailing " (version)").
packageKeyFromTestName() {
  sed -E 's/ \([^)]*\)$//'
}

toolExists() {
  local tool=$1 suite name _tags key
  while IFS=$'\t' read -r suite name _tags; do
    key=$(printf '%s' "$name" | packageKeyFromTestName)
    if [ "$key" = "$tool" ]; then
      return 0
    fi
  done < <(discoverTests)
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

# ----- Listing ---------------------------------------------------------------

listBySuite() {
  local current_suite="" suite name tags
  while IFS=$'\t' read -r suite name tags; do
    if [ "$suite" != "$current_suite" ]; then
      printf '%s%s:%s\n' "$C_BOLD" "$suite" "$C_RESET"
      current_suite=$suite
    fi
    printf '  %s' "$name"
    if [ -n "$tags" ]; then
      printf ' %s[%s]%s' "$C_GRAY" "$tags" "$C_RESET"
    fi
    printf '\n'
  done < <(discoverTests)
}

# Print one bucket of test rows (TSV "suite\tname" entries).
printBucket() {
  local content=$1 suite name
  printf '%s' "$content" | LC_ALL=C sort -u | while IFS=$'\t' read -r suite name; do
    [ -n "$suite" ] || continue
    printf '  %s %s(%s)%s\n' "$name" "$C_GRAY" "$suite" "$C_RESET"
  done
}

# Group tests by the value of a tag prefix (e.g. "toolchain" or "kind").
listByTagPrefix() {
  local prefix=$1 suite name tags tag value matched group
  declare -A buckets=()
  while IFS=$'\t' read -r suite name tags; do
    matched=""
    local IFS_BAK=$IFS
    IFS=','
    for tag in $tags; do
      case $tag in
      "${prefix}:"*)
        if [ -z "$matched" ]; then
          value=${tag#"${prefix}:"}
          matched="$value"
        fi
        ;;
      esac
    done
    IFS=$IFS_BAK
    [ -n "$matched" ] || matched="(no-${prefix})"
    buckets[$matched]+="${suite}"$'\t'"${name}"$'\n'
  done < <(discoverTests)

  while IFS= read -r group; do
    [ -n "$group" ] || continue
    printf '%s%s:%s\n' "$C_BOLD" "$group" "$C_RESET"
    printBucket "${buckets[$group]-}"
  done < <(printf '%s\n' "${!buckets[@]}" | LC_ALL=C sort)
}

# Group by every individual tag (a test with N tags appears under N groups).
listByTag() {
  local suite name tags tag group
  declare -A buckets=()
  while IFS=$'\t' read -r suite name tags; do
    local IFS_BAK=$IFS
    IFS=','
    for tag in $tags; do
      [ -n "$tag" ] || continue
      buckets[$tag]+="${suite}"$'\t'"${name}"$'\n'
    done
    IFS=$IFS_BAK
  done < <(discoverTests)

  while IFS= read -r group; do
    [ -n "$group" ] || continue
    printf '%s%s:%s\n' "$C_BOLD" "$group" "$C_RESET"
    printBucket "${buckets[$group]-}"
  done < <(printf '%s\n' "${!buckets[@]}" | LC_ALL=C sort)
}

runListing() {
  local by=$1
  case $by in
  suite) listBySuite ;;
  toolchain | kind | suite:* | mgr | manager) listByTagPrefix "${by%%:*}" ;;
  tag) listByTag ;;
  *)
    printf 'check-dotfiles: unknown --by value: %s\n' "$by" >&2
    return 1
    ;;
  esac
}

# ----- Filter construction ----------------------------------------------------

buildToolFilterRegex() {
  local tools=("$@") parts=() tool escaped joined
  for tool in "${tools[@]}"; do
    escaped=$(printf '%s' "$tool" | sed 's/[][(){}.^$*+?|\\]/\\&/g')
    parts+=("$escaped")
  done
  joined=$(
    IFS='|'
    printf '%s' "${parts[*]}"
  )
  printf '^(%s)($| )' "$joined"
}

# ----- Per-suite execution + summary -----------------------------------------

# Reads a value of a specific attribute from the first <testsuite> tag.
junitAttr() {
  local file=$1 attr=$2
  sed -nE "s/.*<testsuite[^>]* ${attr}=\"([^\"]+)\".*/\1/p" "$file" | head -n 1
}

printAsciiRule() {
  local width=$1
  printf '%*s\n' "$width" '' | tr ' ' '-'
}

printSectionHeader() {
  local suite=$1
  printf '\n%s== suite: %s ==%s\n' "$C_BLUE$C_BOLD" "$suite" "$C_RESET"
}

runWithSummary() {
  local suites=("$@")
  local tmp_root
  tmp_root=$(mktemp -d -t check-dotfiles.XXXXXX)

  local total_tests=0 total_pass=0 total_skip=0 total_fail=0
  local total_time=0
  local rows=()
  local exit_code=0
  local failed_suites=0
  local suite_path suite_name out_dir tests fails skipped time pass count

  for suite_path in "${suites[@]}"; do
    [ -f "$suite_path" ] || continue
    suite_name=$(suiteDisplayName "$suite_path")

    # Skip suites where the active filters select zero tests so the output
    # is uncluttered.
    count=$("$BATS_BIN" "${BATS_FILTER_ARGS[@]}" --count "$suite_path" 2>/dev/null || echo 0)
    if [ "${count:-0}" -eq 0 ]; then
      continue
    fi

    out_dir="$tmp_root/$suite_name"
    mkdir -p "$out_dir"

    printSectionHeader "$suite_name"

    if "$BATS_BIN" "${BATS_FILTER_ARGS[@]}" \
      --formatter pretty \
      --report-formatter junit --output "$out_dir" \
      "$suite_path"; then
      :
    else
      local rc=$?
      exit_code=$rc
      failed_suites=$((failed_suites + 1))
    fi

    local report="$out_dir/report.xml"
    if [ -f "$report" ]; then
      tests=$(junitAttr "$report" tests)
      fails=$(junitAttr "$report" failures)
      skipped=$(junitAttr "$report" skipped)
      time=$(junitAttr "$report" time)
      tests=${tests:-0}
      fails=${fails:-0}
      skipped=${skipped:-0}
      time=${time:-0}
      pass=$((tests - fails - skipped))
      if [ "$tests" -gt 0 ] || [ "$fails" -gt 0 ]; then
        rows+=("${suite_name}|${tests}|${pass}|${skipped}|${fails}|${time}")
      fi
      total_tests=$((total_tests + tests))
      total_pass=$((total_pass + pass))
      total_skip=$((total_skip + skipped))
      total_fail=$((total_fail + fails))
      total_time=$(awk -v a="$total_time" -v b="$time" 'BEGIN{printf "%.3f", a+b}')
    fi
  done

  rm -rf "$tmp_root"

  printSummaryTable "$total_tests" "$total_pass" "$total_skip" "$total_fail" "$total_time" "${rows[@]}"
  printFinalBanner "$total_tests" "$total_pass" "$total_skip" "$total_fail" "$total_time" "$failed_suites"

  if [ "$total_tests" -eq 0 ]; then
    exit_code=1
  fi

  return $exit_code
}

printSummaryTable() {
  local total_tests=$1 total_pass=$2 total_skip=$3 total_fail=$4 total_time=$5
  shift 5
  local rows=("$@")

  local name_w=14
  local row
  for row in "${rows[@]}"; do
    local n=${row%%|*}
    [ ${#n} -gt "$name_w" ] && name_w=${#n}
  done

  local fmt="%-${name_w}s  %5s  %5s  %5s  %5s  %7s\n"

  printf '\n%s== Summary ==%s\n' "$C_BLUE$C_BOLD" "$C_RESET"
  # shellcheck disable=SC2059 # fmt is constructed above and trusted
  printf "$fmt" "Suite" "Tests" "Pass" "Skip" "Fail" "Time"
  printf '%s' "$C_DIM"
  printAsciiRule $((name_w + 36))
  printf '%s' "$C_RESET"

  local suite tests pass skipped fails time time_fmt color
  for row in "${rows[@]}"; do
    IFS='|' read -r suite tests pass skipped fails time <<<"$row"
    time_fmt=$(printf '%.1fs' "$time")
    if [ "$fails" -gt 0 ]; then
      color=$C_RED
    elif [ "$skipped" -gt 0 ] && [ "$pass" -eq 0 ]; then
      color=$C_YELLOW
    else
      color=$C_GREEN
    fi
    # shellcheck disable=SC2059
    printf "${color}${fmt}${C_RESET}" "$suite" "$tests" "$pass" "$skipped" "$fails" "$time_fmt"
  done

  printf '%s' "$C_DIM"
  printAsciiRule $((name_w + 36))
  printf '%s' "$C_RESET"

  local total_time_fmt
  total_time_fmt=$(printf '%.1fs' "$total_time")
  # shellcheck disable=SC2059
  printf "$C_BOLD$fmt$C_RESET" "Total" "$total_tests" "$total_pass" "$total_skip" "$total_fail" "$total_time_fmt"
}

printFinalBanner() {
  local total_tests=$1 total_pass=$2 total_skip=$3 total_fail=$4 total_time=$5 failed_suites=$6
  local time_fmt
  time_fmt=$(printf '%.1fs' "$total_time")
  printf '\n'
  if [ "$total_fail" -gt 0 ]; then
    printf '%sFAIL: %d test(s) failed in %d suite(s) (%d passed, %d skipped) in %s%s\n' \
      "$C_RED$C_BOLD" "$total_fail" "$failed_suites" \
      "$total_pass" "$total_skip" "$time_fmt" "$C_RESET"
  elif [ "$total_tests" -eq 0 ]; then
    printf '%sWARN: no tests matched the selectors%s\n' "$C_YELLOW$C_BOLD" "$C_RESET"
  else
    printf '%sOK: all %d test(s) passed' "$C_GREEN$C_BOLD" "$total_pass"
    [ "$total_skip" -gt 0 ] && printf ' (%d skipped)' "$total_skip"
    printf ' in %s%s\n' "$time_fmt" "$C_RESET"
  fi
}

# ----- Main -------------------------------------------------------------------

main() {
  setupColors

  local tools=()
  local suite_arg=""
  local tag_filters=()
  local filter_regex=""
  local do_list=false
  local list_by="suite"
  local force_summary=""

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
    --by)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [[ $2 == -* ]]; then
        printf 'check-dotfiles: --by requires a value\n' >&2
        usage >&2
        exit 1
      fi
      list_by=$2
      shift 2
      ;;
    --by=*)
      list_by=${1#--by=}
      shift
      ;;
    --suite)
      suite_arg=$2
      shift 2
      ;;
    --suite=*)
      suite_arg=${1#--suite=}
      shift
      ;;
    --tag)
      tag_filters+=("$2")
      shift 2
      ;;
    --tag=*)
      tag_filters+=("${1#--tag=}")
      shift
      ;;
    --filter)
      filter_regex=$2
      shift 2
      ;;
    --filter=*)
      filter_regex=${1#--filter=}
      shift
      ;;
    --summary)
      force_summary=on
      shift
      ;;
    --no-summary)
      force_summary=off
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
    if [ ${#tools[@]} -gt 0 ] || [ -n "$suite_arg" ] || [ ${#tag_filters[@]} -gt 0 ] || [ -n "$filter_regex" ]; then
      printf 'check-dotfiles: --list does not accept selectors\n' >&2
      usage >&2
      exit 1
    fi
    runListing "$list_by"
    exit $?
  fi

  if [ ${#tools[@]} -gt 0 ]; then
    validateTools "${tools[@]}"
  fi

  # Resolve suite files.
  local suite_files=()
  if [ -n "$suite_arg" ]; then
    resolved_suites=""
    if ! resolved_suites=$(resolveSuites "$suite_arg"); then
      exit 1
    fi
    while IFS= read -r f; do
      [ -n "$f" ] && suite_files+=("${DIR}/${f}")
    done <<<"$resolved_suites"
  elif [ ${#tools[@]} -gt 0 ]; then
    # Backwards-compatible default: package suites only when positional tools given.
    local s
    for s in "${PACKAGE_SUITES[@]}"; do
      [ -f "${DIR}/${s}" ] && suite_files+=("${DIR}/${s}")
    done
  else
    local s
    for s in "${ALL_SUITES[@]}"; do
      [ -f "${DIR}/${s}" ] && suite_files+=("${DIR}/${s}")
    done
  fi

  if [ ${#suite_files[@]} -eq 0 ]; then
    printf 'check-dotfiles: no suites resolved\n' >&2
    exit 1
  fi

  # Build bats argument list.
  BATS_FILTER_ARGS=()
  local tag
  for tag in "${tag_filters[@]}"; do
    BATS_FILTER_ARGS+=(--filter-tags "$tag")
  done

  local combined_regex=""
  if [ -n "$filter_regex" ] && [ ${#tools[@]} -gt 0 ]; then
    combined_regex="(${filter_regex})|$(buildToolFilterRegex "${tools[@]}")"
  elif [ -n "$filter_regex" ]; then
    combined_regex=$filter_regex
  elif [ ${#tools[@]} -gt 0 ]; then
    combined_regex=$(buildToolFilterRegex "${tools[@]}")
  fi

  if [ -n "$combined_regex" ]; then
    BATS_FILTER_ARGS+=(-f "$combined_regex")
  fi

  # Decide on summary mode.
  local use_summary=false
  if [ "$force_summary" = on ]; then
    use_summary=true
  elif [ "$force_summary" = off ]; then
    use_summary=false
  elif [ -t 1 ] && [ "${CI:-}" = "" ]; then
    use_summary=true
  fi

  if [ "$use_summary" = true ]; then
    runWithSummary "${suite_files[@]}"
  else
    "$BATS_BIN" "${BATS_FILTER_ARGS[@]}" "${suite_files[@]}"
  fi
}

main "$@"
