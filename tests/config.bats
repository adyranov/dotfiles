#!/usr/bin/env bats
# bats file_tags=suite:config

load 'helper'

@test "XDG base directories and core configs exist" {
  assert_file_exists "$HOME/.config/shell/exports.sh"
  assert_file_exists "$HOME/.config/git/config"
  assert_file_exists "$HOME/.config/zsh/.zshrc"
  assert_file_exists "$HOME/.config/tmux/tmux.conf.local"
}

@test "git config sets expected core defaults" {
  [ "$(git config --file "$HOME/.config/git/config" --includes init.defaultBranch)" = "main" ]
  [ "$(git config --file "$HOME/.config/git/config" --includes pull.rebase)" = "true" ]
  [ "$(git config --file "$HOME/.config/git/config" --includes diff.algorithm)" = "histogram" ]
}

@test "shell exports and zsh configs parse cleanly" {
  sh -n "$HOME/.config/shell/exports.sh"
  sh -n "$HOME/.config/zsh/aliases.sh"
  sh -n "$HOME/.config/zsh/functions.sh"
  zsh -fn "$HOME/.config/zsh/.zshrc"
  [ ! -f "$HOME/.config/zsh/completions/_agent" ] || zsh -fn "$HOME/.config/zsh/completions/_agent"
  [ ! -f "$HOME/.config/zsh/functions.d/skyl" ] || zsh -fn "$HOME/.config/zsh/functions.d/skyl"
}

@test "chezmoi data loads cleanly from source" {
  run chezmoi --source "$REPO_ROOT" data
  [ "$status" -eq 0 ] || fail "chezmoi data failed: $output"
}
