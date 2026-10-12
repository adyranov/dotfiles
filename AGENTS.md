# Repository Guidelines

## General

- **CRITICAL**: Treat these instructions as the primary source. Use search/shell only if details differ.
- **CRITICAL**: Update `README.md` only for user-facing behavior, setup, or documented command changes; keep it concise with clear overview and essential commands/paths, not internal details, tuning rationale, or exhaustive examples.
- **CRITICAL**: Never modify `AGENTS.md` or `home/private_dot_config/exact_agents/AGENTS.md` without first asking the user and getting explicit approval.
- Do not edit `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md`. Propose changes to `AGENTS.md` instead (and ask before applying them).
- All paths here are relative to the chezmoi source root. Do NOT prefix commands with `cd` or directory changes.
- Compound Engineering artifacts live under `.compound-engineering/artifacts/` (local, gitignored); consult `solutions/` there for past repo learnings before starting non-trivial work.

## Chezmoi & Project Structure

- **Docs**: Consult `https://www.chezmoi.io/`. Assume undocumented features are unsupported.
- **Data Schema**: Data merges `<domain>.base` -> `<domain>.os.<distro>` -> `<domain>.profile.<profile>`. Package definitions use `packages.base.<toolchain>`. Use `base/helpers/load-section` to read merged sections.
- **Template Layout**: `base/` contains shared partials; `os/<distro>/` contains distro-specific partials. Shared scripts live under `.chezmoiscripts/common/`.
- **Toolchains**: `core` is implicitly enabled and always on. Other toolchain labels select their package/data overlays.
- **Version Pinning**: Packages track the latest release; add `pin` only when absolutely necessary (a security-relevant or load-bearing behavior that must not drift, like `nono`'s seatbelt last-match-wins ordering). A necessary pin carries a comment in the package entry naming the dependency and is bumped with a host-terminal probe pass (run the pinned binary's probe commands outside the sandbox).
- **Home Mapping**: Source attributes such as `dot_`, `private_`, `exact_`, `executable_`, `modify_`, and `symlink_` map to chezmoi target states; prefer source attributes over raw files (for example, `private_` for mode 600 and `executable_` for mode 755). `.tmpl` files render through templates.
- **OS Support**: Supported distros: `darwin`, `ubuntu`, `fedora`, `archlinux`.
- **Generated Tests**: Bats specs originate in `home/private_dot_local/share/exact_dotfiles/exact_test/*.bats.tmpl`.

## AI Packages, Policy & Sandboxing

- **Toolchain Enablement**: The `ai` toolchain gates the nested `pi`, `opencode`, and `omp` agent toolchains. Controlled in `.chezmoi.yaml.tmpl`.
- **Two Enforcers**: nono is the hard host sandbox (filesystem, network, process) and DCG (destructive_command_guard) is the destructive-command prompt layer wired into every agent via chezmoi-managed hooks. nono hardens DCG: `DCG_*` environment is scrubbed, DCG's config/session stores are read-only in sandboxes, and agent writes to DCG hook files are denied. There are no in-agent permission layers.
- **Permission Data**: `home/.chezmoidata/base/ai/` holds every rule once; `filesystem.write/read/deny` tiers map to nono's `filesystem.allow/read/deny` (write → r+w `allow`; the profile `write` key stays an empty compatibility list), while `command_policies` and `network.allow_domain` are 1:1 with no key translation.
- **Command Axis**: nono denies a small hard core (git force-push, macOS keychain mutators, secret exports, global/`--remove` `chezmoi apply`); destructive-but-normal commands (`kubectl delete`, `tofu destroy`, package publishes) are gated by DCG packs, not nono. Mediation is PATH-shim based: a deliberate absolute-path exec bypasses the command core, with DCG's command-text analysis as the complement.
- **Filesystem Axis**: default-deny grants, deny-over-grant within custom rules, over non-excludable nono built-in deny groups (credentials, keychains, shell configs/history, browser data) that form the floor. On Linux, Landlock denies cover only paths existing at sandbox start (`capability_elevation` stays off).
- **Network Axis**: proxy-routed egress with domain allow-listing (`network.allow_domain`), kept to machine-necessary hosts; a blocked host is granted only by the user editing the network data and applying (audit-loop). Git is HTTPS-only; raw SSH egress is blocked.
- **Remediation**: a DCG block is approved by the user in their own terminal (`dcg allow …`); a blocked host or path goes through the user via a source edit plus apply. Sandboxed agents report denials and never self-approve or self-widen. Treat nono and DCG denials as security boundaries: if a path is denied, ask the user — do not bypass and do not retry via alternate write paths (`cp`, `mv`, `sed -i`, Python writes, temp-file swaps).
- **Launchers & Profiles**: nono profiles are managed at `~/.config/nono/profiles/` (one shared `base` plus one per agent: `opencode`, `pi`, `omp`), rendered from the permission data. The `agent` launcher (`~/.local/bin/agent`) is invoked as `agent pi|omp|oc` (`opencode` accepted as alias) and defaults to the `factory` profile. `--profile <name>` selects the profile for every agent, accepted before or after the agent word (positional profile words stay compat aliases; args after `--` reach the binary verbatim); omp keeps a single `default` configuration root, and its `--profile <name>` exports `OMP_PROFILE` so omp relocates its agent root to `<config-root>/profiles/<name>/agent`. `minimal` is the MCP/subagent-free tier — guards stay loaded in every profile. The launcher is a plain shell script (`home/private_dot_local/exact_bin/executable_agent`): each agent's profiles, config dirs, env exports, and scrub lists are explicit case blocks, and the zsh `_agent` completion plus the launcher's toolchain gates (`.chezmoiignore.tmpl`, `.chezmoiremove.tmpl`, `exact_completions/.chezmoiignore.tmpl`) list the agent toolchains literally; adding an agent means editing the launcher, the completion, and those three gates. Launchers accept `--no-sandbox` to skip the nono sandbox and disable DCG guards; debug only, zero enforcement. Custom DCG packs are per-tool files under `~/.config/dcg/packs/` gated by toolchain. Sandboxed git worktrees are project-local under `.slim/worktrees/`.
- **CRITICAL**: Agents must edit chezmoi source files only. Do not edit rendered files under `$HOME` to make tests pass.
- **Targeted apply**: positional `chezmoi apply <path>` runs in-sandbox for destinations on the apply allowlist (`[ai.permissions.apply]` in the permission data) — the allowlist *is* the write-grant set, rendered at destination-parent granularity by the seed. Global `chezmoi apply` dies at the filesystem boundary because the full-source walk opens destination dirs under protected roots (zsh, ssh) that no grant may cover — that is why only positional allowlisted applies work. Global applies, `chezmoi apply --force`, and `mise run apply` stay user-only. Security destinations (`~/.config/nono`, `~/.config/dcg`, DCG hook files), agent runtime configs, shell files, and `run_onchange` scripts stay user-applied in the terminal. Off-list destinations are reported by the agent and widened only by the user's data edit plus a terminal apply, landing on the next sandboxed session.

