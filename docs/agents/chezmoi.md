# Chezmoi layout and data

Read this before editing anything under `home/`; AI-specific paths also need `ai-stack.md`.

- **Docs**: Consult `https://www.chezmoi.io/`. Assume undocumented features are unsupported.
- **Source root**: `.chezmoiroot` is `home`; files outside `home/` (this directory included) are never applied.
- **Data Schema**: Non-package domains use flat TOML under `home/.chezmoidata/` (`ai/`, `brew.toml`, `editors.toml`, `repositories.toml`) with zero template directives — templates read `.ai.*`, `.brew.*`, `.editors.*`, `.repositories.*` directly. Package catalogs remain layered (`base/packages/*.toml` + `os/<distro>/packages.toml`) and are queried via `base/packages/walk` + `select`.
- **Externals**: Centralized under `home/.chezmoiexternals/` (`fonts.toml.tmpl`, `themes.toml.tmpl`, `ai.toml.tmpl`); avoid scattered per-directory `.chezmoiexternal.toml.tmpl` files.
- **Host data**: `home/.chezmoi.yaml.tmpl` is the config template (rendered only by `chezmoi init`); host detection lives in `base/helpers/detect-host`. A change there needs the user to re-run `chezmoi init`.
- **Template Layout**: `base/` contains shared partials; `os/<distro>/` contains distro-specific partials. Shared scripts live under `.chezmoiscripts/common/`. Prefer static files (reading a small rendered JSON config at runtime) over heavy `.tmpl` scripts.
- **Decoupled Upgrades**: `chezmoi apply` converges configuration and installs missing packages; bulk upgrades (`topgrade`, `mise upgrade`, `brew upgrade`, `nono pull`) run explicitly via `mise run update`. Exception: Arch Linux runs `pacman -Syu` during apply because Arch does not support partial upgrades.
- **Toolchains**: `core` is implicitly enabled and always on. Other toolchain labels select their package/data overlays.
- **Manager Policy**: mise is the default for user-space CLIs (explicit `manager = "mise"`); system managers serve bootstrap, OS-integrated packages, and targets where the backend has no usable build or asset — backend metadata (e.g. aqua `supported_ifs`) can gate a platform even when upstream ships binaries, so keep such hosts on `system` via a `variants` entry with a why-comment.
- **Version Pinning**: Packages track the latest release; add `pin` only when absolutely necessary (a security-relevant or load-bearing behavior that must not drift). A necessary pin carries a comment in the package entry naming the dependency and is bumped with a host-terminal probe pass (run the pinned binary's probe commands outside the sandbox). nono and its upstream packs track latest.
- **Automatic Updates Everywhere (policy)**: Tools, plugins, integrations, and fetched libraries track upstream latest by default — unpinned packages and plugin entries, `@latest` metadata/schema URLs, default-branch refs, and upstream self-update mechanisms left enabled. This is deliberate: do not add pins, tag-pins, or disable self-updates as a reflex — upstream best-practice advice to pin is overridden here, and the Version Pinning exception above applies only where the user has explicitly deemed a pin necessary.
- **Home Mapping**: Source attributes such as `dot_`, `private_`, `exact_`, `executable_`, `modify_`, and `symlink_` map to chezmoi target states; prefer source attributes over raw files (for example, `private_` for mode 600 and `executable_` for mode 755). `.tmpl` files render through templates.
- **OS Support**: Supported distros: `darwin`, `ubuntu`, `fedora`, `archlinux`.
- **Chezmoi templates**: Prefer data-driven logic over Go template branching.
- **TOML**: Alphabetize keys, use `lower_snake_case` for custom data keys. Entity identifiers (provider/model/package names such as `github-copilot`, `openai.default`) are *values*, not keys, and may be kebab-case or dotted. Package keys follow upstream naming (hyphens allowed).
- **Removals**: `home/.chezmoiremove.tmpl` enforces removals automatically on apply; preview with `chezmoi apply --dry-run`.
