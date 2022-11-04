#!/usr/bin/env bash
common_setup() {
    bats_require_minimum_version 1.8.0
    load 'bats-support/load.bash'
    load 'bats-assert/load.bash'
    load 'bats-file/load.bash'

    [ "$(uname)" == 'Darwin' ] && OS_ID='darwin'

    # shellcheck source=/dev/null disable=SC2034
    [ "$(uname)" == 'Linux' ] && . /etc/os-release && OS_ID=$ID

    # shellcheck source=/dev/null
    . "$HOME/.asdf/asdf.sh"
    if [ -d "$HOME/.asdf/plugins/direnv" ]; then
      eval "$(asdf exec direnv hook bash)"
      direnv() { asdf exec direnv "$@"; }
    fi

    PATH=$PATH:$HOME/.krew/bin
}
