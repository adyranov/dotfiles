# shellcheck shell=sh
# Shared interactive shell setup for zsh and bash.

if [ -n "${ZSH_VERSION:-}" ]; then
  _sh="zsh"
elif [ -n "${BASH_VERSION:-}" ]; then
  _sh="bash"
else
  return 0
fi

_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

# shellcheck source=/dev/null
[ -r "$_cfg/shell/exports.sh" ] && . "$_cfg/shell/exports.sh"
# shellcheck source=/dev/null
[ -r "$_cfg/zsh/functions.sh" ] && . "$_cfg/zsh/functions.sh"
# shellcheck source=/dev/null
[ -r "$_cfg/zsh/aliases.sh" ] && . "$_cfg/zsh/aliases.sh"

_data="${XDG_DATA_HOME:-$HOME/.local/share}"

# _source_cached_init is defined by exports.sh, sourced above; without it, init uncached.
command -v _source_cached_init >/dev/null 2>&1 || _source_cached_init() {
  shift 2
  eval "$("$@")"
}
_source_cached_init starship "$_sh" starship init "$_sh"
_source_cached_init zoxide "$_sh" zoxide init "$_sh" --cmd cd
_source_cached_init direnv "$_sh" direnv hook "$_sh"

_can_modern=0
# shellcheck disable=SC3028
if [ "$_sh" = "zsh" ] || [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  _can_modern=1
fi

if [ "$_can_modern" -eq 1 ]; then
  _source_cached_init atuin "$_sh" atuin init "$_sh" --disable-up-arrow
  if command -v carapace >/dev/null 2>&1; then
    [ -d "$_data/shell/cache" ] || { mkdir -p "$_data/shell/cache" && chmod 700 "$_data/shell"; }
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    export CARAPACE_EXCLUDES='terragrunt,tofu'
    _source_cached_init carapace "$_sh" env XDG_CACHE_HOME="$_data/shell/cache" carapace _carapace "$_sh"
  fi
fi

unset -f _source_cached_init
unset _sh _cfg _data _can_modern
