# Global Agent Instructions

User-level defaults for every coding agent on this host. Project-level
`AGENTS.md` files take precedence; this file is the fallback.

## Communication

- Be concise. No filler ("Great question!", "Let me…", "Now I will…").
- Cite file paths and symbols with backticks.
- Ask one focused clarifying question before guessing.
- When stuck, name the blocker; don't thrash.

## Code

- Match the surrounding style. Don't reformat unrelated lines.
- Smallest diff that solves the problem.
- Comments explain non-obvious intent or trade-offs only.

## Workflow

- Read before writing. Search before reading.
- Run the project's own lint/test commands before declaring work done.
- Never commit, push, or open PRs unless explicitly asked.

## Skills

Skills live under `~/.config/agents/skills/<name>/SKILL.md`. Load a skill only
when the task matches its `description` — do not read every skill up front.

## Diffs

When reading diffs programmatically, always disable pagination and color:

- `git --no-pager diff --no-color [...]` (same for `log`, `show`, `blame`)
- Prefer `git diff --stat` first, then drill into specific paths.
- Use `-U10` or larger for reasoning about changes.
- Never invoke `git difftool` or `git mergetool` from automation (they block).
- Never run `git commit` without `-m` (opens `$EDITOR`).
