# Repository Guidelines

## General

- **CRITICAL**: Follow these repository instructions and verify relevant behavior in source before editing.
- **CRITICAL**: Update `README.md` only for user-facing behavior, setup, or documented command changes; keep it concise with clear overview and essential commands/paths, not internal details, tuning rationale, or exhaustive examples.
- **CRITICAL**: Never modify `AGENTS.md`, `docs/agents/**`, or `home/private_dot_config/exact_agents/AGENTS.md` without first asking the user and getting explicit approval.
- Do not edit `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md` (symlinks to this file). Propose changes to `AGENTS.md` instead (and ask before applying them).
- All paths here are relative to the repository root. Do NOT prefix commands with `cd` or directory changes.
- See `ARCHITECTURE.md` for the repository directory map and apply pipeline.
- Compound Engineering artifacts live under `.compound-engineering/artifacts/` (local, gitignored); consult `solutions/` there for past repo learnings before starting non-trivial work.

## Read before editing

Topic rules live in `docs/agents/`. Read the matching file before touching these paths; the rules there are as binding as this file.

| Touching | Read |
|---|---|
| anything under `home/` (data, templates, scripts, attributes, packages) | `docs/agents/chezmoi.md` |
| AI agents, nono, DCG, skills, roles, MCPs, `executable_agent` | `docs/agents/ai-stack.md` |
| `tests/*.bats` tests, or validating a change | `docs/agents/testing.md` |

## Editing and applying

- **CRITICAL**: Agents must edit chezmoi source files only. Do not edit rendered files under `$HOME` to make tests pass.
- **User-applied changes**: Agents edit chezmoi source and report the destinations to review. The user applies home changes in their own terminal, including positional and global `chezmoi apply`, `mise run apply`, security destinations, agent runtime configs, shell files, and `run_onchange` scripts.
- **Required change workflow**: change source files and write or update concise tests when behavior changes. Review agent edits to this repo with `git diff` before running `chezmoi diff` or `mise run lint` (both render templates on the host), then apply relevant destinations in your terminal and run `mise run test ...` on the applied state; `tests/render.bats` renders from source and can run before applying, while the other suites check the applied state. Documentation-only changes do not require new tests; do not claim test coverage from source-only changes that were not applied.

## Commands

Use **mise tasks** (`mise run ...`).

- `mise run apply --dry-run` — preview a global apply; do not use it as a substitute for targeted review.
- `mise run apply` — perform a global apply; requires explicit user approval.
- `mise run lint` (uses `prek`)
- `mise run test` — run all Bats validation suites (filters in `docs/agents/testing.md`)
- `mise run update` — upgrade packages, `mise` tools, and `nono` packs (decoupled from `chezmoi apply`)
- `chezmoi doctor`, `chezmoi apply --dry-run`

## Coding Style

- Use `.editorconfig` for formatting. Respect `.gitattributes` line endings. `prek` enforces `toml-sort`, `check-toml`, `yamlfmt`, `yamllint`, `markdownlint-cli2`, `editorconfig-checker`, `typos`.
- **Comments**: Keep comments concise; explain non-obvious constraints or why, not what the code already says. Preserve required directives and API documentation.
- **Shell**: POSIX `#!/usr/bin/env sh` with `set -eu`; if Bash is needed, `#!/usr/bin/env bash` with `set -euo pipefail`. Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`, functions in `lowerCamelCase`. Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).
- **CI**: GitHub Actions live under `.github/workflows/`. Update the `dorny/paths-filter` configuration in `.github/workflows/ci.yaml` when adding new top-level paths that affect apply.
- **Secrets**: Keep out of repo. Use `.chezmoiignore` or `age` encryption (`.secrets.age`).

## Commits

- Use Conventional Commits. Squash incidental fix-ups before review.
- Scopes optional but encouraged: `fix(zsh): ...`, `chore(pre-commit): ...`.
- Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.
