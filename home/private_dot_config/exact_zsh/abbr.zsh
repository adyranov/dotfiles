# Built-in zsh abbreviation expansion widget (replaces zsh-abbr).

typeset -gA _abbr_map=()

_abbr_load() {
  local abbr_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-abbr/user-abbreviations"
  [[ -r $abbr_file ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == abbr\ \"*\"=\"*\" ]] || continue
    line="${line#abbr \"}"
    key="${line%%\"=\"*}"
    val="${line#*\"=\"}"
    val="${val%\"}"
    key="${key//\\\!/!}"
    val="${val//\\\$/\$}"
    val="${val//\\\"/\"}"
    _abbr_map[$key]="$val"
  done <"$abbr_file"
}

_abbr_load
unfunction _abbr_load

_abbr_expand() {
  [[ -z $LBUFFER || $LBUFFER == *[[:space:]] ]] && return 0
  local -a tokens=(${(z)LBUFFER})
  while [[ ${tokens[-1]} == '$('* ]]; do
    tokens=(${(z)${tokens[-1]#\$\(}})
    ((${#tokens})) || return 0
  done
  local word="${tokens[-1]}"
  ((${+_abbr_map[$word]})) || return 0
  # Unclosed quotes leave LBUFFER ending in quote/content or unmatched token; require exact suffix match.
  [[ $LBUFFER == *"$word" ]] || return 0

  local n=${#tokens}
  local prev=""
  if ((n > 1)); then
    prev="${tokens[n - 1]}"
    case "$prev" in
    ';' | '|' | '&&' | '||' | '&' | '(' | $'\n') ;;
    sudo | time | '!')
      if ((n > 2)); then
        case "${tokens[n - 2]}" in
        ';' | '|' | '&&' | '||' | '&' | '(' | $'\n') ;;
        *) return 0 ;;
        esac
      fi
      ;;
    *) return 0 ;;
    esac
  fi

  LBUFFER="${LBUFFER%"$word"}${_abbr_map[$word]}"
}

_abbr_expand_space() {
  _abbr_expand
  LBUFFER+=" "
}

_abbr_expand_accept_line() {
  _abbr_expand
  zle accept-line
}

_abbr_no_expand_space() {
  LBUFFER+=" "
}

# zsh-autosuggestions skips widgets named with a leading `_`, so register the
# public widget names (functions keep the `_abbr_` prefix).
zle -N abbr_expand_space _abbr_expand_space
zle -N _abbr_expand_accept_line
zle -N abbr_no_expand_space _abbr_no_expand_space

for _abbr_km in emacs viins; do
  bindkey -M "$_abbr_km" ' ' abbr_expand_space
  bindkey -M "$_abbr_km" '^M' _abbr_expand_accept_line
  bindkey -M "$_abbr_km" '^J' _abbr_expand_accept_line
  bindkey -M "$_abbr_km" '^@' abbr_no_expand_space
done
unset _abbr_km
