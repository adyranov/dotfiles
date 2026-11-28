# Dotfiles Toolkit

Opinionated macOS, Ubuntu, Fedora, Arch Linux, and WSL dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Quick Start

- **Bootstrap**: `curl -fsLS https://raw.githubusercontent.com/adyranov/dotfiles/main/install.sh | sh`
- **Existing chezmoi**: `chezmoi init --apply https://github.com/adyranov/dotfiles`
- **Preview changes**: `mise run apply --dry-run` or `chezmoi diff`
- **Apply**: `mise run apply` (also prunes retired targets)
- **Upgrade packages & tools**: `mise run update`
- **Lint & test**: `mise run lint` and `mise run test`

### Try in Docker

Prebuilt multi-arch images are published to GHCR and Docker Hub:

- **GHCR**: `docker run --rm -it -e TERM -e COLORTERM ghcr.io/adyranov/dotfiles:<ubuntu|fedora|archlinux>`
- **Docker Hub**: `docker run --rm -it -e TERM -e COLORTERM adyranov/dotfiles:<ubuntu|fedora|archlinux>`

### Windows / WSL

1. Install Ubuntu 24.04 (PowerShell as Admin): `wsl --install -d Ubuntu-24.04`
2. Inside WSL: `sudo apt update && sudo apt install -y curl git zsh`
3. Clone and apply: `git clone https://github.com/adyranov/dotfiles && cd dotfiles && ./install.sh`
4. Validate: `mise run test`

## Configuration & Toolchains

`chezmoi init` auto-detects the host OS/arch/type (`laptop`/`desktop` on macOS; `wsl`, `ephemeral`, or the `hostnamectl` chassis such as `vm` or `server` on Linux) and prompts for profile (`personal` / `work`), identity, and optional toolchains:

| Toolchain | Scope |
| --- | --- |
| `ai` | Shared AI routing, skills, nono/DCG guardrails, local LLM tools, SkyPilot (Lambda, RunPod, Vast) |
| `claude`, `omp`, `opencode`, `pi` | Individual AI coding harnesses (nested under `ai`) |
| `cloud`, `docker`, `iac`, `kubernetes` | Cloud CLIs, Docker/Colima, OpenTofu/Terragrunt/sops, kubectl/helm/k9s (macOS Colima runs built-in k3s with Traefik) |
| `golang`, `java`, `node`, `python`, `rust` | Language runtimes and tooling via `mise` |
| `extra` | Optional desktop/media/utility packages |

Setup notes:

- Requires chezmoi 2.73.0 or newer (`.chezmoiversion`).
- Non-interactive runs enable all toolchains and agents. Control them with `WITH_<NAME>=1`, `WITHOUT_<NAME>=1`, or `WITHOUT_TOOLCHAINS=1` (for example `WITHOUT_RUST=1`).
- Some toolchains pull in others: `kubernetes` enables `docker`, `ai` enables `node` and `python`, and any agent enables `ai`.
- The "Restricted Environment" prompt marks hosts without sudo or installer access.
- Intel macOS uses MacPorts; install it first on non-interactive or restricted hosts.
- An existing Colima VM must be recreated (`colima delete && colima start`) to pick up Colima template changes.

Declarative data lives in flat TOML files under `home/.chezmoidata/`:

- `ai/models.toml` — providers, serving endpoints (`local`, `infer01`), and ordered `"provider/model:thinking"` presets
- `ai/roles.toml` — shared orchestrator + worker roster (`explorer`, `oracle`, `fixer`, `designer`)
- `ai/mcp.toml`, `ai/libraries.toml`, `ai/sandbox.toml`, `ai/agents/*.toml` — MCP servers, skills, nono overlays, per-harness settings
- `brew.toml`, `editors.toml`, `repositories.toml`, `base/packages/*.toml` — packages, editor extensions, and Linux APT/DNF repos

## AI Coding Stack

Launch any enabled harness through the unified sandboxed wrapper:

```sh
agent claude   # alias: agent cc  (Claude Code; ~/.config/claude)
agent oc       # alias: agent opencode (OpenCode + Slim; ~/.config/opencode)
agent omp      # oh-my-pi; ~/.config/omp/agent
agent pi       # Pi; ~/.config/pi/agent
```

