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

- Single source of truth: tools live in `.chezmoidata/base/packages.toml` (`packages.base.<toolchain>`, e.g. `packages.base.core`), merge through `.chezmoidata/os/<distro>/packages.toml`, then render via `.chezmoitemplates/common/helpers/render-packages` into the right target (system package manager, `mise`, `krew`, `helm`, and tests).
- Layered overrides: later layers win — `packages.base` (defaults) → `packages.<distro>` keyed by `host.distro.id` (sparse keys such as `name`, `manager`, `version`, `test`, `exclude_arch`). When an override changes `manager`, the `name` automatically resets to the package key (since names are manager-specific, e.g. a brew formula vs a mise backend identifier). To use a non-default name with the new manager, set both `manager` and `name` in the override.
- Conditional disables: set `disabled` to either a boolean, or a comma/space separated string of flags. Supported flags: `headless` (non-interactive sessions), `restricted`, and host type values `desktop`, `laptop`, `wsl`, `ephemeral`. Example: `disabled = "headless,restricted"`.
- OS pinning: set `os = "darwin" | "ubuntu" | "fedora" | "archlinux"` on a package entry to include it only on that distro.

### XDG-first layout

- Exports file: shell environment is centralized in `~/.config/shell/exports.sh` to enforce XDG base directories across tools.
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

See examples in `home/.chezmoidata/base/` and `home/.chezmoidata/os/<distro>/`.

## 🧪 Validate Locally

- After applying dotfiles, run `mise run test` to execute generated Bats tests for system packages, `mise` tools, Helm and Krew plugins, plus shell/Git config checks.
- Run package-only checks with `mise run test <tool>…` (e.g. `mise run test kubectl helm`).
- The test runner lives at `~/.local/share/dotfiles/test/check-dotfiles.sh` and is symlinked to `~/.local/bin/check-dotfiles`.
- The runner fetches Bats plugins on demand and cleans them up after the run.

## 🧑‍💻 Development

- Unified entry point: this project uses **mise tasks** for orchestration.
- Bootstrap development environment: `mise run bootstrap` (configures `pre-commit` and `commit-msg` Git hooks plus native tooling).
- Run linting/validations: `mise run lint` (runs the `pre-commit` stage with `PRE_COMMIT_COLOR=never` for readable status labels; commit messages are checked by the installed `commit-msg` hook).
- Build test containers: `mise run build-containers`.
- Project layout follows chezmoi conventions. See `home/` for source state, `home/.chezmoidata/**` for data-driven packages, and `home/.chezmoitemplates/{common,os}/**` for reusable templates.
- Line endings are enforced via `.gitattributes` (LF for Unix tooling, CRLF for Windows scripts). Keep new files consistent with these defaults.
- Maintainers: see `AGENTS.md` for contributor guidelines and CI expectations.

## 🛠 Init & Customization

- First run is interactive: you’ll be prompted for Git identity, whether it’s a work or restricted environment, and which toolchains to enable.
- Non-interactive/headless: control toolchains via env vars before running `chezmoi init`/`apply`:
  - Enable specific: `WITH_DOCKER=true WITH_KUBERNETES=true`
  - Disable specific: `WITHOUT_JAVA=true WITHOUT_NODE=true`
  - Disable all then opt-in: `WITHOUT_TOOLCHAINS=true WITH_PYTHON=true`
- Environment detection:
  - Ephemeral/container environments are auto-detected and tagged as `ephemeral`.
  - Non-interactive sessions set `.host.interactive = false` (treated as `headless` in package rules).
  - macOS Intel/Apple Silicon and Linuxbrew brew paths are auto-detected and exported for templates.

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

- Host workflow (`.github/workflows/ci-host.yaml`) runs a two-phase test on macOS and Ubuntu (Intel/ARM): Phase 1 installs core packages (`WITHOUT_TOOLCHAINS=true ./install.sh`) and validates, Phase 2 applies all toolchains (`chezmoi apply`) and validates again.
- Docker workflow (`.github/workflows/ci-docker.yaml`) builds Arch Linux, Fedora, and Ubuntu images for `amd64` and `arm64`, runs the same checks, and can optionally publish images.
  - To publish images manually, trigger the workflow with `workflow_dispatch` and set `publish` to `true`.
  - The workflow also generates SPDX SBOM artifacts for published image tags.
