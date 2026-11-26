# Pi Feature Parity Checklist

Tracks parity of **Pi** (`~/.config/pi/agent`) against **Claude Code**, **OMP**, and **OpenCode + Slim**. The shared 4-way contract (roster, tiers, skills, `codegraph`, `engram`, DCG floors, `nono` profiles) stays uniform across all four harnesses; new harness work lands in Pi via external packages curated here.

| Feature | Reference Harness(es) | Pi Status | Providing Package / Mechanism | Notes |
| --- | --- | --- | --- | --- |
| Shared 5-role orchestrator + worker roster | Claude, OMP, OpenCode+Slim | Met | `pi-subagents` + `APPEND_SYSTEM.md` | `APPEND_SYSTEM.md` cleared for child subagents |
| Plan mode | Claude, OMP | Met | `@narumitw/pi-plan-mode` | Native read-only planning & approval flow |
| Todo / task tracking | Claude, OMP | Met | `@juicesharp/rpiv-todo` | Persisted under `~/.config/rpiv-todo` |
| Structured code search & LSP/AST intel | OMP | Met | `pi-lens`, `@ff-labs/pi-fff` | `ast_grep_replace` guarded by `pi-guard.ts` |
| Hashline-anchored edits | OMP | Met | `pi-hashline-readmap` | Line-hash anchors for reliable edits |
| Code graph MCP | Claude, OMP, OpenCode | Met | `pi-mcp-adapter` (`codegraph`) | Exposed to `explorer` role via `mcp` tool |
| Persistent cross-session memory | Claude, OMP, OpenCode | Met | `gentle-engram` | Shared Engram daemon on `ENGRAM_PORT` |
| Web search & fetch | Claude, OMP, OpenCode | Met | `pi-web-access` | Routed through `nono` egress allowlist |
| Interactive clarification prompts | Claude, OpenCode | Met | `pi-ask-user` | Matches Compound Engineering question surface |
| Side-channel / advisor escalation | Claude | Met | `pi-btw`, `pi-advisor-flow` | Fast side queries and escalation |
| Long-running goal loop | Claude | Met | `pi-goal-x` | Bounded iterative goal execution |
| Context & powerline status UI | Claude, OMP | Met | `pi-context`, `pi-powerline-footer`, `@sherif-fanous/pi-catppuccin` | Catppuccin Mocha theme |
| Guardrails & sandbox | Claude, OMP, OpenCode | Met | `nono` + `~/.config/dcg/pi-guard.ts` | Bash + write + `ast_grep_replace` floors |
| Worktree isolation per subagent | Claude (`-w`), OMP (`isolation`) | Partial | External orchestrator (Archon/Cezar/Gas City) | Deferred to container-hosted fleet orchestrator |
| Model fallback chains | OMP (`retry.fallbackChains`), OpenCode+Slim | Missing | **Candidate plugin (build outside this repo)** | Automatic fallback across ordered tier specs |
| TTSR stream rules (mid-stream guard/steer) | OMP | Missing | **Candidate plugin (build outside this repo)** | Real-time stream pattern interception |
| Checkpoint / rewind hooks | Claude, OMP | Missing | Deferred (`pi-rewind-hook`) | Evaluated and deferred |
