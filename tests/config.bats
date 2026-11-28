#!/usr/bin/env bats
# bats file_tags=suite:config

load 'helper'

@test "XDG base directories and core configs exist" {
  assert_file_exists "$HOME/.config/shell/exports.sh"
  assert_file_exists "$HOME/.config/shell/interactive.sh"
  assert_file_exists "$HOME/.config/starship.toml"
  assert_file_exists "$HOME/.bashrc"
  assert_file_exists "$HOME/.bash_profile"
  assert_file_exists "$HOME/.config/git/config"
  assert_file_exists "$HOME/.config/zsh/.zshrc"
  assert_file_exists "$HOME/.config/tmux/tmux.conf.local"
}

@test "git config sets expected core defaults" {
  [ "$(git config --file "$HOME/.config/git/config" --includes init.defaultBranch)" = "main" ]
  [ "$(git config --file "$HOME/.config/git/config" --includes pull.rebase)" = "true" ]
  [ "$(git config --file "$HOME/.config/git/config" --includes diff.algorithm)" = "histogram" ]
}

@test "shell exports and zsh configs parse cleanly" {
  sh -n "$HOME/.config/shell/exports.sh"
  sh -n "$HOME/.config/shell/interactive.sh"
  bash -n "$HOME/.bashrc"
  bash -n "$HOME/.bash_profile"
  sh -n "$HOME/.config/zsh/aliases.sh"
  sh -n "$HOME/.config/zsh/functions.sh"
  zsh -fn "$HOME/.config/zsh/.zshenv"
  zsh -fn "$HOME/.config/zsh/.zshrc"
  zsh -fn "$HOME/.config/zsh/keys.zsh"
  zsh -fn "$HOME/.config/zsh/abbr.zsh"
  [ ! -f "$HOME/.config/zsh/completions/_agent" ] || zsh -fn "$HOME/.config/zsh/completions/_agent"
  [ ! -f "$HOME/.config/zsh/functions.d/skyl" ] || zsh -fn "$HOME/.config/zsh/functions.d/skyl"
  [ ! -f "$HOME/.config/zsh/functions.d/kubesess" ] || bash -n "$HOME/.config/zsh/functions.d/kubesess"
}

