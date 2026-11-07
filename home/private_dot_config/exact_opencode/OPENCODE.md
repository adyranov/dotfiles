# OpenCode Instructions

- Temp files: `/tmp` writes are denied by sandbox. The launcher sets `TMPDIR` to the stable per-agent scratch root `/tmp/agents/opencode`, so ordinary temp APIs land there automatically. For intentional scratch files, write them directly under `/tmp/agents/opencode` and remove them when done.
- Sandbox denials: treat them as stop signs; ask the user to apply/sync generated files. On an unexplained EPERM, run `nono why <path>` (or `nono why --command <cmd>`) to see which grant/deny fired before guessing.
