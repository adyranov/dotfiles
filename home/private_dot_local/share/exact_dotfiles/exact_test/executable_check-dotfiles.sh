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

# gtimeout on macOS (coreutils), timeout on Linux CI; absence fails the run
# loudly below — a test runner without a timeout is not acceptable.
TIMEOUT_BIN="$(command -v gtimeout || command -v timeout || true)"
if [ -z "$TIMEOUT_BIN" ]; then
  printf 'check-dotfiles: gtimeout/timeout not found (coreutils required)\n' >&2
  exit 1
fi
# Exported so bats fixtures reuse the runner's probe (macOS ships no `timeout`).
export TIMEOUT_BIN

if [ ! -x "$BATS_BIN" ]; then
  printf 'check-dotfiles: bats not found at %s\nRun chezmoi apply to fetch test externals.\n' "$BATS_BIN" >&2
  exit 1
fi

# ----- Constants & defaults ---------------------------------------------------

PACKAGE_SUITES=(test-system-packages.bats test-mise-packages.bats test-helm-plugins.bats test-krew-plugins.bats)
AI_SUITES=(test-ai-shared.bats test-ai-pi.bats test-ai-opencode.bats test-ai-omp.bats test-ai-local-llm.bats test-ai-permissions.bats test-ai-dcg.bats test-ai-subagent-limit.bats)
ALL_SUITES=("${PACKAGE_SUITES[@]}" test-config.bats test-runner.bats "${AI_SUITES[@]}")
AGGREGATE_TITLE='aggregate install smoke'

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
  runner) echo test-runner.bats ;;
  ai) printf '%s\n' "${AI_SUITES[@]}" ;;
  ai-shared) echo test-ai-shared.bats ;;
  ai-pi) echo test-ai-pi.bats ;;
  ai-opencode) echo test-ai-opencode.bats ;;
  ai-omp) echo test-ai-omp.bats ;;
  ai-local-llm | ai-llm) echo test-ai-local-llm.bats ;;
  ai-permissions | ai-perms) echo test-ai-permissions.bats ;;
  ai-dcg) echo test-ai-dcg.bats ;;
  ai-subagent-limit | ai-limit) echo test-ai-subagent-limit.bats ;;
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

