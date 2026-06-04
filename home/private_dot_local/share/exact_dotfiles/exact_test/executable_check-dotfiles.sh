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

# ----- Constants & defaults ---------------------------------------------------

PACKAGE_SUITES=(test-system-packages.bats test-mise-packages.bats test-helm-plugins.bats test-krew-plugins.bats)
ALL_SUITES=("${PACKAGE_SUITES[@]}" test-config.bats test-ai.bats)

detectJobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.logicalcpu
  else echo 1; fi
}

# ----- Colors -----------------------------------------------------------------

if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RED=$'\033[31m'
  C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m'
  C_GRAY=$'\033[90m' C_RESET=$'\033[0m'
else
  C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_GRAY='' C_RESET=''
fi

# ----- Helpers ----------------------------------------------------------------

suiteDisplayName() { basename "$1" .bats | sed 's/^test-//'; }

suiteAlias() {
  case $1 in
  packages) printf '%s\n' "${PACKAGE_SUITES[@]}" ;;
  system-packages | system) echo test-system-packages.bats ;;
  mise-packages | mise) echo test-mise-packages.bats ;;
  helm-plugins | helm) echo test-helm-plugins.bats ;;
  krew-plugins | krew) echo test-krew-plugins.bats ;;
  config) echo test-config.bats ;;
  ai) echo test-ai.bats ;;
  all) printf '%s\n' "${ALL_SUITES[@]}" ;;
  *) return 1 ;;
  esac
}

resolveSuites() {
  local IFS=','
  read -r -a parts <<<"$1"
  local name resolved
  for name in "${parts[@]}"; do
    [ -n "$name" ] || continue
    if ! resolved=$(suiteAlias "$name"); then
      printf 'check-dotfiles: unknown suite: %s\n' "$name" >&2
      return 1
    fi
    printf '%s\n' "$resolved"
  done | awk '!seen[$0]++'
}

buildToolFilterRegex() {
  local parts=() tool
  for tool in "$@"; do
    parts+=("$(printf '%s' "$tool" | sed 's/[][(){}.^$*+?|\\]/\\&/g')")
  done
  printf '^(%s)($| )' "$(
    IFS='|'
    printf '%s' "${parts[*]}"
  )"
}

junitAttr() {
  sed -nE "s/.*<testsuite[^>]* ${2}=\"([^\"]+)\".*/\1/p" "$1" | head -n 1
}

# ----- Listing ----------------------------------------------------------------

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
        [ -n "$prev_tags" ] && all_tags="${all_tags:+${all_tags},}${prev_tags}"
        printf '%s\t%s\t%s\n' "$(suiteDisplayName "$f")" "$name" "$all_tags"
        prev_tags=""
      fi
    done <"${DIR}/${f}"
  done
}

listTests() {
  local current_suite="" suite name tags
  while IFS=$'\t' read -r suite name tags; do
    if [ "$suite" != "$current_suite" ]; then
      printf '%s%s:%s\n' "$C_BOLD" "$suite" "$C_RESET"
      current_suite=$suite
    fi
    printf '  %s' "$name"
    [ -n "$tags" ] && printf ' %s[%s]%s' "$C_GRAY" "$tags" "$C_RESET"
    printf '\n'
  done < <(discoverTests)
}

# ----- Execution --------------------------------------------------------------

runSuite() {
  local suite_path=$1 out_dir=$2 parallel=${3:-true}
  local rc=0 jobs_args=()
  [ "$parallel" = true ] && jobs_args=("${BATS_JOBS_ARGS[@]}")
  "$BATS_BIN" "${jobs_args[@]}" "${BATS_FILTER_ARGS[@]}" \
    --formatter tap \
    --report-formatter junit --output "$out_dir" \
    "$suite_path" >"$out_dir/stdout.log" 2>&1 || rc=$?
  printf '%d' "$rc" >"$out_dir/exit_code"
}

collectMetrics() {
  local suite_name=$1 report="$2/report.xml"
  [ -f "$report" ] || return 0
  local tests fails skipped time
  tests=$(junitAttr "$report" tests)
  tests=${tests:-0}
  fails=$(junitAttr "$report" failures)
  fails=${fails:-0}
  skipped=$(junitAttr "$report" skipped)
  skipped=${skipped:-0}
  time=$(junitAttr "$report" time)
  time=${time:-0}
  printf '%s|%d|%d|%d|%d|%s' "$suite_name" "$tests" $((tests - fails - skipped)) "$skipped" "$fails" "$time"
}

