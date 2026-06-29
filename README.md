# ✨ Dotfiles Toolkit

Opinionated macOS, Ubuntu, Fedora, Arch Linux, and WSL dotfiles powered by [chezmoi](https://www.chezmoi.io/).

They orchestrate shells, editors, runtimes, and developer tooling so every machine feels the same.

## ⚙️ Installation Methods

- Quick bootstrap: `curl -fsLS https://raw.githubusercontent.com/adyranov/dotfiles/main/install.sh | sh`
- Existing chezmoi: `chezmoi init --apply https://github.com/adyranov/dotfiles`
- Change review: `mise run apply --dry-run` or `chezmoi diff`
- Validate: `mise run test`

### Try in Docker

Prebuilt images are also published to GHCR and Docker Hub:

- GHCR (recommended):
  - Ubuntu: `docker pull ghcr.io/adyranov/dotfiles:ubuntu && docker run --rm -it -e TERM -e COLORTERM ghcr.io/adyranov/dotfiles:ubuntu`
  - Fedora: `docker pull ghcr.io/adyranov/dotfiles:fedora && docker run --rm -it -e TERM -e COLORTERM ghcr.io/adyranov/dotfiles:fedora`
  - Arch: `docker pull ghcr.io/adyranov/dotfiles:archlinux && docker run --rm -it -e TERM -e COLORTERM ghcr.io/adyranov/dotfiles:archlinux`

- Docker Hub:
  - Ubuntu: `docker pull adyranov/dotfiles:ubuntu && docker run --rm -it -e TERM -e COLORTERM adyranov/dotfiles:ubuntu`
  - Fedora: `docker pull adyranov/dotfiles:fedora && docker run --rm -it -e TERM -e COLORTERM adyranov/dotfiles:fedora`
  - Arch: `docker pull adyranov/dotfiles:archlinux && docker run --rm -it -e TERM -e COLORTERM adyranov/dotfiles:archlinux`

### Windows / WSL

- Install WSL Ubuntu 24.04 (PowerShell as Administrator): `wsl --install -d Ubuntu-24.04`
- After reboot, open Ubuntu (WSL) and install prerequisites: `sudo apt update && sudo apt install -y curl git zsh`
- Clone and apply the dotfiles inside WSL: `git clone https://github.com/adyranov/dotfiles && cd dotfiles && ./install.sh`
- Validate with `~/.local/bin/check-dotfiles` and rerun `./install.sh` whenever you need to converge.

## 🧩 How It Works

- **Layered data**: base defaults merge with OS and profile overrides under
  `home/.chezmoidata/`.
- **Packages and toolchains**: package TOML renders native packages, `mise`
  tools, Helm/Krew plugins, tests, completions, and agent command policy.
- **Profiles**: personal/work data controls model routing, brew extras, and host
  sizing without duplicating base definitions.
- **Generated tests**: Bats specs render from the same data so package and config
  checks stay aligned with what chezmoi applies.

### AI agents

- The `ai` toolchain gates nested agents such as Pi, plus model routing, skills,
  permissions, and sandbox configuration.
- Pi command policy defaults to ask, allows safe read/status operations, and
  denies destructive patterns.
- Greywall provides the host filesystem/network/process sandbox; Pi permission
  prompts are a higher-level agent guard.
- Pi uses runtime profiles: `pi-agent` or `pi-agent core` (daily driver with Plannotator, permission system, catppuccin), `pi-agent minimal`
  (stripped: no Plannotator, no MCP servers, no subagents), and `pi-agent factory` for the full rpiv-pi stack. Sessions are isolated per profile.
- Opencode is managed as a first-class agent: `opencode-agent` launches
  opencode inside a Greywall sandbox (or `--no-greywall` for direct use,
  `--no-update` to skip the dependency cache preflight).
  Runtime profiles: `opencode-agent` or `opencode-agent core` for the daily driver
  with context pruning and notification plugins, `opencode-agent minimal` for a
  lightweight stack (no plugins, no subagents), and `opencode-agent factory` for
  slim multi-agent orchestration with background subagents, worktrees, and planning.
  Core uses the default OpenCode config location; factory uses a profile overlay
  (`~/.config/opencode/profiles/factory/`).

### Local LLM serving

**`llm-serve`** is the local OpenAI-compatible gateway on
`http://127.0.0.1:8321/v1`. Model data lives in
`home/.chezmoidata/base/ai/local.toml`; profile overrides live in
`home/.chezmoidata/profile/<profile>/ai.toml`.

- `llm-serve` — start in the foreground (Ctrl-C to stop)
- `llm-serve start` — start in the background
- `llm-serve stop` / `restart` / `status` / `list` / `logs`
- `llm-pull` — download missing local model weights and report stale GGUF caches
- `llm-bench [model ...]` — warm and benchmark local models with AIPerf

| Host | Default engine | Notes |
| --- | --- | --- |
| darwin / arm64 | profile (`engine` in `ai.toml`) | Installs both oMLX and `adyranov/tap/llama-cpp`; runtime picks `omlx` or `llamacpp` |
| darwin / amd64 | `llamacpp` | `adyranov/tap/llama-cpp`; native llama.cpp router mode |
| Linux / WSL2 | `llamacpp` | mise `llama.cpp` native router mode |

Set `engine = "omlx"` or `engine = "llamacpp"` under `[ai.profile.<profile>.local]`.
Each model must declare the matching backend (`mlx` or `gguf`). Qwen 3.5+ GGUF models
auto-attach the froggeric chat template. Use `llm-pull` to download weights, then
`chezmoi apply` to sync model symlinks and llama.cpp router presets.

Local model defaults are profile-specific and sized for each host class with
practical context windows rather than maximum possible limits. Use `llm-bench` to
evaluate alternatives for the current machine.

### Editor extensions

- VS Code and Cursor share settings/keybindings defined in `.chezmoidata/base/editors.toml` and rendered via `editors/vscode/` templates.
- Extensions are installed by `common/run_onchange_after_36_install-editor-extensions.sh.tmpl` (re-runs when the extension or settings list changes).

### XDG-first layout

- Exports file: shell environment is centralized in `~/.config/shell/exports.sh` (assembled from modular `exports.d/` fragments) to enforce XDG base directories across tools.
- An XDG migration planner (`before/run_onchange_before_05_xdg-migration-plan.sh.tmpl`) prints suggested `mv` commands when legacy dotfile paths are detected — it never modifies files itself.
- Smart completions: Zsh completions for kubectl, mise, tofu, etc., are automatically generated and synced with tool versions via `run_onchange` hashing.
- Moved dotfiles: bash/zsh history and sessions, npm cache/prefix, cargo/rustup, gradle, krew, pass, wget, readline, less, svn, git excludes, asdf files, and more are redirected under the XDG tree.
- Atuin is the default Zsh history backend. Legacy zsh history can be imported manually with `HISTFILE=... atuin import zsh`.
- Mac and Linux behave the same; `$XDG_RUNTIME_DIR` is set per host type (macOS uses `$TMPDIR`).
- Preview removals after migrating: `chezmoi --remove --dry-run apply` shows legacy dotfiles ready to prune.

### Catppuccin Mocha theming

A unified **Catppuccin Mocha** color scheme is applied across all terminal tools. Theme assets are fetched automatically via per-tool `.chezmoiexternal.toml.tmpl` files with a weekly refresh period. Themed tools include: bat, btop, delta (git), fzf, ghostty, k9s, lazygit, LS_COLORS (vivid), tmux, yazi, zsh-syntax-highlighting, and atuin.

### macOS Launch Agents

- Managed agents live under `home/private_Library/LaunchAgents` (rendered to `~/Library/LaunchAgents`).
- Launch agents are reloaded by `home/.chezmoiscripts/os/darwin/run_onchange_after_20_bootstrap-launch-agents.tmpl` (after macOS defaults in `run_onchange_after_10_configure-darwin.tmpl`).
- Non-macOS hosts ignore `home/private_Library/**` via template guards so Linux/WSL environments stay clean.

See examples in `home/.chezmoidata/base/`, `home/.chezmoidata/os/<distro>/`, and `home/.chezmoidata/profile/<profile>/`.

## 🧪 Validate Locally

- After applying dotfiles, run `mise run test` to execute generated Bats tests for system packages, `mise` tools, Helm and Krew plugins, AI agents, plus shell/Git config checks.
- Run package-only checks with `mise run test <tool>…` (e.g. `mise run test kubectl helm`).
- The test runner lives at `~/.local/share/dotfiles/test/check-dotfiles.sh` and is symlinked to `~/.local/bin/check-dotfiles`.
- All suites run in parallel by default (auto-detects CPU count). Use `-j1` for sequential/debug mode.
- Run specific suites: `check-dotfiles --suite config` or `check-dotfiles --suite config,ai`.
- Filter by tag: `check-dotfiles --tag toolchain:kubernetes`.
- Filter by test name regex: `check-dotfiles --filter 'git config'`.
- List all discovered tests: `check-dotfiles --list`.
- Bats and its plugins (`bats-assert`, `bats-support`, `bats-file`) are managed by chezmoi via `.chezmoiexternal.toml.tmpl` and persist in the test directory.

## 🧑‍💻 Development

- Unified entry point: this project uses **mise tasks** for orchestration.
- Bootstrap development environment: `mise run bootstrap` (installs `pre-commit` and `commit-msg` Git hooks).
- Run linting/validations: `mise run lint` (runs the `pre-commit` stage with `PRE_COMMIT_COLOR=never` for readable status labels; commit messages are checked by the installed `commit-msg` hook).
- Build test containers: `mise run build-containers`.
- Project layout follows chezmoi conventions. See `home/` for source state, `home/.chezmoidata/**` for data-driven packages, and `home/.chezmoitemplates/{common,os}/**` for reusable templates.
- Line endings are enforced via `.gitattributes` (LF for Unix tooling, CRLF for Windows scripts). Keep new files consistent with these defaults.
- Maintainers: see `AGENTS.md` for contributor guidelines and CI expectations.

## 🛠 Init & Customization

- First run is interactive: you’ll be prompted for Git identity, environment profile, restricted-mode behavior, and which toolchains to enable.
- Non-interactive/headless: control toolchains via env vars before running `chezmoi init`/`apply`:
  - Enable specific: `WITH_DOCKER=true WITH_KUBERNETES=true`
  - Disable specific: `WITHOUT_JAVA=true WITHOUT_NODE=true`
  - Disable all then opt-in: `WITHOUT_TOOLCHAINS=true WITH_PYTHON=true`
  - AI agents (nested under `ai`): `WITH_PI=true`, `WITHOUT_PI=true`
- Environment detection:
  - Ephemeral/container environments are auto-detected and tagged as `ephemeral`.
  - Non-interactive sessions set `.host.interactive = false` (treated as `headless` in package rules).
  - macOS Intel/Apple Silicon and Linuxbrew brew paths are auto-detected and exported for templates.
- macOS applies a generated CA bundle at `~/.config/certificates/ca-bundle.pem` from trusted system keychain certificates. If Greyproxy has generated `~/.local/share/greyproxy/ca-cert.pem`, it is appended to the bundle.

## 🧪 Containers

Use the helper to build and test local validation containers:

- List available images: `mise run build-containers --list`
- Build all: `mise run build-containers`
- Build one: `mise run build-containers archlinux|fedora|ubuntu`
- Use custom BuildKit config: `mise run build-containers --config ~/.config/docker/buildkitd/buildkitd.toml`
- Inject custom CA bundle: `mise run build-containers --ca-certs /path/to/ca-bundle.pem`
- Build full test stage (installs all tools): `mise run build-containers --full-test [archlinux|fedora|ubuntu]`

Notes:

- Supports parallel builds when `parallel` is installed; otherwise runs sequentially (the script hints how to install it).
- Pass `GITHUB_TOKEN` to enable authenticated fetches during container builds.

## 🤖 CI

- PR/main CI (`.github/workflows/ci.yaml`) is the fast gate: it runs path-filtered Docker validation, plus smoke host installs on Ubuntu amd64 and Apple Silicon macOS (`WITHOUT_TOOLCHAINS=true ./install.sh --data=false` followed by `check-dotfiles`).
- Full regression (`.github/workflows/ci-regression.yaml`) runs weekly and on demand. It covers the full host matrix, including Ubuntu ARM, Intel macOS, WSL, Docker, and the full toolchain install path.
- Host workflow (`.github/workflows/ci-host.yaml`) supports `smoke` and `full` modes. Full mode runs the two-phase core install/check and full toolchain install/check.
- Docker workflow (`.github/workflows/ci-docker.yaml`) builds Arch Linux, Fedora, and Ubuntu images for `amd64` and `arm64`, runs the same checks, and can optionally publish images.
  - To publish images manually, trigger the workflow with `workflow_dispatch` and set `publish` to `true`.

- WSL workflow (`.github/workflows/ci-wsl.yaml`) provisions Ubuntu 24.04 inside Windows runners, restores cached APT and mise downloads, runs `./install.sh`, then `~/.local/bin/check-dotfiles`.
- Security scan (`.github/workflows/security-scan.yaml`) runs Trivy after each Docker CI build and uploads SARIF results to the GitHub Security tab.
- Container cleanup (`.github/workflows/cleanup-containers.yaml`) prunes old untagged container versions from GHCR on a weekly schedule.
- Lint (`.github/workflows/lint.yaml`) runs `pre-commit` hooks on push and pull requests to `main`.
- License year update (`.github/workflows/update-license-year.yaml`) automatically bumps the copyright year in `LICENSE` on January 1st.
- When adding new top-level paths, update the `dorny/paths-filter` sections in the CI workflows so triggers remain accurate.

## 🖥 Supported Platforms

- 🍎 macOS (arm64 & x86_64) with Homebrew-backed packages.
- 🐧 Ubuntu (amd64 primary, arm64 best-effort with per-tool exclusions).
- 🦬 Fedora (amd64 focus, arm64 best-effort) via dnf.
- 🎯 Arch Linux (amd64 & arm64) via pacman.
- 💻 WSL inherits the Linux profiles; tailor overrides through `.chezmoidata`.

## 🧭 Install Manager Legend

- `system` → Native package manager (Homebrew, apt, dnf, pacman).
- `mise` → [mise](https://github.com/jdx/mise) runtime manager and UBI packages.
- `krew` → [Krew](https://krew.sigs.k8s.io/) kubectl plugin manager.
- `helm` → [Helm](https://helm.sh/) plugin manager.

## 🧰 Toolchains & Tools

Columns show macOS, Ubuntu, Fedora, and Arch Linux coverage. `✅` means the tool is provisioned on all architectures for that OS; `❌ (arch)` flags a missing architecture. The Install column highlights when `mise` is responsible (`mise ✅`), otherwise the native package manager or plugin manager is used.

### ☁️ Cloud

| Tool                                            | Description            | Install                     | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------------- | ---------------------- | --------------------------- | ----- | ------ | ------ | ---- |
| [AWS CLI](https://github.com/aws/aws-cli)       | Manage AWS services    | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [Azure CLI](https://github.com/Azure/azure-cli) | Manage Azure resources | `system`                    | ✅    | ✅     | ✅     | ✅   |

### 🛠 Common CLI

| Tool                                                     | Description                     | Install                                | macOS | Ubuntu          | Fedora | Arch |
| -------------------------------------------------------- | ------------------------------- | -------------------------------------- | ----- | --------------- | ------ | ---- |
| [Atuin](https://github.com/atuinsh/atuin)                | Shell history sync and search   | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [Bash](https://www.gnu.org/software/bash/)               | POSIX shell for scripting       | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [bat](https://github.com/sharkdp/bat)                    | Syntax-aware pager              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [btop](https://github.com/aristocratos/btop)             | Modern resource monitor         | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [chezmoi](https://www.chezmoi.io/)                       | Manage dotfiles across machines | `system` (Ubuntu via `mise ✅`)        | ✅    | ✅              | ✅     | ✅   |
| [curl](https://curl.se/)                                 | HTTP toolkit                    | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [delta](https://github.com/dandavison/delta)             | Git diff pager                  | `system` (Ubuntu via `mise ✅`)        | ✅    | ✅              | ✅     | ✅   |
| [difftastic](https://github.com/Wilfred/difftastic)      | Structural diff tool            | `mise ✅` (macOS/Fedora/Arch: `system`)   | ✅    | ✅              | ✅     | ✅   |
| [direnv](https://github.com/direnv/direnv)               | Directory-aware env loader      | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [doggo](https://github.com/mr-karan/doggo)               | Modern DNS client               | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [dust](https://github.com/bootandy/dust)                 | du alternative in Rust          | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [eza](https://github.com/eza-community/eza)              | Modern ls replacement           | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [fd](https://github.com/sharkdp/fd)                      | Fast find utility               | `system` (`fd-find` on Ubuntu/Fedora)  | ✅    | ✅              | ✅     | ✅   |
| [fzf](https://github.com/junegunn/fzf)                   | Fuzzy finder                    | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Git](https://git-scm.com/)                              | Distributed VCS                 | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [GitHub CLI](https://github.com/cli/cli)                 | GitHub command-line client      | `system` (`github-cli` on Arch)        | ✅    | ✅              | ✅     | ✅   |
| [Glow](https://github.com/charmbracelet/glow)            | Markdown renderer in terminal   | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [GNU Coreutils](https://www.gnu.org/software/coreutils/) | GNU userland tools              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [GnuPG](https://gnupg.org/)                              | OpenPGP encryption toolkit      | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Greyproxy](https://github.com/GreyhavenHQ/greyproxy)   | Network-level request proxy     | `mise ✅`                              | ✅    | ✅              | ✅     | ✅   |
| [Greywall](https://github.com/GreyhavenHQ/greywall)     | Filesystem/process sandbox      | `mise ✅`                              | ✅    | ✅              | ✅     | ✅   |
| [hyperfine](https://github.com/sharkdp/hyperfine)        | Command benchmarking            | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [jnv](https://github.com/ynqa/jnv)                       | Interactive JSON viewer with jq  | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [jq](https://stedolan.github.io/jq/)                     | JSON processor                  | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [lazygit](https://github.com/jesseduffield/lazygit)      | Terminal UI for Git             | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [mise](https://github.com/jdx/mise)                      | Runtime/version manager         | `system` (Fedora via bootstrap script) | ✅    | ✅              | ✅     | ✅   |
| [mkcert](https://github.com/FiloSottile/mkcert)          | Local TLS certificate generator | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [Neovim](https://github.com/neovim/neovim)               | Modal code editor               | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [OpenSSH](https://www.openssh.com/)                      | SSH client and agent            | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [ouch](https://github.com/ouch-org/ouch)                 | Painless compression            | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [rage](https://github.com/str4d/rage)                    | Age-compatible encryption       | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [rclone](https://rclone.org/)                            | Cloud storage sync              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [ripgrep](https://github.com/BurntSushi/ripgrep)         | Recursive text search           | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [sd](https://github.com/chmln/sd)                        | Intuitive sed alternative       | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [tealdeer](https://github.com/dbrgn/tealdeer)            | Fast tldr client                | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [tmux](https://github.com/tmux/tmux)                     | Terminal multiplexer            | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [topgrade](https://github.com/topgrade-rs/topgrade)      | System-wide upgrader            | `mise ✅` (macOS: `system`)            | ✅    | ✅              | ✅     | ✅   |
| [vivid](https://github.com/sharkdp/vivid)                | LS_COLORS theme generator       | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [wget](https://www.gnu.org/software/wget/)               | Network downloader              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [xh](https://github.com/ducaale/xh)                      | Friendly HTTP client in Rust    | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [Yazi](https://github.com/sxyazi/yazi)                   | Fast terminal file manager      | `mise ✅` (macOS/Arch: `system`)       | ✅    | ✅              | ✅     | ✅   |
| [zoxide](https://github.com/ajeetdsouza/zoxide)          | Smarter cd command              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Zsh](https://www.zsh.org/)                              | Advanced shell                  | `system`                               | ✅    | ✅              | ✅     | ✅   |

### 🐳 Containers

| Tool                                                   | Description              | Install                                 | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------------------------ | ------------------------ | --------------------------------------- | ----- | ------ | ------ | ---- |
| [Docker Engine](https://www.docker.com/)               | Container runtime        | `system` (`docker-ce` on Ubuntu/Fedora) | ✅    | ✅     | ✅     | ✅   |
| [Docker Compose](https://docs.docker.com/compose/)     | Compose v2 plugin        | `system` (`docker-compose-plugin`)      | ✅    | ✅     | ✅     | ✅   |
| [Docker Buildx](https://docs.docker.com/build/buildx/) | Extended docker build    | `system` (`docker-buildx-plugin`)       | ✅    | ✅     | ✅     | ✅   |
| [Dive](https://github.com/wagoodman/dive)              | Analyze container layers | `mise ✅` (macOS: `system`)             | ✅    | ✅     | ✅     | ✅   |
| [LazyDocker](https://github.com/jesseduffield/lazydocker) | TUI for Docker           | `mise ✅`                               | ✅    | ✅     | ✅     | ✅   |

### ➕ Extras

| Tool                                                         | Description                  | Install                           | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------------------------------ | ---------------------------- | --------------------------------- | ----- | ------ | ------ | ---- |
| [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey) | YubiKey plugin for age encryption | `system`                    | ✅    | ❌     | ❌     | ❌   |
| [bubblewrap](https://github.com/containers/bubblewrap)        | Unprivileged sandboxing      | `system`                          | ❌    | ✅     | ✅     | ✅   |
| [gocryptfs](https://github.com/rfjakob/gocryptfs)            | Encrypted overlay filesystem | `system` (`gocryptfs-mac`)        | ✅    | ✅     | ✅     | ✅   |
| [mas](https://github.com/mas-cli/mas)                         | Mac App Store CLI            | `system`                          | ✅    | ❌     | ❌     | ❌   |
| [OpenSC](https://github.com/OpenSC/OpenSC)                   | Smart card middleware        | `system`                          | ✅    | ❌     | ❌     | ❌   |
| [pam-u2f](https://github.com/Yubico/pam-u2f)                 | U2F PAM module               | `system`                          | ✅    | ❌     | ❌     | ❌   |
| [pinentry-mac](https://github.com/GPGTools/pinentry)          | GPG passphrase entry for macOS | `system`                        | ✅    | ❌     | ❌     | ❌   |
| [qrencode](https://fukuchi.org/works/qrencode/)              | QR code generator            | `system`                          | ✅    | ✅     | ✅     | ✅   |
| [socat](http://www.dest-unreach.org/socat/)                   | Multipurpose socket relay    | `system`                          | ❌    | ✅     | ✅     | ✅   |
| [YubiKey Manager](https://github.com/Yubico/yubikey-manager) | YubiKey configuration tool   | `system`                          | ✅    | ❌     | ❌     | ❌   |

### 🦫 Go Runtime

| Tool                  | Description           | Install   | macOS | Ubuntu | Fedora | Arch |
| --------------------- | --------------------- | --------- | ----- | ------ | ------ | ---- |
| [Go](https://go.dev/) | Go language toolchain | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🏗 Infrastructure as Code

| Tool                                                     | Description                    | Install   | macOS | Ubuntu | Fedora | Arch |
| -------------------------------------------------------- | ------------------------------ | --------- | ----- | ------ | ------ | ---- |
| [OpenTofu](https://opentofu.org/)                        | Open source Terraform fork     | `mise ✅`                      | ✅    | ✅     | ✅     | ✅   |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Terraform wrapper              | `mise ✅` (macOS: `system`)   | ✅    | ✅     | ✅     | ✅   |
| [sops](https://github.com/getsops/sops)                  | Secrets encryption             | `mise ✅` (macOS: `system`)   | ✅    | ✅     | ✅     | ✅   |

### ☕️ Java Stack

| Tool                                      | Description             | Install   | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------- | ----------------------- | --------- | ----- | ------ | ------ | ---- |
| [Apache Maven](https://maven.apache.org/) | Java dependency manager | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [OpenJDK (LTS)](https://openjdk.org/)     | Java runtime + compiler | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### ☸️ Kubernetes Core

| Tool                                                                                                                      | Description                  | Install   | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | --------- | ----- | ------ | ------ | ---- |
| [kubesess](https://github.com/Ramilito/kubesess)                                                                          | Switch kubecontexts quickly  | `mise ✅`                    | ✅    | ✅     | ✅     | ✅   |
| [Helm](https://helm.sh/)                                                                                                  | Kubernetes package manager   | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [k3d](https://k3d.io/)                                                                                                    | Lightweight K3s clusters     | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [k9s](https://k9scli.io/)                                                                                                 | TUI for Kubernetes           | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/)                                                                  | Kubernetes control plane CLI | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [kustomize](https://github.com/kubernetes-sigs/kustomize)                                                                 | YAML customization           | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [kubecolor](https://github.com/dty1er/kubecolor)                                                                          | Colorize kubectl output      | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [Kubescape](https://github.com/kubescape/kubescape)                                                                       | CIS and risk scanner         | `mise ✅`                    | ✅    | ✅     | ✅     | ✅   |
| [yq](https://github.com/mikefarah/yq)                                                                                     | YAML processor               | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [Stern](https://github.com/stern/stern)                                                                                   | Tail multi-pod logs          | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [helm-diff](https://github.com/databus23/helm-diff)                                                                       | Helm release diffing         | `helm`                       | ✅    | ✅     | ✅     | ✅   |
| [oc](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)            | OpenShift CLI                | `mise ✅` (macOS: `system`) | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |

### 🔌 kubectl Plugins

| Plugin                                                                                                        | Description            | Install | macOS | Ubuntu          | Fedora | Arch |
| ------------------------------------------------------------------------------------------------------------- | ---------------------- | ------- | ----- | --------------- | ------ | ---- |
| [access-matrix](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/access-matrix.yaml)         | RBAC visibility        | `krew`  | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |
| [get-all](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/get-all.yaml)                     | Dump all resources     | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [neat](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/neat.yaml)                           | Clean manifest output  | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [node-shell](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/node-shell.yaml)               | SSH into nodes         | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [rbac-tool](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/rbac-tool.yaml)                 | RBAC visualization     | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [tree](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/tree.yaml)                           | Resource hierarchy     | `krew`  | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |

### 🟢 Node.js

| Tool                                 | Description                   | Install   | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------ | ----------------------------- | --------- | ----- | ------ | ------ | ---- |
| [Bun](https://bun.sh/)              | Fast JS runtime and bundler   | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [Node.js (LTS)](https://nodejs.org/) | JS runtime + package managers | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🐍 Python

| Tool                                  | Description                  | Install   | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------- | ---------------------------- | --------- | ----- | ------ | ------ | ---- |
| [Python](https://www.python.org/)     | Python runtime & pip tooling | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [uv](https://github.com/astral-sh/uv) | Fast Python package manager  | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🦀 Rust

| Tool                               | Description             | Install   | macOS | Ubuntu | Fedora | Arch |
| ---------------------------------- | ----------------------- | --------- | ----- | ------ | ------ | ---- |
| [Rust](https://www.rust-lang.org/) | Rust toolchain (rustup) | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🤖 AI Agents

| Tool                                                               | Description                   | Install                        | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------------------------------------ | ----------------------------- | ------------------------------ | ----- | ------ | ------ | ---- |
| [AIPerf](https://github.com/ai-dynamo/aiperf)                      | LLM endpoint benchmarking     | `mise ✅`                      | ✅    | ✅     | ✅     | ✅   |
| [opencode](https://opencode.ai)                                   | AI coding agent (terminal)    | `mise ✅`                      | ✅    | ✅     | ✅     | ✅   |
| [pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) | Coding agent                  | `mise ✅`                      | ✅    | ✅     | ✅     | ✅   |
| [rtk](https://github.com/rtk-ai/rtk)                              | AI agent toolkit              | `mise ✅` (macOS: `system`)   | ✅    | ✅     | ✅     | ✅   |

## 🧰 GUI Apps (macOS)

These desktop apps are installed on macOS via Homebrew casks or the App Store (mas).

### 🍺 Homebrew Casks

| App                                                                    | Description                     |
| ---------------------------------------------------------------------- | ------------------------------- |
| [AnyDesk](https://anydesk.com/)                                        | Remote desktop access           |
| [Brave Browser](https://brave.com/)                                    | Privacy-focused web browser     |
| [Calibre](https://calibre-ebook.com/)                                  | E-book manager                  |
| [Cryptomator](https://cryptomator.org/)                                | Cloud storage encryption        |
| [Cursor](https://www.cursor.com/)                                      | AI-powered code editor          |
| [draw.io Desktop](https://www.diagrams.net/)                           | Diagram editor                  |
| [Ghostty](https://ghostty.org/)                                        | GPU-accelerated terminal        |
| [Google Drive](https://www.google.com/drive/download/)                 | Cloud storage desktop client    |
| [HandBrake](https://handbrake.fr/)                                     | Video transcoder                |
| [IINA](https://iina.io/)                                               | Modern media player             |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/)            | Manage JetBrains IDEs           |
| [Ice](https://icemenubar.app/)                                         | Menu bar manager                |
| [KeePassXC](https://keepassxc.org/)                                    | Password manager                |
| [Keka](https://www.keka.io/)                                           | File archiver                   |
| [Kindle Previewer](https://kdp.amazon.com/en_US/help/topic/G202131170) | E-book preview tool             |
| [LocalSend](https://localsend.org/)                                    | Local network file transfer     |
| [LuLu](https://objective-see.org/products/lulu.html)                   | Outbound firewall               |
| [Maccy](https://maccy.app/)                                            | Clipboard manager               |
| [macFUSE](https://github.com/macfuse/macfuse)                          | Filesystem in userspace support |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl)     | External display controls       |
| [OnyX](https://www.titanium-software.fr/en/onyx.html)                  | macOS maintenance utility       |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner)              | Remove app leftovers            |
| [Rancher Desktop](https://rancherdesktop.io/)                          | Container management and Kubernetes |
| [Rectangle](https://rectangleapp.com/)                                 | Window manager                  |
| [RustDesk](https://rustdesk.com/)                                      | Open-source remote desktop      |
| [Signal](https://signal.org/)                                          | Private messenger               |
| [Spotify](https://www.spotify.com/)                                    | Music streaming client          |
| [Stats](https://github.com/exelban/stats)                              | Menu bar system monitor         |
| [Syncthing](https://syncthing.net/)                                    | Peer-to-peer file sync          |
| [Telegram Desktop](https://desktop.telegram.org/)                      | Telegram client                 |
| [tinyMediaManager](https://www.tinymediamanager.org/)                  | Media file organizer            |
| [Tor Browser](https://www.torproject.org/)                             | Privacy browser                 |
| [Transmission](https://transmissionbt.com/)                            | BitTorrent client               |
| [VeraCrypt](https://www.veracrypt.fr/)                                 | Disk encryption                 |
| [Visual Studio Code](https://code.visualstudio.com/)                   | Code editor                     |
| [XnView MP](https://www.xnview.com/en/xnviewmp/)                       | Image viewer and organizer      |
| [Yandex Disk](https://disk.yandex.com/)                                | Cloud storage desktop client    |
| [Zoom](https://zoom.us/download)                                       | Video conferencing              |

### 🍎 App Store (mas)

| App                                                                                | Description               |
| ---------------------------------------------------------------------------------- | ------------------------- |
| [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)                  | Keep-awake utility        |
| [Brother iPrint&Scan](https://apps.apple.com/app/brother-iprint-scan/id1193539993) | Printer/scanner utility   |
| [CotEditor](https://apps.apple.com/app/coteditor/id1024640650)                     | Plain text editor         |
| [Keynote](https://www.apple.com/keynote/)                                          | Apple presentations       |
| [Numbers](https://www.apple.com/numbers/)                                          | Apple spreadsheets        |
| [Pages](https://www.apple.com/pages/)                                              | Apple word processor      |
| [Slack](https://slack.com/)                                                        | Team messaging            |
| [Tailscale](https://tailscale.com/)                                                | Mesh VPN client           |
| [WhatsApp](https://www.whatsapp.com/download)                                      | Messenger client          |
| [Windows App](https://www.microsoft.com/windows-app)                               | Microsoft remote desktop  |
| [WireGuard](https://www.wireguard.com/)                                            | VPN client                |
| [Xcode](https://developer.apple.com/xcode/)                                        | Apple IDE                 |
