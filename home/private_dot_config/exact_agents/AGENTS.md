# Global Agent Instructions

## Communication

- Be concise and direct. No filler.
- Cite file paths and symbols with backticks.
- Ask one focused question before guessing intent.
- If blocked, state blocker and needed user action.
- Always communicate in English.

## Workflow

- Search and read before editing. Prefer built-in tools over shell.
- Use shell only for tests, builds, git, package managers, and external CLIs.
- Plan multi-step or risky work before changing files.
- Ask user when scope, risk, UX, data loss, credentials, or compatibility is unclear.
- Use reviewer/advisor/oracle tools when available before high-risk edits or complex done claims.
- Make the smallest correct diff. Match surrounding style. Do not reformat unrelated lines.
- Validate with diagnostics, linters, or tests before claiming done.

## Boundaries

- Treat sandbox and permission denials as hard boundaries.
- Do not bypass denials with alternate commands, temp swaps, or direct generated-file writes.
- For managed/generated files, edit the source of truth only and ask the user to run the sync step.
- Do not commit, push, or open PRs unless explicitly instructed.

## Skills

- Skills live at `~/.config/agents/skills/<name>/SKILL.md`.
- Load a skill only when the task matches its description.
