# Tests and validation

Read this before writing or changing tests in `tests/*.bats` (repo-only Bats specs; never deployed to `$HOME`).

Keep created tests concise and behavior-focused. Prefer a few high-value invariants or smoke tests over exhaustive assertions against generated configuration. Do not duplicate source data in tests or snapshot fields owned by upstream schemas unless guarding a specific regression.

- **Corner cases, not combinations:** test invariants and corner cases, never every combination of every parameter. Package install coverage is one aggregate smoke in `tests/packages.bats` that reports all offenders in a single pass; keep standalone tests only for corner cases (architecture/manager routing, Brewfile rejections, render failures, OAuth/parity invariants).
- **Timeouts are mandatory**: `mise run test` hard-caps runs at 120s wall clock with a 10s kill-after (`CHECK_DOTFILES_SUITE_TIMEOUT` overrides); a suite that overruns is a suite bug — keep aggregate probes bounded.
- **Single gate:** `mise run test` runs all 4 suites (`tests/render.bats`, `tests/packages.bats`, `tests/ai.bats`, `tests/config.bats`).
- **No source-text tests:** do not assert on the text or line order of another source file (e.g. grepping the launcher); test rendered output and behaviour. Narrow data-hygiene invariants over source data (e.g. no template directives in `.chezmoidata`) are allowed.
- **Test commands**:
  - `mise run test` — run all suites
  - `mise run test -- tests/render.bats` — run a single suite (`render`, `packages`, `ai`, `config`)
  - `mise run test -- --filter-tags suite:ai` — filter by Bats file tag
  - `mise run test -- --filter 'git config'` — filter by test name regex
  - `mise run test -- --count` — count discovered tests
- **Validate in the user terminal**: `chezmoi doctor`, targeted `chezmoi diff <destination...>`, targeted `chezmoi apply --dry-run <destination...>`, and `chezmoi verify`. For source rendering, run `chezmoi --source . execute-template -f <source>`.
