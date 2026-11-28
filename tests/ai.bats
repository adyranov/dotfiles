#!/usr/bin/env bats
# bats file_tags=suite:ai

load 'helper'

@test "shared AGENTS.md and skills symlinks resolve for all enabled agents" {
  toolchain_enabled ai || skip "ai toolchain disabled"
  assert_file_exists "$HOME/.config/agents/AGENTS.md"
  assert_symlink_resolves "$HOME/.agents" "$HOME/.config/agents"

  if toolchain_enabled claude; then
    assert_symlink_resolves "$HOME/.config/claude/CLAUDE.md" "$HOME/.config/agents/AGENTS.md"
    assert_symlink_resolves "$HOME/.config/claude/skills" "$HOME/.config/agents/skills"
    assert_symlink_resolves "$HOME/.config/claude/plugins" "$HOME/.local/share/claude/plugins"
  fi
  if toolchain_enabled opencode; then
    assert_symlink_resolves "$HOME/.config/opencode/AGENTS.md" "$HOME/.config/agents/AGENTS.md"
    assert_symlink_resolves "$HOME/.config/opencode/plugins/dcg-guard.js" "$HOME/.config/dcg/opencode-guard.js"
  fi
  if toolchain_enabled pi; then
    assert_symlink_resolves "$HOME/.config/pi/agent/AGENTS.md" "$HOME/.config/agents/AGENTS.md"
  fi
  if toolchain_enabled omp; then
    assert_symlink_resolves "$HOME/.config/omp/agent/AGENTS.md" "$HOME/.config/agents/AGENTS.md"
  fi
}

@test "all enabled agents ship read-only DCG guards in ~/.config/dcg and dcg denies destructive commands" {
  toolchain_enabled ai || skip "ai toolchain disabled"
  assert_file_exists "$HOME/.config/dcg/guard-core.mjs"
  require_cmd dcg ai

  if toolchain_enabled claude; then
    assert_file_exists "$HOME/.config/dcg/claude-guard.mjs"
    assert_file_exists "$HOME/.config/dcg/claude-settings.json"
  fi
  if toolchain_enabled opencode; then assert_file_exists "$HOME/.config/dcg/opencode-guard.js"; fi
  if toolchain_enabled pi; then assert_file_exists "$HOME/.config/dcg/pi-guard.ts"; fi
  if toolchain_enabled omp; then assert_file_exists "$HOME/.config/dcg/omp-guard.ts"; fi

  local cmd decision
  for cmd in "rm -rf ~" "kubectl delete pod x" "git worktree remove --force wt"; do
    decision="$(jq -cn --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | env DCG_FAIL_CLOSED=1 dcg hook --robot --batch | head -n 1 | jq -r '.decision // "none"')"
    [ "$decision" = "deny" ] || fail "expected dcg to deny '$cmd', got $decision"
  done
  for cmd in "ls -la" 'git commit -m "fix rebase handling"' 'gh pr create --title "delete dead code"' "git worktree remove wt"; do
    decision="$(jq -cn --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | env DCG_FAIL_CLOSED=1 dcg hook --robot --batch | head -n 1 | jq -r '.decision // "none"')"
    [ "$decision" = "allow" ] || fail "expected dcg to allow '$cmd', got $decision"
  done
}