- WSL workflow (`.github/workflows/ci-wsl.yaml`) provisions Ubuntu 24.04 inside Windows runners, restores cached APT/mise/rustup/cargo/krew/helm downloads, runs `./install.sh`, then `~/.local/bin/check-dotfiles`.
- Security scan (`.github/workflows/security-scan.yaml`) runs Trivy weekly against the latest container image and uploads SARIF results to the GitHub Security tab.
- Container cleanup (`.github/workflows/cleanup-containers.yaml`) prunes old untagged container versions from GHCR on a weekly schedule.
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
| [Atuin](https://github.com/atuinsh/atuin)                | Shell history sync and search   | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Bash](https://www.gnu.org/software/bash/)               | POSIX shell for scripting       | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [bat](https://github.com/sharkdp/bat)                    | Syntax-aware pager              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [btop](https://github.com/aristocratos/btop)             | Modern resource monitor         | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [chezmoi](https://www.chezmoi.io/)                       | Manage dotfiles across machines | `system` (Ubuntu via `mise ✅`)        | ✅    | ✅              | ✅     | ✅   |
| [GNU Coreutils](https://www.gnu.org/software/coreutils/) | GNU userland tools              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [curl](https://curl.se/)                                 | HTTP toolkit                    | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [delta](https://github.com/dandavison/delta)             | Git diff pager                  | `system` (Ubuntu via `mise ✅`)        | ✅    | ✅              | ✅     | ✅   |
| [direnv](https://github.com/direnv/direnv)               | Directory-aware env loader      | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [doggo](https://github.com/mr-karan/doggo)               | Modern DNS client               | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [dust](https://github.com/bootandy/dust)                 | du alternative in Rust          | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [eza](https://github.com/eza-community/eza)              | Modern ls replacement           | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [fd](https://github.com/sharkdp/fd)                      | Fast find utility               | `system` (`fd-find` on Ubuntu/Fedora)  | ✅    | ✅              | ✅     | ✅   |
| [fzf](https://github.com/junegunn/fzf)                   | Fuzzy finder                    | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Git](https://git-scm.com/)                              | Distributed VCS                 | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [GitHub CLI](https://github.com/cli/cli)                 | GitHub command-line client      | `system` (`github-cli` on Arch)        | ✅    | ✅              | ✅     | ✅   |
| [GnuPG](https://gnupg.org/)                              | OpenPGP encryption toolkit      | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Glow](https://github.com/charmbracelet/glow)            | Markdown renderer in terminal   | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [hyperfine](https://github.com/sharkdp/hyperfine)        | Command benchmarking            | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [jnv](https://github.com/ynqa/jnv)                       | Interactive JSON viewer with jq  | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [jq](https://stedolan.github.io/jq/)                     | JSON processor                  | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [lazygit](https://github.com/jesseduffield/lazygit)      | Terminal UI for Git             | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [mise](https://github.com/jdx/mise)                      | Runtime/version manager         | `system` (Fedora via bootstrap script) | ✅    | ✅              | ✅     | ✅   |
| [mkcert](https://github.com/FiloSottile/mkcert)          | Local TLS certificate generator | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [Neovim](https://github.com/neovim/neovim)               | Modal code editor               | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [ouch](https://github.com/ouch-org/ouch)                 | Painless compression            | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [rage](https://github.com/str4d/rage)                    | Age-compatible encryption       | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [rclone](https://rclone.org/)                            | Cloud storage sync              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [ripgrep](https://github.com/BurntSushi/ripgrep)         | Recursive text search           | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [sd](https://github.com/chmln/sd)                        | Intuitive sed alternative       | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [tealdeer](https://github.com/dbrgn/tealdeer)            | Fast tldr client                | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [tmux](https://github.com/tmux/tmux)                     | Terminal multiplexer            | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [topgrade](https://github.com/topgrade-rs/topgrade)      | System-wide upgrader            | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [vivid](https://github.com/sharkdp/vivid)                | LS_COLORS theme generator       | `system` (Ubuntu/Fedora via `mise ✅`) | ✅    | ✅              | ✅     | ✅   |
| [wget](https://www.gnu.org/software/wget/)               | Network downloader              | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [xh](https://github.com/ducaale/xh)                      | Friendly HTTP client in Rust    | `system`                               | ✅    | ✅              | ✅     | ✅   |
| [Yazi](https://github.com/sxyazi/yazi)                   | Fast terminal file manager      | `system`                               | ✅    | ✅              | ✅     | ✅   |
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
| [gocryptfs](https://github.com/rfjakob/gocryptfs)            | Encrypted overlay filesystem | `system` (`gocryptfs-mac`)        | ✅    | ✅     | ✅     | ✅   |
| [OpenSC](https://github.com/OpenSC/OpenSC)                   | Smart card middleware        | `system`                          | ✅    | ❌     | ❌     | ❌   |
| [pam-u2f](https://github.com/Yubico/pam-u2f)                 | U2F PAM module               | `system`                          | ✅    | ❌     | ❌     | ❌   |
| [qrencode](https://fukuchi.org/works/qrencode/)              | QR code generator            | `system`                          | ✅    | ✅     | ✅     | ✅   |
| [YubiKey Manager](https://github.com/Yubico/yubikey-manager) | YubiKey configuration tool   | `system`                          | ✅    | ❌     | ❌     | ❌   |

### 🦫 Go Runtime

| Tool                  | Description           | Install   | macOS | Ubuntu | Fedora | Arch |
| --------------------- | --------------------- | --------- | ----- | ------ | ------ | ---- |
| [Go](https://go.dev/) | Go language toolchain | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🏗 Infrastructure as Code

| Tool                                                     | Description                    | Install   | macOS | Ubuntu | Fedora | Arch |
| -------------------------------------------------------- | ------------------------------ | --------- | ----- | ------ | ------ | ---- |
| [OpenTofu](https://opentofu.org/)                        | Open source Terraform fork     | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Terraform wrapper              | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [sops](https://github.com/getsops/sops)                  | Secrets encryption             | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### ☕️ Java Stack

| Tool                                      | Description             | Install   | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------- | ----------------------- | --------- | ----- | ------ | ------ | ---- |
| [Apache Maven](https://maven.apache.org/) | Java dependency manager | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [OpenJDK (LTS)](https://openjdk.org/)     | Java runtime + compiler | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### ☸️ Kubernetes Core

| Tool                                                                                                                      | Description                  | Install   | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | --------- | ----- | ------ | ------ | ---- |
| [kubesess](https://github.com/Ramilito/kubesess)                                                                          | Switch kubecontexts quickly  | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [Helm](https://helm.sh/)                                                                                                  | Kubernetes package manager   | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [k3d](https://k3d.io/)                                                                                                    | Lightweight K3s clusters     | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [k9s](https://k9scli.io/)                                                                                                 | TUI for Kubernetes           | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/)                                                                  | Kubernetes control plane CLI | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [kustomize](https://github.com/kubernetes-sigs/kustomize)                                                                 | YAML customization           | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [kubecolor](https://github.com/dty1er/kubecolor)                                                                          | Colorize kubectl output      | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [Kubescape](https://github.com/kubescape/kubescape)                                                                       | CIS and risk scanner         | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [yq](https://github.com/mikefarah/yq)                                                                                     | YAML processor               | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [Stern](https://github.com/stern/stern)                                                                                   | Tail multi-pod logs          | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [helm-diff](https://github.com/databus23/helm-diff)                                                                       | Helm release diffing         | `helm`    | ✅    | ✅     | ✅     | ✅   |
| [oc](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)            | OpenShift CLI                | `mise ✅` | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |

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
| [Ghostty](https://ghostty.org/)                                        | GPU-accelerated terminal        |
| [Google Drive](https://www.google.com/drive/download/)                 | Cloud storage desktop client    |
| [HandBrake](https://handbrake.fr/)                                     | Video transcoder                |
| [IINA](https://iina.io/)                                               | Modern media player             |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/)            | Manage JetBrains IDEs           |
| [KeePassXC](https://keepassxc.org/)                                    | Password manager                |
| [Keka](https://www.keka.io/)                                           | File archiver                   |
| [Kindle Previewer](https://kdp.amazon.com/en_US/help/topic/G202131170) | E-book preview tool             |
| [LocalSend](https://localsend.org/)                                    | Local network file transfer     |
| [Maccy](https://maccy.app/)                                            | Clipboard manager               |
| [macFUSE](https://github.com/macfuse/macfuse)                          | Filesystem in userspace support |
| [OnyX](https://www.titanium-software.fr/en/onyx.html)                  | macOS maintenance utility       |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner)              | Remove app leftovers            |
| [Rancher Desktop](https://rancherdesktop.io/)                          | Container management and Kubernetes |
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
| [Brother iPrint&Scan](https://apps.apple.com/app/brother-iprint-scan/id1193539993) | Printer/scanner utility   |
| [Keynote](https://www.apple.com/keynote/)                                          | Apple presentations       |
| [Messenger](https://www.messenger.com/desktop)                                     | Facebook Messenger client |
| [Numbers](https://www.apple.com/numbers/)                                          | Apple spreadsheets        |
| [Pages](https://www.apple.com/pages/)                                              | Apple word processor      |
| [Slack](https://slack.com/)                                                        | Team messaging            |
| [Tailscale](https://tailscale.com/)                                                | Mesh VPN client           |
| [WhatsApp](https://www.whatsapp.com/download)                                      | Messenger client          |
| [Windows App](https://www.microsoft.com/windows-app)                               | Microsoft remote desktop  |
| [WireGuard](https://www.wireguard.com/)                                            | VPN client                |
| [Xcode](https://developer.apple.com/xcode/)                                        | Apple IDE                 |
