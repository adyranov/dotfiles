alias kctx=kubectx
alias kns=kubens

# ls => exa
# exchange ls with exa
# https://the.exa.website/
if (( $+commands[exa] )); then
  alias ls='exa'
fi

# cat/less/man => bat

# exchange cat/less with bat
# https://github.com/sharkdp/bat
if (( $+commands[bat] )); then
  alias cat='bat -pp'
  alias less='bat --paging=always'

  # override MANPAGER
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"

fi

# grep => ripgrep

# exchange grep with ripgrep
# https://github.com/BurntSushi/ripgrep
if (( $+commands[rg] )); then
  alias grep='rg'
fi

# top => htop

# exchange top with htop
# https://github.com/htop-dev/htop
if (( $+commands[htop] )); then
  alias top='htop'
fi

# vim => neovim

# exchange vim with neovim
# https://github.com/neovim/neovim
if (( $+commands[vim] )); then
  alias vim='nvim'
fi
