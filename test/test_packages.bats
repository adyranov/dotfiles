#!./test/bats/bin/bats

load 'common-helper'

setup() {
  common_setup
}

@test "bash" {
  run bash --help
  assert_success
}

@test "bat" {
  BAT=bat
  if [ $OS_ID == 'ubuntu' ]; then
    BAT=batcat
  fi
  run $BAT --help
  assert_success
}

@test "colima" {
  [ $OS_ID != 'darwin' ] && skip "Not macOS"
  run colima --help
  assert_success
}

@test "curl" {
  run curl --help
  assert_success
}

@test "datree" {
  run datree --help
  assert_success
}

@test "delta" {
  run delta --help
  assert_success
}

@test "direnv" {
  run direnv --help
  assert_success
}

@test "dive" {
  run dive --help
  assert_success
}

@test "docker" {
  run docker --help
  assert_success
}

@test "exa" {
  run exa --help
  assert_success
}

@test "fd" {
  FD=fd
  if [ $OS_ID == 'ubuntu' ]; then
    FD=fdfind
  fi
  run $FD --help
  assert_success
}

@test "gh" {
  run gh --help
  assert_success
}

@test "git" {
  run git --help
  assert_success
}

@test "gpg" {
  run gpg --help
  assert_success
}

@test "helm" {
  run helm --help
  assert_success
}

@test "htop" {
  run htop --help
  assert_success
}

@test "httpie" {
  run http --version
  assert_success
}

@test "java" {
  run java --help
  assert_success
}

@test "jq" {
  run jq --help
  assert_success
}

@test "k9s" {
  run k9s --help
  assert_success
}

@test "kubectl" {
  run kubectl --help
  assert_success
}

@test "kubectx" {
  run kubectx --help
  assert_success
}

@test "mas" {
  [ $OS_ID != 'darwin' ] && skip "Not macOS"
  run mas
  assert_success
}

@test "maven" {
  run mvn --help
  assert_success
}

@test "neovim" {
  run nvim --help
  assert_success
}

@test "nodejs" {
  run node --help
  assert_success
}

@test "npm" {
  run npm -v
  assert_success
}

@test "popeye" {
  run popeye --help
  assert_success
}

@test "pre-commit" {
  run pre-commit --help
  assert_success
}

@test "ripgrep" {
  run rg --help
  assert_success
}

@test "skopeo" {
  run skopeo --help
  assert_success
}

@test "sops" {
  run sops --help
  assert_success
}

@test "stern" {
  run stern --help
  assert_success
}

@test "terraform" {
  run terraform --help
  assert_success
}

@test "terragrunt" {
  run terragrunt --help
  assert_success
}

@test "tflint" {
  run tflint --help
  assert_success
}

@test "tmux" {
  run tmux -V
  assert_success
}

@test "wget" {
  run wget --help
  assert_success
}

@test "yarn" {
  run yarn --help
  assert_success
}

@test "yq" {
  run yq --help
  assert_success
}

@test "zsh" {
  run zsh --help
  assert_success
}
