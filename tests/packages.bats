#!/usr/bin/env bats
# bats file_tags=suite:packages

load 'helper'

@test "mise doctor reports a healthy installation" {
  command -v mise >/dev/null 2>&1 || skip "mise not installed"
  [ -f "$HOME/.config/mise/mise.toml" ] || skip "mise.toml not applied"
  run mise doctor
  [ "$status" -eq 0 ] || fail "mise doctor failed: $output"
}

@test "aggregate install smoke: enabled system, mise, and helm packages are runnable" {
  local offenders="" key cmd list_file="$BATS_TEST_TMPDIR/packages.tsv"
  chezmoi --source "$REPO_ROOT" execute-template >"$list_file" <<'TMPL'
{{- range $entry := includeTemplate "base/packages/walk" (dict "root" .) | mustFromJson -}}
{{-   $pkg := $entry.pkg -}}
{{-   $bin := printf "%s" (index $pkg "bin" | default $entry.id) -}}
{{-   $ver := printf "%s --version" $bin -}}
{{-   if hasKey $pkg "version" -}}{{- $ver = printf "%s" (index $pkg "version") -}}{{- end -}}
{{-   $test := $ver -}}
{{-   if hasKey $pkg "test" -}}
{{-     $raw := index $pkg "test" -}}
{{-     if kindIs "bool" $raw -}}{{- if not $raw -}}{{- $test = "" -}}{{- end -}}{{- else -}}{{- $test = printf "%s" $raw -}}{{- end -}}
{{-   end -}}
{{-   if $test }}
{{ $entry.id }}	{{ $test }}
{{-   end -}}
{{- end -}}
TMPL
  while IFS=$'\t' read -r key cmd; do
    [ -n "$key" ] || continue
    if ! bash -c "$cmd" >/dev/null 2>&1 </dev/null; then
      offenders="$offenders $key"
    fi
  done <"$list_file"
  [ -z "$offenders" ] || fail "packages failed install smoke:$offenders"
}

@test "darwin package routing separates Intel MacPorts from ARM Homebrew" {
  local intel arm
  intel="$BATS_TEST_TMPDIR/intel.brew"
  arm="$BATS_TEST_TMPDIR/arm.brew"

  chezmoi --source "$REPO_ROOT" execute-template \
    --override-data '{"host":{"arch":"amd64","distro":{"family":"darwin","id":"darwin"},"interactive":true,"profile":"personal","restricted":false,"type":"desktop"},"toolchains":{"cloud":true}}' \
    -f "$REPO_ROOT/home/private_dot_config/exact_brew/Brewfile.tmpl" >"$intel"
  grep -Fq 'tap "adyranov/tap"' "$intel" || fail "Intel Brewfile missing adyranov/tap"
  ! grep -Fq 'cask "azure-cli"' "$intel" || fail "Intel Brewfile must not emit arm64-only azure-cli cask"

  chezmoi --source "$REPO_ROOT" execute-template \
    --override-data '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"interactive":true,"profile":"personal","restricted":false,"type":"laptop"},"toolchains":{"cloud":true}}' \
    -f "$REPO_ROOT/home/private_dot_config/exact_brew/Brewfile.tmpl" >"$arm"
  grep -Fq 'cask "azure-cli"' "$arm" || fail "ARM Brewfile missing azure-cli cask"
}

@test "Intel Brewfile rejects disallowed Homebrew formulae" {
  run chezmoi --source "$REPO_ROOT" execute-template <<'TMPL'
{{- $root := dict "host" (dict "distro" (dict "id" "darwin" "family" "darwin") "arch" "amd64" "interactive" true "restricted" false "type" "desktop" "profile" "personal") "toolchains" (dict) "packages" (dict "base" (dict "core" (dict "bad-formula" (dict "manager" "brew"))) "os" (dict) "profile" (dict)) "brew" (dict) -}}
{{- includeTemplate "os/darwin/brewfile" $root -}}
TMPL
  [ "$status" -ne 0 ] || fail "expected Intel Brewfile to reject disallowed formula"
  [[ "$output" == *"Intel macOS cannot install Homebrew formulae: bad-formula"* ]] \
    || fail "unexpected Intel Brewfile failure output: $output"
}
