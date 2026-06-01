# Repository Guidelines

## General Guidelines

- **CRITICAL**: Always treat these instructions as the primary source. Use search or shell commands only if you encounter details that don't align with this guidance.
- **CRITICAL**: After any major refactoring, or changes to scripts, packages, or tools, update `README.md` and/or `AGENTS.md` to reflect the new state.
- **CRITICAL**: Do NOT modify `home/private_dot_config/exact_agents/AGENTS.md` (the global agent config deployed to `~/.config/agents/AGENTS.md`) unless explicitly asked. That file is a concise, repository-agnostic system prompt — keep project-specific guidance here.
- Do not edit `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md` directly—these are copies of this file kept for legacy agent compatibility. Update `AGENTS.md` instead.
- This repository contains dotfiles for different command-line tools and is managed with [chezmoi](https://www.chezmoi.io).
- The chezmoi **user guide** is available at [https://www.chezmoi.io/user-guide/](https://www.chezmoi.io/user-guide/).
- The chezmoi **reference documentation** is available at [https://www.chezmoi.io/reference/](https://www.chezmoi.io/reference/).
- When working with chezmoi, consult the user guide and reference docs to understand valid commands, templates, and configuration options. If it is not included there, assume it is not supported.

## Project Structure & Module Organization

- Shared-vs-OS terminology — three nearby words intentionally name distinct layers and should not be conflated:
  - `base` is the **data** layer: `home/.chezmoidata/base/packages.toml` holds OS-agnostic package definitions (`packages.base.<toolchain>`) merged with `packages.os.<distro>.<toolchain>` from `home/.chezmoidata/os/<distro>/` and `packages.profile.<profile>.<toolchain>` from `home/.chezmoidata/profile/<profile>/`.
  - `common` is the **template / script** layer: `home/.chezmoitemplates/common/` (shared partials and helpers) and `home/.chezmoiscripts/common/` (after-phase scripts that run on every OS). The `before/`, `os/<distro>/`, and `post/` siblings under `home/.chezmoiscripts/` are also OS-agnostic except for `os/<distro>/`.
  - `core` is the **toolchain** label: the always-on toolchain bucket inside `packages.base.core` / `packages.os.<distro>.core` and `repositories.os.<distro>.core.*`. It is implicitly enabled and is intentionally absent from the user-selectable toolchain list in `home/.chezmoi.yaml.tmpl`.
- `home/` mirrors the eventual `$HOME`. Files and folders prefixed `dot_`, `private_`, or `exact_` map to chezmoi source states; `.tmpl` files render via templates.
- `home/.chezmoidata/**` uses the common layer schema `<domain>.<layer_axis>.<layer_value>...`: shared data uses `<domain>.base`, OS data uses `<domain>.os.<distro>`, and profile data uses `<domain>.profile.<profile>` (`personal` or `work`). Examples: `packages.base.core`, `packages.os.darwin.core`, `packages.profile.work.core`, `ai.base.pi.packages`, `ai.profile.personal.pi.routes`, `repositories.os.ubuntu.core`, `brew.profile.personal`, `editors.base.vscode`, and `editors.profile.work.vscode`.
- `home/.chezmoiscripts/` holds numbered `run_*` scripts under `before/` (decrypt, bootstrap/install dispatchers), `common/` (shared after-phase tooling), `os/<distro>/` (`.init.sh` pre-bootstrap hook; optional after-phase scripts such as macOS defaults), `toolchains/<id>/` (scripts gated by toolchain enablement), and `post/` (scripts that must run after `os/`, e.g. z4h bootstrap). `.chezmoiignore` limits scripts to `before/`, `common/`, `post/`, `os/{{ .host.distro.id }}/`, and conditionally `toolchains/<id>/` (only when the corresponding toolchain is enabled). Each `os/<distro>/.init.sh` is invoked via the `read-source-state` pre-hook in `home/.chezmoi.yaml.tmpl` and must only install tools needed before chezmoi can read source state (e.g. `rage`, Homebrew, COPRs). `home/.chezmoitemplates/` holds reusable partials under `common/` (headers, helpers) and `os/<distro>/` (`bootstrap`, `install` partials loaded by `before/run_onchange_before_{10,20}_*` via `common/helpers/load-os-partial`). A missing `bootstrap` or `install` partial is a no-op (`load-os-partial` checks with `stat`). Fedora `bootstrap` uses dnf5 `config-manager addrepo` (`--from-repofile` or `--set=baseurl`); `dnf5-plugins` must be present (installed in `os/fedora/.init.sh`).
- Per-tool external assets (e.g. themes) are fetched via `.chezmoiexternal.toml.tmpl` files placed in each tool's config directory. These use `refreshPeriod` (typically `"168h"`) to avoid re-downloading on every apply. Toolchain-gated externals wrap content in `{{- if .toolchains.<id> }}` guards.
- Generated Bats specs originate from `home/private_dot_local/share/exact_dotfiles/exact_test/*.bats.tmpl` (rendered to `~/.local/share/dotfiles/test/*.bats`).
- `home/dot_local/exact_bin/` ships helper links via chezmoi symlink source names (e.g., `symlink_check-dotfiles`), and `home/private_dot_config/shell/` contains shell exports and functions.
- `.mise.toml` defines the project's task orchestration.
- `.github/workflows/` contains CI workflows executed by GitHub Actions.
- `.github/renovate.json5` is a Renovate Bot configuration file.
- `containers/` houses Dockerfiles and local test tooling. Use `mise run build-containers` to build and test.

## Build, Test, and Development Commands

- Unified entry point: this project uses **mise tasks** for orchestration.
- `mise run apply`: applies changes to the home directory; review the diff before confirming.
- `mise run test`: executes generated Bats validation suites.
- `mise run lint`: runs formatting and safety validations for the `pre-commit` stage with `PRE_COMMIT_COLOR=never` so status labels stay readable in the configured terminal theme (uses global `pre-commit` managed by `mise`; commit messages are checked by the installed `commit-msg` hook).
- `mise run bootstrap`: configures local `pre-commit` and `commit-msg` Git hooks and ensures native tool versions.
- `mise run build-containers`: builds and tests local validation containers.
- `chezmoi doctor`: validates environment and configuration.

## CI Expectations

- Host workflow (`.github/workflows/ci-host.yaml`): runs `./install.sh` on a matrix (macOS/Ubuntu and Intel/ARM) and then `mise run test`.
- Docker workflow (`.github/workflows/ci-docker.yaml`): builds Arch Linux, Fedora, and Ubuntu images for `amd64` and `arm64`, runs the same dotfiles checks, and can publish images from main or on demand.
  - Manual publish: dispatch the workflow with the `publish` input set to `true`.
  - The workflow also generates SPDX SBOM artifacts for published image tags.
- Main CI workflow (`.github/workflows/ci.yaml`) includes a dedicated `pre-commit` job using `mise run lint`.
- WSL workflow (`.github/workflows/ci-wsl.yaml`): provisions Ubuntu 24.04 inside Windows runners, restores cached package directories (APT, mise, rustup, cargo, krew, helm), runs `./install.sh`, then executes `mise run test`.
- If you add new top-level paths, update the `dorny/paths-filter` filters in each workflow so CI triggers remain accurate.

## Coding Style & Naming Conventions

### General

- Use the .editorconfig file located in the repository root to maintain consistent formatting across all files.
- Respect `.gitattributes` enforced line endings (LF for Unix tooling, CRLF for Windows scripts); do not override these defaults.

### Chezmoi

- `home/.chezmoidata/**/*` alphabetize keys, keep names lower_snake_case, always define a `test` on entries in `packages.base` (a command or check used by templates/tests, e.g., `command -v tool` or `tool --version`). Express platform and profile differences via layered TOML (`packages.base` → `packages.os.<distro>` via `host.distro.id` → `packages.profile.<profile>` via `host.profile`), with toolchain sections such as `core` (always-on CLI), `docker`, `kubernetes`, `ai`, etc. Optional `os = "<distro>"` pinning on a package entry, and `disabled` flags like `headless`, `restricted`, `desktop`, `wsl`, `ephemeral`. Use profile package overrides such as `some-package = {disabled = true}` under `packages.profile.<profile>.<toolchain>` instead of profile-name disabled flags. Optional toolchains are listed in `.chezmoi.yaml.tmpl` (`$toolchains`, `$toolchainIcons`); `chezmoi init` writes `data.toolchains.<id>` booleans to `chezmoi.toml`. Restricted-mode behavior is host-specific and comes from `.host.restricted`. The `ai` toolchain is an umbrella that gates a nested agent selection (`$agents` list: `pi`); each agent gets its own boolean in `data.toolchains.<agentId>`. The `core` toolchain is always on and is not part of the selectable list. Layout: `base/packages.toml`, `base/ai.toml`, `base/editors.toml`, `os/<distro>/` (`packages.toml`, optional `repositories.toml` keyed by toolchain), and `profile/<profile>/` (`packages.toml`, optional `brew.toml`, or domain-specific data such as `ai.toml`). APT/DNF repos are nested as `repositories.os.<distro>.<toolchain>.<name>` and applied by `os/<distro>/bootstrap` only when that toolchain is enabled (`core` is always enabled). Homebrew profile data uses `brew.profile.<profile>` in `profile/<profile>/brew.toml`; CLI tools remain in `packages.os.darwin.*`.
- `home/.chezmoitemplates/**` reuse shared partials; prefer data-driven logic over Go template branching. Use `common/helpers/load-layered-section` with `section = "<domain>.<path>"` (for example, `editors.vscode` or `ai.pi`) to read merged sections from `<domain>.base`, `<domain>.os.<distro>`, and `<domain>.profile.<profile>` instead of duplicating lookup/merge logic in callers. Bats tests for packages are generated via `common/packages/render` (format templates under `common/packages/format/`); each test name matches the package key in `packages.toml`. GitHub asset helpers live in `common/github/` (`archive`, `latest-tag`, `raw`). Editor templates live in `editors/vscode/` (`settings.json`, `keybindings.json`).
- Prefer chezmoi source attributes for file state: use `executable_` prefixes for executables (755), `private_` for sensitive files (600), `exact_` to prune unmanaged files in a directory, and `symlink_` to create symlinks rather than committing literal symlink objects.
- Package keys may follow upstream naming (including hyphens) for clarity and parity with tests; apply lower_snake_case to custom data keys you introduce.
- TOML should be consistently ordered and linted; pre-commit enforces `toml-sort`, `taplo`, `yamlfmt`, `yamllint`, `markdownlint-cli2`, `editorconfig-checker`, `codespell`.
- The template data defines `host` fields used across templates and data:
  - Booleans: `.host.interactive`, `.host.restricted`
  - OS/arch/type: `.host.distro.id` (`darwin`, `ubuntu`, `fedora`, `archlinux`), `.host.arch`, `.host.type` (`desktop`, `laptop`, `wsl`, `ephemeral`)
- Supported OSes are `darwin`, `ubuntu`, `fedora`, and `archlinux`. Adding a new OS requires updating `home/.chezmoi.yaml.tmpl` (support check), `home/.chezmoidata/os/<distro>/`, `home/.chezmoiscripts/os/<distro>/.init.sh`, and `home/.chezmoitemplates/os/<distro>/`.

### Shell scripts

- Default to POSIX `#!/usr/bin/env sh`; use `set -eu`. If you need `pipefail` or other Bashisms, switch to `#!/usr/bin/env bash` and use `set -euo pipefail`.
- Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`; functions in `lowerCamelCase`.
- Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).

## Testing Guidelines

- Validate locally with `chezmoi doctor`, `chezmoi diff`, `chezmoi apply --dry-run`, and `chezmoi verify`. Only surface clean diffs for review.
- Ensure `mise run lint` passes.
- Run `~/.local/bin/check-dotfiles` after applying changes with `chezmoi apply`. The runner (`home/private_dot_local/share/exact_dotfiles/exact_test/executable_check-dotfiles.sh`, symlinked as `check-dotfiles`) executes generated Bats suites for system packages, `mise` tools, Helm/Krew plugins, AI agents/skills, plus `test-config.bats` for shell/Git settings.
- Run a single package test by package key (same id as in `packages.toml`): `check-dotfiles openssh-client`, or several at once: `check-dotfiles kubectl helm k9s` (package suites only; does not run `test-config.bats`).
- Run specific suites: `check-dotfiles --suite config` or `check-dotfiles --suite ai,skills`.
- Filter by tag: `check-dotfiles --tag toolchain:kubernetes` or `check-dotfiles --tag suite:ai,kind:permission`.
- Filter by test name regex: `check-dotfiles --filter '^skill .* frontmatter'`.
- List tests grouped by field: `check-dotfiles --list --by suite|toolchain|tag|kind`.
- Use `check-dotfiles --help` for full usage.
- Use `chezmoi --remove --dry-run apply` to preview removals enforced by `home/.chezmoiremove.tmpl` and avoid unintended deletions.

## Commit & Pull Request Guidelines

- Use Conventional Commits for commit subjects and squash incidental fix-ups before review.
- Scopes are optional but encouraged when they clarify the affected area, for example `fix(zsh): restore atuin up-arrow history` or `chore(pre-commit): add conventional commit hook`.
- Allowed commit types use the standard `conventional-pre-commit` defaults: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, and `test`.

## Security & Configuration Tips

- Keep secrets out of the repo; store host-specific values in `.chezmoiignore` or encrypt them with `age`.
- Ensure files have the correct permissions (755 for executables and 644 for configuration files). When handled by chezmoi, prefer `executable_` for executables and `private_` for secrets; see the [chezmoi documentation](https://www.chezmoi.io/reference/source-state-attributes/).
- Use `$TMPDIR` for scratch files. For secrets, use `0700` for directories and `0600` for files, and document required token scopes in accompanying docs.
- Age keys: when `.secrets.age` is enabled, the key at `home/.keys/key.txt.age` is decrypted to `~/.config/age/key.txt` during apply by a `run_onchange_before` script. Permissions are tightened to `0600`.
