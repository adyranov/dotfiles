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

### AI tooling

The `ai` toolchain gates shared model routing, skills, sandbox configuration,
cloud inference tools, and the nested `pi`, `opencode`, and `omp` agent
toolchains. Two enforcers back every agent; there are no in-agent permission
layers:

- **nono** is the hard host boundary (filesystem, network, process):
  default-deny filesystem grants with deny-over-grant precedence on top of
  non-excludable built-in deny groups (credentials, keychains, shell
  configs/history, browser data), a small command hard core (git force-push,
  keychain mutators, secret exports, global `chezmoi apply`), and proxy-routed
  network egress with domain allow-listing. Git is HTTPS-only; SSH egress is
  blocked. Agents reuse your existing SSH connections: open a master in your
  terminal (`ssh -M -o ControlPersist=yes root@host true`, per your `ControlPath
${SSH_DATA_HOME}/sockets/%C`) and agents ride it by literal socket path,
  `ssh -S "$SSH_DATA_HOME/sockets/<hash>" <host> <cmd>` — agents cannot
  reproduce `%C` (they do not read `~/.ssh/config`), so they discover sockets
  with `ls` and probe each with `ssh -O check` / a `hostname` ride. Only that
  socket dir is granted — no keys, no raw egress; a master must exist first.
- **DCG** (`dcg`) gates destructive-but-normal commands
  (`kubectl delete`, `tofu destroy`, package publishes) through
  chezmoi-managed per-agent hooks. nono hardens the gate: `DCG_*` environment
  is scrubbed, DCG's stores are read-only inside sandboxes, and hook files
  deny agent writes, so approvals happen only outside them.

All rules live once in `home/.chezmoidata/base/ai/`; the data keys mirror the
rendered nono profile sections (`filesystem`, `command_policies`,
`network.allow_domain`) at `~/.config/nono/profiles/`.

When an agent is blocked:

- DCG-blocked command: approve it in your own terminal (`dcg allow …`), then
  the agent retries.
- Blocked network host: nono's audit records the denial; add the domain to the
  network data and apply. Agents never widen their own egress.
- Blocked destination: `chezmoi apply <path>` runs in-sandbox only for
  destinations on the apply allowlist (`[ai.permissions.apply]` in
  `home/.chezmoidata/base/ai/permissions.toml`), which is also where the write
  grants come from. Anything off the list is refused at the filesystem boundary:
  the agent reports the destination, you add it to the data and apply in your
  terminal, and the wider grants attach at sandbox start — so the change lands
  on the agent's next session, never mid-session. Bare and flag-leading applies
  (`chezmoi apply --force`, `mise run apply`, …) stay denied, and security
  destinations, agent runtime configs, rendered shell files, and `run_onchange`
  scripts stay user-applied.

Sandboxed agents get dev-loop parity: `git` resolves to the system binary,
git worktrees live project-local under `.slim/worktrees/`, and
`mise run lint`/`mise run test` run inside the sandbox.

Caveats: on Linux, Landlock denies cover only paths that exist when the
sandbox starts (`capability_elevation` is off). `--no-sandbox` on any agent
launcher skips nono entirely and disarms the DCG guard hooks — debug only,
zero enforcement; such sessions leave no DCG history or nono log, so the agent
transcript is the audit trail. nono command
mediation is PATH-shim based, so a deliberate absolute-path exec bypasses the
command core; DCG's command-text analysis is the complement. The pi agent dirs
are sandbox-writable (upstream lockfile contract), with hook write-protection
as macOS Seatbelt denies and a documented Linux ceiling.

Subagent concurrency defaults to 8 and is preset-specific (personal Qwen: 4);
OpenCode remains uncapped until it exposes a native width limit.

The `agent` launcher runs every agent (`agent pi|omp|oc`, with `opencode` as an
alias), and a zsh completion `_agent` ships with it. Select a profile with
`--profile NAME`, before or after the agent word (`agent --profile core pi
"Hi there"`); positional profile words stay compat aliases, and arguments
after `--` reach the binary verbatim. The launcher is a plain
shell script: each agent's profiles, config dirs, env exports, and scrub lists
are explicit cases in the script, so adding an agent means editing the
launcher, the completion, and the toolchain gates.

#### Credentials

You supply agent credentials through the environment you launch from (`direnv`, a
global export, a prefix) — chezmoi never stores or reads them. nono scrubs every
credential name out of the sandbox and re-injects the real value at egress through
its loopback proxy routes, so the agent holds a phantom token and no value.
Repository scope is the token's own grant: a fine-grained token
per project, enforced by GitHub. Rotation is a new value plus a relaunch. OMP stays
credential-free.

Delegation is one story per host: your terminal keeps the full identity and every
sandbox gets a deliberately scoped subset. On macOS the subset arrives as phantom
tokens — scrubbed values, with the proxy injecting the real credential at egress.
On Linux hosts whose kernel cannot enforce the proxy (stock Ubuntu, WSL2) the
exported provider keys pass through into the agent env, names redacted in the
audit trail, and GitHub is not delegated there: `gh` and git work stay your
terminal's. GitHub delegation rides the project's fine-grained token at the
session-tier `gh` grant, and the macOS keychain is unreachable in-sandbox on
every path, files and Mach IPC. Full permissions exist only outside the sandbox,
launched by a human (`--no-sandbox`).