@test "zsh config has no legacy framework references, loads plugins offline, and sets keybindings" {
  ! grep -rqiE --exclude-dir=plugins --exclude='*.zwc' 'z4h|zsh4humans|p10k|ohmyzsh' "$HOME/.config/zsh" || fail "legacy framework reference found under ~/.config/zsh"
  local err_out
  err_out="$(TERM=vt100 zsh -ic exit 2>&1 >/dev/null || true)"
  [ -z "$err_out" ] || fail "zsh -ic exit wrote to stderr: $err_out"

  local bk
  bk="$(zsh -ic 'bindkey')"
  [[ "$bk" == *"backward-word"* ]] || fail "missing backward-word binding"
  [[ "$bk" == *"forward-word"* ]] || fail "missing forward-word binding"
  [[ "$bk" == *"up-line-or-beginning-search"* ]] || fail "missing up-line-or-beginning-search binding"
  [[ "$bk" == *"_zsh_cd_back"* ]] || fail "missing _zsh_cd_back binding"
  [[ "$bk" == *"_zsh_cd_up"* ]] || fail "missing _zsh_cd_up binding"

  if [ -r "$HOME/.config/zsh/abbr.zsh" ]; then
    local abbr_out dupes
    abbr_out="$(zsh -ic '
      zle() { :; }
      print -r -- "count=${#_abbr_map}"
      print -r -- "gst=${_abbr_map[gst]:-}"
      print -r -- "czs=${_abbr_map[czs]:-}"
      print -r -- "x=${_abbr_map[x]:-}"
      print -r -- "legacy=$(( ${+_abbr_map[d64]} + ${+_abbr_map[e64]} + ${+_abbr_map[ef64]} ))"
      LBUFFER="gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e1=$LBUFFER"
      LBUFFER="echo gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e2=$LBUFFER"
      LBUFFER="ls && gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e3=$LBUFFER"
      LBUFFER="'\''gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e4=$LBUFFER"
      LBUFFER="gst"; RBUFFER=""; _abbr_no_expand_space; print -r -- "e5=$LBUFFER"
      LBUFFER="(gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e6=$LBUFFER"
      LBUFFER="echo \$(gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e7=$LBUFFER"
      LBUFFER="time gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e8=$LBUFFER"
      LBUFFER="! gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e9=$LBUFFER"
      LBUFFER="git gst"; RBUFFER=""; _abbr_expand_space; print -r -- "e10=$LBUFFER"
    ')"
    [[ "$abbr_out" == *"count=244"* ]] || fail "expected 244 abbreviations: $abbr_out"
    [[ "$abbr_out" == *"gst=git status"* ]] || fail "expected gst -> git status: $abbr_out"
    [[ "$abbr_out" == *'czs=cd $(chezmoi source-path)'* ]] || fail "expected czs -> cd \$(chezmoi source-path): $abbr_out"
    [[ "$abbr_out" == *"x=ouch decompress"* ]] || fail "expected x -> ouch decompress: $abbr_out"
    [[ "$abbr_out" == *"legacy=0"* ]] || fail "orphaned encode64 abbreviations still present: $abbr_out"
    [[ "$abbr_out" == *"e1=git status "* ]] || fail "Space did not expand gst: $abbr_out"
    [[ "$abbr_out" == *"e2=echo gst "* ]] || fail "Space expanded argument gst: $abbr_out"
    [[ "$abbr_out" == *"e3=ls && git status "* ]] || fail "Space did not expand gst after &&: $abbr_out"
    [[ "$abbr_out" == *"e4='gst "* ]] || fail "Space expanded inside quote: $abbr_out"
    [[ "$abbr_out" == *"e5=gst "* ]] || fail "Ctrl+Space expanded gst: $abbr_out"
    [[ "$abbr_out" == *"e6=(git status "* ]] || fail "Space did not expand (gst: $abbr_out"
    [[ "$abbr_out" == *'e7=echo $(git status '* ]] || fail "Space did not expand echo \$(gst: $abbr_out"
    [[ "$abbr_out" == *"e8=time git status "* ]] || fail "Space did not expand time gst: $abbr_out"
    [[ "$abbr_out" == *"e9=! git status "* ]] || fail "Space did not expand ! gst: $abbr_out"
    [[ "$abbr_out" == *"e10=git gst "* ]] || fail "Space expanded git gst: $abbr_out"
    dupes="$(sed -n 's/^abbr "\([^"]*\)"=.*/\1/p' "$HOME/.config/zsh-abbr/user-abbreviations" | sort | uniq -d)"
    [ -z "$dupes" ] || fail "duplicate abbreviation names found: $dupes"
  fi

  local osc_in osc_out
  osc_in="$(TMUX=1 zsh -ic '_tmux_osc_precmd' 2>/dev/null | cat -v)"
  [[ "$osc_in" == *"]133;A"* ]] && [[ "$osc_in" == *"]7;file://"* ]] || fail "missing raw OSC 133/7 inside tmux: $osc_in"
  [[ "$osc_in" != *"Ptmux;"* ]] || fail "unexpected DCS Ptmux wrapper in OSC hook: $osc_in"
  osc_out="$(env -u TMUX zsh -ic 'functions _tmux_osc_precmd >/dev/null 2>&1 && echo defined || echo absent')"
  [ "$osc_out" = "absent" ] || fail "tmux OSC hook should not be defined outside tmux"
}

@test "carapace covers former completion tools and preserves terragrunt/tofu wrappers" {
  command -v carapace >/dev/null 2>&1 || skip "carapace not installed"
  local clist tool
  clist="$(carapace --list)"
  for tool in gh kubectl docker mise atuin bat bun fd glow helm k3d lazygit rg uv xh; do
    printf '%s\n' "$clist" | jq -e --arg t "$tool" 'has($t)' >/dev/null || fail "carapace --list missing $tool"
  done
  for tool in chezmoi hf k9s kubecolor kubescape oc rclone sky stern yq; do
    assert_file_exists "$HOME/.config/carapace/specs/${tool}.yaml"
  done
  for tool in doggo omp sops topgrade terragrunt tofu; do
    assert_file_exists "$HOME/.config/zsh/completions/_${tool}"
    zsh -fn "$HOME/.config/zsh/completions/_${tool}"
  done
  if [ -r "$HOME/.config/zsh/.zshrc" ]; then
    local tg_comp tofu_comp
    tg_comp="$(zsh -ic 'printf "%s" "${_comps[terragrunt]:-}"' 2>/dev/null || true)"
    tofu_comp="$(zsh -ic 'printf "%s" "${_comps[tofu]:-}"' 2>/dev/null || true)"
    [ "$tg_comp" = "_terragrunt" ] || fail "expected terragrunt completion _terragrunt, got: $tg_comp"
    [ "$tofu_comp" = "_tofu" ] || fail "expected tofu completion _tofu, got: $tofu_comp"
  fi
}

@test "interactive bash loads shared setup cleanly with zero stderr" {
  local err_out
  err_out="$(TERM=vt100 bash -ic true 2>&1 >/dev/null | grep -vE '^bash: (cannot set terminal process group|no job control in this shell)' || true)"
  [ -z "$err_out" ] || fail "bash -ic true wrote to stderr: $err_out"
  bash -ic 'type cdi >/dev/null && alias ll >/dev/null'
  if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] && command -v atuin >/dev/null 2>&1; then
    bash -ic 'type __atuin_history >/dev/null'
  fi
}

@test "starship config parses and renders 2-line prompt without right prompt or emoji" {
  command -v starship >/dev/null 2>&1 || skip "starship not installed"
  STARSHIP_CONFIG="$HOME/.config/starship.toml" starship print-config >/dev/null
  ! python3 - "$HOME/.config/starship.toml" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
sys.exit(0 if re.search(r"[\U0001F300-\U0001FAFF\u2600-\u276E\u2770-\u27BF]", text) else 1)
PY

  local repo="$BATS_TEST_TMPDIR/starship-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q

  local out_repo stripped nl_count right_out dur_4s dur_1s st_1 st_0
  out_repo="$(cd "$repo" && env -u AGENT_SANDBOX -u STARSHIP_SHELL TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt)"
  stripped="$(printf '%s' "$out_repo" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/%\{|%\}//g')"
  nl_count="$(printf '%s' "$stripped" | tr -cd '\n' | wc -c | tr -d ' ')"
  [ "$nl_count" -eq 2 ] || fail "expected 2 newlines (3 lines) in prompt, got $nl_count: $stripped"
  [[ "$stripped" == *$'\n❯ ' ]] || fail "expected prompt to end with '❯ ' and no trailing newline: $stripped"

  right_out="$(cd "$repo" && TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --right)"
  [ -z "$right_out" ] || fail "expected empty right prompt, got: $right_out"

  dur_4s="$(cd "$repo" && TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --cmd-duration 4000)"
  [[ "$dur_4s" == *"4s"* ]] || fail "expected cmd_duration 4s on line 1: $dur_4s"
  dur_1s="$(cd "$repo" && TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --cmd-duration 1000)"
  [[ "$dur_1s" != *"1s"* ]] || fail "unexpected cmd_duration for 1000ms (<3000ms): $dur_1s"

  st_1="$(cd "$repo" && TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --status 1)"
  [[ "$st_1" == *"1"* ]] || fail "expected error status 1 in prompt: $st_1"
  st_0="$(cd "$repo" && TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --status 0)"
  [[ "$st_0" != *""* ]] || fail "unexpected error status symbol for status 0: $st_0"

  local out_on out_off out_wsl
  out_on="$(TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" AGENT_SANDBOX=1 starship prompt)"
  [[ "$out_on" == *"sandbox"* ]] || fail "expected sandbox badge in prompt: $out_on"
  if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ] && [ -z "${WSL_DISTRO_NAME:-}" ]; then
    out_off="$(env -u AGENT_SANDBOX TERM=xterm-256color STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt)"
    [[ "$out_off" != *"sandbox"* ]] || fail "unexpected sandbox badge when AGENT_SANDBOX is unset: $out_off"
    out_wsl="$(env -u AGENT_SANDBOX TERM=xterm-256color WSL_DISTRO_NAME=Ubuntu-24.04 STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt)"
    [[ "$out_wsl" == *"wsl"* ]] && [[ "$out_wsl" != *"container"* ]] || fail "expected wsl badge without container: $out_wsl"
  fi
}