# Bare package keys must name a pkg:<id> tag in a package suite; the fixed
# aggregate title alone would let unknown keys pass the smoke vacuously.
validateToolKeys() {
  local known key
  known=$(discoverTests | awk -F'\t' '
    $1 == "system-packages" || $1 == "mise-packages" || $1 == "helm-plugins" || $1 == "krew-plugins" { print $3 }' |
    tr ',' '\n')
  local unknown=()
  for key in "$@"; do
    printf '%s\n' "$known" | grep -qxF "pkg:$key" || unknown+=("$key")
  done
  [ ${#unknown[@]} -eq 0 ] && return 0
  for key in "${unknown[@]}"; do
    printf 'check-dotfiles: unknown package key: %s\n' "$key" >&2
  done
  return 1
}

# ----- Execution --------------------------------------------------------------

runSuite() {
  local suite_path=$1 out_dir=$2 jobs=$3
  local rc=0 jobs_args=()
  [ "${jobs:-1}" -gt 1 ] && jobs_args=(--jobs "$jobs" --no-parallelize-across-files)
  # Hard wall-clock cap per suite: a suite that overruns its budget is a suite
  # bug (missing probe batching / timeouts), not a slow pass. Every suite
  # must finish within 120s. CHECK_DOTFILES_SUITE_TIMEOUT overrides.
  local cap=120
  # Core-only hosts render helm/krew suites with zero packages; an empty suite
  # there is data-correct, not a red gate (bats >=1.10 flag).
  "${TIMEOUT_BIN}" -k 10 "${CHECK_DOTFILES_SUITE_TIMEOUT:-$cap}" "$BATS_BIN" --allow-empty-suite "${jobs_args[@]+"${jobs_args[@]}"}" "${BATS_FILTER_ARGS[@]+"${BATS_FILTER_ARGS[@]}"}" \
    "${BATS_TIMING_ARGS[@]+"${BATS_TIMING_ARGS[@]}"}" \
    --formatter tap \
    --report-formatter junit --output "$out_dir" \
    "$suite_path" >"$out_dir/stdout.log" 2>&1 || rc=$?
  printf '%d' "$rc" >"$out_dir/exit_code"
  if [ ${#BATS_TIMING_ARGS[@]} -gt 0 ]; then reportSlowest "$out_dir/stdout.log"; fi
}

# Top-5 slowest per-test times from the TAP " in Nms" timing suffix, appended
# to the suite log so the collection phase prints them at the suite tail.
reportSlowest() {
  local slow
  slow=$(
    {
      grep -E ' in [0-9.]+ ?ms$' "$1" || true
    } | sed -E 's/^(.*) in ([0-9.]+) ?ms$/\2\t\1/' |
      sort -rn | head -n 5
  ) || true
  [ -n "$slow" ] || return 0
  {
    printf -- '-- slowest tests --\n'
    printf '%s\n' "$slow" | awk -F'\t' '{sub(/ *#$/, "", $2); printf "  %8.1fms  %s\n", $1, $2}'
  } >>"$1"
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
  local total_tests=0 total_pass=0 total_skip=0 total_fail=0
  local rows=() uncounted_suites=()
  local wall_start
  wall_start=$(date +%s)

  # Pre-count exists to guard "no tests matched" per suite: run it only for
  # filtered runs; unfiltered every suite runs and parse errors surface via
  # runSuite rc + printed log.
  local active=() suite_path count count_output
  if [ ${#BATS_FILTER_ARGS[@]} -gt 0 ]; then
    for suite_path in "${suites[@]}"; do
      [ -f "$suite_path" ] || continue
      if ! count_output=$("$BATS_BIN" "${BATS_FILTER_ARGS[@]+"${BATS_FILTER_ARGS[@]}"}" --count "$suite_path" 2>&1); then
        printf '\n%s== suite: %s ==%s\n' "$C_BLUE$C_BOLD" "$(suiteDisplayName "$suite_path")" "$C_RESET"
        printf '%s\n' "$count_output"
        rm -rf "$tmp_root"
        return 1
      fi
      count=$(printf '%s\n' "$count_output" | tail -n 1)
      case $count in
      '' | *[!0-9]*)
        printf 'check-dotfiles: invalid test count for %s: %s\n' "$suite_path" "$count" >&2
        rm -rf "$tmp_root"
        return 1
        ;;
      esac
      [ "$count" -gt 0 ] && active+=("$suite_path")
    done
  else
    for suite_path in "${suites[@]}"; do
      if [ -f "$suite_path" ]; then active+=("$suite_path"); fi
    done
  fi

  # Launch suites concurrently, bounded. Polling jobs -rp: bash 3.2 (macOS
  # system bash) has no wait -n. Per-suite junit dirs keep concurrency safe.
  local pids=() dirs=() names=() suite_name out_dir
  local suite_parallel=${CHECK_DOTFILES_PARALLEL_SUITES:-4}
  [[ $suite_parallel =~ ^[0-9]+$ ]] && [ "$suite_parallel" -ge 1 ] || suite_parallel=4
  # Split the bats -j budget across concurrent suites; serial suites get it
  # all. bats --jobs needs GNU parallel — without it, concurrent suites stay
  # internally serial (HEAD behavior; single-suite runs keep the old contract).
  local jobs_per_suite=1
  if [ "$suite_parallel" -eq 1 ] || [ ${#active[@]} -eq 1 ]; then
    jobs_per_suite=$parallel_jobs
  elif [ "$parallel_jobs" -gt "$suite_parallel" ] && command -v parallel >/dev/null 2>&1; then
    jobs_per_suite=$((parallel_jobs / suite_parallel))
  fi
  for suite_path in "${active[@]+"${active[@]}"}"; do
    suite_name=$(suiteDisplayName "$suite_path")
    out_dir="$tmp_root/$suite_name"
    mkdir -p "$out_dir"
    dirs+=("$out_dir")
    names+=("$suite_name")
    while [ "$(jobs -rp | wc -l | tr -d '[:space:]')" -ge "$suite_parallel" ]; do sleep 0.2; done
    runSuite "$suite_path" "$out_dir" "$jobs_per_suite" &
    pids+=($!)
  done

  # Wait for completion.
  local i
  for ((i = 0; i < ${#pids[@]}; i++)); do wait "${pids[$i]}" 2>/dev/null || true; done

  # Collect results in suite order.
  local show_summary=false
  [ -t 1 ] && [ "${CI:-}" = "" ] && show_summary=true

  for ((i = 0; i < ${#names[@]}; i++)); do
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
      # A failed setup can produce a JUnit row with zero counted failures.
      [ "$rc" -ne 0 ] && [ "$fails" -eq 0 ] && uncounted_suites+=("$sn $rc")
    elif [ "$rc" -ne 0 ]; then
      # rc != 0 with no junit report (timeout kill, crash): invisible to the
      # metrics rows; track it for the verdict below.
      uncounted_suites+=("$sn $rc")
    fi
  done

  rm -rf "$tmp_root"

  # Count nonzero suites missed by JUnit before printing totals.
  local mj mj_name mj_rc
  for mj in "${uncounted_suites[@]+"${uncounted_suites[@]}"}"; do
    read -r mj_name mj_rc <<<"$mj"
    printf '%sFAIL: suite %s exited %s with no counted failures (no junit report, zeroed report, timeout-killed or crashed)%s\n' \
      "$C_RED$C_BOLD" "$mj_name" "$mj_rc" "$C_RESET"
    total_fail=$((total_fail + 1))
  done

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
By default runs suites concurrently (4 at a time) with a bats jobs budget of
the auto-detected CPU count.

Selectors:
  TOOL...               Package key(s) (e.g. kubectl helm). Runs the aggregate
                        install smoke of the package suites, filtered to the
                        smoke checks of exactly those keys.
  --suite NAME[,...]    Suite names: packages, system-packages, mise-packages,
                        helm-plugins, krew-plugins, config, runner, ai, all
  --tag EXPR[,...]      Bats tag filter (AND within, OR across repeated
                        flags). Tag-scoped runs of a package aggregate
                        execute all of its keys unfiltered.
  --filter REGEX        Bats name filter regex.

Options:
  -j, --jobs N          Bats parallel jobs budget (default: CPU count;
                        split across concurrent suites; 1=sequential tests).
  -l, --list            List discovered tests and exit.
  -h, --help            Show this help.

Examples:
  check-dotfiles                          # all suites
  check-dotfiles kubectl helm             # aggregate smoke, these keys only
  check-dotfiles --suite config,ai        # specific suites
  check-dotfiles --tag toolchain:kubernetes
  check-dotfiles -j1                      # sequential (debug)

Environment:
  CHECK_DOTFILES_PARALLEL_SUITES  Concurrent suites (default 4; 1=serial).
  CHECK_DOTFILES_SUITE_TIMEOUT  Per-suite wall-clock cap in seconds
                                (default 120, 10s kill-after).
  CHECK_DOTFILES_TIMING         1=bats --timing + slowest-tests tail (default),
                                0=off.
  CHECK_DOTFILES_PKG_KEYS       Comma-separated package keys scoping the
                                aggregate smoke (set by TOOL... selectors).
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

  # Resolve suites. A missing listed suite is a silent drop in bare runs;
  # the runner cannot know toolchain gating (ai-off lacks test-ai-*), so
  # WARN and continue.
  local suite_files=()
  if [ -n "$suite_arg" ]; then
    local resolved
    if ! resolved=$(resolveSuites "$suite_arg"); then exit 1; fi
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ -f "${DIR}/${f}" ]; then
        suite_files+=("${DIR}/${f}")
      else printf 'check-dotfiles: WARN: listed suite %s missing from applied tree\n' "$f" >&2; fi
    done <<<"$resolved"
  elif [ ${#tools[@]} -gt 0 ]; then
    local s
    for s in "${PACKAGE_SUITES[@]}"; do
      if [ -f "${DIR}/${s}" ]; then
        suite_files+=("${DIR}/${s}")
      else printf 'check-dotfiles: WARN: listed suite %s missing from applied tree\n' "$s" >&2; fi
    done
  else
    local s
    for s in "${ALL_SUITES[@]}"; do
      if [ -f "${DIR}/${s}" ]; then
        suite_files+=("${DIR}/${s}")
      else printf 'check-dotfiles: WARN: listed suite %s missing from applied tree\n' "$s" >&2; fi
    done
  fi
  [ ${#suite_files[@]} -eq 0 ] && {
    printf 'check-dotfiles: no suites resolved\n' >&2
    exit 1
  }
  if [ ${#tools[@]} -gt 0 ]; then
    validateToolKeys "${tools[@]}" || exit 1
  fi

  # Build bats filter args. Pass each user --tag flag through as its own
  # --filter-tags: bats semantics are commas=AND within one flag, repeated
  # flags=OR. Parentheses and semicolons are not operators — composing a
  # `(a);(b)` expression feeds bats' internal eval, which strips the parens
  # of the first term and runs the rest as shell. With no user tags, run
  # unfiltered.
  BATS_FILTER_ARGS=()
  local tag
  for tag in "${tag_filters[@]+"${tag_filters[@]}"}"; do
    BATS_FILTER_ARGS+=(--filter-tags "$tag")
  done

  # Package keys scope the aggregate smoke in BOTH tools-only and
  # filter+tools runs.
  if [ ${#tools[@]} -gt 0 ]; then
    CHECK_DOTFILES_PKG_KEYS="$(
      IFS=,
      printf '%s' "${tools[*]}"
    )"
    export CHECK_DOTFILES_PKG_KEYS
  fi
  local combined_regex=""
  if [ -n "$filter_regex" ] && [ ${#tools[@]} -gt 0 ]; then
    combined_regex="(${filter_regex})|${AGGREGATE_TITLE}"
  elif [ -n "$filter_regex" ]; then
    combined_regex=$filter_regex
  elif [ ${#tools[@]} -gt 0 ]; then
    combined_regex=$AGGREGATE_TITLE
  fi
  [ -n "$combined_regex" ] && BATS_FILTER_ARGS+=(-f "$combined_regex")

  # Parallel config: bats -j budget, split across concurrent suites in runAll.
  [ -z "$parallel_jobs" ] && parallel_jobs=$(detectJobs)
  case $parallel_jobs in
  '' | *[!0-9]*) parallel_jobs=1 ;;
  esac
  # bats >=1.10 --timing; CHECK_DOTFILES_TIMING=0 opts out.
  BATS_TIMING_ARGS=()
  if [ "${CHECK_DOTFILES_TIMING:-1}" = "1" ] &&
    "$BATS_BIN" --help 2>&1 | command grep -q -- '--timing'; then
    BATS_TIMING_ARGS=(--timing)
  fi

  runAll "${suite_files[@]}"
}

main "$@"
