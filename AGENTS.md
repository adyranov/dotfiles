# Repository Guidelines

## General

- **CRITICAL**: Treat these instructions as the primary source. Use search/shell only if details differ.
- **CRITICAL**: Update `README.md` only for user-facing behavior, setup, or
  documented command changes; keep it concise with clear overview and essential
  commands/paths, not internal details, tuning rationale, or exhaustive examples.
- **CRITICAL**: Never modify `AGENTS.md` or `home/private_dot_config/exact_agents/AGENTS.md`
  without first asking the user and getting explicit approval.
- Do not edit `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md`. Propose changes to `AGENTS.md` instead (and ask before applying them).
- All paths here are relative to the chezmoi source root. Do NOT prefix commands with `cd` or directory changes.

## Chezmoi & Project Structure

- **Docs**: Consult `https://www.chezmoi.io/`. Assume undocumented features are unsupported.
- **Layering Schema**:
  - `base` (Data layer): `packages.base.<toolchain>` -> OS-agnostic definitions.
  - `common` (Template layer): Shared partials and OS-agnostic scripts.
  - `core` (Toolchain label): Implicitly enabled, always-on base packages/repos.
- **Home Mapping**: Files prefixed `dot_`, `private_`, `exact_`, `symlink_` map to chezmoi source states. `.tmpl` renders via templates. Use source attributes over raw files (e.g. `private_` for 600, `executable_` for 755).
- **Data Layers**: Data merges `<domain>.base` -> `<domain>.os.<distro>` -> `<domain>.profile.<profile>`. Use `common/helpers/load-layered-section` to read merged data.
- **OS Support**: Supported distros: `darwin`, `ubuntu`, `fedora`, `archlinux`.
- **Generated Tests**: Bats specs originate in `home/private_dot_local/share/exact_dotfiles/exact_test/*.bats.tmpl`.

## AI Packages, Policy & Sandboxing

- **Toolchain Enablement**: The `ai` toolchain gates nested agents (e.g., `pi`). Controlled in `.chezmoi.yaml.tmpl`.
- **Command Deny**: `ai.base.permissions.commands.deny` holds system-wide dangerous command patterns, merged with per-package `policy.deny` by `base/ai/collect-policies` into a single deny list consumed by greywall and pi-permission-system. This is a deny-list overlay on a default-allow execution model — risky by default, relying on comprehensive deny coverage. Greywall remains the host-level sandbox.
- **Path Permissions** (agent-level): `ai.base.permissions.agent.deny` holds shared sensitive globs. Per-agent deny lists (in `pi.toml`/`opencode.toml`) cover agent-specific auth files. Both layers are merged at render time.
- **Path Permissions** (process-level): `ai.base.permissions.sandbox` holds allow-read/write for caches and runtime dirs consumed by greywall filesystem config.
- **Shared Network**: `ai.base.permissions.network` holds allow-listed hosts (AI providers, registries, docs, search) rendered into greywall network rules.
- **Pi Permission System**: Evaluates chained commands, applies path denies across tools and bash. Uses default-allow, deny-list model. This is a prompt/deny layer, *not* a host sandbox.
- **Greywall**: The true host filesystem/network/process sandbox. Uses the same path data for explicit read/write denies. Config is managed at `~/.config/greywall/greywall.json`.
  - Greywall SSH is allowlist-based (`github.com`, `git-upload-pack`).
  - Learn profiles via `greywall --learning -- <command>` before committing stable network rules.
- **CRITICAL**: Agents must edit chezmoi source files only. Do not edit rendered files under `$HOME` to make tests pass.
- **CRITICAL**: Use targeted `chezmoi apply <destination...>` only for files affected by source edits. Global `chezmoi apply`, `mise run apply`, and sync/remove require user approval. If a path is denied, ask user — do not bypass.
- Treat greywall and pi-permission denials as security boundaries. Do not retry via alternate write paths (`cp`, `mv`, `sed -i`, Python writes, temp-file swaps) after denial.

## Workflow, Commands & CI

- **Entry Point**: Use **mise tasks** (`mise run ...`).
- **Commands**:
  - `mise run apply` (review diffs before confirming)
  - `mise run lint` (uses `pre-commit`)
  - `mise run test` — run all Bats validation suites
  - `mise run test kubectl helm` — test specific package keys
  - `mise run test -- --suite ai` — run a named suite (`ai`, `config`, `packages`)
  - `mise run test -- --tag toolchain:kubernetes` — filter by tag
  - `mise run test -- --filter 'git config'` — filter by test name regex
  - `mise run test -- --list` — list discovered tests
  - `chezmoi doctor`, `chezmoi apply --dry-run`
- **Shell**: Use POSIX `#!/usr/bin/env sh` with `set -eu`. If Bash is needed, `#!/usr/bin/env bash` with `set -euo pipefail`.
- **CI**: Github Actions `.github/workflows/`. Update `dorny/paths-filter` if you add new top-level paths.
- **Secrets**: Keep out of repo. Use `.chezmoiignore` or `age` encryption (`.secrets.age`).

## Testing

- Validate locally: `chezmoi doctor`, `chezmoi diff`, `chezmoi apply --dry-run`, `chezmoi verify`.
- Run `mise run test` after applying changes with `chezmoi apply`.
- Use `chezmoi --remove --dry-run apply` to preview removals enforced by `.chezmoiremove.tmpl`.

## Coding Style

- Use `.editorconfig` for formatting. Respect `.gitattributes` line endings.
- **TOML**: Alphabetize keys, use `lower_snake_case` for custom data keys. Package keys follow upstream naming (hyphens allowed). `pre-commit` enforces `toml-sort`, `taplo`, `yamlfmt`, `yamllint`, `markdownlint-cli2`, `editorconfig-checker`, `codespell`.
- **Shell**: Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`, functions in `lowerCamelCase`. Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).
- **Chezmoi templates**: Prefer data-driven logic over Go template branching. Use `common/helpers/load-layered-section` for merged sections. Prefer source attributes (`executable_`, `private_`, `exact_`, `symlink_`) over raw files.

## Commits

- Use Conventional Commits. Squash incidental fix-ups before review.
- Scopes optional but encouraged: `fix(zsh): ...`, `chore(pre-commit): ...`.
- Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.