@test "DCG guard-core and agent hooks block write-axis bypasses, safety controls, and bad input" {
  require_cmd node
  local core="$REPO_ROOT/home/private_dot_config/exact_dcg/guard-core.mjs"
  local hook="$REPO_ROOT/home/private_dot_config/exact_dcg/claude-guard.mjs"
  local oc_hook="$REPO_ROOT/home/private_dot_config/exact_dcg/opencode-guard.js"
  node --check "$core"
  node --check "$hook"
  node --check "$oc_hook"

  # Malformed JSON -> fail closed (exit 2)
  run bash -c 'printf "not-json" | node "$1"' _ "$hook"
  [ "$status" -eq 2 ] || fail "malformed stdin exited $status (want 2)"

  # Symlink bypass (dangling + symlink/../config traversal) + nested submodules + project/agent safety controls
  mkdir -p "$BATS_TEST_TMPDIR/repo/.git/hooks" "$BATS_TEST_TMPDIR/wt"
  printf 'gitdir: /tmp/evil\n' >"$BATS_TEST_TMPDIR/wt/.git"
  ln -s "$BATS_TEST_TMPDIR/repo/.git/config" "$BATS_TEST_TMPDIR/sneaky-link"
  ln -s "$BATS_TEST_TMPDIR/repo/.git/hooks" "$BATS_TEST_TMPDIR/hooks-link"
  local p
  for p in \
    wt/.git \
    repo/.git/config \
    repo/.GIT/HOOKS/pre-commit \
    repo/.git/worktrees/feat/config.worktree \
    repo/.git/modules/vendor/foo/config \
    repo/.mcp.json \
    repo/opencode.json \
    repo/.opencode/plugin.js \
    repo/.claude/CLAUDE.md \
    repo/.claude/rules/x.md \
    repo/.claude/settings.json \
    repo/.claude/settings.local.json \
    "$BATS_TEST_TMPDIR/sneaky-link" \
    "$BATS_TEST_TMPDIR/hooks-link/../config" \
    "$HOME/.config/dcg/guard-core.mjs" \
    "$HOME/.config/dcg/claude-guard.mjs" \
    "$HOME/.config/dcg/claude-settings.json" \
    "$HOME/.config/nono/profiles/claude.json" \
    "$HOME/.config/claude/settings.json" \
    "$HOME/.config/claude/.claude.json" \
    "$HOME/.config/claude/rules/evil.md" \
    "$HOME/.config/opencode/plugins/dcg-guard.js" \
    "$HOME/.config/opencode/cli.json" \
    "$HOME/.local/share/opencode/auth.json" \
    "$HOME/.config/pi/agent/settings.json" \
    "$HOME/.config/pi/agent/APPEND_SYSTEM.md" \
    "$HOME/.config/pi/agent/models.json" \
    "$HOME/.config/pi/agent/auth.json" \
    "$HOME/.config/pi/agent/mcp.json" \
    "$HOME/.config/omp/agent/config.yml" \
    "$HOME/.config/omp/agent/models.yml"
  do
    run bash -c 'printf %s "$1" | node "$2"' _ "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$p\"},\"cwd\":\"$BATS_TEST_TMPDIR\"}" "$hook"
    [ "$status" -eq 2 ] || fail "protected write $p exited $status (want 2)"
  done

  # ReDoS timing guard: deeply repeated /modules/a segments must finish in < 50ms
  run node --input-type=module -e '
    import { fileWriteBlockReason } from "'"$core"'";
    const t0 = performance.now();
    const res = fileWriteBlockReason("/repo/.git" + "/modules/a".repeat(30) + "/notconfig", "/tmp");
    const ms = performance.now() - t0;
    if (res !== null || ms >= 50) process.exit(1);
  '
  [ "$status" -eq 0 ] || fail "guard-core ReDoS timing guard failed: $output"

  # OpenCode guard enforces write-axis floors on write, apply_patch, and ast_grep_replace
  run node --input-type=module -e '
    import { DcgGuard } from "'"$oc_hook"'";
    const g = await DcgGuard();
    const cwd = "'"$BATS_TEST_TMPDIR"'";
    await g["tool.execute.before"]({ tool: "apply_patch" }, { args: { patchText: "*** Begin Patch\n*** Update File: src/app.ts\n@@\n-a\n+b\n*** End Patch", cwd } });
    await g["tool.execute.before"]({ tool: "ast_grep_replace" }, { args: { paths: ["."], cwd } });
    await g["tool.execute.before"]({ tool: "ast_grep_replace" }, { args: { paths: ["src/app.ts"], dryRun: false, cwd } });
    for (const call of [
      [{ tool: "write" }, { args: { filePath: "repo/.git/config", cwd } }],
      [{ tool: "apply_patch" }, { args: { patchText: "*** Begin Patch\n*** Update File: repo/.git/config\n*** End Patch", cwd } }],
      [{ tool: "apply_patch" }, { args: { patchText: "+++ \"b/repo/.git/config\"\n", cwd } }],
      [{ tool: "apply_patch" }, { args: { patchText: "+++ b/repo/.mcp.json 2026-01-01 00:00:00 +0000\n", cwd } }],
      [{ tool: "apply_patch" }, { args: { patchText: "no file headers", cwd } }],
      [{ tool: "ast_grep_replace" }, { args: { paths: ["."], dryRun: false, cwd } }],
      [{ tool: "ast_grep_replace" }, { args: { paths: ["~"], dryRun: false, cwd } }],
      [{ tool: "ast_grep_replace" }, { args: { paths: ["src/**/*.ts"], dryRun: false, cwd } }],
      [{ tool: "ast_grep_replace" }, { args: { paths: ["repo/.git/config"], dryRun: false, cwd } }],
    ]) {
      let blocked = false;
      try {
        await g["tool.execute.before"](call[0], call[1]);
      } catch (e) {
        blocked = String(e.message).includes("Blocked by DCG");
      }
      if (!blocked) process.exit(1);
    }
  '
  [ "$status" -eq 0 ] || fail "opencode-guard.js apply_patch/write/ast_grep_replace checks failed: $output"

  # OMP guard handles hashline edit + ast_edit (benign allowed, protected blocked)
  run node --input-type=module -e '
    import { extractOmpEditPaths, fileWritesBlockReason } from "'"$core"'";
    const cwd = "'"$BATS_TEST_TMPDIR"'";
    if (fileWritesBlockReason(extractOmpEditPaths("[src/app.ts#AA11]\nSWAP 1\n"), cwd, "edit")) process.exit(1);
    if (!fileWritesBlockReason(extractOmpEditPaths("[repo/.git/config#AA11]\nSWAP 1\n"), cwd, "edit")) process.exit(1);
    if (!fileWritesBlockReason(["repo/.git/config"], cwd, "ast_edit")) process.exit(1);
  '
  [ "$status" -eq 0 ] || fail "guard-core OMP edit/ast_edit checks failed: $output"

  # DCG_BYPASS=1 in hook env cannot weaken dcg (U8/R11)
  if command -v dcg >/dev/null 2>&1; then
    run bash -c 'printf %s "$1" | env DCG_BYPASS=1 node "$2"' _ '{"tool_name":"Bash","tool_input":{"command":"rm -rf ~"}}' "$hook"
    [ "$status" -eq 2 ] || fail "DCG_BYPASS=1 weakened guard (exit $status, want 2)"
    run bash -c 'printf %s "$1" | node "$2"' _ '{"tool_name":"Monitor","tool_input":{"command":"rm -rf ~"}}' "$hook"
    [ "$status" -eq 2 ] || fail "Monitor destructive command was not blocked (exit $status, want 2)"
  fi

  # Directly load pi-guard.ts and omp-guard.ts to verify ast_grep_replace / ast_edit guards
  run node --input-type=module -e '
    import piGuard from "'"$REPO_ROOT"'/home/private_dot_config/exact_dcg/pi-guard.ts";
    import ompGuard from "'"$REPO_ROOT"'/home/private_dot_config/exact_dcg/omp-guard.ts";
    let piFn, ompFn;
    piGuard({ on: (_e, fn) => { piFn = fn; } });
    ompGuard({ on: (_e, fn) => { ompFn = fn; } });
    const cwd = "'"$BATS_TEST_TMPDIR"'";
    if (await piFn({ toolName: "ast_grep_replace", input: { paths: ["."], cwd } })) process.exit(1);
    if (!(await piFn({ toolName: "ast_grep_replace", input: { paths: ["."], dryRun: false, cwd } }))?.block) process.exit(2);
    if (!(await piFn({ toolName: "ast_grep_replace", input: { paths: ["~"], dryRun: false, cwd } }))?.block) process.exit(21);
    if (!(await piFn({ toolName: "ast_grep_replace", input: { paths: ["src/**/*.ts"], dryRun: false, cwd } }))?.block) process.exit(3);
    if (!(await piFn({ toolName: "ast_grep_replace", input: { paths: ["'"$HOME"'/.config/claude/settings.json"], dryRun: false, cwd } }))?.block) process.exit(4);
    if (await piFn({ toolName: "ast_grep_replace", input: { paths: ["src/app.ts"], dryRun: false, cwd } })) process.exit(5);
    if (!(await ompFn({ toolName: "ast_edit", input: { paths: ["."], cwd } }))?.block) process.exit(6);
    if (!(await ompFn({ toolName: "ast_edit", input: { paths: ["~"], cwd } }))?.block) process.exit(61);
    if (!(await ompFn({ toolName: "ast_edit", input: { paths: ["src/**/*.ts"], cwd } }))?.block) process.exit(7);
    if (!(await ompFn({ toolName: "ast_edit", input: { paths: ["'"$HOME"'/.config/claude/settings.json"], cwd } }))?.block) process.exit(8);
    if (await ompFn({ toolName: "ast_edit", input: { paths: ["src/app.ts"], cwd } })) process.exit(9);
  '
  [ "$status" -eq 0 ] || fail "pi-guard.ts / omp-guard.ts direct check failed (exit $status): $output"

  # Relative path with no cwd -> fail closed (exit 2)
  run bash -c 'printf %s "$1" | node "$2"' _ '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' "$hook"
  [ "$status" -eq 2 ] || fail "relative write with missing cwd exited $status (want 2)"

  # NotebookEdit checks notebook_path
  run bash -c 'printf %s "$1" | node "$2"' _ "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"repo/.git/config\"},\"cwd\":\"$BATS_TEST_TMPDIR\"}" "$hook"
  [ "$status" -eq 2 ] || fail "NotebookEdit .git/config exited $status (want 2)"

  # Benign write -> allowed (exit 0)
  run bash -c 'printf %s "$1" | node "$2"' _ "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/app.ts\"},\"cwd\":\"$BATS_TEST_TMPDIR\"}" "$hook"
  [ "$status" -eq 0 ] || fail "benign write exited $status (want 0)"
}

