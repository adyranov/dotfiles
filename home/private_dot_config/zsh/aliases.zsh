alias sudo='sudo ' # https://wiki.archlinux.org/title/Sudo#Passing_aliases
alias reload=exec ${SHELL} -l

# chezmoi
alias cz="chezmoi"
alias cza="chezmoi apply"
alias czd="chezmoi diff"
alias czs='cd $(chezmoi source-path)'
alias czu="chezmoi update"

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
