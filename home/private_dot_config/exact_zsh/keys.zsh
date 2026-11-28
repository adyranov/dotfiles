# Zsh-only keybindings, widgets, and tmux OSC 133/7 hooks.
bindkey -e

# Up/Down prefix-history search.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Option/Alt word motion and deletion.
bindkey '^[[1;3D' backward-word
bindkey '^[b' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^[f' forward-word
bindkey '^[^?' backward-kill-word
bindkey '^[^H' backward-kill-word

# Shift+arrow directory navigation widgets.
typeset -ga _dir_hist_back=()
typeset -ga _dir_hist_fwd=()

_dir_hist_chpwd() {
  if [[ -n ${OLDPWD-} && $OLDPWD != "$PWD" ]]; then
    _dir_hist_back+=("$OLDPWD")
    _dir_hist_fwd=()
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _dir_hist_chpwd

_zsh_cd_back() {
  ((${#_dir_hist_back} > 0)) || return 0
  local target="${_dir_hist_back[-1]}"
  _dir_hist_back=("${_dir_hist_back[@]:0:-1}")
  _dir_hist_fwd+=("$PWD")
  builtin cd -q -- "$target" 2>/dev/null || return 0
  zle reset-prompt
}
zle -N _zsh_cd_back
bindkey '^[[1;2D' _zsh_cd_back

_zsh_cd_forward() {
  ((${#_dir_hist_fwd} > 0)) || return 0
  local target="${_dir_hist_fwd[-1]}"
  _dir_hist_fwd=("${_dir_hist_fwd[@]:0:-1}")
  _dir_hist_back+=("$PWD")
  builtin cd -q -- "$target" 2>/dev/null || return 0
  zle reset-prompt
}
zle -N _zsh_cd_forward
bindkey '^[[1;2C' _zsh_cd_forward

_zsh_cd_up() {
  _dir_hist_back+=("$PWD")
  _dir_hist_fwd=()
  builtin cd -q .. 2>/dev/null || return 0
  zle reset-prompt
}
zle -N _zsh_cd_up
bindkey '^[[1;2A' _zsh_cd_up

_zsh_fzf_cd_child() {
  (($+commands[fzf])) || return 0
  local dir
  if (($+commands[fd])); then
    dir="$(fd --type d --hidden --follow --exclude .git 2>/dev/null | fzf --height=40% --reverse)"
  else
    dir="$(find . -mindepth 1 -maxdepth 4 -type d -not -path '*/.git*' 2>/dev/null | fzf --height=40% --reverse)"
  fi
  if [[ -n $dir ]]; then
    _dir_hist_back+=("$PWD")
    _dir_hist_fwd=()
    builtin cd -q -- "$dir" 2>/dev/null
  fi
  zle reset-prompt
}
zle -N _zsh_fzf_cd_child
bindkey '^[[1;2B' _zsh_fzf_cd_child

# Esc Esc toggles leading sudo.
_zsh_sudo_command_line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N _zsh_sudo_command_line
bindkey '^[^[' _zsh_sudo_command_line

# Raw unwrapped OSC 133 and OSC 7 inside tmux (Ghostty's injected integration
# does not reach shells started by tmux).
if [[ -n ${TMUX-} ]]; then
  _tmux_osc_precmd() {
    local _rc=$?
    printf '\e]133;D;%s\a' "$_rc"
    printf '\e]7;file://%s%s\a' "${HOST:-localhost}" "$PWD"
    printf '\e]133;A\a'
  }
  _tmux_osc_preexec() {
    printf '\e]133;C\a'
  }
  add-zsh-hook precmd _tmux_osc_precmd
  add-zsh-hook preexec _tmux_osc_preexec
fi

# Transient prompt: collapse previous prompts to a plain ❯ on accept-line.
_starship_saved_prompt="${PROMPT-}"

_zsh_transient_precmd() {
  PROMPT="$_starship_saved_prompt"
}

_zsh_transient_line_finish() {
  PROMPT='%F{magenta}❯%f '
  zle reset-prompt
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-finish _zsh_transient_line_finish
add-zsh-hook precmd _zsh_transient_precmd