@test "agent launcher routes harnesses, verifies guardrail integrity, and refuses tampered configs" {
  local bin="$REPO_ROOT/home/private_dot_local/exact_bin/executable_agent"
  local fake_home="$BATS_TEST_TMPDIR/fakehome"
  local fake_cfg="$BATS_TEST_TMPDIR/xdg"
  mkdir -p "$fake_home" "$fake_cfg/dcg" "$fake_cfg/claude" "$fake_cfg/opencode/plugins"

  local a
  for a in claude oc omp pi; do
    run env AGENT_HOST_ROOT="$fake_home" "$bin" "$a" --print-env
    [ "$status" -eq 0 ] || fail "agent $a --print-env failed: $output"
    ! printf '%s' "$output" | grep -q 'NO_PROXY=' || fail "agent $a emitted NO_PROXY"
  done

  run "$bin" nonexistent-agent --help
  [ "$status" -ne 0 ] || fail "expected unknown agent subcommand to fail"

  # Seed read-only dcg fixtures and verify startup check refuses non-worktree and tampered configs
  printf '// core\n' >"$fake_cfg/dcg/guard-core.mjs"
  printf '// guard\n' >"$fake_cfg/dcg/claude-guard.mjs"
  printf '{}\n' >"$fake_cfg/dcg/claude-settings.json"
  printf '// oc\n' >"$fake_cfg/dcg/opencode-guard.js"

  # 0. Non-worktree pwd -> pwd_guard refuses even in container builds without .git
  local non_wt="$BATS_TEST_TMPDIR/non-wt" wt="$BATS_TEST_TMPDIR/wt"
  mkdir -p "$non_wt" "$wt"
  run bash -c 'cd "$1" && exec env XDG_CONFIG_HOME="$2" "$3" claude --no-sandbox -- --version' _ "$non_wt" "$fake_cfg" "$bin"
  [ "$status" -ne 0 ] || fail "expected pwd_guard to refuse non-worktree directory"
  [[ "$output" == *"Not inside a git worktree"* ]] || fail "expected non-worktree error: $output"
  git -C "$wt" init -q
  cd "$wt"

  # 1. Tampered Claude settings.json (disableAllHooks: true) -> launcher refuses
  printf '{"disableAllHooks": true}\n' >"$fake_cfg/claude/settings.json"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse disableAllHooks=true"
  [[ "$output" == *"settings.json"* ]] || fail "expected refusal to name settings.json: $output"

  # 2. Tampered Claude settings.json (bypassPermissions) -> launcher refuses
  printf '{"permissions":{"defaultMode":"bypassPermissions"},"hooks":{"PreToolUse":[{"hooks":[{"command":"node ~/.config/dcg/claude-guard.mjs"}]}]}}\n' >"$fake_cfg/claude/settings.json"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse bypassPermissions"
  [[ "$output" == *"settings.json"* ]] || fail "expected refusal to name settings.json: $output"

  # 3. Replaced OpenCode plugin symlink (regular file instead of symlink to dcg/) -> launcher refuses
  printf '// tampered\n' >"$fake_cfg/opencode/plugins/dcg-guard.js"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" opencode --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse non-symlink opencode plugin"
  [[ "$output" == *"dcg-guard.js"* ]] || fail "expected refusal to name dcg-guard.js: $output"

  # 4. Missing node on PATH (and empty XDG_DATA_HOME) -> Claude startup check fails closed
  local no_node_bin="$BATS_TEST_TMPDIR/no-node-bin"
  mkdir -p "$no_node_bin" "$BATS_TEST_TMPDIR/empty-data"
  local cmd_name cmd_path
  for cmd_name in uname git tput readlink sh jq; do
    cmd_path="$(command -v "$cmd_name" || true)"
    [ -n "$cmd_path" ] && ln -sf "$cmd_path" "$no_node_bin/$cmd_name"
  done
  printf '{"hooks":{"PreToolUse":[{"hooks":[{"command":"node ~/.config/dcg/claude-guard.mjs"}]}]}}\n' >"$fake_cfg/claude/settings.json"
  run env PATH="$no_node_bin" XDG_DATA_HOME="$BATS_TEST_TMPDIR/empty-data" XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to fail closed when node is missing"
  [[ "$output" == *"node"* ]] || fail "expected refusal to mention node: $output"

  # 5. Missing jq on PATH (with node present) -> Claude startup check fails closed
  local no_jq_bin="$BATS_TEST_TMPDIR/no-jq-bin"
  mkdir -p "$no_jq_bin"
  for cmd_name in uname git tput readlink sh node env; do
    cmd_path="$(command -v "$cmd_name" || true)"
    [ -n "$cmd_path" ] && ln -sf "$cmd_path" "$no_jq_bin/$cmd_name"
  done
  run env PATH="$no_jq_bin" XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to fail closed when jq is missing"
  [[ "$output" == *"jq"* ]] || fail "expected refusal to mention jq: $output"

  # 6. Manifest drift catches forbiddenKeys, extra hooks, autoMode/env/plugin/permissions/sandbox tampering, and altered MCP commands (U5/AE2)
  local base_hooks='{"PreToolUse":[{"hooks":[{"command":"node ~/.config/dcg/claude-guard.mjs","type":"command"}],"matcher":"Bash|Monitor|Write|Edit|MultiEdit|NotebookEdit"}]}'
  printf '{"autoMode":{"allow":["$defaults"],"environment":["$defaults"]},"enabledPlugins":{"p@m":true},"env":{"FOO":"1"},"forbiddenKeys":["apiKeyHelper","gcpAuthRefresh","proxyAuthHelper"],"hooks":%s,"marketplaces":[],"mcpServers":{"codegraph":{"args":[],"command":"codegraph","type":"stdio"}},"permissions":{"defaultMode":"auto","deny":[]},"sandbox":{"enabled":false},"statusLineCommand":"claude-powerline"}\n' "$base_hooks" >"$fake_cfg/dcg/claude-managed.json"
  printf '{"apiKeyHelper":"evil","autoMode":{"allow":["$defaults"],"soft_deny":["evil"]},"enabledPlugins":{"p@m":true,"rogue@x":true},"env":{"FOO":"1","NODE_OPTIONS":"--require=/tmp/x"},"permissions":{"allow":["Bash(*)"],"defaultMode":"auto","deny":[]},"sandbox":{"enabled":true},"statusLine":{"command":"claude-powerline"},"extraKnownMarketplaces":{},"hooks":{"PreToolUse":[{"hooks":[{"command":"node ~/.config/dcg/claude-guard.mjs","type":"command"},{"command":"evil","type":"command"}],"matcher":"Bash|Monitor|Write|Edit|MultiEdit|NotebookEdit"}]}}\n' >"$fake_cfg/claude/settings.json"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse settings drift"
  [[ "$output" == *"apiKeyHelper"* && "$output" == *"autoMode"* && "$output" == *"enabledPlugins"* && "$output" == *"env"* && "$output" == *"hooks"* && "$output" == *"permissions"* && "$output" == *"sandbox"* ]] \
    || fail "expected refusal to name apiKeyHelper, autoMode, enabledPlugins, env, hooks, permissions, sandbox: $output"

  printf '{"autoMode":{"allow":["$defaults"],"environment":["$defaults"]},"enabledPlugins":{"p@m":true},"env":{"FOO":"1"},"permissions":{"defaultMode":"auto","deny":[]},"sandbox":{"enabled":false},"statusLine":{"command":"claude-powerline"},"extraKnownMarketplaces":{},"hooks":%s}\n' "$base_hooks" >"$fake_cfg/claude/settings.json"
  printf '{"mcpServers":{"codegraph":{"args":[],"command":"/tmp/evil","type":"stdio"}}}\n' >"$fake_cfg/claude/.claude.json"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse altered codegraph command"
  [[ "$output" == *"mcpServers"* ]] || fail "expected refusal to name mcpServers: $output"
  rm -f "$fake_cfg/claude/.claude.json"

  # 7. Guard self-test failure -> launcher refuses (U8/R11)
  printf 'process.exit(1);\n' >"$fake_cfg/dcg/claude-guard.mjs"
  run env XDG_CONFIG_HOME="$fake_cfg" "$bin" claude --no-sandbox -- --version
  [ "$status" -ne 0 ] || fail "expected launcher to refuse failing guard self-test"
  [[ "$output" == *"self-test"* ]] || fail "expected refusal to mention self-test: $output"

  # 8. GITHUB_GIT_CREDENTIAL is derived at eval time; --print-env never carries the token value
  local gh_agent gh_out
  for gh_agent in pi claude; do
    gh_out="$(env GITHUB_TOKEN=t sh -c 'eval "$("$1" "$2" --print-env)"; printf "%s" "${GITHUB_GIT_CREDENTIAL:-}"' _ "$bin" "$gh_agent")"
    [ "$gh_out" = "x-access-token:t" ] || fail "$gh_agent GITHUB_GIT_CREDENTIAL mismatch: $gh_out"
  done
  gh_out="$(env -u GITHUB_TOKEN sh -c 'eval "$("$1" pi --print-env)"; printf "%s" "${GITHUB_GIT_CREDENTIAL:-}"' _ "$bin")"
  [ -z "$gh_out" ] || fail "GITHUB_GIT_CREDENTIAL set without GITHUB_TOKEN: $gh_out"
  gh_out="$(env GITHUB_TOKEN=tok-value-123 "$bin" pi --print-env)"
  [[ "$gh_out" != *tok-value-123* ]] || fail "--print-env leaked the token value"

  # 9. U16: /.dockerenv wins over WSL_DISTRO_NAME in isContainer()
  local wsl_root="$BATS_TEST_TMPDIR/wsl-docker"
  mkdir -p "$wsl_root" "$BATS_TEST_TMPDIR/no-nono-bin"
  touch "$wsl_root/.dockerenv"
  for cmd_name in uname git tput readlink sh jq node awk grep tr; do
    cmd_path="$(command -v "$cmd_name" || true)"
    [ -n "$cmd_path" ] && ln -sf "$cmd_path" "$BATS_TEST_TMPDIR/no-nono-bin/$cmd_name"
  done
  printf '#!/bin/sh\necho container-ok\n' >"$BATS_TEST_TMPDIR/no-nono-bin/pi"
  chmod +x "$BATS_TEST_TMPDIR/no-nono-bin/pi"
  printf '// pi\n' >"$fake_cfg/dcg/pi-guard.ts"
  run env -u AGENT_SANDBOX PATH="$BATS_TEST_TMPDIR/no-nono-bin" AGENT_HOST_ROOT="$wsl_root" WSL_DISTRO_NAME="Ubuntu-24.04" XDG_CONFIG_HOME="$fake_cfg" "$bin" pi -- --version
  [ "$status" -eq 0 ] && [[ "$output" == *"container-ok"* ]] || fail "WSL + /.dockerenv was not treated as container: $output"

  # 10. Existing ~/.claude migration preserves projects and refuses when real skills/CLAUDE.md would be lost
  local mig="$REPO_ROOT/home/.chezmoiscripts/run_before_05_migrate-claude-dir.sh"
  local mig_home="$BATS_TEST_TMPDIR/mig-ok"
  mkdir -p "$mig_home/.claude/projects/p1"
  printf 'session\n' >"$mig_home/.claude/projects/p1/log.jsonl"
  run env HOME="$mig_home" "$mig"
  [ "$status" -eq 0 ] || fail "migration failed on projects: $output"
  [ ! -e "$mig_home/.claude" ] && [ -f "$mig_home/.local/state/claude/projects/p1/log.jsonl" ] \
    || fail "migration did not move ~/.claude/projects into ~/.local/state/claude/projects"

  local mig_block="$BATS_TEST_TMPDIR/mig-block"
  mkdir -p "$mig_block/.claude/skills/custom"
  printf 'keep\n' >"$mig_block/.claude/skills/custom/SKILL.md"
  run env HOME="$mig_block" "$mig"
  [ "$status" -ne 0 ] || fail "expected migration to refuse real ~/.claude/skills"
  [ -f "$mig_block/.claude/skills/custom/SKILL.md" ] || fail "refused migration must leave ~/.claude/skills untouched"

  local mig_agents="$BATS_TEST_TMPDIR/mig-agents"
  mkdir -p "$mig_agents/.claude/agents"
  printf 'custom\n' >"$mig_agents/.claude/agents/custom.md"
  run env HOME="$mig_agents" "$mig"
  [ "$status" -ne 0 ] || fail "expected migration to refuse real ~/.claude/agents"
  [ -f "$mig_agents/.claude/agents/custom.md" ] || fail "refused migration must leave ~/.claude/agents untouched"

  local mig_post="$BATS_TEST_TMPDIR/mig-post"
  mkdir -p "$mig_post/.config/claude/agents"
  ln -s ".config/claude" "$mig_post/.claude"
  printf 'managed\n' >"$mig_post/.config/claude/agents/explorer.md"
  run env HOME="$mig_post" "$mig"
  [ "$status" -eq 0 ] || fail "post-migration symlinked ~/.claude failed: $output"
  [ -f "$mig_post/.config/claude/agents/explorer.md" ] || fail "post-migration must preserve ~/.config/claude/agents/explorer.md"
}

