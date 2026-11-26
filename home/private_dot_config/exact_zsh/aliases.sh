# shellcheck shell=sh
# shellcheck disable=SC2139
alias reload="exec ${SHELL} -l"
command -v kubecolor >/dev/null 2>&1 && alias kubectl='kubecolor'

# eza
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --icons --level=2'
  alias l='eza -lah --icons --group-directories-first --git'
fi

# less/man => bat (keep POSIX cat intact)
if command -v bat >/dev/null 2>&1; then
  alias less='bat --paging=always'

  # override MANPAGER (MANROFFOPT=-c prevents groff 1.23+ SGR corruption)
  export MANROFFOPT="-c"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# vim => neovim
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
fi

# npm packages
alias ncu="npx --yes -p npm-check-updates@latest ncu"

alias sudo='sudo ' # https://wiki.archlinux.org/title/Sudo#Passing_aliases