runAll() {
  local suites=("$@")
  local tmp_root exit_code=0 failed_suites=0
  tmp_root=$(mktemp -d -t check-dotfiles.XXXXXX)
  local total_tests=0 total_pass=0 total_skip=0 total_fail=0 total_time=0
  local rows=()
  local wall_start
  wall_start=$(date +%s)

  # Filter to suites with matching tests.
  local active=() suite_path count
  for suite_path in "${suites[@]}"; do
    [ -f "$suite_path" ] || continue
    count=$("$BATS_BIN" "${BATS_FILTER_ARGS[@]}" --count "$suite_path" 2>/dev/null || echo 0)
    [ "${count:-0}" -gt 0 ] && active+=("$suite_path")
  done

  # Launch all suites in parallel.
  local pids=() dirs=() names=() suite_name out_dir
  local use_internal_parallel=true
  [ ${#active[@]} -gt 1 ] && use_internal_parallel=false
  for suite_path in "${active[@]}"; do
    suite_name=$(suiteDisplayName "$suite_path")
    out_dir="$tmp_root/$suite_name"
    mkdir -p "$out_dir"
    dirs+=("$out_dir")
    names+=("$suite_name")
    runSuite "$suite_path" "$out_dir" "$use_internal_parallel" &
    pids+=($!)
  done

  # Wait for completion.
  local i
  for i in "${!pids[@]}"; do wait "${pids[$i]}" 2>/dev/null || true; done

  # Collect results in suite order.
  local show_summary=false
  [ -t 1 ] && [ "${CI:-}" = "" ] && show_summary=true

  for i in "${!names[@]}"; do
    local sn="${names[$i]}" sd="${dirs[$i]}"
    local rc
    rc=$(cat "$sd/exit_code" 2>/dev/null || echo 1)

    if [ "$show_summary" = true ] || [ "$rc" -ne 0 ]; then
      printf '\n%s== suite: %s ==%s\n' "$C_BLUE$C_BOLD" "$sn" "$C_RESET"
      [ -f "$sd/stdout.log" ] && cat "$sd/stdout.log"
    fi

    [ "$rc" -ne 0 ] && {
      exit_code=$rc
      failed_suites=$((failed_suites + 1))
    }

    local row
    row=$(collectMetrics "$sn" "$sd")
    if [ -n "$row" ]; then
      rows+=("$row")
      local tests pass skipped fails time
      IFS='|' read -r _ tests pass skipped fails time <<<"$row"
      total_tests=$((total_tests + tests))
      total_pass=$((total_pass + pass))
      total_skip=$((total_skip + skipped))
      total_fail=$((total_fail + fails))
      total_time=$(awk -v a="$total_time" -v b="$time" 'BEGIN{printf "%.3f", a+b}')
    fi
  done

  rm -rf "$tmp_root"

  # Summary table.
  if [ "$show_summary" = true ] && [ ${#rows[@]} -gt 0 ]; then
    local name_w=14 row
    for row in "${rows[@]}"; do
      local n=${row%%|*}
      [ ${#n} -gt "$name_w" ] && name_w=${#n}
    done
    local fmt="%-${name_w}s  %5s  %5s  %5s  %5s  %7s\n"
    printf '\n%s== Summary ==%s\n' "$C_BLUE$C_BOLD" "$C_RESET"
    # shellcheck disable=SC2059
    printf "$fmt" "Suite" "Tests" "Pass" "Skip" "Fail" "Time"
    printf '%s%*s%s\n' "$C_DIM" $((name_w + 36)) '' "$C_RESET" | tr ' ' '-'
    local suite tests pass skipped fails time color
    for row in "${rows[@]}"; do
      IFS='|' read -r suite tests pass skipped fails time <<<"$row"
      if [ "$fails" -gt 0 ]; then
        color=$C_RED
      elif [ "$skipped" -gt 0 ] && [ "$pass" -eq 0 ]; then
        color=$C_YELLOW
      else color=$C_GREEN; fi
      # shellcheck disable=SC2059
      printf "${color}${fmt}${C_RESET}" "$suite" "$tests" "$pass" "$skipped" "$fails" "$(printf '%.1fs' "$time")"
    done
    printf '%s%*s%s\n' "$C_DIM" $((name_w + 36)) '' "$C_RESET" | tr ' ' '-'
    # shellcheck disable=SC2059
    printf "$C_BOLD${fmt}$C_RESET" "Total" "$total_tests" "$total_pass" "$total_skip" "$total_fail" "$(printf '%ds' "$(($(date +%s) - wall_start))")"
  fi

  # Final status line.
  local wall_end wall_elapsed
  wall_end=$(date +%s)
  wall_elapsed=$((wall_end - wall_start))

  printf '\n'
  if [ "$total_fail" -gt 0 ]; then
    printf '%sFAIL: %d test(s) failed in %d suite(s) (%d passed, %d skipped) in %ds%s\n' \
      "$C_RED$C_BOLD" "$total_fail" "$failed_suites" "$total_pass" "$total_skip" "$wall_elapsed" "$C_RESET"
  elif [ "$total_tests" -eq 0 ]; then
    printf '%sWARN: no tests matched the selectors%s\n' "$C_YELLOW$C_BOLD" "$C_RESET"
    exit_code=1
  else
    printf '%sOK: all %d test(s) passed' "$C_GREEN$C_BOLD" "$total_pass"
    [ "$total_skip" -gt 0 ] && printf ' (%d skipped)' "$total_skip"
    printf ' in %ds%s\n' "$wall_elapsed" "$C_RESET"
  fi

  return "$exit_code"
}

# ----- Main -------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: check-dotfiles [OPTIONS] [TOOL...]

Run Bats validation suites for installed dotfile packages and configuration.
By default runs all suites in parallel with auto-detected CPU count.

Selectors:
  TOOL...               Package key(s) (e.g. kubectl helm). Restricts to
                        package suites and matches the `pkg:<key>` tag.
  --suite NAME[,...]    Suite names: packages, system-packages, mise-packages,
                        helm-plugins, krew-plugins, config, ai, all
  --tag EXPR[,...]      Bats tag filter (AND within, OR across repeated flags).
  --filter REGEX        Bats name filter regex.

Options:
  -j, --jobs N          Parallel jobs per suite (default: CPU count; 1=sequential).
  -l, --list            List discovered tests and exit.
  -h, --help            Show this help.

Examples:
  check-dotfiles                          # all suites, full parallel
  check-dotfiles kubectl helm             # only these packages
  check-dotfiles --suite config,ai        # specific suites
  check-dotfiles --tag toolchain:kubernetes
  check-dotfiles -j1                      # sequential (debug)
EOF
}

main() {
  local tools=() suite_arg="" tag_filters=() filter_regex="" parallel_jobs=""

  while [ $# -gt 0 ]; do
    case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -l | --list)
      listTests
      exit $?
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
    -j | --jobs)
      parallel_jobs=$2
      shift 2
      ;;
    -j*)
      parallel_jobs=${1#-j}
      shift
      ;;
    --jobs=*)
      parallel_jobs=${1#--jobs=}
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

  # Resolve suites.
  local suite_files=()
  if [ -n "$suite_arg" ]; then
    local resolved
    if ! resolved=$(resolveSuites "$suite_arg"); then exit 1; fi
    while IFS= read -r f; do
      [ -n "$f" ] && suite_files+=("${DIR}/${f}")
    done <<<"$resolved"
  elif [ ${#tools[@]} -gt 0 ]; then
    local s
    for s in "${PACKAGE_SUITES[@]}"; do [ -f "${DIR}/${s}" ] && suite_files+=("${DIR}/${s}"); done
  else
    local s
    for s in "${ALL_SUITES[@]}"; do [ -f "${DIR}/${s}" ] && suite_files+=("${DIR}/${s}"); done
  fi
  [ ${#suite_files[@]} -eq 0 ] && {
    printf 'check-dotfiles: no suites resolved\n' >&2
    exit 1
  }

  # Build bats filter args.
  BATS_FILTER_ARGS=()
  local tag
  for tag in "${tag_filters[@]}"; do BATS_FILTER_ARGS+=(--filter-tags "$tag"); done

  local combined_regex=""
  if [ -n "$filter_regex" ] && [ ${#tools[@]} -gt 0 ]; then
    combined_regex="(${filter_regex})|$(buildToolFilterRegex "${tools[@]}")"
  elif [ -n "$filter_regex" ]; then
    combined_regex=$filter_regex
  elif [ ${#tools[@]} -gt 0 ]; then
    combined_regex=$(buildToolFilterRegex "${tools[@]}")
  fi
  [ -n "$combined_regex" ] && BATS_FILTER_ARGS+=(-f "$combined_regex")

  # Parallel config.
  [ -z "$parallel_jobs" ] && parallel_jobs=$(detectJobs)
  BATS_JOBS_ARGS=()
  if [ "$parallel_jobs" -gt 1 ] 2>/dev/null; then
    BATS_JOBS_ARGS=(--jobs "$parallel_jobs" --no-parallelize-across-files)
  fi

  runAll "${suite_files[@]}"
}

main "$@"