- Clients that cannot honor a base-URL override (the Gemini family) are listed in
  `env_injected` in `home/.chezmoidata/base/ai/credentials.toml`: their real value
  reaches the agent env, redacted in logs.
- Routes activate only on hosts that enforce the proxy (macOS; Linux once
  `nono setup` reports Landlock per-port enforcement, declared per host). Elsewhere
  the exported provider keys pass through into the agent env (names added to
  `env_injected` per distro overlay, redacted in logs), and the launcher prints the
  mode; on route-capable hosts it also names any route whose credential source is
  missing from that shell.
  `gh` keeps its
  real `hosts.yml` denied and runs from a relocated state dir, and authenticates on the
  phantom `GH_TOKEN`: the egress swap is measured (`gh api /user` returns the account,
  rate limit 5000).
- The store is invisible to agents (`.envrc`, `.env*`, `.direnv/` on the deny
  floor); on Linux, denies cover only paths that exist at sandbox start.
- `--no-sandbox` runs unscrubbed with the real values: debug only. Provider traffic
  crosses the loopback in plaintext and is re-originated as TLS upstream.

#### Engram daemon

Every launch supervises one shared Engram daemon per host: it starts on
demand, is detached (it outlives every agent session), and is restarted
automatically when it fails its health check or the Engram binary changes —
the launcher records the daemon's binary identity (version + resolved path +
mtime) at spawn and compares it on each launch, so a `mise` rebuild or
upgrade restarts the daemon on the next launch. A healthy, current daemon is
left untouched; every profile, including `minimal`, supervises it. Daemons launched
manually with a different argv are outside supervision: they are never
restarted, and a hung manual daemon ends launches in a fail-closed die until
it is cleaned up. `ENGRAM_PORT` / `ENGRAM_URL` override the supervised port
(default `7437`).

#### Pi

- `agent pi` runs the default `factory` profile with Catppuccin. Bare args are
  messages: `agent pi "Hi there"` starts a session with that prompt.
- `agent --profile minimal pi` (or `agent pi minimal`) removes MCP servers and subagents.
- `agent pi factory` carries the Compound Engineering stack: CE skills, the
  `pi-subagents` fleet, `pi-ask-user` questions, and `pi-goal-x` goals.
  Sessions are isolated per profile.
- Ponytail discipline spans pi and OpenCode (core and factory) and OMP's default root.

#### OpenCode

- `agent oc` (alias `agent opencode`) defaults to `factory`; `--no-sandbox`
  skips nono and the DCG guards (debug only).
- OpenCode's bare positional is a **project path**, not a prompt: send prompts
  as `agent oc --prompt "Hi there"` (TUI) or `agent oc run "Hi there"`
  (headless); bare `agent oc hi` makes opencode try to `cd` into `hi`.
- `minimal` uses `~/.config/opencode/opencode.jsonc` with base plugins and
  built-in agents. `core` uses
  `~/.config/opencode/profiles/core/opencode.jsonc` and adds daily-driver
  integrations. `factory` uses
  `~/.config/opencode/profiles/factory/opencode.jsonc` and adds
  oh-my-opencode-slim multi-agent orchestration.
- Every profile exposes the local LLM gateway as `local/<id>`. Catalog and
  engine data live under `[ai.profile.<profile>.serving.local]`.
