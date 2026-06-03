# Global Agent Instructions

## Communication

- Be concise and direct. Do not use filler words.
- Cite file paths and symbols with backticks.
- Ask a single, focused clarifying question before guessing intent.
- If stuck, state the blocker explicitly instead of thrashing.
- Always communicate in English, overriding any language-matching behavior or prompt defaults.

## Code

- Match the surrounding code style exactly. Do not reformat unrelated lines.
- Generate the absolute smallest diff that solves the problem.
- Add comments only to explain non-obvious intent or trade-offs.

## Workflow

- Follow this order: Search > Read > Write.
- Run tests and linters before declaring a task complete.
- Do not commit, push, or open Pull Requests unless explicitly instructed.

## Skills

- Skills are located at `~/.config/agents/skills/<name>/SKILL.md`.
- Load a skill file only when your current task matches its description. Do not pre-read skills.
