#!/usr/bin/env bash
# bats runs `load` at file scope, so the assert helpers exist in setup_file
# too; common_setup's loads are idempotent and stay for per-test contexts.
load 'bats-support/load.bash'
load 'bats-assert/load.bash'
load 'bats-file/load.bash'

common_setup() {
  bats_require_minimum_version 1.12.0
  load 'bats-support/load.bash'
  load 'bats-assert/load.bash'
  load 'bats-file/load.bash'

  # shellcheck source=/dev/null
  source "$HOME"/.config/shell/exports.sh
}

# DCG robot-mode probes: exit 0 = allow, 1 = deny (`dcg test --robot`).
# dcg ships in core packages (always installed), so a missing pinned binary is
# install drift: fail, never skip, so enforcement decay is red on every host.
require_dcg() {
  command -v dcg >/dev/null || {
    echo "dcg pinned binary not found — mise install github:Dicklesworthstone/destructive_command_guard" >&2
    return 1
  }
}

# In the agent sandbox the PATH-first chezmoi (mise shim) cannot exec mise
# (status 126); the sandbox's own command shim is runnable. Probe PATH
# candidates and take the first that answers (host terminals pick the shim).
# Memoized: suites probe once.
chezmoiBin() {
  [ -n "${CHEZMOI_BIN:-}" ] && {
    printf '%s\n' "$CHEZMOI_BIN"
    return 0
  }
  local IFS=: __d __c
  for __d in $PATH; do
    __c="$__d/chezmoi"
    [ -x "$__c" ] && "$__c" --version >/dev/null 2>&1 &&
      {
        CHEZMOI_BIN="$__c"
        printf '%s\n' "$__c"
        return 0
      }
  done
  return 1
}

# tmplFile NAME — locate a source template (repo-relative NAME). Chezmoi's
# source-path is <repo>/home on hosts and docker, the default (empty) dir on
# CI hosts where install.sh's --source is not persisted; the repo clone lives
# at GITHUB_WORKSPACE there. Try each root bare and with a home/ prefix;
# take the first file that exists.
tmplFile() {
  local name="$1" __r
  local -a __roots=()
  local __cb
  __cb="$(chezmoiBin 2>/dev/null)" || __cb=""
  [ -n "$__cb" ] && __roots+=("$("$__cb" source-path 2>/dev/null)")
  __roots+=("${BATS_TEST_DIRNAME:-}/.." "${GITHUB_WORKSPACE:-}")
  for __r in "${__roots[@]}"; do
    [ -n "$__r" ] || continue
    [ -f "$__r/$name" ] && {
      printf '%s\n' "$__r/$name"
      return 0
    }
    [ -f "$__r/home/$name" ] && {
      printf '%s\n' "$__r/home/$name"
      return 0
    }
  done
  printf 'tmplFile: %s: source template not found\n' "$name" >&2
  return 1
}

# render_source TMPL OUT [OVERRIDE_DATA] — chezmoi execute-template via the
# PATH-probed binary, assert success, and strip the .init.sh Homebrew noise
# prefix chezmoi prints on hosts without brew (kept from the shebang or
# #compdef line on).
render_source() {
  local tmpl="$1" out="$2" override="${3:-}" cb
  cb="$(chezmoiBin)"
  # includeTemplate resolves .chezmoitemplates against the source root, not
  # the -f path: pin --source to the located root (CI hosts keep the default
  # empty source dir, so the configured root alone misses the clone).
  local -a args=(execute-template)
  local __d2 __i
  __d2="$(dirname "$tmpl")"
  for __i in 1 2 3 4 5 6 7 8; do
    [ -d "$__d2/.chezmoitemplates" ] && {
      args+=(--source "$__d2")
      break
    }
    [ "$__d2" = "/" ] && break
    __d2="$(dirname "$__d2")"
  done
  args+=(-f "$tmpl")
  [ -n "$override" ] && args+=(--override-data "$override")
  run "$cb" "${args[@]}"
  assert_success
  local body
  # shellcheck disable=SC2154  # $output is set by the bats run above
  body="$(sed -n -e '/^#!/,$p' -e '/^#compdef /,$p' <<<"$output")"
  # Sources without a shebang/compdef marker (e.g. .chezmoiignore) keep the
  # full output; the noise lines never collide with their content entries.
  if [ -n "$body" ]; then printf '%s\n' "$body" >"$out"; else printf '%s\n' "$output" >"$out"; fi
}