## Workflow, Commands & CI

- **Entry Point**: Use **mise tasks** (`mise run ...`).
- **Required change workflow**: change source files, write or update concise tests when behavior changes, run `mise run lint`, write the allowlisted destinations in-sandbox via positional `chezmoi apply <path>` (see Sandboxing/Targeted apply), then run relevant `mise run test ...` on the applied state — tests exercise applied/rendered infrastructure, so run them only after the user applies. Documentation-only changes do not require new tests; do not claim test coverage from source-only changes that were not applied.
- **Commands**:
  - `mise run apply --dry-run` — preview a global apply; do not use it as a substitute for targeted review.
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
- **CI**: GitHub Actions live under `.github/workflows/`. Update the `dorny/paths-filter` configuration in `.github/workflows/ci.yaml` when adding new top-level paths.
- **Secrets**: Keep out of repo. Use `.chezmoiignore` or `age` encryption (`.secrets.age`).

## Testing

Keep created tests concise and behavior-focused. Prefer a few high-value invariants or smoke tests over exhaustive assertions against generated configuration. Do not duplicate source data in tests or snapshot fields owned by upstream schemas unless guarding a specific regression.

- **Corner cases, not combinations:** test invariants and corner cases, never every combination of every parameter. Package install coverage is one aggregate smoke per manager suite that reports all offenders in a single pass; keep standalone per-package tests only for corner cases (architecture/manager routing, overlay selection, Brewfile rejections, render failures). Prefer one test that lists all offenders over N near-identical tests.
- **Timeouts are mandatory**: the runner hard-caps each suite at 120s wall clock with a 10s kill-after (`CHECK_DOTFILES_SUITE_TIMEOUT` overrides); a suite that overruns is a suite bug — keep aggregate probes bounded.
- **Single gate:** one fast gate, no live layer — `mise run test` runs every suite under the corner-cases-only + aggregate-smoke policy. The DCG robot probes (`ai-dcg` suite) are the enforcement-adjacent suite: probes fail (never skip) when the pinned binary or rendered packs are missing, and the suite is unapplied when the `ai` toolchain is off, so enforcement decay is red on any applied host.
- Validate locally (user terminal): `chezmoi doctor`, targeted `chezmoi diff <destination...>`, targeted `chezmoi apply --dry-run <destination...>`, `chezmoi verify`. Agents validate rendered output with `chezmoi execute-template -f <source>` / targeted `chezmoi cat <source>` (source-only, no protected-destination walk).
- Use `chezmoi --remove --dry-run apply` to preview removals enforced by `home/.chezmoiremove.tmpl`.

## Coding Style

- Use `.editorconfig` for formatting. Respect `.gitattributes` line endings.
- **TOML**: Alphabetize keys, use `lower_snake_case` for custom data keys. Entity identifiers (provider/model/package names such as `github-copilot`, `openai.default`) are *values*, not keys, and may be kebab-case or dotted. Package keys follow upstream naming (hyphens allowed). `pre-commit` enforces `toml-sort`, `taplo`, `yamlfmt`, `yamllint`, `markdownlint-cli2`, `editorconfig-checker`, `codespell`.
- **Shell**: Constants in `UPPER_SNAKE_CASE`, locals in `lower_snake_case`, functions in `lowerCamelCase`. Prefer standard utilities (`awk`, `sed`, `grep`, `curl`).
- **Chezmoi templates**: Prefer data-driven logic over Go template branching.

## Commits

- Use Conventional Commits. Squash incidental fix-ups before review.
- Scopes optional but encouraged: `fix(zsh): ...`, `chore(pre-commit): ...`.
- Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.
