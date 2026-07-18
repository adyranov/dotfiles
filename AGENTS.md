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
- **Data Schema**: Data merges `<domain>.base` -> `<domain>.os.<distro>` ->
  `<domain>.profile.<profile>`. Package definitions use
  `packages.base.<toolchain>`. Use `base/helpers/load-section` to read merged
  sections.
- **Template Layout**: `base/` contains shared partials; `os/<distro>/`
  contains distro-specific partials. Shared scripts live under
  `.chezmoiscripts/common/`.
- **Toolchains**: `core` is implicitly enabled and always on. Other toolchain
  labels select their package/data overlays.
- **Home Mapping**: Source attributes such as `dot_`, `private_`, `exact_`,
  `executable_`, `modify_`, and `symlink_` map to chezmoi target states.
  `.tmpl` files render through templates. Prefer source attributes over raw
  files (for example, `private_` for mode 600 and `executable_` for mode 755).
- **OS Support**: Supported distros: `darwin`, `ubuntu`, `fedora`, `archlinux`.
- **Generated Tests**: Bats specs originate in `home/private_dot_local/share/exact_dotfiles/exact_test/*.bats.tmpl`.

## AI Packages, Policy & Sandboxing

- **Toolchain Enablement**: The `ai` toolchain gates the nested `pi`,
  `opencode`, and `omp` agent toolchains. Controlled in `.chezmoi.yaml.tmpl`.
- **Command Deny**: `ai.base.permissions.commands.deny` holds system-wide dangerous command patterns, merged with per-package `policy.deny` by `base/ai/security/collect-policies` into a single deny list consumed by greywall and pi-permission-system. This is a deny-list overlay on a default-allow execution model — risky by default, relying on comprehensive deny coverage. Greywall remains the host-level sandbox.
- **Path Permissions** (agent-level): `ai.base.permissions.agent.deny` holds shared sensitive globs. Per-agent deny lists under `home/.chezmoidata/base/ai/agents/` cover agent-specific auth files. Both layers are merged at render time.
- **Path Permissions** (process-level): `ai.base.permissions.sandbox` holds allow-read/write for caches and runtime dirs consumed by greywall filesystem config.
- **Shared Network**: `ai.base.permissions.network` holds allow-listed hosts (AI providers, registries, docs, search) rendered into greywall network rules.
- **Pi Permission System**: Evaluates chained commands, applies path denies across tools and bash. Uses default-allow, deny-list model. This is a prompt/deny layer, *not* a host sandbox.
- **Greywall**: The true host filesystem/network/process sandbox. Uses the same path data for explicit read/write denies. Config is managed at `~/.config/greywall/greywall.json`.
  - Greywall SSH is allowlist-based (`github.com`, `git-upload-pack`).
  - Learn profiles via `greywall --learning -- <command>` before committing stable network rules.
- **CRITICAL**: Agents must edit chezmoi source files only. Do not edit rendered files under `$HOME` to make tests pass.
- **CRITICAL**: Use targeted `chezmoi apply <destination...>` only for destinations affected by source edits. Agents have approval to run targeted apply before tests; never substitute global `chezmoi apply`, `mise run apply`, sync, or remove unless the user explicitly approves that broader operation. If a path is denied, ask user — do not bypass.
- Treat greywall and pi-permission denials as security boundaries. Do not retry via alternate write paths (`cp`, `mv`, `sed -i`, Python writes, temp-file swaps) after denial.

## Workflow, Commands & CI

- **Entry Point**: Use **mise tasks** (`mise run ...`).
- **Required change workflow**: change source files, write or update concise
  tests when behavior changes, run `mise run lint`, run targeted
  `chezmoi apply <destination...>` for affected rendered files, then run
  relevant `mise run test ...`. Documentation-only changes do not require new
  tests. Tests validate applied/rendered infrastructure; do not claim test
  coverage from source-only changes that were not applied.
- **Commands**:
  - `mise run apply --dry-run` — preview a global apply; do not use it as a
    substitute for targeted review.
  - `mise run apply` — perform a global apply; requires explicit user approval.
  - `mise run lint` (uses `pre-commit`)
  - `mise run test` — run all Bats validation suites
  - `mise run test kubectl helm` — test specific package keys
  - `mise run test -- --suite ai` — run a named suite (`ai`, `config`, `packages`)
  - `mise run test -- --tag toolchain:kubernetes` — filter by tag
  - `mise run test -- --filter 'git config'` — filter by test name regex
  - `mise run test -- --list` — list discovered tests
  - `chezmoi doctor`, `chezmoi apply --dry-run`
- **Shell**: Use POSIX `#!/usr/bin/env sh` with `set -eu`. If Bash is needed, `#!/usr/bin/env bash` with `set -euo pipefail`.
- **CI**: GitHub Actions live under `.github/workflows/`. Update the
  `dorny/paths-filter` configuration in `.github/workflows/ci.yaml` when adding
  new top-level paths.
- **Secrets**: Keep out of repo. Use `.chezmoiignore` or `age` encryption (`.secrets.age`).

## Testing

Keep created tests concise and behavior-focused. Prefer a few high-value invariants or smoke tests over exhaustive assertions against generated configuration. Do not duplicate source data in tests or snapshot fields owned by upstream schemas unless guarding a specific regression.

- Validate locally: `chezmoi doctor`, targeted `chezmoi diff <destination...>`, targeted `chezmoi apply --dry-run <destination...>`, `chezmoi verify`.
- Run `mise run lint` before applying changed destinations.
- Run targeted `chezmoi apply <destination...>` for affected rendered files before tests. Do not run global apply without explicit user approval.
- Run relevant `mise run test ...` only after targeted apply, because tests exercise applied/rendered infrastructure.
- Use `chezmoi --remove --dry-run apply` to preview removals enforced by
  `home/.chezmoiremove.tmpl`.

## Coding Style

- Use `.editorconfig` for formatting. Respect `.gitattributes` line endings.
- **TOML**: Alphabetize keys, use `lower_snake_case` for custom data keys. Package keys follow upstream naming (hyphens allowed). `pre-commit` enforces `toml-sort`, `taplo`, `yamlfmt`, `yamllint`, `markdownlint-cli2`, `editorconfig-checker`, `codespell`.
- **Shell**: Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`, functions in `lowerCamelCase`. Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).
- **Chezmoi templates**: Prefer data-driven logic over Go template branching.
  Use `base/helpers/load-section` for merged sections. Prefer source attributes
  (`executable_`, `private_`, `exact_`, `modify_`, `symlink_`) over raw files.

## Commits

- Use Conventional Commits. Squash incidental fix-ups before review.
- Scopes optional but encouraged: `fix(zsh): ...`, `chore(pre-commit): ...`.
- Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.