@test "zsh refreshes stale compinit dump, tracks Shift+arrow dir history, caches init, and handles ssh-agent" {
  # 1. Stale zcompdump (>24h) is refreshed on startup
  local comp_data="$BATS_TEST_TMPDIR/comp-data"
  mkdir -p "$comp_data/shell"
  : >"$comp_data/shell/zcompdump"
  touch -t 200001010000 "$comp_data/shell/zcompdump"
  local ref_ts="$BATS_TEST_TMPDIR/ref-ts"
  touch -t 202001010000 "$ref_ts"
  XDG_DATA_HOME="$comp_data" zsh -ic exit
  [ "$comp_data/shell/zcompdump" -nt "$ref_ts" ] || fail "stale zcompdump was not refreshed"

  # 2. Shift+Up -> Shift+Left returns, Shift+Left -> cd /tmp records previous dir, and transient prompt toggles
  local dir_a="$BATS_TEST_TMPDIR/a" dir_b="$BATS_TEST_TMPDIR/a/b"
  mkdir -p "$dir_b"
  local nav_out
  nav_out="$(cd -P "$dir_b" && zsh -ic '
    zle() { :; }
    _zsh_cd_up
    _zsh_cd_back
    print -r -- "$PWD"
    cd /tmp
    print -r -- "${_dir_hist_back[-1]:-}"
    _zsh_transient_line_finish
    print -r -- "$PROMPT"
    _zsh_transient_precmd
    [[ "$PROMPT" != "%F{magenta}❯%f " ]] && print -r -- "restored"
    [[ "${widgets[zle-line-finish]:-}" == "user:azhw:zle-line-finish" ]] && zstyle -L | grep -q "_zsh_transient_line_finish" && print -r -- "hooked"
  ')"
  local line1 line2 line3 line4 line5
  line1="$(printf '%s\n' "$nav_out" | sed -n '1p')"
  line2="$(printf '%s\n' "$nav_out" | sed -n '2p')"
  line3="$(printf '%s\n' "$nav_out" | sed -n '3p')"
  line4="$(printf '%s\n' "$nav_out" | sed -n '4p')"
  line5="$(printf '%s\n' "$nav_out" | sed -n '5p')"
  [ "$line1" = "$(cd "$dir_b" && pwd -P)" ] || fail "Shift+Up then Shift+Left landed in $line1"
  [ "$line2" = "$(cd "$dir_b" && pwd -P)" ] || fail "cd /tmp after Shift+Left did not record previous dir: $line2"
  [ "$line3" = "%F{magenta}❯%f " ] || fail "transient prompt did not collapse: $line3"
  [ "$line4" = "restored" ] || fail "transient precmd did not restore PROMPT: $line4"
  [ "$line5" = "hooked" ] || fail "transient hook not registered via add-zle-hook-widget: $line5"

  # 3. Real zsh -ic ssh-agent + YubiKey loading across exit codes 1, 2, and 0
  local fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  local ssh_home="$BATS_TEST_TMPDIR/ssh-home"
  local add_log="$BATS_TEST_TMPDIR/ssh-add.log"
  local agent_log="$BATS_TEST_TMPDIR/ssh-agent.log"
  local agent_up="$BATS_TEST_TMPDIR/agent-up"
  mkdir -p "$fake_bin" "$ssh_home/.ssh" "$ssh_home/.local/share/shell"
  ln -s "$HOME/.zshenv" "$ssh_home/.zshenv"
  ln -s "$HOME/.config" "$ssh_home/.config"
  [ ! -f "$HOME/.local/share/shell/zcompdump" ] || cp "$HOME/.local/share/shell/zcompdump" "$ssh_home/.local/share/shell/zcompdump"
  : >"$ssh_home/.ssh/id_yk_blue"
  cat >"$fake_bin/ssh-add" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >>"${FAKE_SSH_ADD_LOG}"
if [ "${1:-}" = "-l" ]; then
  if [ -n "${FAKE_SSH_AGENT_UP:-}" ] && [ -f "${FAKE_SSH_AGENT_UP}" ]; then
    exit 1
  fi
  exit "${FAKE_SSH_ADD_RC:-1}"
fi
exit 0
SH
  cat >"$fake_bin/ssh-agent" <<'SH'
#!/usr/bin/env sh
echo called >>"${FAKE_SSH_AGENT_LOG}"
[ -z "${FAKE_SSH_AGENT_UP:-}" ] || : >"${FAKE_SSH_AGENT_UP}"
printf 'SSH_AUTH_SOCK=/tmp/fake-agent.sock; export SSH_AUTH_SOCK;\n'
SH
  chmod +x "$fake_bin/ssh-add" "$fake_bin/ssh-agent"
  local test_path="$fake_bin:$PATH:/opt/local/bin:/opt/local/sbin:/opt/local/libexec/gnubin"

  # Case 1: ssh-add -l exits 1 (agent up, no keys) -> 0 ssh-agent calls, key added
  : >"$add_log"
  : >"$agent_log"
  env -u AGENT_SANDBOX -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$ssh_home" XDG_CONFIG_HOME="$ssh_home/.config" XDG_DATA_HOME="$ssh_home/.local/share" ZDOTDIR="$ssh_home/.config/zsh" \
    MISE_DATA_DIR="$HOME/.local/share/mise" MISE_STATE_DIR="$HOME/.local/state/mise" \
    PATH="$test_path" SSH_AUTH_SOCK=/tmp/existing.sock \
    FAKE_SSH_ADD_RC=1 FAKE_SSH_ADD_LOG="$add_log" FAKE_SSH_AGENT_LOG="$agent_log" \
    zsh -ic exit </dev/null
  [ ! -s "$agent_log" ] || fail "ssh-agent spawned when ssh-add exited 1"
  grep -Fq -- "-q $ssh_home/.ssh/id_yk_blue" "$add_log" || fail "expected id_yk_blue added on exit 1: $(cat "$add_log")"

  # Case 2: ssh-add -l exits 2 (no agent) -> 1 ssh-agent call, then key added
  : >"$add_log"
  : >"$agent_log"
  rm -f "$agent_up" "$ssh_home/.local/share/shell/ssh-agent.env"
  env -u AGENT_SANDBOX -u SSH_AUTH_SOCK -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$ssh_home" XDG_CONFIG_HOME="$ssh_home/.config" XDG_DATA_HOME="$ssh_home/.local/share" ZDOTDIR="$ssh_home/.config/zsh" \
    MISE_DATA_DIR="$HOME/.local/share/mise" MISE_STATE_DIR="$HOME/.local/state/mise" \
    PATH="$test_path" \
    FAKE_SSH_ADD_RC=2 FAKE_SSH_AGENT_UP="$agent_up" FAKE_SSH_ADD_LOG="$add_log" FAKE_SSH_AGENT_LOG="$agent_log" \
    zsh -ic exit </dev/null
  [ "$(wc -l <"$agent_log" | tr -d ' ')" -eq 1 ] || fail "expected ssh-agent once on exit 2, got: $(wc -l <"$agent_log")"
  grep -Fq -- "-q $ssh_home/.ssh/id_yk_blue" "$add_log" || fail "expected id_yk_blue added after agent start: $(cat "$add_log")"

  # Case 3: ssh-add -l exits 0 (keys loaded) -> 0 ssh-agent calls, no key add
  : >"$add_log"
  : >"$agent_log"
  env -u AGENT_SANDBOX -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$ssh_home" XDG_CONFIG_HOME="$ssh_home/.config" XDG_DATA_HOME="$ssh_home/.local/share" ZDOTDIR="$ssh_home/.config/zsh" \
    MISE_DATA_DIR="$HOME/.local/share/mise" MISE_STATE_DIR="$HOME/.local/state/mise" \
    PATH="$test_path" SSH_AUTH_SOCK=/tmp/existing.sock \
    FAKE_SSH_ADD_RC=0 FAKE_SSH_ADD_LOG="$add_log" FAKE_SSH_AGENT_LOG="$agent_log" \
    zsh -ic exit </dev/null
  [ ! -s "$agent_log" ] || fail "ssh-agent spawned when ssh-add exited 0"
  ! grep -Fq -- "id_yk_blue" "$add_log" || fail "unexpected ssh-add key load when keys already loaded: $(cat "$add_log")"

  # 4. Tool init cache reuses existing file and regenerates when key changes
  local starship_cache="$ssh_home/.local/share/shell/init/starship.zsh"
  local mise_cache="$ssh_home/.local/share/shell/init/mise.zsh"
  assert_file_exists "$starship_cache"
  assert_file_exists "$mise_cache"
  grep -Eq '^# bin: .*/mise$' "$mise_cache" || fail "unexpected mise init cache header: $(head -n 1 "$mise_cache")"
  local mark="$BATS_TEST_TMPDIR/cache-mark"
  sleep 1
  touch "$mark"
  env -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$ssh_home" XDG_CONFIG_HOME="$ssh_home/.config" XDG_DATA_HOME="$ssh_home/.local/share" ZDOTDIR="$ssh_home/.config/zsh" \
    MISE_DATA_DIR="$HOME/.local/share/mise" MISE_STATE_DIR="$HOME/.local/state/mise" \
    zsh -ic 'typeset -f _mise_hook >/dev/null' </dev/null
  [ ! "$starship_cache" -nt "$mark" ] || fail "starship init cache was unexpectedly regenerated on second startup"
  [ ! "$mise_cache" -nt "$mark" ] || fail "mise init cache was unexpectedly regenerated on second startup"
  printf '# bin: /stale/starship\n' >"$starship_cache"
  env -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$ssh_home" XDG_CONFIG_HOME="$ssh_home/.config" XDG_DATA_HOME="$ssh_home/.local/share" ZDOTDIR="$ssh_home/.config/zsh" \
    MISE_DATA_DIR="$HOME/.local/share/mise" MISE_STATE_DIR="$HOME/.local/state/mise" \
    zsh -ic exit </dev/null
  grep -Eq '^# bin: .*/starship$' "$starship_cache" || fail "stale init cache bin header was not regenerated: $(head -n 1 "$starship_cache")"

  local fake_cache_home="$BATS_TEST_TMPDIR/fake-cache-home" empty_mise="$BATS_TEST_TMPDIR/empty-mise"
  local fake_direnv="$fake_cache_home/.local/bin/direnv"
  mkdir -p "$fake_cache_home/.local/bin" "$fake_cache_home/.local/share/shell" "$empty_mise"
  ln -s "$HOME/.zshenv" "$fake_cache_home/.zshenv"
  ln -s "$HOME/.config" "$fake_cache_home/.config"
  [ ! -f "$HOME/.local/share/shell/zcompdump" ] || cp "$HOME/.local/share/shell/zcompdump" "$fake_cache_home/.local/share/shell/zcompdump"
  cat >"$fake_direnv" <<'SH'
#!/usr/bin/env sh
echo 'export _FAKE_CACHE_V=1'
SH
  chmod +x "$fake_direnv"
  local direnv_cache="$fake_cache_home/.local/share/shell/init/direnv.zsh"
  env -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$fake_cache_home" XDG_CONFIG_HOME="$fake_cache_home/.config" ZDOTDIR="$fake_cache_home/.config/zsh" \
    MISE_DATA_DIR="$empty_mise" MISE_STATE_DIR="$BATS_TEST_TMPDIR/empty-mise-state" \
    PATH="/usr/bin:/bin" zsh -ic exit </dev/null
  assert_file_exists "$direnv_cache"
  [ "$(head -n 1 "$direnv_cache")" = "# bin: $fake_direnv" ] || fail "unexpected direnv cache header: $(head -n 1 "$direnv_cache")"
  grep -q '_FAKE_CACHE_V=1' "$direnv_cache" || fail "expected v1 in direnv cache"
  sleep 1
  cat >"$fake_direnv" <<'SH'
#!/usr/bin/env sh
echo 'export _FAKE_CACHE_V=2'
SH
  chmod +x "$fake_direnv"
  env -u __MISE_DIFF -u __MISE_ORIG_PATH -u __MISE_SESSION \
    HOME="$fake_cache_home" XDG_CONFIG_HOME="$fake_cache_home/.config" ZDOTDIR="$fake_cache_home/.config/zsh" \
    MISE_DATA_DIR="$empty_mise" MISE_STATE_DIR="$BATS_TEST_TMPDIR/empty-mise-state" \
    PATH="/usr/bin:/bin" zsh -ic exit </dev/null
  grep -q '_FAKE_CACHE_V=2' "$direnv_cache" || fail "init cache was not regenerated after touching binary newer than cache"
}

@test "chezmoi data loads cleanly from source" {
  run chezmoi --source "$REPO_ROOT" data
  [ "$status" -eq 0 ] || fail "chezmoi data failed: $output"
}
