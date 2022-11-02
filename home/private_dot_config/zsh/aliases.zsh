alias sudo='sudo ' # https://wiki.archlinux.org/title/Sudo#Passing_aliases

alias k=kubectl
alias kctx=kubectx
alias kns=kubens

alias tf=terraform
alias tg=terragrunt

alias reload=exec ${SHELL} -l

alias u="brew update                      && \
         brew upgrade                     && \
         brew upgrade --cask --greedy     && \
         brew cleanup --prune=1           && \
         asdf update || true              && \
         asdf plugin-update --all || true && \
         rustup self update || true       && \
         rustup update || true            && \
         npm update -g || true            && \
         chezmoi upgrade                  && \
         z4h update"
# ls => exa
# exchange ls with exa
# https://the.exa.website/
if (( $+commands[exa] )); then
  alias ls='exa --group-directories-first --sort=name --classify'
  alias la='ls -la'
  alias lt='ls --tree --level=2'
fi

# cat/less/man => bat

# exchange cat/less with bat
# https://github.com/sharkdp/bat
if (( $+commands[bat] || $+commands[batcat] )); then
	if (( ! $+commands[bat] )); then
		alias bat='batcat'
	fi
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