- Factory workflows can run inside `tmux`; oh-my-opencode-slim supports
  worktree-based execution and caps background fan-out at the active preset's
  limit. Pane spawning does not currently engage on the OpenCode 1.18 host
  line (slim's v2 adapter skips the pane wiring), so background children run
  headless; pane decisions log under
  `~/.local/share/opencode/log/oh-my-opencode-slim.tui-*.log` with reason
  tokens such as `admission-none` or `host-unreachable` — a missing tui log
  means the pane wiring never initialized. Panes are factory-only by design:
  core sessions never load slim.
- Personal routing uses OpenCode Go and OpenAI Codex primary routes with
  DeepSeek fallbacks. Work routing uses GitHub Copilot without fallback arrays.
  oh-my-opencode-slim fallback chains are remote-only; `provider=local` is not
  allowed in fallback entries.

Prerequisites: Node >=20 and OpenCode >=1.4.3.

#### OMP

OMP (oh-my-pi) is installed through the mise GitHub backend
(`github:can1357/oh-my-pi`, unpinned to track upstream). `agent omp` is a thin
wrapper around the shared launcher: it runs omp under the nono sandbox
(`--no-sandbox` is debug-only) and forwards the remaining arguments.
`agent omp --profile NAME` selects a named omp profile through `OMP_PROFILE`
(free-form names; omp relocates its own agent root). Managed routing uses Luna as
the primary/orchestrator model, Terra as the oracle/advisor, and DeepSeek v4
flash for task workers, with OMP subagents surfaced through OMP's native
task/session UI rather than automatic tmux or Herdr panes. Its config root is
`~/.config/omp` and the agent root (config, auth, extensions) is
`~/.config/omp/agent`; the legacy `~/.omp` path is a managed symlink.
The managed skills tree loads the Compound Engineering skills and the ponytail
discipline skill via `skills.customDirectories`. Authenticate
separately with `omp /login`.

#### Cloud inference

SkyPilot task YAMLs and RunPod settings are managed under
`~/.config/skypilot/` and `~/.config/runpod/` when the `ai` toolchain is enabled.
Run `runpod config` before using RunPod, then launch catalog tasks with
`skyl <category/task> [sky launch flags]`. Persistent RunPod volumes are opt-in
under `[skypilot.base.runpod]` in
`home/.chezmoidata/base/skypilot/tasks.toml`; the volume and GPU pod must use the
same RunPod zone.

### Local and remote model serving

**`llm-serve`** is the local OpenAI-compatible gateway on
`http://127.0.0.1:8321/v1`. Model data lives in
`home/.chezmoidata/base/ai/models.toml`; profile overrides live in
`home/.chezmoidata/profile/<profile>/models.toml`.

- `llm-serve` — start in the foreground (Ctrl-C to stop)
- `llm-serve start` — start in the background
- `llm-serve stop` / `restart` / `status` / `list` / `logs`
- `llm-pull` — download missing local model weights and report stale GGUF caches
- `llm-bench [model ...]` — warm and benchmark local models with AIPerf

Serving providers live under `ai.serving.<id>`. The `local`
provider (`kind = "local"`) drives `llm-serve`; a remote endpoint is a
`kind = "openai-compatible"` provider with a `base_url` and explicit nested
models, for example:

```toml
[ai.profile.personal.serving.infer01]
kind = "openai-compatible"
base_url = "http://infer01:8080/v1"

[[ai.profile.personal.serving.infer01.models]]
id = "qwen3.8-flash-next"
```

OpenCode, Pi, and OMP read the same provider/models and selected preset. The
selected preset is `ai.presets.default` (default `balanced`); set
`ai.profile.<profile>.presets.default = "qwen"` to route roles to Qwen.
Apply the managed OpenCode, Pi, and OMP configuration files and restart those
clients; set the value back to `balanced` to revert. OpenCode's runtime
`/preset` is a client-local override and does not update the shared TOML, Pi, or
OMP. Remote endpoints are keyless and assumed to be on a trusted private
network.

If the server changes the model served under an existing ID, refresh its static
metadata before applying. When removing an endpoint, also remove its
`infer01:8080` network allow from the per-agent configuration, re-apply, and
restart the affected agents so the rendered nono profiles under
`~/.config/nono/profiles/` are refreshed; there is no separate rules API or
dashboard to clean.

| Host           | Default engine                             | Notes                                                                                     |
| -------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------- |
| darwin / arm64 | profile (`serving.providers.local.engine`) | Installs oMLX and tap-backed `adyranov/tap/llama-cpp`; runtime picks `omlx` or `llamacpp` |
| darwin / amd64 | `llamacpp`                                 | `adyranov/tap/llama-cpp`; native llama.cpp router mode                                    |
| Linux / WSL2   | `llamacpp`                                 | mise `llama.cpp` native router mode                                                       |

Set `engine = "omlx"` or `engine = "llamacpp"` under
`[ai.profile.<profile>.serving.local]`. Each local model must
declare the matching backend (`mlx` or `gguf`). Qwen 3.5+ GGUF models
auto-attach the froggeric chat template. Use `llm-pull` to download weights, then
`chezmoi apply` to sync model symlinks and llama.cpp router presets.

Local model defaults are profile-specific and sized for each host class with
practical context windows rather than maximum possible limits. Use `llm-bench` to
evaluate alternatives for the current machine.

### Editor extensions

- VS Code and Cursor share settings/keybindings defined in
  `home/.chezmoidata/base/editors.toml` and rendered through editor templates.
- Extensions are installed by
  `home/.chezmoiscripts/common/run_onchange_after_36_install-editor-extensions.sh.tmpl`
  when the extension or settings list changes.

### XDG-first layout

- Exports file: shell environment is centralized in `~/.config/shell/exports.sh` (assembled from modular `exports.d/` fragments) to enforce XDG base directories across tools.
- An XDG migration planner
  (`home/.chezmoiscripts/before/run_onchange_before_05_xdg-migration-plan.sh.tmpl`)
  prints suggested `mv` commands when legacy dotfile paths are detected; it
  never modifies files itself.
- Smart completions: Zsh completions for kubectl, mise, tofu, etc., are automatically generated and synced with tool versions via `run_onchange` hashing.
- Moved dotfiles: bash/zsh history and sessions, npm cache/prefix, cargo/rustup, gradle, krew, pass, wget, readline, less, svn, git excludes, asdf files, and more are redirected under the XDG tree.
- Atuin is the default Zsh history backend. Legacy zsh history can be imported manually with `HISTFILE=... atuin import zsh`.
- Mac and Linux behave the same; `$XDG_RUNTIME_DIR` is set per host type (macOS uses `$TMPDIR`).
- Preview removals after migrating: `chezmoi --remove --dry-run apply` shows legacy dotfiles ready to prune.

### Catppuccin Mocha theming

A unified **Catppuccin Mocha** color scheme is applied across all terminal
tools. Per-tool `.chezmoiexternal.toml.tmpl` files track upstream default
branches and refresh them weekly without GitHub API tag lookups. Themed
tools include: bat, btop, delta (git), fzf, ghostty, k9s, lazygit, LS_COLORS
(vivid), tmux, yazi, zsh-syntax-highlighting, and atuin.

### macOS Launch Agents

- Managed agents live under `home/private_Library/LaunchAgents` (rendered to `~/Library/LaunchAgents`).
- Launch agents are reloaded by
  `home/.chezmoiscripts/os/darwin/run_onchange_after_20_bootstrap-launch-agents.tmpl`
  after macOS defaults in
  `home/.chezmoiscripts/os/darwin/run_onchange_after_10_configure-darwin.tmpl`.
- Non-macOS hosts ignore `home/private_Library/**` via template guards so Linux/WSL environments stay clean.

See examples in `home/.chezmoidata/base/`, `home/.chezmoidata/os/<distro>/`, and `home/.chezmoidata/profile/<profile>/`.

## 🧪 Validate Locally

- After applying dotfiles, run `mise run test` — the single fast gate: generated Bats tests for system packages, `mise` tools, Helm and Krew plugins, AI agents (including the DCG robot probes, whose probes fail — never skip — when the pinned dcg binary or rendered packs are missing; the suite is unapplied when the ai toolchain is off), plus shell/Git config checks. The whole suite is expected to finish well under two minutes.
- Each package/manager suite runs one aggregate install smoke that checks all
  applicable package keys in a single pass; failures report every offending
  package (name + exit status) at once. Presence and runnability only — no
  version-value assertions.
- Run package-key checks with `check-dotfiles kubectl helm` (or
  `mise run test kubectl helm`): the aggregate smoke runs filtered to exactly
  those keys. Tag-scoped runs (e.g. `--tag toolchain:kubernetes`) execute the
  whole manager aggregate unfiltered — only bare keys filter keys.
- The test runner lives at `~/.local/share/dotfiles/test/check-dotfiles.sh` and is symlinked to `~/.local/bin/check-dotfiles`. `check-dotfiles` requires `gtimeout`/`timeout` (GNU coreutils; macOS: `brew install coreutils`).
- All suites run in parallel by default (auto-detects CPU count). Use `-j1` for sequential/debug mode.
- Run specific suites: `check-dotfiles --suite config` or `check-dotfiles --suite config,ai`.
- Filter by tag: `check-dotfiles --tag toolchain:kubernetes`.
- Filter by test name regex: `check-dotfiles --filter 'git config'`.
- List all discovered tests: `check-dotfiles --list`.
- Bats and its plugins (`bats-assert`, `bats-support`, `bats-file`) track their
  upstream default branches via `.chezmoiexternal.toml.tmpl`.

## 🧑‍💻 Development

- Unified entry point: this project uses **mise tasks** for orchestration.
- Bootstrap development environment: `mise run bootstrap` (installs `pre-commit` and `commit-msg` Git hooks).
- Run linting/validations: `mise run lint` (runs the `pre-commit` stage with `PRE_COMMIT_COLOR=never` for readable status labels; commit messages are checked by the installed `commit-msg` hook).
- Build test containers: `mise run build-containers`.
- Project layout follows chezmoi conventions. See `home/` for source state,
  `home/.chezmoidata/**` for layered data, and
  `home/.chezmoitemplates/{base,os}/**` for reusable templates.
- Line endings are enforced via `.gitattributes` (LF for Unix tooling, CRLF for Windows scripts). Keep new files consistent with these defaults.
- Maintainers: see `AGENTS.md` for contributor guidelines and CI expectations.

## 🛠 Init & Customization

- First run is interactive: you’ll be prompted for Git identity, environment profile, restricted-mode behavior, and which toolchains to enable.
- Non-interactive/headless: control toolchains via env vars before running `chezmoi init`/`apply`:
  - Enable specific: `WITH_DOCKER=true WITH_KUBERNETES=true`
  - Disable specific: `WITHOUT_JAVA=true WITHOUT_NODE=true`
  - Disable all then opt-in: `WITHOUT_TOOLCHAINS=true WITH_PYTHON=true`
  - AI agents (nested under `ai`): `WITH_PI=true`, `WITH_OPENCODE=true`, or
    `WITH_OMP=true`; each also supports the corresponding `WITHOUT_*` variable.
- Environment detection:
  - Ephemeral/container environments are auto-detected and tagged as `ephemeral`.
  - Non-interactive sessions set `.host.interactive = false` (treated as `headless` in package rules).
  - macOS Intel/Apple Silicon and Linuxbrew brew paths are auto-detected and exported for templates.
- macOS applies a generated CA bundle at `~/.config/certificates/ca-bundle.pem` from trusted system keychain certificates.

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
- `GITHUB_TOKEN` is optional for authenticated fetches during container builds;
  ordinary `chezmoi diff` and `chezmoi apply` do not require it.

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
- When adding new top-level paths, update the `dorny/paths-filter`
  configuration in `.github/workflows/ci.yaml` so triggers remain accurate.

## 🖥 Supported Platforms

- 🍎 macOS (arm64 via Homebrew; x86_64 via MacPorts and mise, with Homebrew for `mas` and casks).
- 🐧 Ubuntu (amd64 primary, arm64 best-effort with per-tool exclusions).
- 🦬 Fedora (amd64 focus, arm64 best-effort) via dnf.
- 🎯 Arch Linux (amd64 & arm64) via pacman.
- 💻 WSL inherits the Linux profiles; tailor overrides through `.chezmoidata`.

## 🧭 Install Manager Legend

- `system` → Default native manager (Homebrew on arm64 Darwin, MacPorts on Intel; apt, dnf, pacman on Linux).
- `brew` → Homebrew formulae and casks on arm64 Darwin; on Intel only the `mas` formula and casks are available.
- `macports` → Verified MacPorts ports on Intel macOS.
- `mise` → [mise](https://github.com/jdx/mise) runtime manager and UBI packages.
- `krew` → [Krew](https://krew.sigs.k8s.io/) kubectl plugin manager.
- `helm` → [Helm](https://helm.sh/) plugin manager.

## 🧰 Toolchains & Tools

This inventory covers user-facing tools; service and support packages are
omitted. Columns show macOS, Ubuntu, Fedora, and Arch Linux coverage. `✅` means
the tool is provisioned on all architectures for that OS; `❌ (arch)` flags a
missing architecture. The Install column highlights when `mise` is responsible
(`mise ✅`); otherwise the selected native manager or plugin manager is used.
Portable tools use `mise` where a base definition exists; tap-backed formulae
remain arm64-only Homebrew integrations, while GUI applications remain
Homebrew casks. App Store applications use `mas`.
Legacy table annotations that say `system` refer to the native provider; on
Darwin that provider is now resolved as `macports` on Intel and `brew` on arm64
unless the package explicitly selects another manager.

Current Darwin exceptions are explicit in `.chezmoidata`: portable CLI tools
use `mise`, Intel macOS uses MacPorts for system packages but Homebrew for
`mas` and casks, tap-backed AI and hardware tools use Homebrew only on arm64,
and `rage` remains a mise tool bootstrapped before source decryption.
Installomator and direct DMG/PKG installers are deferred.

### ☁️ Cloud

| Tool                                            | Description            | Install                     | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------------- | ---------------------- | --------------------------- | ----- | ------ | ------ | ---- |
| [AWS CLI](https://github.com/aws/aws-cli)       | Manage AWS services    | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [Azure CLI](https://github.com/Azure/azure-cli) | Manage Azure resources | `system`                    | ✅    | ✅     | ✅     | ✅   |

### 🛠 Common CLI

| Tool                                                                  | Description                             | Install                                 | macOS | Ubuntu | Fedora | Arch |
| --------------------------------------------------------------------- | --------------------------------------- | --------------------------------------- | ----- | ------ | ------ | ---- |
| [Atuin](https://github.com/atuinsh/atuin)                             | Shell history sync and search           | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [Bash](https://www.gnu.org/software/bash/)                            | POSIX shell for scripting               | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [bat](https://github.com/sharkdp/bat)                                 | Syntax-aware pager                      | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [btop](https://github.com/aristocratos/btop)                          | Modern resource monitor                 | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [chezmoi](https://www.chezmoi.io/)                                    | Manage dotfiles across machines         | `system` (Ubuntu via `mise ✅`)         | ✅    | ✅     | ✅     | ✅   |
| [curl](https://curl.se/)                                              | HTTP toolkit                            | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [dcg](https://github.com/Dicklesworthstone/destructive_command_guard) | Destructive command guard               | `mise ✅`                               | ✅    | ✅     | ✅     | ✅   |
| [delta](https://github.com/dandavison/delta)                          | Git diff pager                          | `system` (Ubuntu via `mise ✅`)         | ✅    | ✅     | ✅     | ✅   |
| [difftastic](https://github.com/Wilfred/difftastic)                   | Structural diff tool                    | `mise ✅` (macOS/Fedora/Arch: `system`) | ✅    | ✅     | ✅     | ✅   |
| [direnv](https://github.com/direnv/direnv)                            | Directory-aware env loader              | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [doggo](https://github.com/mr-karan/doggo)                            | Modern DNS client                       | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [dust](https://github.com/bootandy/dust)                              | du alternative in Rust                  | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [eza](https://github.com/eza-community/eza)                           | Modern ls replacement                   | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [fd](https://github.com/sharkdp/fd)                                   | Fast find utility                       | `system` (`fd-find` on Ubuntu/Fedora)   | ✅    | ✅     | ✅     | ✅   |
| [fzf](https://github.com/junegunn/fzf)                                | Fuzzy finder                            | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [Git](https://git-scm.com/)                                           | Distributed VCS                         | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [GitHub CLI](https://github.com/cli/cli)                              | GitHub command-line client              | `system` (`github-cli` on Arch)         | ✅    | ✅     | ✅     | ✅   |
| [Glow](https://github.com/charmbracelet/glow)                         | Markdown renderer in terminal           | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [GNU Coreutils](https://www.gnu.org/software/coreutils/)              | GNU userland tools                      | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [GnuPG](https://gnupg.org/)                                           | OpenPGP encryption toolkit              | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [hyperfine](https://github.com/sharkdp/hyperfine)                     | Command benchmarking                    | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [jnv](https://github.com/ynqa/jnv)                                    | Interactive JSON viewer with jq         | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [jq](https://stedolan.github.io/jq/)                                  | JSON processor                          | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [lazygit](https://github.com/jesseduffield/lazygit)                   | Terminal UI for Git                     | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [mise](https://github.com/jdx/mise)                                   | Runtime/version manager                 | `system` (Fedora via bootstrap script)  | ✅    | ✅     | ✅     | ✅   |
| [mkcert](https://github.com/FiloSottile/mkcert)                       | Local TLS certificate generator         | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [Neovim](https://github.com/neovim/neovim)                            | Modal code editor                       | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [nono](https://github.com/nolabs-ai/nono)                             | Host filesystem/network/process sandbox | `mise ✅`                               | ✅    | ✅     | ✅     | ✅   |
| [OpenSSH](https://www.openssh.com/)                                   | SSH client and agent                    | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [ouch](https://github.com/ouch-org/ouch)                              | Painless compression                    | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [rage](https://github.com/str4d/rage)                                 | Age-compatible encryption               | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [rclone](https://rclone.org/)                                         | Cloud storage sync                      | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [ripgrep](https://github.com/BurntSushi/ripgrep)                      | Recursive text search                   | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [sd](https://github.com/chmln/sd)                                     | Intuitive sed alternative               | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [tealdeer](https://github.com/dbrgn/tealdeer)                         | Fast tldr client                        | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [tmux](https://github.com/tmux/tmux)                                  | Terminal multiplexer                    | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [topgrade](https://github.com/topgrade-rs/topgrade)                   | System-wide upgrader                    | `mise ✅` (macOS: `system`)             | ✅    | ✅     | ✅     | ✅   |
| [vivid](https://github.com/sharkdp/vivid)                             | LS_COLORS theme generator               | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [wget](https://www.gnu.org/software/wget/)                            | Network downloader                      | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [xh](https://github.com/ducaale/xh)                                   | Friendly HTTP client in Rust            | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [Yazi](https://github.com/sxyazi/yazi)                                | Fast terminal file manager              | `mise ✅` (macOS/Arch: `system`)        | ✅    | ✅     | ✅     | ✅   |
| [zoxide](https://github.com/ajeetdsouza/zoxide)                       | Smarter cd command                      | `system`                                | ✅    | ✅     | ✅     | ✅   |
| [Zsh](https://www.zsh.org/)                                           | Advanced shell                          | `system`                                | ✅    | ✅     | ✅     | ✅   |

### 🐳 Containers

| Tool                                                      | Description              | Install                                 | macOS | Ubuntu | Fedora | Arch |
| --------------------------------------------------------- | ------------------------ | --------------------------------------- | ----- | ------ | ------ | ---- |
| [Docker Engine](https://www.docker.com/)                  | Container runtime        | `system` (`docker-ce` on Ubuntu/Fedora) | ✅    | ✅     | ✅     | ✅   |
| [Docker Compose](https://docs.docker.com/compose/)        | Compose v2 plugin        | `system` (`docker-compose-plugin`)      | ✅    | ✅     | ✅     | ✅   |
| [Docker Buildx](https://docs.docker.com/build/buildx/)    | Extended docker build    | `system` (`docker-buildx-plugin`)       | ✅    | ✅     | ✅     | ✅   |
| [Dive](https://github.com/wagoodman/dive)                 | Analyze container layers | `mise ✅` (macOS: `system`)             | ✅    | ✅     | ✅     | ✅   |
| [LazyDocker](https://github.com/jesseduffield/lazydocker) | TUI for Docker           | `mise ✅`                               | ✅    | ✅     | ✅     | ✅   |

### ➕ Extras

| Tool                                                              | Description                       | Install                    | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------------------------------- | --------------------------------- | -------------------------- | ----- | ------ | ------ | ---- |
| [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey) | YubiKey plugin for age encryption | `system`                   | ✅    | ❌     | ❌     | ❌   |
| [bubblewrap](https://github.com/containers/bubblewrap)            | Unprivileged sandboxing           | `system`                   | ❌    | ✅     | ✅     | ✅   |
| [gocryptfs](https://github.com/rfjakob/gocryptfs)                 | Encrypted overlay filesystem      | `system` (`gocryptfs-mac`) | ✅    | ✅     | ✅     | ✅   |
| [mas](https://github.com/mas-cli/mas)                             | Mac App Store CLI                 | `brew`                     | ✅    | ❌     | ❌     | ❌   |
| [OpenSC](https://github.com/OpenSC/OpenSC)                        | Smart card middleware             | `system`                   | ✅    | ❌     | ❌     | ❌   |
| [pam-u2f](https://github.com/Yubico/pam-u2f)                      | U2F PAM module                    | `system`                   | ✅    | ❌     | ❌     | ❌   |
| [qrencode](https://fukuchi.org/works/qrencode/)                   | QR code generator                 | `system`                   | ✅    | ✅     | ✅     | ✅   |
| [socat](http://www.dest-unreach.org/socat/)                       | Multipurpose socket relay         | `system`                   | ❌    | ✅     | ✅     | ✅   |
| [YubiKey Manager](https://github.com/Yubico/yubikey-manager)      | YubiKey configuration tool        | `system`                   | ✅    | ❌     | ❌     | ❌   |

### 🦫 Go Runtime

| Tool                  | Description           | Install   | macOS | Ubuntu | Fedora | Arch |
| --------------------- | --------------------- | --------- | ----- | ------ | ------ | ---- |
| [Go](https://go.dev/) | Go language toolchain | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### 🏗 Infrastructure as Code

| Tool                                                     | Description                | Install                     | macOS | Ubuntu | Fedora | Arch |
| -------------------------------------------------------- | -------------------------- | --------------------------- | ----- | ------ | ------ | ---- |
| [OpenTofu](https://opentofu.org/)                        | Open source Terraform fork | `mise ✅`                   | ✅    | ✅     | ✅     | ✅   |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Terraform wrapper          | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |
| [sops](https://github.com/getsops/sops)                  | Secrets encryption         | `mise ✅` (macOS: `system`) | ✅    | ✅     | ✅     | ✅   |

### ☕️ Java Stack

| Tool                                      | Description             | Install   | macOS | Ubuntu | Fedora | Arch |
| ----------------------------------------- | ----------------------- | --------- | ----- | ------ | ------ | ---- |
| [Apache Maven](https://maven.apache.org/) | Java dependency manager | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
| [OpenJDK (LTS)](https://openjdk.org/)     | Java runtime + compiler | `mise ✅` | ✅    | ✅     | ✅     | ✅   |

### ☸️ Kubernetes Core

| Tool                                                                                                            | Description                  | Install                     | macOS | Ubuntu          | Fedora | Arch |
| --------------------------------------------------------------------------------------------------------------- | ---------------------------- | --------------------------- | ----- | --------------- | ------ | ---- |
| [kubesess](https://github.com/Ramilito/kubesess)                                                                | Switch kubecontexts quickly  | `mise ✅`                   | ✅    | ✅              | ✅     | ✅   |
| [Helm](https://helm.sh/)                                                                                        | Kubernetes package manager   | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [k3d](https://k3d.io/)                                                                                          | Lightweight K3s clusters     | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [k9s](https://k9scli.io/)                                                                                       | TUI for Kubernetes           | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/)                                                        | Kubernetes control plane CLI | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [kustomize](https://github.com/kubernetes-sigs/kustomize)                                                       | YAML customization           | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [kubecolor](https://github.com/dty1er/kubecolor)                                                                | Colorize kubectl output      | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [Kubescape](https://github.com/kubescape/kubescape)                                                             | CIS and risk scanner         | `mise ✅`                   | ✅    | ✅              | ✅     | ✅   |
| [yq](https://github.com/mikefarah/yq)                                                                           | YAML processor               | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [Stern](https://github.com/stern/stern)                                                                         | Tail multi-pod logs          | `mise ✅` (macOS: `system`) | ✅    | ✅              | ✅     | ✅   |
| [helm-diff](https://github.com/databus23/helm-diff)                                                             | Helm release diffing         | `helm`                      | ✅    | ✅              | ✅     | ✅   |
| [oc](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html) | OpenShift CLI                | `mise ✅` (macOS: `system`) | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |

### 🔌 kubectl Plugins

| Plugin                                                                                                | Description           | Install | macOS | Ubuntu          | Fedora | Arch |
| ----------------------------------------------------------------------------------------------------- | --------------------- | ------- | ----- | --------------- | ------ | ---- |
| [access-matrix](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/access-matrix.yaml) | RBAC visibility       | `krew`  | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |
| [get-all](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/get-all.yaml)             | Dump all resources    | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [neat](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/neat.yaml)                   | Clean manifest output | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [node-shell](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/node-shell.yaml)       | SSH into nodes        | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [rbac-tool](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/rbac-tool.yaml)         | RBAC visualization    | `krew`  | ✅    | ✅              | ✅     | ✅   |
| [tree](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins/tree.yaml)                   | Resource hierarchy    | `krew`  | ✅    | ✅ / ❌ (arm64) | ✅     | ✅   |

### 🟢 Node.js

| Tool                                 | Description                   | Install   | macOS | Ubuntu | Fedora | Arch |
| ------------------------------------ | ----------------------------- | --------- | ----- | ------ | ------ | ---- |
| [Bun](https://bun.sh/)               | Fast JS runtime and bundler   | `mise ✅` | ✅    | ✅     | ✅     | ✅   |
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

### 🤖 AI and inference

| Tool                                                                | Description                       | Install                     | macOS            | Ubuntu | Fedora | Arch |
| ------------------------------------------------------------------- | --------------------------------- | --------------------------- | ---------------- | ------ | ------ | ---- |
| [AIPerf](https://github.com/ai-dynamo/aiperf)                       | LLM endpoint benchmarking         | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [codegraph](https://github.com/colbymchenry/codegraph)              | MCP code intelligence             | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [Engram](https://github.com/Gentleman-Programming/engram)           | Agent memory and MCP server       | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [Hugging Face CLI](https://huggingface.co/docs/huggingface_hub/)    | Model download and repository CLI | `mise ✅` (macOS: `system`) | ✅               | ✅     | ✅     | ✅   |
| [llama.cpp](https://github.com/ggml-org/llama.cpp)                  | Local GGUF inference server       | `mise ✅` (macOS: `system`) | ✅               | ✅     | ✅     | ✅   |
| [oMLX](https://github.com/jundot/omlx)                              | Local Apple Silicon inference     | `system`                    | ✅ / ❌ (x86_64) | ❌     | ❌     | ❌   |
| [OMP](https://omp.sh)                                               | oh-my-pi coding agent             | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [OpenCode](https://opencode.ai)                                     | Terminal coding agent             | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [Pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) | Terminal coding agent             | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [RunPod](https://www.runpod.io/)                                    | Cloud GPU provider CLI            | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |
| [SkyPilot](https://docs.skypilot.co/)                               | Multi-cloud workload launcher     | `mise ✅`                   | ✅               | ✅     | ✅     | ✅   |

## 🧰 GUI Apps (macOS)

These desktop apps are installed on macOS via Homebrew casks or the App Store
(`mas`). Installomator and direct vendor installers are intentionally deferred.

### 🍺 Homebrew Casks

| App                                                                    | Description                         |
| ---------------------------------------------------------------------- | ----------------------------------- |
| [AnyDesk](https://anydesk.com/)                                        | Remote desktop access               |
| [Brave Browser](https://brave.com/)                                    | Privacy-focused web browser         |
| [Calibre](https://calibre-ebook.com/)                                  | E-book manager                      |
| [Cryptomator](https://cryptomator.org/)                                | Cloud storage encryption            |
| [Cursor](https://www.cursor.com/)                                      | AI-powered code editor              |
| [draw.io Desktop](https://www.diagrams.net/)                           | Diagram editor                      |
| [Ghostty](https://ghostty.org/)                                        | GPU-accelerated terminal            |
| [Google Drive](https://www.google.com/drive/download/)                 | Cloud storage desktop client        |
| [HandBrake](https://handbrake.fr/)                                     | Video transcoder                    |
| [IINA](https://iina.io/)                                               | Modern media player                 |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/)            | Manage JetBrains IDEs               |
| [Ice](https://icemenubar.app/)                                         | Menu bar manager                    |
| [KeePassXC](https://keepassxc.org/)                                    | Password manager                    |
| [Keka](https://www.keka.io/)                                           | File archiver                       |
| [Kindle Previewer](https://kdp.amazon.com/en_US/help/topic/G202131170) | E-book preview tool                 |
| [LocalSend](https://localsend.org/)                                    | Local network file transfer         |
| [LuLu](https://objective-see.org/products/lulu.html)                   | Outbound firewall                   |
| [Maccy](https://maccy.app/)                                            | Clipboard manager                   |
| [macFUSE](https://github.com/macfuse/macfuse)                          | Filesystem in userspace support     |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl)     | External display controls           |
| [OnyX](https://www.titanium-software.fr/en/onyx.html)                  | macOS maintenance utility           |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner)              | Remove app leftovers                |
| [Rancher Desktop](https://rancherdesktop.io/)                          | Container management and Kubernetes |
| [Rectangle](https://rectangleapp.com/)                                 | Window manager                      |
| [RustDesk](https://rustdesk.com/)                                      | Open-source remote desktop          |
| [Signal](https://signal.org/)                                          | Private messenger                   |
| [Spotify](https://www.spotify.com/)                                    | Music streaming client              |
| [Stats](https://github.com/exelban/stats)                              | Menu bar system monitor             |
| [Syncthing](https://syncthing.net/)                                    | Peer-to-peer file sync              |
| [Telegram Desktop](https://desktop.telegram.org/)                      | Telegram client                     |
| [tinyMediaManager](https://www.tinymediamanager.org/)                  | Media file organizer                |
| [Tor Browser](https://www.torproject.org/)                             | Privacy browser                     |
| [Transmission](https://transmissionbt.com/)                            | BitTorrent client                   |
| [VeraCrypt](https://www.veracrypt.fr/)                                 | Disk encryption                     |
| [Visual Studio Code](https://code.visualstudio.com/)                   | Code editor                         |
| [XnView MP](https://www.xnview.com/en/xnviewmp/)                       | Image viewer and organizer          |
| [Yandex Disk](https://disk.yandex.com/)                                | Cloud storage desktop client        |
| [Zoom](https://zoom.us/download)                                       | Video conferencing                  |

### 🍎 App Store (mas)

| App                                                                                | Description              |
| ---------------------------------------------------------------------------------- | ------------------------ |
| [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)                  | Keep-awake utility       |
| [Brother iPrint&Scan](https://apps.apple.com/app/brother-iprint-scan/id1193539993) | Printer/scanner utility  |
| [CotEditor](https://apps.apple.com/app/coteditor/id1024640650)                     | Plain text editor        |
| [Keynote](https://www.apple.com/keynote/)                                          | Apple presentations      |
| [Numbers](https://www.apple.com/numbers/)                                          | Apple spreadsheets       |
| [Pages](https://www.apple.com/pages/)                                              | Apple word processor     |
| [Slack](https://slack.com/)                                                        | Team messaging           |
| [Tailscale](https://tailscale.com/)                                                | Mesh VPN client          |
| [WhatsApp](https://www.whatsapp.com/download)                                      | Messenger client         |
| [Windows App](https://www.microsoft.com/windows-app)                               | Microsoft remote desktop |
| [WireGuard](https://www.wireguard.com/)                                            | VPN client               |
| [Xcode](https://developer.apple.com/xcode/)                                        | Apple IDE                |
