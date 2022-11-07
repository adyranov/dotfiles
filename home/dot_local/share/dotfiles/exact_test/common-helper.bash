#!/usr/bin/env bash
common_setup() {
    bats_require_minimum_version 1.8.0
    load 'bats-support/load.bash'
    load 'bats-assert/load.bash'
    load 'bats-file/load.bash'

    # shellcheck source=/dev/null
    source "$HOME"/.config/shell/exports.sh
}
