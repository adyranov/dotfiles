# OpenCode Instructions

- Temp files: `/tmp` writes are denied by sandbox. The launcher sets `TMPDIR` to the stable per-agent scratch root `/tmp/agents/opencode`, so ordinary temp APIs land there automatically. For intentional scratch files, write them directly under `/tmp/agents/opencode` and remove them when done.