- **Sandboxing**: `agent <harness>` runs interactive sessions under **nono**. On macOS, every Claude Code session not launched via `agent` (including terminal `claude`) uses Claude's built-in sandbox, which still allows unsandboxed commands, so it is weaker containment than nono. Linux containers (`host.type == "ephemeral"`) rely on the container itself.
- **Launcher limits**: `agent` refuses `$HOME`, `/`, and paths outside a git worktree. `--no-sandbox` keeps DCG but passes real credentials. `agent claude -w [name]` opens a native worktree.
- **Agent keys**: DeepSeek, OpenRouter, OpenCode (Zen/Go), Brave Search, and GitHub keys are plain env vars inherited by `agent` (the wrapper never loads secrets). Suggested layout: `~/src/.envrc` for LLM/Brave keys (agent-only, spend-capped) and `~/src/<org>/.envrc` with `source_up` plus a fine-grained per-org `GITHUB_TOKEN` (90-day expiry, no admin/secrets/gists); keep secrets out of repo-level `.envrc`. Orca/T3 must pass these vars from their own config or start from a direnv-loaded shell. nono strips them and agents see phantoms.
- **Destructive-command guard**: **DCG** (`dcg`) guards commands and file writes in all 4 harnesses. Approve exceptions with `dcg allow <rule> --reason …`.
- **Shared contract**: `~/.config/agents/AGENTS.md`, `~/.config/agents/skills/`, `roles.toml`, and `mcp.toml` stay uniform across all 4 harnesses (see [docs/pi-parity.md](docs/pi-parity.md)). Subscription Opus runs only in Claude Code.
- **Claude migration**: with the `claude` toolchain on, apply moves `~/.claude` into `~/.config/claude` (state to `~/.local/state/claude`, plugins to `~/.local/share/claude/plugins`) and leaves `~/.claude` as a symlink. It aborts if `~/.claude/skills` or `~/.claude/CLAUDE.md` (or the `~/.config/claude` equivalents) are real files.
- **Engram memory daemon**: supervised automatically on agent launches (`ENGRAM_PORT`, default `7437`).

## Local & Cloud Inference

- **`llm-serve [start|stop|restart|status|list|logs]`** — local OpenAI-compatible gateway on `127.0.0.1:8321` (`llamacpp` or `omlx`), reading `~/.config/local-llm/config.json`.
- **`llm-pull`** — downloads configured HuggingFace weights and reports stale GGUF caches.
- **`llm-bench [model ...]`** — native `llama-bench` / `mlx_lm` throughput benchmarks.
- **`skyl [--job] <category/task> [flags]`** — launches static SkyPilot task YAMLs from `~/.config/skypilot/` (`--job` runs a managed job). Clouds: Lambda, RunPod, Vast; credentials via `uvx runpod config`, `VAST_AI_ACCOUNT_KEY`/`VAST_AI_API_KEY`, `LAMBDA_CLOUD_API_KEY`.

## Development & Architecture

- See [ARCHITECTURE.md](ARCHITECTURE.md) for the repository layout, apply pipeline, and test suite structure.
- Common tasks (`.mise.toml`): `mise run bootstrap`, `mise run lint`, `mise run test`, `mise run apply`, `mise run update`.
- Run targeted tests: `mise run test -- tests/render.bats` or `mise run test -- --filter-tags suite:ai`.

## 🧰 Toolchains & Tools

Inventory of user-facing tools per toolchain, casks, and App Store apps. Generated from `home/.chezmoidata` by `mise run docs-tools`; do not edit by hand. Assumes an interactive, unrestricted desktop host on the personal profile with all toolchains enabled.

<!-- tools:start -->

Install Manager Legend:

- `system`: the native manager — `brew` on Apple Silicon macOS, `macports` on Intel macOS, `apt`/`dnf`/`pacman` on Ubuntu/Fedora/Arch.
- `cask`: Homebrew cask.
- `mise ✅`: installed by mise. Parentheses list platforms whose manager differs from the primary.
- `helm`: Helm plugin; `external`: installed by bootstrap outside a package manager.
- `✅` = installed on all architectures; `❌` = not installed on that OS; `❌ (arch)` = missing on that architecture. Library and service probes are omitted.