# launcher_probe AGENT ARGS... — run the applied launcher with a pinned probe
# home and ENGRAM_* env; assert against the /fixture-home paths it bakes.
launcher_probe() {
  local agent="$1"
  shift
  run env HOME=/fixture-home XDG_CONFIG_HOME=/fixture-home/.config \
    ENGRAM_DATA_DIR=/tmp/character-env/engram-data ENGRAM_PORT=43123 \
    "$HOME/.local/bin/agent" "$agent" "$@"
  assert_success
}

# scratch_env — env args that route the launcher scratch bootstrap into a
# Bats-owned root instead of the live /tmp/agents tree (AGENT_LAUNCH_TEST_MODE)
# and pin the whole Engram supervision surface (state, data, port, url) into
# the Bats tmpdir on a fixed non-7437 port (mirrors launcher_probe), so
# inherited XDG_STATE_HOME/ENGRAM_PORT can never steer a test launch at the
# live daemon. Pair with the setup_mock_bins engram/pkill/pgrep/curl stubs:
# tests never signal real processes nor spawn real daemons.
scratch_env() {
  printf 'AGENT_LAUNCH_TEST_MODE=1 AGENT_LAUNCH_TEST_SCRATCH_ROOT=%s XDG_STATE_HOME=%s/xdg-state ENGRAM_DATA_DIR=%s/engram-data ENGRAM_PORT=43123 ENGRAM_URL=http://127.0.0.1:43123' \
    "$BATS_TEST_TMPDIR/agents" "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR"
}

# assert_scratch_mode_0700 DIR — the launcher's stat_field probe (executable_agent):
# BSD stat first, numeric-validate, GNU fallback; asserts the exact 0700 mode.
assert_scratch_mode_0700() {
  local mode
  mode="$(stat -f %Lp "$1" 2>/dev/null || true)"
  case "$mode" in '' | *[!0-9]*) mode="$(stat -c %a "$1" 2>/dev/null || true)" ;; esac
  assert_equal "$mode" "700"
}

# setup_mock_bins DIR [curl nc nono] — shared exit-0 curl/nc/pkill stubs plus a
# nono pass-through (skip `run --profile X`, step over `--`, exec the
# binary). Suites override any stub by writing their own file afterwards.
setup_mock_bins() {
  local d="$1" n
  shift
  local -a names=("$@")
  # Default = full-launch set: pwd_guard (git) plus the Engram supervision
  # surface offline; suites launching end-to-end need every one of these.
  [ "${#names[@]}" -gt 0 ] || names=(curl nc nono git engram pkill pgrep)
  for n in "${names[@]}"; do
    case "$n" in
    curl | nc | pkill) printf '#!/usr/bin/env sh\nexit 0\n' >"$d/$n" ;;
    nono)
      # Scan to the `--` separator (profile flags come in many shapes; a
      # fixed shift count breaks as soon as the launcher grows an option).
      # shellcheck disable=SC2016  # stub ships literal $1/$# for the stub shell
      printf '#!/usr/bin/env sh\nwhile [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done\n[ "$#" -gt 0 ] && shift\nexec "$@"\n' >"$d/$n"
      ;;
    echo:*)
      # argv echo stub named after the agent binary: prints every forwarded arg.
      # shellcheck disable=SC2016  # stub ships literal $@ for the stub shell
      n="${n#echo:}"
      printf '#!/usr/bin/env sh\nprintf "%%s\\n" "$@"\n' >"$d/$n"
      ;;
    git)
      # Faithful minimal rev-parse for the launcher's pwd_guard: walks for
      # .git like real git, so negative cwd probes keep failing closed.
      cat >"$d/git" <<'GITSTUB'
#!/usr/bin/env sh
[ "$1 $2" = "rev-parse --is-inside-work-tree" ] || exit 1
d=$PWD
while :; do
  [ -d "$d/.git" ] && { echo true; exit 0; }
  [ "$d" = / ] && break
  d=${d%/*}
  [ -n "$d" ] || d=/
done
exit 1
GITSTUB
      ;;
    engram)
      # Offline daemon: `version` answers for the identity probe; every other
      # subcommand (serve) exits at once, so a spawned "daemon" is a no-op
      # that signals readiness through the stub curl.
      # shellcheck disable=SC2016  # stub ships literal $1 for the stub shell
      printf '#!/usr/bin/env sh\ncase "$1" in version) printf "engram 0.0-test\\n" ;; esac\nexit 0\n' >"$d/$n"
      ;;
    pgrep)
      # No supervised process: restart_daemon's kill-wait loop breaks at once.
      printf '#!/usr/bin/env sh\nexit 1\n' >"$d/$n"
      ;;
    *)
      echo "setup_mock_bins: no shared stub for '$n'" >&2
      return 1
      ;;
    esac
    chmod +x "$d/$n"
  done
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
