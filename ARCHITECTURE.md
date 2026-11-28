# Architecture

Structural map of this [chezmoi](https://www.chezmoi.io/) repository (`home/` is the source root via `.chezmoiroot`). For authoring rules and policies, see [AGENTS.md](AGENTS.md) and `docs/agents/`.

## Directory Map

| Path | Responsibility |
| --- | --- |
| `home/.chezmoi.yaml.tmpl` | Interactive/headless host config (`host.*`, `toolchains.*`, `secrets.age`) |
| `home/.chezmoidata/` | Flat domain TOML (`ai/`, `brew.toml`, `editors.toml`, `repositories.toml`) and layered package catalogs (`base/packages/`, `os/<distro>/packages.toml`) |
| `home/.chezmoiexternals/` | Centralized external archives/repos (`fonts.toml.tmpl`, `themes.toml.tmpl`, `ai.toml.tmpl`) |
| `home/.chezmoitemplates/` | Shared partials: `base/packages/` selector DSL, `base/ai/parse-route`, `base/ai/roles/`, `base/ai/sandbox/render-profile`, `base/editors/vscode-settings`, `os/<distro>/install`, `os/<distro>/bootstrap` (not on Arch), `os/darwin/brewfile` |
| `home/.chezmoiscripts/` | Ordered scripts: `run_before_05_migrate-claude-dir.sh`, `before/` -> `common/` (incl. editor extensions) -> `os/<distro>/` -> `toolchains/`; `os/<distro>/.init.sh` is the read-source-state pre-hook |
| `home/private_dot_config/` | XDG configs (`zsh`, `tmux`, `git`, `nvim`, `claude`, `opencode`, `omp`, `pi`, `dcg`, `nono`, `local-llm`, `skypilot`, etc.) |
| `home/private_dot_local/exact_bin/` | User CLIs: `agent`, `llm-serve`, `llm-pull`, `llm-bench` |
| `.mise/tasks/` | Repo mise tasks (`build-containers`, `docs-tools`) |
| `tests/` | Repo-only Bats suites: `render.bats`, `packages.bats`, `ai.bats`, `config.bats` |
| `containers/` | Multi-arch Dockerfiles (`archlinux`, `fedora`, `ubuntu`) published by `ci-docker.yaml` |

## Apply Pipeline

```text
home/.chezmoi.yaml.tmpl      -> renders ~/.config/chezmoi/chezmoi.yaml
  |
  v
.chezmoiscripts/os/<distro>/.init.sh    -> read-source-state pre-hook
.chezmoiscripts/run_before_05_*         -> ~/.claude migration (claude toolchain)
  |
  v
.chezmoiscripts/before/      -> OS bootstrap (MacPorts/Homebrew/apt/dnf/pacman)
  |
  v
home/* (files & modify_*)    -> renders configs, symlinks, externals
  |
  v
.chezmoiscripts/common/      -> mise tools, helm plugins, bat cache, login shell
.chezmoiscripts/os/<distro>/ -> OS defaults, LaunchAgents, CA bundle
.chezmoiscripts/toolchains/  -> nono packs, omlx links, Java truststore
```

Gated paths are ignored via `home/.chezmoiignore.tmpl`; unconditionally retired paths are pruned via `home/.chezmoiremove.tmpl`.

## AI Stack Data Flow

- **Routing**: `home/.chezmoidata/ai/models.toml` defines ordered `"provider/model:thinking"` tier lists (`big`, `medium`, `oracle`, `small`, `visual`); `base/ai/parse-route` parses each spec for OpenCode, Pi, and Claude (OMP consumes the raw strings directly).
- **Roles**: `home/.chezmoidata/ai/roles.toml` + `base/ai/roles/*` render the shared roster (`orchestrator`, `explorer`, `oracle`, `fixer`, `designer`) into each harness's native format.
- **Guardrails**: `home/private_dot_config/exact_dcg/guard-core.mjs` is the shared DCG evaluator (command + write-axis floors across all 4 harnesses inside read-only `~/.config/dcg/`); `nono/exact_profiles/<agent>.json.tmpl` extends upstream `nolabs-ai/<agent>` packs with `ai/sandbox.toml` overlays.
- **Local LLM**: `local-llm/config.json.tmpl` selects the serving engine by platform (`omlx` on Apple Silicon, `llamacpp` elsewhere) for static `llm-serve`, `llm-pull`, and `llm-bench` via `jq`.

## Testing & CI

| Suite | Scope |
| --- | --- |
| `tests/render.bats` | TOML syntax, non-interactive init, AI cross-refs, personal/work renders, `modify_` merges, render matrix (OS/arch/profile), gopls gating, Colima, nono profiles & OAuth/write-protection invariants |
| `tests/packages.bats` | Applied `mise` tools, aggregate CLI smoke, Intel MacPorts vs ARM Homebrew routing & Brewfile guardrails |
| `tests/ai.bats` | Shared symlinks, DCG hooks & write-axis floors, `agent` launcher, live `nono` sandbox |
| `tests/config.bats` | XDG dirs, git core defaults, POSIX/Zsh syntax checks, `chezmoi data` |

GitHub Actions run `ci.yaml` (path-filtered PR/main gate dispatching `ci-host`/`ci-docker`), `lint.yaml` (`prek` + template rendering), `ci-host.yaml` (Ubuntu + macOS smoke/full), `ci-docker.yaml` (Arch/Fedora/Ubuntu Bats `docker-test` gating multi-arch image builds), `ci-wsl.yaml` (Ubuntu WSL), `ci-regression.yaml` (weekly full lane), and `security-scan.yaml` (Trivy on `main`).
