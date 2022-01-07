alias cdgr=cd-gitroot

alias k=kubectl
alias kctx=kubectx
alias kns=kubens

alias tf=terraform
alias tg=terragrunt

alias reload=exec ${SHELL} -l

# ls => exa
# exchange ls with exa
# https://the.exa.website/
if (( $+commands[exa] )); then
  alias ls='exa --group-directories-first --sort=name --classify'
  alias lt='ls --tree --level=2'
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
if (( $+commands[nvim] )); then
  alias vim='nvim'
fi
