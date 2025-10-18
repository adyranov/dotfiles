# Repository Guidelines

## General Guidelines

- **CRITICAL**: Always treat these instructions as the primary source. Use search or shell commands only if you encounter details that don’t align with this guidance.
- Do not edit `.clinerules`, `.cursor/rules`, `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md` directly—these are symlinks to this file. Update `AGENTS.md` instead.
- This repository contains dotfiles for different command-line tools and is managed with [chezmoi](https://www.chezmoi.io).
- The chezmoi **user guide** is available at [https://www.chezmoi.io/user-guide/](https://www.chezmoi.io/user-guide/).
- The chezmoi **reference documentation** is available at [https://www.chezmoi.io/reference/](https://www.chezmoi.io/reference/).
- When working with chezmoi, consult the user guide and reference docs to understand valid commands, templates, and configuration options. If it is not included there, assume it is not supported.

## Project Structure & Module Organization

- `home/` mirrors the eventual `$HOME`. Files and folders prefixed `dot_`, `private_`, or `exact_` map to chezmoi source states; `.tmpl` files render via templates.
- `home/.chezmoidata/universal/packages.universal.toml` is the source of truth for tools. Add overrides under `home/.chezmoidata/{darwin,fedora,ubuntu,archlinux}` rather than branching templates.
- `home/.chezmoitemplates/` houses reusable templates.
- Generated Bats specs originate from `home/dot_local/share/dotfiles/exact_test/`.
- `home/dot_local/exact_bin/` ships helper links via chezmoi symlink source names (e.g., `symlink_check-dotfiles`), and `home/private_dot_config/shell/` contains shell exports and functions.
- `.github/workflows/` contains CI workflows executed by GitHub Actions
- `.github/renovate.json5` is a Renovate Bot configuration file.
- `containers/` houses Dockerfiles and local test tooling. Use `scripts/build-containers.sh` to build and test.

## Build, Test, and Development Commands

- `chezmoi doctor` validates environment and configuration.
- `chezmoi diff` shows a preview of changes to the home directory; review this before committing updates.
- `chezmoi apply --dry-run` checks template rendering without modifying files.
- `chezmoi apply` applies changes for real; only run after confirming the diff.
- `scripts/setup-pre-commit.sh` bootstraps the repo-local virtualenv and installs the `pre-commit` hook; rerun after dependency updates.
- `pre-commit run --all-files` runs formatting and safety validations (config: `.pre-commit-config.yaml`).

## CI Expectations

- Host workflow (`.github/workflows/ci-host.yaml`): runs `./install.sh` on a matrix (macOS/Ubuntu and Intel/ARM) and then `~/.local/bin/check-dotfiles`.
- Docker workflow (`.github/workflows/ci-docker.yaml`): builds Arch Linux, Fedora, and Ubuntu images for `amd64` and `arm64`, runs the same dotfiles checks, and can publish images from main or on demand.
  - Manual publish: dispatch the workflow with the `publish-image` input set to `true`.
- WSL workflow (`.github/workflows/ci-wsl.yaml`): provisions Ubuntu 24.04 inside Windows runners, restores cached package directories (APT, mise, rustup, cargo, krew, helm), runs `./install.sh`, then executes `~/.local/bin/check-dotfiles`.
- If you add new top-level paths, update the `dorny/paths-filter` filters in each workflow so CI triggers remain accurate.

## Coding Style & Naming Conventions

### General

- Use the .editorconfig file located in the repository root to maintain consistent formatting across all files.
- Respect `.gitattributes` enforced line endings (LF for Unix tooling, CRLF for Windows scripts); do not override these defaults.

### Chezmoi

- `home/.chezmoidata/**/*` alphabetize keys, keep names lower_snake_case, always define a `test` (a command or check used by templates/tests, e.g., `command -v tool` or `tool --version`), and express platform differences via `overrides.<os>`, `os =`, or `disabled` flags like `headless`, `restricted`, `desktop`, `wsl`, `ephemeral`. Include concrete overrides (e.g., `overrides.darwin.enabled = true`, `overrides.ubuntu.enabled = false`) and place OS-specific data under `home/.chezmoidata/{darwin,fedora,ubuntu,archlinux}`.
- `home/.chezmoitemplates/**/*` reuse shared partials, prefer data-driven logic over Go template branching.
- Prefer chezmoi source attributes for file state: use `executable_` prefixes for executables (755), `private_` for sensitive files (600), `exact_` to prune unmanaged files in a directory, and `symlink_` to create symlinks rather than committing literal symlink objects.
- Package keys may follow upstream naming (including hyphens) for clarity and parity with tests; apply lower_snake_case to custom data keys you introduce.
- TOML should be consistently ordered and linted; pre-commit enforces `toml-sort`, `yamlfmt`, `yamllint`, `editorconfig-checker`, `codespell`.
- The template data defines `host` fields used across templates and data:
  - Booleans: `.host.work`, `.host.restricted`, `.host.interactive`
  - OS/arch/type: `.host.distro.id` (`darwin`, `ubuntu`, `fedora`, `archlinux`), `.host.arch`, `.host.type` (`desktop`, `laptop`, `wsl`, `ephemeral`)
- Supported OSes are `darwin`, `ubuntu`, `fedora`, and `archlinux`. Adding a new OS requires updating `home/.chezmoi.yaml.tmpl` (support check), `home/.chezmoidata/<os>`, and `home/.chezmoiscripts/<os>`.

### Shell scripts

- Default to POSIX `#!/usr/bin/env sh`; use `set -eu`. If you need `pipefail` or other Bashisms, switch to `#!/usr/bin/env bash` and use `set -euo pipefail`.
- Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`; functions in `lowerCamelCase`.
- Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).

## Testing Guidelines

- Validate locally with `chezmoi doctor`, `chezmoi diff`, `chezmoi apply --dry-run`, and `chezmoi verify`. Only surface clean diffs for review.
- Ensure `pre-commit run --all-files` passes.
- Run `~/.local/bin/check-dotfiles` after applying changes with `chezmoi apply`
- Use `chezmoi --remove --dry-run apply` to preview removals enforced by `home/.chezmoiremove.tmpl` and avoid unintended deletions.

## Commit & Pull Request Guidelines

- Use imperative, scope-aware commit subjects and squash incidental fix-ups before review.

## Security & Configuration Tips

- Keep secrets out of the repo; store host-specific values in `.chezmoiignore` or encrypt them with `age`.
- Ensure files have the correct permissions (755 for executables and 644 for configuration files). When handled by chezmoi, prefer `executable_` for executables and `private_` for secrets; see the [chezmoi documentation](https://www.chezmoi.io/reference/source-state-attributes/).
- Use `$TMPDIR` for scratch files. For secrets, use `0700` for directories and `0600` for files, and document required token scopes in accompanying docs.
- Age keys: when `.secrets.age` is enabled, the key at `home/.keys/key.txt.age` is decrypted to `~/.config/age/key.txt` during apply by a `run_onchange_before` script. Permissions are tightened to `0600`.