### 🛠 Common CLI

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey) | YubiKey plugin for age encryption | `mise ✅` (macOS Intel: `macports`) | ✅ | ❌ | ❌ | ❌ |
| [ast-grep](https://ast-grep.github.io) | Structural code search and rewrite | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [atuin](https://github.com/atuinsh/atuin) | Shell history sync and search | `mise ✅` (macOS Intel: `macports`; Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [bat](https://github.com/sharkdp/bat) | Syntax-aware pager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [btop](https://github.com/aristocratos/btop) | Resource monitor | `mise ✅` (macOS: `system`) | ✅ | ✅ | ✅ | ✅ |
| [carapace](https://carapace.sh) | Multi-shell argument completer | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [chezmoi](https://www.chezmoi.io) | Dotfiles manager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [curl](https://curl.se) | HTTP transfer toolkit | `system` | ✅ | ✅ | ✅ | ✅ |
| [dcg](https://github.com/Dicklesworthstone/destructive_command_guard) | Destructive command guard | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [delta](https://github.com/dandavison/delta) | Git diff pager | `mise ✅` (macOS Intel: `macports`) | ✅ | ✅ | ✅ | ✅ |
| [difftastic](https://github.com/Wilfred/difftastic) | Structural diff tool | `mise ✅` (Fedora: `dnf`; Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [direnv](https://direnv.net) | Directory-aware env loader | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [doggo](https://github.com/mr-karan/doggo) | Modern DNS client | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [dust](https://github.com/bootandy/dust) | Disk usage viewer | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [fd](https://github.com/sharkdp/fd) | Fast find alternative | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Git](https://git-scm.com) | Distributed version control | `system` | ✅ | ✅ | ✅ | ✅ |
| [GitHub CLI](https://cli.github.com) | GitHub command-line client | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [glow](https://github.com/charmbracelet/glow) | Terminal markdown renderer | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [GNU Coreutils](https://www.gnu.org/software/coreutils) | GNU userland tools | `system` | ✅ | ✅ | ✅ | ✅ |
| [GnuPG](https://gnupg.org) | OpenPGP encryption toolkit | `system` | ✅ | ✅ | ✅ | ✅ |
| [hyperfine](https://github.com/sharkdp/hyperfine) | Command benchmarking | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [jnv](https://github.com/ynqa/jnv) | Interactive JSON viewer with jq | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [jq](https://jqlang.org) | JSON processor | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for Git | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [mas](https://github.com/mas-cli/mas) | Mac App Store CLI | `brew` | ✅ | ❌ | ❌ | ❌ |
| [mise](https://mise.jdx.dev) | Runtime and tool version manager | `external` | ✅ | ✅ | ✅ | ✅ |
| [mkcert](https://github.com/FiloSottile/mkcert) | Local TLS certificate generator | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [Neovim](https://neovim.io) | Modal code editor | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [nono](https://github.com/nolabs-ai/nono) | Filesystem, network and process sandbox | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [OpenSSH](https://www.openssh.com) | SSH client and agent | `system` | ✅ | ✅ | ✅ | ✅ |
| [ouch](https://github.com/ouch-org/ouch) | Painless compression | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [pinentry-mac](https://github.com/GPGTools/pinentry) | GnuPG passphrase prompt for macOS | `system` | ✅ | ❌ | ❌ | ❌ |
| [rage](https://github.com/str4d/rage) | Age-compatible encryption | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [rclone](https://rclone.org) | Cloud storage sync | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Recursive text search | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [sd](https://github.com/chmln/sd) | Intuitive sed alternative | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [starship](https://starship.rs) | Cross-shell prompt | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | Fast tldr client | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer | `system` | ✅ | ✅ | ✅ | ✅ |
| [topgrade](https://github.com/topgrade-rs/topgrade) | System-wide upgrader | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [vivid](https://github.com/sharkdp/vivid) | LS_COLORS theme generator | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [xh](https://github.com/ducaale/xh) | Friendly HTTP client | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [Yazi](https://github.com/sxyazi/yazi) | Terminal file manager | `mise ✅` (Arch: `pacman`) | ✅ | ✅ | ✅ | ✅ |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter cd command | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🤖 AI and Inference

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [codegraph](https://github.com/colbymchenry/codegraph) | Code knowledge graph MCP server | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Engram](https://github.com/Gentleman-Programming/engram) | Agent memory and MCP server | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Hugging Face CLI](https://huggingface.co/docs/huggingface_hub) | Model download and repository CLI | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | Local GGUF inference server | `mise ✅` (macOS: `brew`) | ✅ | ✅ | ✅ | ✅ |
| [oMLX](https://github.com/jundot/omlx) | Local Apple Silicon inference | `system` | ❌ (amd64) | ❌ | ❌ | ❌ |
| [Pyright](https://github.com/microsoft/pyright) | Python type checker and language server (agent LSP) | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [rust-analyzer](https://github.com/rust-lang/rust-analyzer) | Rust language server (agent LSP) | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [SkyPilot](https://docs.skypilot.co) | Multi-cloud workload launcher | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server) | TypeScript and JavaScript language server (agent LSP) | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🟠 Claude Code

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Claude Code](https://code.claude.com) | Anthropic coding agent CLI | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [claude-powerline](https://github.com/Owloops/claude-powerline) | Statusline for Claude Code | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ☁️ Cloud

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [AWS CLI](https://github.com/aws/aws-cli) | Manage AWS services | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Azure CLI](https://github.com/Azure/azure-cli) | Manage Azure resources | `system` (macOS ARM: `cask`) | ✅ | ✅ | ✅ | ✅ |

### 🐳 Containers

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Colima](https://github.com/abiosoft/colima) | Container runtime VM for macOS | `mise ✅` | ✅ | ❌ | ❌ | ❌ |
| [dive](https://github.com/wagoodman/dive) | Container image layer explorer | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Docker](https://www.docker.com) | Docker CLI (Engine on Linux; Colima on macOS) | `system` | ✅ | ✅ | ✅ | ✅ |
| [Docker Buildx](https://docs.docker.com/build/buildx) | Extended docker build | `system` | ✅ | ✅ | ✅ | ✅ |
| [Docker Compose](https://docs.docker.com/compose) | Multi-container app orchestration | `system` | ✅ | ✅ | ✅ | ✅ |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Terminal UI for Docker | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Lima](https://lima-vm.io) | Linux virtual machines | `mise ✅` | ✅ | ❌ | ❌ | ❌ |

### ✨ Extras

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [OpenSC](https://github.com/OpenSC/OpenSC) | Smart card middleware | `system` | ✅ | ❌ | ❌ | ❌ |
| [pam-u2f](https://github.com/Yubico/pam-u2f) | U2F PAM module | `system` | ✅ | ❌ | ❌ | ❌ |
| [qrencode](https://fukuchi.org/works/qrencode) | QR code generator | `system` | ✅ | ✅ | ✅ | ✅ |
| [YubiKey Manager](https://github.com/Yubico/yubikey-manager) | YubiKey configuration tool | `system` | ✅ | ❌ | ❌ | ❌ |

### 🐹 Go

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Go](https://go.dev) | Go language toolchain | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [gopls](https://github.com/golang/tools/tree/master/gopls) | Go language server | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🏗️ Infrastructure as Code

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [OpenTofu](https://opentofu.org) | Open source Terraform fork | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [SOPS](https://github.com/getsops/sops) | Secrets encryption | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Terraform wrapper | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ☕ Java

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Apache Maven](https://maven.apache.org) | Java build and dependency tool | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [OpenJDK](https://openjdk.org) | Java runtime and compiler | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ☸️ Kubernetes

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Helm](https://helm.sh) | Kubernetes package manager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [helm-diff](https://github.com/databus23/helm-diff) | Helm release diffing | `helm` | ✅ | ✅ | ✅ | ✅ |
| [k3d](https://k3d.io) | Lightweight K3s clusters | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [k9s](https://k9scli.io) | Terminal UI for Kubernetes | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubecolor](https://github.com/kubecolor/kubecolor) | Colorize kubectl output | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubectl](https://kubernetes.io/docs/reference/kubectl) | Kubernetes command-line client | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubectl-get-all](https://github.com/corneliusweig/ketall) | Dump all kubectl resources (ketall) | `mise ✅` | ✅ | ❌ (arm64) | ❌ (arm64) | ❌ (arm64) |
| [kubectl-neat](https://github.com/itaysk/kubectl-neat) | Clean kubectl manifest output | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Kubescape](https://github.com/kubescape/kubescape) | Kubernetes security scanner | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubesess](https://github.com/Ramilito/kubesess) | Switch kubecontexts quickly | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [oc](https://github.com/openshift/oc) | OpenShift CLI | `mise ✅` | ✅ | ❌ (arm64) | ❌ (arm64) | ❌ (arm64) |
| [stern](https://github.com/stern/stern) | Tail multi-pod logs | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [yq](https://github.com/mikefarah/yq) | YAML processor | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🟢 Node.js

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Bun](https://bun.com) | Fast JS runtime and bundler | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Node.js](https://nodejs.org) | JS runtime with npm | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ⚡ OMP

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [OMP](https://github.com/can1357/oh-my-pi) | oh-my-pi coding agent | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🔗 OpenCode

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [OpenCode](https://opencode.ai) | Open-source terminal coding agent | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🥧 Pi

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) | Minimal extensible terminal coding agent | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🐍 Python

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Python](https://www.python.org) | Python runtime and pip tooling | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [uv](https://github.com/astral-sh/uv) | Fast Python package manager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🦀 Rust

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Rust](https://www.rust-lang.org) | Rust toolchain | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🍺 Homebrew Casks

Apple Silicon Mac, personal profile.

| App | Description |
| --- | --- |
| [AnyDesk](https://anydesk.com) | Remote desktop access |
| [Brave Browser](https://brave.com) | Privacy-focused web browser |
| [calibre](https://calibre-ebook.com) | E-book manager |
| [Cryptomator](https://cryptomator.org) | Cloud storage encryption |
| [Cursor](https://www.cursor.com) | AI-powered code editor |
| [draw.io Desktop](https://www.drawio.com) | Diagram editor |
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal |
| [Google Drive](https://www.google.com/drive/download) | Cloud storage desktop client |
| [HandBrake](https://handbrake.fr) | Video transcoder |
| [Ice](https://icemenubar.app) | Menu bar manager |
| [IINA](https://iina.io) | Modern media player |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app) | Manage JetBrains IDEs |
| [KeePassXC](https://keepassxc.org) | Password manager |
| [Keka](https://www.keka.io) | File archiver |
| [Kindle Previewer](https://kdp.amazon.com/en_US/help/topic/G202131170) | E-book preview tool |
| [LocalSend](https://localsend.org) | Local network file transfer |
| [LuLu](https://objective-see.org/products/lulu.html) | Outbound firewall |
| [Maccy](https://maccy.app) | Clipboard manager |
| [macFUSE](https://github.com/macfuse/macfuse) | Filesystem in userspace support |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl) | External display controls |
| [OnyX](https://www.titanium-software.fr/en/onyx.html) | macOS maintenance utility |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | Remove app leftovers |
| [Rectangle](https://rectangleapp.com) | Window manager |
| [RustDesk](https://rustdesk.com) | Open-source remote desktop |
| [Signal](https://signal.org) | Private messenger |
| [Spotify](https://www.spotify.com) | Music streaming client |
| [Stats](https://github.com/exelban/stats) | Menu bar system monitor |
| [Syncthing](https://syncthing.net) | Peer-to-peer file sync |
| [Telegram Desktop](https://desktop.telegram.org) | Telegram client |
| [tinyMediaManager](https://www.tinymediamanager.org) | Media file organizer |
| [Tor Browser](https://www.torproject.org) | Privacy browser |
| [Transmission](https://transmissionbt.com) | BitTorrent client |
| [VeraCrypt](https://www.veracrypt.fr) | Disk encryption |
| [Visual Studio Code](https://code.visualstudio.com) | Code editor |
| [XnView MP](https://www.xnview.com/en/xnviewmp) | Image viewer and organizer |
| [Yandex Disk](https://disk.yandex.com) | Cloud storage desktop client |
| [Zoom](https://zoom.us/download) | Video conferencing |

### 🍎 App Store (mas)

Apple Silicon Mac, personal profile.

| App | Description |
| --- | --- |
| [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) | Keep-awake utility |
| [Brother iPrint&Scan](https://apps.apple.com/app/brother-iprint-scan/id1193539993) | Printer and scanner utility |
| [CotEditor](https://apps.apple.com/app/coteditor/id1024640650) | Plain text editor |
| [Keynote](https://www.apple.com/keynote) | Apple presentations |
| [Numbers](https://www.apple.com/numbers) | Apple spreadsheets |
| [Pages](https://www.apple.com/pages) | Apple word processor |
| [Slack](https://slack.com) | Team messaging |
| [Tailscale](https://tailscale.com) | Mesh VPN client |
| [WhatsApp](https://www.whatsapp.com/download) | Messenger client |
| [Windows App](https://www.microsoft.com/windows-app) | Microsoft remote desktop client |
| [WireGuard](https://www.wireguard.com) | VPN client |
| [Xcode](https://developer.apple.com/xcode) | Apple IDE |

<!-- tools:end -->