@test "nono why and live sandbox confirm read-only ~/.config/dcg guards and hidden ~/.ssh" {
  toolchain_enabled ai || skip "ai toolchain disabled"
  [ "$(chezmoi --source "$REPO_ROOT" data | jq -r '.host.type // ""')" != "ephemeral" ] || skip "ephemeral container host"
  require_cmd nono ai
  [ -d "$HOME/.config/nono/profiles" ] || fail "ai toolchain enabled and nono installed but ~/.config/nono/profiles missing"
  local f
  for f in "$HOME/.config/nono/profiles"/*.json; do
    [ -f "$f" ] || continue
    jq -e '.meta.name and .extends and .filesystem and .network' "$f" >/dev/null \
      || fail "invalid nono profile: $f"
  done

  [ -z "${AGENT_SANDBOX:-}" ] || skip "nested sandbox: live nono probe is host-authoritative"

  # Query nono why on every agent whose upstream pack is installed: guarded dcg files
  # must be readable (op=read -> allowed) and unwritable (op=write -> denied).
  # nono rejects an empty XDG_RUNTIME_DIR, so give every call a clean one.
  local agent path r_status w_status runtime_dir="$BATS_TEST_TMPDIR/runtime"
  mkdir -p "$runtime_dir"
  for agent in claude omp opencode pi; do
    [ -f "$HOME/.config/nono/profiles/${agent}.json" ] || continue
    [ -d "$HOME/.config/nono/packages/nolabs-ai/${agent}" ] || continue
    local paths=("$HOME/.config/dcg/guard-core.mjs")
    case "$agent" in
      claude) paths+=("$HOME/.config/dcg/claude-guard.mjs" "$HOME/.config/dcg/claude-settings.json") ;;
      opencode) paths+=("$HOME/.config/dcg/opencode-guard.js") ;;
      pi) paths+=("$HOME/.config/dcg/pi-guard.ts") ;;
      omp) paths+=("$HOME/.config/dcg/omp-guard.ts") ;;
    esac
    for path in "${paths[@]}"; do
      assert_file_exists "$path"
      local r_out w_out
      r_out="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$path" --op read --json 2>&1 || true)"
      w_out="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$path" --op write --json 2>&1 || true)"
      r_status="$(printf '%s\n' "$r_out" | sed -n '/^{/,$p' | jq -r '.status' 2>/dev/null || true)"
      w_status="$(printf '%s\n' "$w_out" | sed -n '/^{/,$p' | jq -r '.status' 2>/dev/null || true)"
      [ "$r_status" = "allowed" ] || fail "nono why ($agent read $path) = $r_status (want allowed): $r_out"
      [ "$w_status" = "denied" ] || fail "nono why ($agent write $path) = $w_status (want denied): $w_out"
    done
    # Host-executed caches and shell plugin/completion paths must be write-denied for all 4 agents.
    # Shell dirs are protected by having no grants at all, so a nonexistent canary
    # child proves folder-level protection (nothing else writable in that tree).
    local exec_path
    for exec_path in \
      "$HOME/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
      "$HOME/.local/share/shell/zcompdump" \
      "$HOME/.local/share/shell/init/starship.zsh" \
      "$HOME/.local/share/shell/canary-$RANDOM.zsh" \
      "$HOME/.config/zsh/canary-$RANDOM.zsh" \
      "$HOME/.local/share/shell/cache/carapace/bridges-zsh.json" \
      "$HOME/.config/carapace/specs/kubecolor.yaml" \
      "$HOME/.local/share/prek/cache" \
      "$HOME/.local/share/pre-commit/cache" \
      "$HOME/.local/share/chezmoi-cache/x" \
      "$HOME/.local/share/npm-cache/_npx" \
      "$HOME/.local/share/uv-cache/x"
    do
      w_status="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$exec_path" --op write --json 2>/dev/null | jq -r '.status')"
      [ "$w_status" = "denied" ] || fail "nono why ($agent write $exec_path) = $w_status (want denied)"
    done
    if [ "$(uname -s)" = "Darwin" ]; then
      # ~/.cache/carapace is denied via the deny list, which renders on macOS only;
      # on Linux ~/.cache is broadly granted, so no probe there.
      for exec_path in "$HOME/.cache/carapace/bridges-zsh.json" "$HOME/Library/Caches/carapace/bridges-zsh.json"; do
        w_status="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$exec_path" --op write --json 2>/dev/null | jq -r '.status')"
        [ "$w_status" = "denied" ] || fail "nono why ($agent write $exec_path) = $w_status (want denied)"
      done
    fi
    for exec_path in "$HOME/.local/share/zsh/history" "$HOME/.bash_history"; do
      r_status="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$exec_path" --op read --json 2>/dev/null | jq -r '.status')"
      [ "$r_status" = "denied" ] || fail "nono why ($agent read $exec_path) = $r_status (want denied)"
    done
    # R21/R22/AE3: non-claude agents must be write-denied on Claude config & .claude.json;
    # claude must be write-denied on installed plugins under ~/.local/share/claude/plugins (U6).
    # On Linux, Landlock cannot deny-override upstream nolabs-ai/opencode's $HOME/.claude allow.
    if [ "$agent" = "claude" ]; then
      w_status="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile claude --path "$HOME/.local/share/claude/plugins/installed_plugins.json" --op write --json 2>/dev/null | jq -r '.status')"
      [ "$w_status" = "denied" ] || fail "nono why (claude write plugins/installed_plugins.json) = $w_status (want denied)"
    elif [ "$agent" != "opencode" ] || [ "$(uname -s)" = "Darwin" ]; then
      for exec_path in "$HOME/.config/claude/settings.json" "$HOME/.config/claude/.claude.json"; do
        w_status="$(XDG_RUNTIME_DIR="$runtime_dir" nono why --profile "$agent" --path "$exec_path" --op write --json 2>/dev/null | jq -r '.status')"
        [ "$w_status" = "denied" ] || fail "nono why ($agent write $exec_path) = $w_status (want denied)"
      done
    fi
  done

  [ -d "$HOME/.config/nono/packages/nolabs-ai/pi" ] || skip "pi pack not pulled"
  local tout
  tout="$(command -v gtimeout || command -v timeout || true)"
  [ -n "$tout" ] || skip "no timeout binary"

  # Live nono probe: set XDG_RUNTIME_DIR cleanly; verify ~/.ssh is hidden and shell bypasses
  # (cp /dev/null, rm, node -e) against ~/.config/dcg/sandbox-ro-canary are blocked by the kernel.
  assert_file_exists "$HOME/.config/dcg/sandbox-ro-canary"
  [ -f "$HOME/.ssh/config" ] || skip "~/.ssh/config absent; cannot verify SSH read denial"
  run "$tout" 20 env XDG_RUNTIME_DIR="$runtime_dir" NONO_NO_SAVE_PROMPT=1 nono run --profile pi --allow-cwd -- \
    sh -c '
      echo nono-canary
      cat "$HOME/.ssh/config" >/dev/null 2>&1 && echo ssh-readable
      cp /dev/null "$HOME/.config/dcg/sandbox-ro-canary" 2>/dev/null && echo cp-bypass
      rm -f "$HOME/.config/dcg/sandbox-ro-canary" 2>/dev/null && echo rm-bypass
      node -e "require(\"fs\").writeFileSync(process.env.HOME + \"/.config/dcg/sandbox-ro-canary\", \"\")" 2>/dev/null && echo node-bypass
      head -n 1 "$HOME/.config/dcg/sandbox-ro-canary" >/dev/null 2>&1 && echo dcg-readable
    '
  [[ "$output" == *"nono-canary"* ]] || fail "nono canary missing: $output"
  [[ "$output" == *"dcg-readable"* ]] || fail "nono blocked reading ~/.config/dcg/sandbox-ro-canary: $output"
  [[ "$output" != *"ssh-readable"* ]] || fail "nono sandbox leaked ~/.ssh/config!"
  [[ "$output" != *"cp-bypass"* ]] || fail "nono allowed cp /dev/null overwrite of sandbox-ro-canary!"
  [[ "$output" != *"rm-bypass"* ]] || fail "nono allowed rm of sandbox-ro-canary!"
  [[ "$output" != *"node-bypass"* ]] || fail "nono allowed node write to sandbox-ro-canary!"
}

@test "every agent sandbox runs git with the global config include chain and node" {
  toolchain_enabled ai || skip "ai toolchain disabled"
  command -v nono >/dev/null 2>&1 || skip "nono not installed"
  [ -z "${AGENT_SANDBOX:-}" ] || skip "nested sandbox: live nono probe is host-authoritative"
  local tout
  tout="$(command -v gtimeout || command -v timeout || true)"
  [ -n "$tout" ] || skip "no timeout binary"

  # An unreadable git include (e.g. ~/.config/git/base) is fatal for every git call.
  local repo="$BATS_TEST_TMPDIR/repo" runtime_dir="$BATS_TEST_TMPDIR/runtime" agent ran=0
  mkdir -p "$repo" "$runtime_dir"
  git -C "$repo" init -q
  for agent in claude omp opencode pi; do
    [ -f "$HOME/.config/nono/profiles/${agent}.json" ] || continue
    [ -d "$HOME/.config/nono/packages/nolabs-ai/${agent}" ] || continue
    ran=1
    run bash -c 'cd "$1" && "$2" 30 env XDG_RUNTIME_DIR="$3" NONO_NO_SAVE_PROMPT=1 nono run -s --profile "$4" --allow-cwd -- \
      sh -c "git status --short && git config --list >/dev/null && node --version >/dev/null && echo smoke-ok"' \
      _ "$repo" "$tout" "$runtime_dir" "$agent"
    [[ "$output" == *"smoke-ok"* ]] || fail "$agent sandbox: git/node smoke failed: $output"
  done
  [ "$ran" -eq 1 ] || skip "no agent pack pulled"
}
