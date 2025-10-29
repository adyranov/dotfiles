# ✨ Dotfiles Toolkit

Opinionated macOS, Ubuntu, Fedora, Arch Linux, and WSL dotfiles powered by [chezmoi](https://www.chezmoi.io/).

They orchestrate shells, editors, runtimes, and developer tooling so every machine feels the same.

## ⚙️ Installation Methods

- Quick bootstrap: `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply adyranov`
- Local clone: `git clone https://github.com/adyranov/dotfiles && cd dotfiles && ./install.sh`
- Existing chezmoi: `chezmoi init --apply https://github.com/adyranov/dotfiles`
- Change review: `chezmoi diff` → then `chezmoi apply` or `chezmoi apply --dry-run`; validate with `chezmoi verify`

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

- Single source of truth: tools live in `.chezmoidata/*/packages.*.toml` and render via a shared template at `.chezmoitemplates/universal/packages` into the right target (system package manager, `mise`, `krew`, `helm`, and tests).
- Per-OS overrides: each package may define `overrides.<os>` with keys like `name`, `manager`, `version`, `test`, and `exclude_arch` to fine-tune behavior per platform/arch.
- Conditional disables: set `disabled` to either a boolean, or a comma/space separated string of flags. Supported flags: `headless` (non-interactive sessions), `restricted`, and host type values `desktop`, `laptop`, `wsl`, `ephemeral`. Example: `disabled = "headless,restricted"`.
- OS pinning: set `os = "darwin" | "ubuntu" | "fedora" | "archlinux"` on a package to include it only on that OS.

### XDG-first layout

- Exports file: shell environment is centralized in `~/.config/shell/exports.sh` to enforce XDG base directories across tools.
- Core dirs: `XDG_CONFIG_HOME=~/.config`, `XDG_CACHE_HOME=~/.cache`, `XDG_DATA_HOME=~/.local/share`, `XDG_STATE_HOME=~/.local/state`.
- Moved dotfiles: bash/zsh history and sessions, npm cache/prefix, cargo/rustup, gradle, krew, pass, wget, readline, less, svn, git excludes, asdf files, and more are redirected under the XDG tree.
- Mac and Linux behave the same; `$XDG_RUNTIME_DIR` is set per host type (macOS uses `$TMPDIR`).
- Preview removals after migrating: `chezmoi --remove --dry-run apply` shows legacy dotfiles ready to prune.

### macOS Launch Agents

- Managed agents live under `home/private_Library/LaunchAgents` (rendered to `~/Library/LaunchAgents`).
- The bootstrap script only reloads agents that are managed by chezmoi: `home/.chezmoiscripts/darwin/run_onchange_after_20_bootstrap-launch-agents.tmpl`.
- Non-macOS hosts ignore `home/private_Library/**` via template guards so Linux/WSL environments stay clean.

See examples in `home/.chezmoidata/universal/packages.universal.toml` and OS-specific overrides in `home/.chezmoidata/darwin`, `home/.chezmoidata/fedora`, `home/.chezmoidata/ubuntu`, and `home/.chezmoidata/archlinux`.

## 🧪 Validate Locally

- After applying dotfiles, run `check-dotfiles` to execute generated Bats tests for system packages, `mise` tools, Helm and Krew plugins.
- The test runner lives at `~/.local/share/dotfiles/test/check-dotfiles.sh` and is symlinked to `~/.local/bin/check-dotfiles`.
- The runner fetches Bats plugins on demand and cleans them up after the run.

## 🧑‍💻 Development

- Bootstrap local hooks: `./scripts/setup-pre-commit.sh` (installs a repo-local virtualenv and the `pre-commit` hook).
- Run validations anytime: `pre-commit run --all-files`.
- Project layout follows chezmoi conventions. See `home/` for source state, `home/.chezmoidata/**` for data-driven packages, and `home/.chezmoitemplates/**` for reusable templates.
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
- Password manager: `rbw` (Bitwarden CLI) config is rendered automatically on macOS and Linux with your Git email and a suitable `pinentry` (uses `pinentry-mac` when available).

## 🧪 Containers

Use the helper to build and test local validation containers:

- List available images: `./scripts/build-containers.sh --list`
- Build all: `./scripts/build-containers.sh`
- Build one: `./scripts/build-containers.sh archlinux|fedora|ubuntu`
- Use custom BuildKit config: `./scripts/build-containers.sh --config ~/.config/docker/buildkitd/buildkitd.toml`
- Build full test stage (installs all tools): `./scripts/build-containers.sh --full-test [archlinux|fedora|ubuntu]`

Notes:
- Supports parallel builds when `parallel` is installed; otherwise runs sequentially (the script hints how to install it).
- Pass `GITHUB_TOKEN` to enable authenticated fetches during container builds.

## 🤖 CI

- Host workflow (`.github/workflows/ci-host.yaml`) installs via `./install.sh` on macOS and Ubuntu (Intel/ARM) and then runs `~/.local/bin/check-dotfiles`.
- Docker workflow (`.github/workflows/ci-docker.yaml`) builds Arch Linux, Fedora, and Ubuntu images for `amd64` and `arm64`, runs the same checks, and can optionally publish images.
  - To publish images manually, trigger the workflow with `workflow_dispatch` and set `publish-image` to `true`.
- WSL workflow (`.github/workflows/ci-wsl.yaml`) provisions Ubuntu 24.04 inside Windows runners, restores cached APT/mise/rustup/cargo/krew/helm downloads, runs `./install.sh`, then `~/.local/bin/check-dotfiles`.
- When adding new top-level paths, update the `dorny/paths-filter` sections in both workflows so CI triggers remain accurate.

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

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [AWS CLI](https://github.com/aws/aws-cli) | Manage AWS services | `mise ✅` (macOS: `system`) | ✅ | ✅ | ✅ | ✅ |
| [Azure CLI](https://github.com/Azure/azure-cli) | Manage Azure resources | `system` | ✅ | ✅ | ✅ | ✅ |

### 🛠 Common CLI

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Bash](https://www.gnu.org/software/bash/) | POSIX shell for scripting | `system` | ✅ | ✅ | ✅ | ✅ |
| [act](https://github.com/nektos/act) | Run GitHub Actions locally | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [bat](https://github.com/sharkdp/bat) | Syntax-aware pager | `system` | ✅ | ✅ | ✅ | ✅ |
| [broot](https://github.com/Canop/broot) | Tree-based directory navigator | `system` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [btop](https://github.com/aristocratos/btop) | Modern resource monitor | `system` | ✅ | ✅ | ✅ | ✅ |
| [GNU Coreutils](https://www.gnu.org/software/coreutils/) | GNU userland tools | `system` | ✅ | ✅ | ✅ | ✅ |
| [chezmoi](https://www.chezmoi.io/) | Manage dotfiles across machines | `system` (Ubuntu via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [croc](https://github.com/schollz/croc) | Secure file transfer | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [curl](https://curl.se/) | HTTP toolkit | `system` | ✅ | ✅ | ✅ | ✅ |
| [direnv](https://github.com/direnv/direnv) | Directory-aware env loader | `system` | ✅ | ✅ | ✅ | ✅ |
| [duf](https://github.com/muesli/duf) | Disk usage overview | `system` | ✅ | ✅ | ✅ | ✅ |
| [dust](https://github.com/bootandy/dust) | du alternative in Rust | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement | `system` | ✅ | ✅ | ✅ | ✅ |
| [fd](https://github.com/sharkdp/fd) | Fast find utility | `system` (`fd-find` on Ubuntu/Fedora) | ✅ | ✅ | ✅ | ✅ |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `system` | ✅ | ✅ | ✅ | ✅ |
| [GitHub CLI](https://github.com/cli/cli) | GitHub command-line client | `system` (`github-cli` on Arch) | ✅ | ✅ | ✅ | ✅ |
| [Git](https://git-scm.com/) | Distributed VCS | `system` | ✅ | ✅ | ✅ | ✅ |
| [delta](https://github.com/dandavison/delta) | Git diff pager | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [GnuPG](https://gnupg.org/) | Encryption and signing | `system` | ✅ | ✅ | ✅ | ✅ |
| [HTTPie](https://github.com/httpie/cli) | Friendly HTTP client | `system` | ✅ | ✅ | ✅ | ✅ |
| [hyperfine](https://github.com/sharkdp/hyperfine) | Command benchmarking | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [jq](https://stedolan.github.io/jq/) | JSON processor | `system` | ✅ | ✅ | ✅ | ✅ |
| [mise](https://github.com/jdx/mise) | Runtime/version manager | `system` (Fedora via bootstrap script) | ✅ | ✅ | ✅ | ✅ |
| [mkcert](https://github.com/FiloSottile/mkcert) | Local TLS certificate generator | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [Neovim](https://github.com/neovim/neovim) | Modal code editor | `system` | ✅ | ✅ | ✅ | ✅ |
| [procs](https://github.com/dalance/procs) | Process viewer | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [rage](https://github.com/str4d/rage) | Age-compatible encryption | `system` (Ubuntu via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [rbw](https://github.com/doy/rbw) | Bitwarden CLI | `system` (Ubuntu via `mise ✅`) | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [rclone](https://rclone.org/) | Cloud storage sync | `system` | ✅ | ✅ | ✅ | ✅ |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Recursive text search | `system` | ✅ | ✅ | ✅ | ✅ |
| [sd](https://github.com/chmln/sd) | Intuitive sed alternative | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer | `system` | ✅ | ✅ | ✅ | ✅ |
| [tokei](https://github.com/XAMPPRocky/tokei) | Code statistics | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [vivid](https://github.com/sharkdp/vivid) | LS_COLORS theme generator | `system` (Ubuntu/Fedora via `mise ✅`) | ✅ | ✅ | ✅ | ✅ |
| [wget](https://www.gnu.org/software/wget/) | Network downloader | `system` | ✅ | ✅ | ✅ | ✅ |
| [Zsh](https://www.zsh.org/) | Advanced shell | `system` | ✅ | ✅ | ✅ | ✅ |

### 🐳 Containers

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [QEMU](https://www.qemu.org/) | Virtualization backend | `system` | ✅ | ❌ | ❌ | ❌ |
| [Colima](https://github.com/abiosoft/colima) | Docker on macOS | `system` | ✅ | ❌ | ❌ | ❌ |
| [Docker Engine](https://www.docker.com/) | Container runtime | `system` (`docker-ce` on Ubuntu/Fedora) | ✅ | ✅ | ✅ | ✅ |
| [Docker Compose](https://docs.docker.com/compose/) | Compose v2 plugin | `system` (`docker-compose-plugin`) | ✅ | ✅ | ✅ | ✅ |
| [Docker Buildx](https://docs.docker.com/build/buildx/) | Extended docker build | `system` (`docker-buildx-plugin`) | ✅ | ✅ | ✅ | ✅ |
| [Dive](https://github.com/wagoodman/dive) | Analyze container layers | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ➕ Extras

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [gocryptfs](https://github.com/rfjakob/gocryptfs) | Encrypted overlay filesystem | `system` (`gocryptfs-mac`) | ✅ | ✅ | ✅ | ✅ |
| [qrencode](https://fukuchi.org/works/qrencode/) | QR code generator | `system` | ✅ | ✅ | ✅ | ✅ |
| [Unison](https://www.cis.upenn.edu/~bcpierce/unison/) | Bi-directional file sync | `system` | ✅ | ✅ | ✅ | ✅ |
| [ZBar](https://github.com/mchehab/zbar) | Barcode scanner CLI | `system` (`zbar-tools` on Ubuntu) | ✅ | ✅ | ✅ | ✅ |

### 🦫 Go Runtime

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Go](https://go.dev/) | Go language toolchain | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🏗 Infrastructure as Code

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Terraform](https://www.terraform.io/) | Provision cloud infrastructure | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Terraform wrapper | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [sops](https://github.com/getsops/sops) | Secrets encryption | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [TFLint](https://github.com/terraform-linters/tflint) | Terraform linting | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [ShellCheck](https://www.shellcheck.net/) | Shell script analyzer | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ☕️ Java Stack

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Apache Ant](https://ant.apache.org/) | Java build system | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Apache Maven](https://maven.apache.org/) | Java dependency manager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [OpenJDK 25](https://openjdk.org/) | Java runtime + compiler | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### ☸️ Kubernetes Core

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [kubesess](https://github.com/Ramilito/kubesess) | Switch kubecontexts quickly | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Helm](https://helm.sh/) | Kubernetes package manager | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [k3d](https://k3d.io/) | Lightweight K3s clusters | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [k9s](https://k9scli.io/) | TUI for Kubernetes | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Kubernetes control plane CLI | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [OpenShift oc](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html) | OpenShift CLI | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kustomize](https://github.com/kubernetes-sigs/kustomize) | YAML customization | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubectx](https://github.com/ahmetb/kubectx) | Context switcher | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubens](https://github.com/ahmetb/kubectx) | Namespace switcher | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [kubecolor](https://github.com/dty1er/kubecolor) | Colorize kubectl output | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [yq](https://github.com/mikefarah/yq) | YAML processor | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Datree](https://github.com/datreeio/datree) | Policy checks for configs | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Popeye](https://github.com/derailed/popeye) | Cluster sanitizer | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [Stern](https://github.com/stern/stern) | Tail multi-pod logs | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [helm-diff](https://github.com/databus23/helm-diff) | Helm release diffing | `helm` | ✅ | ✅ | ✅ | ✅ |
| [helm-secrets](https://github.com/jkroepke/helm-secrets) | Secrets in Helm charts | `helm` | ✅ | ✅ | ✅ | ✅ |

### 🔌 kubectl Plugins

| Plugin | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [access-matrix](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/access-matrix.yaml) | RBAC visibility | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [blame](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/blame.yaml) | Track config authors | `krew` | ✅ | ✅ | ✅ | ✅ |
| [cost](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/cost.yaml) | Estimate cluster spend | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [datree](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/datree.yaml) | Policy validation | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [deprecations](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/deprecations.yaml) | Detect deprecated APIs | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [get-all](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/get-all.yaml) | Dump all resources | `krew` | ✅ | ✅ | ✅ | ✅ |
| [images](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/images.yaml) | List images in cluster | `krew` | ✅ | ✅ | ✅ | ✅ |
| [konfig](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/konfig.yaml) | Merge kubeconfigs | `krew` | ✅ | ✅ | ✅ | ✅ |
| [kubescape](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/kubescape.yaml) | CIS benchmark scanner | `krew` | ✅ | ✅ | ✅ | ✅ |
| [kyverno](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/kyverno.yaml) | Policy CLI | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [modify-secret](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/modify-secret.yaml) | Patch secrets inline | `krew` | ✅ | ✅ | ✅ | ✅ |
| [neat](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/neat.yaml) | Clean manifest output | `krew` | ✅ | ✅ | ✅ | ✅ |
| [node-shell](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/node-shell.yaml) | SSH into nodes | `krew` | ✅ | ✅ | ✅ | ✅ |
| [outdated](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/outdated.yaml) | Detect stale resources | `krew` | ✅ | ✅ | ✅ | ✅ |
| [rbac-tool](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/rbac-tool.yaml) | RBAC visualization | `krew` | ✅ | ✅ | ✅ | ✅ |
| [resource-capacity](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/resource-capacity.yaml) | Capacity overview | `krew` | ✅ | ✅ | ✅ | ✅ |
| [score](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/score.yaml) | Workload scoring | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [slice](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/slice.yaml) | Split big manifests | `krew` | ✅ | ✅ | ✅ | ✅ |
| [sniff](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/sniff.yaml) | Packet capture | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [tree](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/tree.yaml) | Resource hierarchy | `krew` | ✅ | ✅ / ❌ (arm64) | ✅ | ✅ |
| [tunnel](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/tunnel.yaml) | Port-forward helper | `krew` | ✅ | ✅ | ✅ | ✅ |
| [view-allocations](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/view-allocations.yaml) | Allocation heatmap | `krew` | ✅ | ✅ | ✅ | ✅ |
| [who-can](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/who-can.yaml) | RBAC access checks | `krew` | ✅ | ✅ | ✅ | ✅ |

### 🟢 Node.js

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Node.js 22](https://nodejs.org/) | JS runtime + package managers | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

### 🐍 Python

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Python](https://www.python.org/) | Python runtime & pip tooling | `mise ✅` | ✅ | ✅ | ✅ | ✅ |
| [uv](https://github.com/astral-sh/uv) | Fast Python package manager | `mise ✅` (macOS: `system`) | ✅ | ✅ | ✅ | ✅ |

### 🦀 Rust

| Tool | Description | Install | macOS | Ubuntu | Fedora | Arch |
| --- | --- | --- | --- | --- | --- | --- |
| [Rust](https://www.rust-lang.org/) | Rust toolchain (rustup) | `mise ✅` | ✅ | ✅ | ✅ | ✅ |

## 🧰 GUI Apps (macOS)

These desktop apps are installed on macOS via Homebrew casks or the App Store (mas).

### 🍺 Homebrew Casks

| App | Description |
| --- | --- |
| [AnyDesk](https://anydesk.com/) | Remote desktop access |
| [AppCleaner](https://freemacsoft.net/appcleaner/) | Uninstall apps completely |
| [Brave Browser](https://brave.com/) | Privacy-focused web browser |
| [Calibre](https://calibre-ebook.com/) | E-book manager |
| [Cursor](https://www.cursor.com/) | AI-powered code editor |
| [Ghostty](https://ghostty.org/) | GPU-accelerated terminal |
| [Google Drive](https://www.google.com/drive/download/) | Cloud storage desktop client |
| [HandBrake](https://handbrake.fr/) | Video transcoder |
| [IINA](https://iina.io/) | Modern media player |
| [iTerm2](https://iterm2.com/) | Terminal emulator for macOS |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/) | Manage JetBrains IDEs |
| [KeePassXC](https://keepassxc.org/) | Password manager |
| [Keka](https://www.keka.io/) | File archiver |
| [LocalSend](https://localsend.org/) | Local network file transfer |
| [Maccy](https://maccy.app/) | Clipboard manager |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | Remove app leftovers |
| [Rectangle](https://rectangleapp.com/) | Window manager (tiling) |
| [RustDesk](https://rustdesk.com/) | Open-source remote desktop |
| [OnyX](https://www.titanium-software.fr/en/onyx.html) | macOS maintenance utility |
| [Signal](https://signal.org/) | Private messenger |
| [Spotify](https://www.spotify.com/) | Music streaming client |
| [Syncthing](https://syncthing.net/) | Peer-to-peer file sync |
| [Telegram Desktop](https://desktop.telegram.org/) | Telegram client |
| [Transmission](https://transmissionbt.com/) | BitTorrent client |
| [VeraCrypt](https://www.veracrypt.fr/) | Disk encryption |
| [Visual Studio Code](https://code.visualstudio.com/) | Code editor |
| [VLC](https://www.videolan.org/vlc/) | Media player |
| [Warp](https://www.warp.dev/) | Modern terminal |
| [XnView MP](https://www.xnview.com/en/xnviewmp/) | Image viewer and organizer |
| [Yandex Disk](https://disk.yandex.com/) | Cloud storage desktop client |
| [Zoom](https://zoom.us/download) | Video conferencing |
| [Stats](https://github.com/exelban/stats) | Menu bar system monitor |
| [macFUSE](https://github.com/macfuse/macfuse) | Filesystem in userspace support |

### 🍎 App Store (mas)

| App | Description |
| --- | --- |
| [Bitwarden](https://bitwarden.com/) | Password manager |
| [Brother iPrint&Scan](https://apps.apple.com/app/brother-iprint-scan/id1193539993) | Printer/scanner utility |
| [Keynote](https://www.apple.com/keynote/) | Apple presentations |
| [Messenger](https://www.messenger.com/desktop) | Facebook Messenger client |
| [Numbers](https://www.apple.com/numbers/) | Apple spreadsheets |
| [Pages](https://www.apple.com/pages/) | Apple word processor |
| [Slack](https://slack.com/) | Team messaging |
| [Tailscale](https://tailscale.com/) | Mesh VPN client |
| [The Unarchiver](https://theunarchiver.com/) | Archive extractor |
| [WhatsApp](https://www.whatsapp.com/download) | Messenger client |
| [Windows App](https://www.microsoft.com/windows-app) | Microsoft remote desktop |
| [WireGuard](https://www.wireguard.com/) | VPN client |
| [Xcode](https://developer.apple.com/xcode/) | Apple IDE |
