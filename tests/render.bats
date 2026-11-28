#!/usr/bin/env bats
# bats file_tags=suite:render

load 'helper'

@test "all .chezmoidata TOML files parse cleanly with no template directives" {
  local f
  while IFS= read -r f; do
    ! grep -Fq '{{' "$f" || fail "template directive found in static data: $f"
    python3 -c 'import tomllib, sys; tomllib.load(open(sys.argv[1], "rb"))' "$f" \
      || fail "invalid TOML: $f"
  done < <(find "$REPO_ROOT/home/.chezmoidata" -name '*.toml' | sort)
}

@test "chezmoi config template renders cleanly non-interactively" {
  run chezmoi --source "$REPO_ROOT" execute-template --init -f "$REPO_ROOT/home/.chezmoi.yaml.tmpl" </dev/null
  [ "$status" -eq 0 ] || fail "config template failed: $output"
  printf '%s\n' "$output" | sed -n '/^hooks:/,$p' | yq -e '.data.host.distro.id and .data.toolchains' >/dev/null \
    || fail "rendered chezmoi.yaml failed YAML validation"
}

@test "AI presets and roles cross-references are valid across personal and work profiles" {
  python3 - "$REPO_ROOT" <<'PY'
import pathlib, sys, tomllib

root = pathlib.Path(sys.argv[1]) / "home/.chezmoidata/ai"
models = tomllib.loads((root / "models.toml").read_text())["ai"]
roles = tomllib.loads((root / "roles.toml").read_text())["ai"]
mcp = tomllib.loads((root / "mcp.toml").read_text())["ai"]["mcp"]["servers"]
libs = tomllib.loads((root / "libraries.toml").read_text())["ai"]["libraries"]["skills"]

shared_skills = {s for lib in libs.values() for s in lib.get("include", [])}
for role_name, rd in roles["roles"].items():
    for s in rd.get("skills", []):
        if s != "*" and s not in shared_skills:
            sys.exit(f"role {role_name} references unknown skill {s}")
    for m in rd.get("mcps", []):
        if m not in mcp:
            sys.exit(f"role {role_name} references unknown MCP {m}")
    # Workers must never receive delegation tools
    if role_name != "orchestrator":
        for agent, tools in roles["tool_sets"][rd["tools"]].items():
            for forbidden in ("subagent", "Agent", "task"):
                if forbidden in tools:
                    sys.exit(f"worker {role_name} tool_set grants {forbidden} on {agent}")

for prof_name, prof in models["profiles"].items():
    valid = {f"{p}/{m}" for p, ms in prof.get("providers", {}).items() for m in ms}
    served = {}
    for sp_id, sp in prof.get("serving", {}).items():
        for m in sp.get("models", []):
            valid.add(f"{sp_id}/{m['id']}")
            served[f"{sp_id}/{m['id']}"] = m
    for preset_name, preset in prof.get("presets", {}).items():
        for tier_name, specs in preset.get("tiers", {}).items():
            assert specs, f"{prof_name}.{preset_name}.{tier_name} is empty"
            for spec in specs:
                prov, rest = spec.split("/", 1)
                mid = rest.rsplit(":", 1)[0] if ":" in rest else rest
                ref = f"{prov}/{mid}"
                if ref not in valid:
                    sys.exit(f"{prof_name}.{preset_name}.{tier_name} references unlisted model {ref}")
                # A served model's efforts are the only thinking levels its chat
                # template takes; infer01's qwen template has no off level at all.
                efforts = served.get(ref, {}).get("efforts")
                thinking = rest.rsplit(":", 1)[1] if ":" in rest else "off"
                if efforts and thinking not in efforts:
                    sys.exit(f"{ref} tier {tier_name} asks thinking={thinking}, model takes {efforts}")
PY
}

@test "rendered AI JSON/YAML configs parse cleanly and uphold OAuth/parity invariants on personal and work" {
  local prof out
  for prof in personal work; do
    local data="{\"host\":{\"profile\":\"$prof\"}}"
    out="$BATS_TEST_TMPDIR/$prof"
    mkdir -p "$out"

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_opencode/opencode.jsonc.tmpl" "$out/opencode.jsonc" "$data"
    sed '/^[[:space:]]*\/\//d' "$out/opencode.jsonc" | jq -e '.model and .mcp.servers and .default_agent == "orchestrator"' >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_opencode/oh-my-opencode-slim.json.tmpl" "$out/slim.json" "$data"
    jq -e '
      .preset
      and .autoUpdate == false
      and (.presets | has("anthropic") | not)
      and (.presets[.preset] | keys | sort == ["designer","explorer","fixer","oracle","orchestrator"])
      and .presets[.preset].oracle.permission.edit == "deny"
      and .presets[.preset].oracle.permission.subagent == "deny"
      and .presets[.preset].fixer.permission.subagent == "deny"
    ' "$out/slim.json" >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_private_omp/agent/modify_config.yml" "$out/omp.yml" "$data"
    yq -o=json "$out/omp.yml" | jq -e '.modelRoles.default and .task.maxConcurrency and (.task.agentModelOverrides | keys | sort == ["designer","explorer","fixer","oracle"])' >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_private_omp/agent/private_models.yml.tmpl" "$out/omp-models.yml" "$data"
    yq -o=json "$out/omp-models.yml" | jq -e '.providers.local.models | length > 0' >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/modify_settings.json" "$out/pi.json" "$data"
    jq -e '.defaultModel and .subagents.disableBuiltins == true and (.enabledModels | map(startswith("anthropic/")) | any | not)' "$out/pi.json" >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" "$out/claude.json" "$data"
    jq -e '.agent == "orchestrator" and .disableAllHooks == false and (.hooks.PreToolUse | length > 0) and (.fallbackModel | type == "array") and (has("mcpServers") | not)' "$out/claude.json" >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_private_dot_claude.json" "$out/claude-dot.json" "$data"
    jq -e '.mcpServers.codegraph.command == "codegraph" and .mcpServers.engram.command == "engram" and (.mcpServers | has("delegate") | not)' "$out/claude-dot.json" >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/private_models.json.tmpl" "$out/pi-models.json" "$data"
    jq -e '.providers.local.models | length > 0' "$out/pi-models.json" >/dev/null

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_shell/exact_exports.d/ai-agents.sh.tmpl" "$out/ai-agents.sh" "$data"
    sh -n "$out/ai-agents.sh"
  done

  # Local LLM engine selection is OS/arch-driven: darwin/arm64 -> omlx, elsewhere -> llamacpp
  render_with_data "$REPO_ROOT/home/private_dot_config/local-llm/config.json.tmpl" "$BATS_TEST_TMPDIR/local-arm.json" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"}}'
  jq -e '.engine == "omlx" and (.port > 0) and (.models | length > 0)' "$BATS_TEST_TMPDIR/local-arm.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/local-llm/config.json.tmpl" "$BATS_TEST_TMPDIR/local-intel.json" '{"host":{"arch":"amd64","distro":{"family":"darwin","id":"darwin"},"profile":"work"}}'
  jq -e '.engine == "llamacpp" and (.port > 0) and (.models | length > 0)' "$BATS_TEST_TMPDIR/local-intel.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/local-llm/config.json.tmpl" "$BATS_TEST_TMPDIR/local-zero-warmup.json" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"},"ai":{"profiles":{"personal":{"serving":{"local":{"omlx_bench_warmup_runs":0}}}}}}'
  jq -e '.omlx_bench_warmup_runs == 0' "$BATS_TEST_TMPDIR/local-zero-warmup.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/llama.cpp/models.ini.tmpl" "$BATS_TEST_TMPDIR/models.ini" '{"host":{"arch":"amd64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"},"toolchains":{"ai":true}}'
  grep -Fq 'version = 1' "$BATS_TEST_TMPDIR/models.ini"
  grep -Fq 'flash-attn = auto' "$BATS_TEST_TMPDIR/models.ini"
}

@test "all 4 worker roles render cleanly for pi, omp, opencode, and claude" {
  local role out="$BATS_TEST_TMPDIR/roles"
  mkdir -p "$out"
  for role in designer explorer fixer oracle; do
    render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/exact_agents/${role}.md.tmpl" "$out/pi-${role}.md"
    grep -Fq "name: $role" "$out/pi-${role}.md"
    grep -Fq "subagentOnlyExtensions:" "$out/pi-${role}.md" && grep -Fq "/.config/dcg/pi-guard.ts" "$out/pi-${role}.md" || fail "pi role $role missing subagentOnlyExtensions pi-guard.ts"

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_private_omp/agent/exact_agents/${role}.md.tmpl" "$out/omp-${role}.md"
    grep -Fq "name: $role" "$out/omp-${role}.md"

    render_with_data "$REPO_ROOT/home/private_dot_config/exact_opencode/oh-my-opencode-slim/${role}_append.md.tmpl" "$out/oc-${role}.md"
    [ -s "$out/oc-${role}.md" ] || fail "opencode role $role rendered empty"

    render_with_data "$REPO_ROOT/home/private_dot_config/claude/exact_agents/${role}.md.tmpl" "$out/claude-${role}.md" '{"host":{"profile":"personal"}}'
    grep -Fq "name: $role" "$out/claude-${role}.md"
  done
  grep -Fq "mcp__codegraph__*" "$out/claude-explorer.md" || fail "claude explorer missing mcp__codegraph__* tool"
  grep -Fq "mcp__engram__mem_search" "$out/claude-oracle.md" || fail "claude oracle missing mcp__engram__mem_search"
  ! grep -Fq "mcp__plugin_engram" "$out/claude-oracle.md" || fail "claude oracle still uses plugin engram prefix"
  ! grep -Fq "mem_save" "$out/claude-oracle.md" || fail "claude oracle should not receive mem_save"
  grep -Fq "mcp" "$out/pi-explorer.md" || fail "pi explorer missing mcp tool"
  grep -Fq "mem_search" "$out/pi-oracle.md" || fail "pi oracle missing engram mem_search tool"
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/exact_agents/fixer.md.tmpl" "$out/pi-fixer-balanced.md" '{"host":{"profile":"personal"},"ai":{"profiles":{"personal":{"default_preset":"balanced"}}}}'
  grep -Fq "model: opencode/" "$out/pi-fixer-balanced.md" || fail "pi fixer balanced preset should map opencode-zen to opencode/"

  render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/private_advisor.json.tmpl" "$out/pi-advisor-balanced.json" '{"host":{"profile":"personal"},"ai":{"profiles":{"personal":{"default_preset":"balanced"}}}}'
  jq -e '.advisor == "opencode/kimi-k3.1-pro"' "$out/pi-advisor-balanced.json" >/dev/null
}

@test "nono profiles and read-only dcg settings render with uniform credentials, deny_vars, and OAuth scoping" {
  local agent out
  for agent in claude omp opencode pi; do
    out="$BATS_TEST_TMPDIR/intel-${agent}.json"
    render_with_data "$REPO_ROOT/home/private_dot_config/nono/exact_profiles/${agent}.json.tmpl" "$out" '{"host":{"arch":"amd64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"}}'
    jq -e --arg a "$agent" '
      .meta.name == $a
      and (.extends | index("nolabs-ai/" + $a) != null)
      and ((.filesystem.allow // []) | map(endswith("/.config/dcg")) | any | not)
      and ((.filesystem.read // []) | map(endswith("/.config/dcg")) | any)
      and ((.filesystem.read // []) | map(endswith("/.config/git/hooks-template")) | any)
      and ((.filesystem.read // []) | index("/opt/local") != null)
      and ((.network.open_port // []) | index(7437) != null)
      and ((.network.open_port // []) | index(8321) != null)
      and ((.environment.deny_vars // []) | (index("*_TOKEN") != null and index("*_KEY") != null and index("*SECRET*") != null and index("DCG_*") != null and index("BW_*") != null and index("BWS_*") != null and index("PROTON_PASS_*") != null and index("OP_*") != null and index("SSH_AUTH_SOCK") != null))
      and .environment.case_insensitive_vars == true
      and (.network.custom_credentials.github_git | (.inject_mode == "basic_auth" and .upstream == "https://github.com" and .credential_key == "env://GITHUB_GIT_CREDENTIAL" and (.endpoint_rules | any(.method == "POST" and .path == "/*/*/git-receive-pack"))))
      and ((.filesystem.deny // []) | (map(endswith("/Library/Application Support/Bitwarden CLI")) | any))
    ' "$out" >/dev/null || fail "intel darwin nono profile invariants failed for $agent"
  done

  # Claude keeps only the github routes (keychain login, no anthropic route); deepseek/openrouter/opencode
  # route via nono phantoms to omp/opencode/pi only (R24), and work profile omits infer01 (R25).
  jq -e '(.network.credentials // []) | sort == ["brave","deepseek","github","github_git","opencode","openrouter"]' "$BATS_TEST_TMPDIR/intel-omp.json" >/dev/null
  jq -e '(.network.credentials // []) | sort == ["brave","deepseek","github","github_git","opencode","openrouter"]' "$BATS_TEST_TMPDIR/intel-opencode.json" >/dev/null
  jq -e '(.network.credentials // []) | sort == ["brave","deepseek","github","github_git","opencode","openrouter"]' "$BATS_TEST_TMPDIR/intel-pi.json" >/dev/null
  jq -e '(.network.credentials // []) | sort == ["github","github_git"]' "$BATS_TEST_TMPDIR/intel-claude.json" >/dev/null
  jq -e '.network.custom_credentials | (.deepseek.credential_key == "env://DEEPSEEK_API_KEY") and (.opencode.credential_key == "env://OPENCODE_API_KEY") and (.openrouter.credential_key == "env://OPENROUTER_API_KEY") and (.github.credential_key == "env://GITHUB_TOKEN") and (.brave.credential_key == "env://BRAVE_SEARCH_API_KEY") and (.brave.env_var == "BRAVE_API_KEY") and (.brave.inject_header == "X-Subscription-Token") and (.brave.upstream == "https://api.search.brave.com") and (.deepseek | has("keychain") | not)' "$BATS_TEST_TMPDIR/intel-pi.json" >/dev/null
  jq -e '(.network.allow_domain // []) | index("infer01") != null' "$BATS_TEST_TMPDIR/intel-pi.json" >/dev/null
  # CI log storage is GitHub's named Blob accounts only; a blob wildcard admits anyone's storage.
  for agent in claude omp opencode pi; do
    jq -e '(.network.allow_domain // []) as $d
      | ($d | index("productionresultssa0.blob.core.windows.net") != null)
      and ($d | map(select(endswith(".blob.core.windows.net"))) | all(test("^productionresultssa[0-9]+\\.blob\\.core\\.windows\\.net$")))' \
      "$BATS_TEST_TMPDIR/intel-${agent}.json" >/dev/null || fail "$agent: blob hosts must be named productionresultssaN accounts only"
  done
  jq -e '(.environment.set_vars.GIT_CONFIG_NOSYSTEM == "1") and (.environment.set_vars.NPM_CONFIG_CACHE | contains("/.cache/sandbox-npm")) and (.environment.set_vars.UV_CACHE_DIR | contains("/.cache/sandbox-uv"))' "$BATS_TEST_TMPDIR/intel-pi.json" >/dev/null
  jq -e '(.filesystem.deny | length) > 0' "$BATS_TEST_TMPDIR/intel-opencode.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/nono/exact_profiles/opencode.json.tmpl" "$BATS_TEST_TMPDIR/linux-opencode.json" '{"host":{"arch":"amd64","distro":{"family":"linux","id":"ubuntu"},"profile":"personal"}}'
  jq -e '(.filesystem | has("deny") | not) and .environment.set_vars.GIT_CONFIG_NOSYSTEM == "1"' "$BATS_TEST_TMPDIR/linux-opencode.json" >/dev/null
  jq -e '.network.custom_credentials | (.deepseek.credential_key == "env://DEEPSEEK_API_KEY") and (.opencode.credential_key == "env://OPENCODE_API_KEY") and (.openrouter.credential_key == "env://OPENROUTER_API_KEY")' "$BATS_TEST_TMPDIR/linux-opencode.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/nono/exact_profiles/pi.json.tmpl" "$BATS_TEST_TMPDIR/work-pi.json" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"work"}}'
  jq -e '(.network.allow_domain // []) | index("infer01") == null' "$BATS_TEST_TMPDIR/work-pi.json" >/dev/null

  # Read-only Claude settings overlay in ~/.config/dcg/ disables built-in sandbox (nono owns it)
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_dcg/claude-settings.json.tmpl" "$BATS_TEST_TMPDIR/claude-settings.json"
  jq -e '.disableAllHooks == false and .sandbox.enabled == false and (.hooks.PreToolUse[0].hooks[0].command | contains("/.config/dcg/claude-guard.mjs")) and (.autoMode.environment | join(" ") | contains("nono"))' "$BATS_TEST_TMPDIR/claude-settings.json" >/dev/null

  # Desktop built-in sandbox renders on darwin with failIfUnavailable + denyRead, off on linux (R12/AE1)
  render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" "$BATS_TEST_TMPDIR/claude-darwin.json" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"}}'
  jq -e '.sandbox.enabled == true and .sandbox.failIfUnavailable == true and .sandbox.autoAllowBashIfSandboxed == true and (.sandbox.filesystem.denyRead | map(endswith("/.ssh")) | any) and (.sandbox.filesystem.denyRead | map(endswith("/.config/age")) | any) and (.sandbox.filesystem.denyRead | map(endswith("/Library/Keychains")) | any) and (.sandbox.filesystem.denyRead | map(endswith("/.config/gh/hosts.yml")) | any | not) and (.sandbox.network.allowedDomains | length > 10) and (.autoMode.environment | join(" ") | contains("nono") | not)' "$BATS_TEST_TMPDIR/claude-darwin.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" "$BATS_TEST_TMPDIR/claude-linux.json" '{"host":{"arch":"amd64","distro":{"family":"linux","id":"ubuntu"},"profile":"personal"}}'
  jq -e '.sandbox.enabled == false and .autoMode.environment == ["$defaults"]' "$BATS_TEST_TMPDIR/claude-linux.json" >/dev/null

  # Shared orchestrator body in Claude orchestrator & Pi APPEND_SYSTEM.md, absent from Pi SYSTEM.md (U12)
  render_with_data "$REPO_ROOT/home/private_dot_config/claude/exact_agents/orchestrator.md.tmpl" "$BATS_TEST_TMPDIR/claude-orch.md" '{"host":{"profile":"personal"}}'
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/APPEND_SYSTEM.md.tmpl" "$BATS_TEST_TMPDIR/pi-orch.md" '{"host":{"profile":"personal"}}'
  grep -Fq '## Delegation contract' "$BATS_TEST_TMPDIR/claude-orch.md"
  grep -Fq '## Delegation contract' "$BATS_TEST_TMPDIR/pi-orch.md"
  ! grep -Fq '## Delegation contract' "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/SYSTEM.md"

  # Native Anthropic provider disabled on OpenCode, Pi, and OMP (R21/AE4)
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_opencode/opencode.jsonc.tmpl" "$BATS_TEST_TMPDIR/oc-anth.jsonc" '{"host":{"profile":"personal"}}'
  sed '/^[[:space:]]*\/\//d' "$BATS_TEST_TMPDIR/oc-anth.jsonc" | jq -e '(.policies // []) | any(.action == "provider.use" and .effect == "deny" and .resource == "anthropic")' >/dev/null
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/private_models.json.tmpl" "$BATS_TEST_TMPDIR/pi-anth.json" '{"host":{"profile":"personal"}}'
  jq -e '.providers.anthropic.baseUrl == "http://127.0.0.1:1"' "$BATS_TEST_TMPDIR/pi-anth.json" >/dev/null
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_private_omp/agent/modify_config.yml" "$BATS_TEST_TMPDIR/omp-anth.yml" '{"host":{"distro":{"family":"darwin","id":"darwin"},"profile":"personal"}}'
  yq -o=json "$BATS_TEST_TMPDIR/omp-anth.yml" | jq -e '((.disabledProviders // []) | index("anthropic") != null) and .isolation.backend == "apfs" and (.task | has("isolation") | not)' >/dev/null
}

@test "modify_ templates preserve user keys while enforcing managed settings and auth normalization" {
  local out="$BATS_TEST_TMPDIR/modify"
  mkdir -p "$out"

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" \
    '{"userCustomFlag": true, "agent": "stale", "disableAllHooks": true, "apiKeyHelper": "evil", "proxyAuthHelper": "evil", "enableAllProjectMcpServers": true, "autoMode": {"soft_deny": ["evil"], "classifyAllShell": false}, "extraKnownMarketplaces": {"rogue": {}}, "sandbox": {"excludedCommands": ["rm"]}, "mcpServers": {"delegate": {}}}' \
    "$out/claude.json" '{"host":{"profile":"personal"}}'
  jq -e '.userCustomFlag == true and .agent == "orchestrator" and .disableAllHooks == false and (has("apiKeyHelper") | not) and (has("proxyAuthHelper") | not) and (has("enableAllProjectMcpServers") | not) and (has("mcpServers") | not) and (.autoMode | has("soft_deny") | not) and (.extraKnownMarketplaces | has("rogue") | not) and (.sandbox | has("excludedCommands") | not) and (.hooks.PreToolUse[0].hooks[0].command | contains("/.config/dcg/claude-guard.mjs"))' "$out/claude.json" >/dev/null

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_config/claude/modify_private_dot_claude.json" \
    '{"oauthAccount": {"email": "keep@example.com"}, "mcpServers": {"delegate": {"command": "old"}, "rogue": {"command": "evil"}}, "projects": {"/tmp/p": {"hasTrustDialogAccepted": true, "mcpServers": {"evil": {}}, "enabledMcpjsonServers": ["x"], "allowedTools": ["Bash"]}}}' \
    "$out/claude-dot.json" '{"host":{"profile":"personal"}}'
  jq -e '.oauthAccount.email == "keep@example.com" and (.mcpServers | keys | sort == ["codegraph","engram"]) and .projects["/tmp/p"].hasTrustDialogAccepted == true and (.projects["/tmp/p"].mcpServers | length == 0) and (.projects["/tmp/p"].enabledMcpjsonServers | length == 0) and (.projects["/tmp/p"].allowedTools | length == 0)' "$out/claude-dot.json" >/dev/null

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/modify_settings.json" \
    '{"userNote": "keep-me", "defaultModel": "old"}' \
    "$out/pi.json" '{"host":{"profile":"personal"}}'
  jq -e '.userNote == "keep-me" and .defaultModel != "old"' "$out/pi.json" >/dev/null

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_config/exact_private_omp/agent/modify_config.yml" \
    $'userKey: keep-me\n' \
    "$out/omp.yml" '{"host":{"profile":"personal"}}'
  yq -o=json "$out/omp.yml" | jq -e '.userKey == "keep-me" and (.modelRoles.default | length > 0)' >/dev/null

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_config/exact_pi/exact_agent/modify_private_auth.json" \
    '{"anthropic":{"type":"oauth"},"custom-oauth":{"type":"oauth"},"deepseek":{"type":"api_key","key":"raw-secret"}}' \
    "$out/pi-auth.json" '{"host":{"profile":"personal"}}'
  jq -e '."custom-oauth".type == "oauth" and (has("anthropic") | not) and .deepseek.key == "$DEEPSEEK_API_KEY"' "$out/pi-auth.json" >/dev/null

  render_modify_with_stdin \
    "$REPO_ROOT/home/private_dot_local/share/opencode/modify_private_auth.json" \
    '{"anthropic":{"type":"oauth"},"custom-oauth":{"type":"oauth"},"deepseek":{"type":"api_key","key":"raw"},"opencode":{"type":"api_key","key":"raw"}}' \
    "$out/oc-auth.json" '{"host":{"profile":"personal"}}'
  jq -e '."custom-oauth".type == "oauth" and (has("anthropic") | not) and (has("deepseek") | not) and (has("opencode") | not)' "$out/oc-auth.json" >/dev/null
}

@test "render matrix archives all OS/arch/profile cells cleanly with non-intersecting managed/remove sets" {
  local cfg="$BATS_TEST_TMPDIR/fixture-chezmoi.yaml"
  cat >"$cfg" <<EOF
destDir: "$BATS_TEST_TMPDIR/home"
sourceDir: "$REPO_ROOT/home"
data:
  brew:
    path: "/nonexistent/brew"
  gpg:
    encrypt: ""
    sign: ""
  host:
    arch: "amd64"
    distro:
      family: "linux"
      id: "ubuntu"
    home: "$BATS_TEST_TMPDIR/home"
    interactive: false
    profile: "personal"
    restricted: false
    source: "$REPO_ROOT/home"
    type: "desktop"
  personal:
    email: "matrix@example.com"
    name: "Matrix Test"
    username: "matrix"
  secrets:
    age: false
  toolchains:
    ai: true
    claude: true
    cloud: true
    docker: true
    extra: true
    golang: true
    iac: true
    java: true
    kubernetes: true
    node: true
    omp: true
    opencode: true
    pi: true
    python: true
    rust: true
EOF
  mkdir -p "$BATS_TEST_TMPDIR/home"

  local -a cells=() pids=() labels=()
  local spec family id arch htype prof
  for spec in \
    "darwin:darwin:amd64:desktop" \
    "darwin:darwin:arm64:laptop" \
    "linux:ubuntu:amd64:desktop" \
    "linux:ubuntu:arm64:desktop" \
    "linux:ubuntu:amd64:wsl" \
    "linux:fedora:amd64:desktop" \
    "linux:archlinux:amd64:ephemeral"
  do
    for prof in personal work; do
      cells+=("${spec}:${prof}")
    done
  done

  # Run matrix cells in parallel batches (portable across bash 3.2+; close Bats FD 3)
  local idx=0 batch_size=4 cell err_f i
  while [ "$idx" -lt "${#cells[@]}" ]; do
    pids=()
    labels=()
    for ((i = 0; i < batch_size && idx < ${#cells[@]}; i++, idx++)); do
      cell="${cells[$idx]}"
      IFS=':' read -r family id arch htype prof <<<"$cell"
      err_f="$BATS_TEST_TMPDIR/err-${id}-${arch}-${htype}-${prof}.txt"
      labels+=("${id}/${arch}/${htype}/${prof}:${err_f}")
      (
        set -o pipefail
        override="$(jq -cn \
          --arg family "$family" --arg id "$id" --arg arch "$arch" \
          --arg htype "$htype" --arg prof "$prof" \
          '{host:{arch:$arch,distro:{family:$family,id:$id},profile:$prof,type:$htype}}')"
        if ! out="$(chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data "$override" \
          archive --exclude=externals --output /dev/null 2>&1)"; then
          printf 'archive failed for %s/%s/%s/%s: %s\n' "$id" "$arch" "$htype" "$prof" "$out" >"$err_f"
          exit 1
        fi
        managed_f="$BATS_TEST_TMPDIR/managed-${id}-${arch}-${htype}-${prof}.txt"
        remove_f="$BATS_TEST_TMPDIR/remove-${id}-${arch}-${htype}-${prof}.txt"
        chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data "$override" managed --exclude=remove >"$managed_f"
        chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data "$override" \
          execute-template -f "$REPO_ROOT/home/.chezmoiremove.tmpl" | sed '/^[[:space:]]*$/d' >"$remove_f"
        overlap="$(comm -12 <(sort -u "$managed_f") <(sort -u "$remove_f"))"
        if [ -n "$overlap" ]; then
          printf 'managed/remove overlap for %s/%s/%s/%s: %s\n' "$id" "$arch" "$htype" "$prof" "$overlap" >"$err_f"
          exit 1
        fi
      ) 3>&- &
      pids+=("$!")
    done
    for i in "${!pids[@]}"; do
      if ! wait "${pids[$i]}"; then
        err_f="${labels[$i]#*:}"
        fail "$(cat "$err_f" 2>/dev/null || printf 'cell failed: %s' "${labels[$i]%%:*}")"
      fi
    done
  done

  # U16: WSL excludes docker-ce while standard Ubuntu keeps it
  local wsl_pkgs ubuntu_pkgs
  wsl_pkgs="$(chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data '{"host":{"arch":"amd64","distro":{"family":"linux","id":"ubuntu"},"type":"wsl"}}' \
    execute-template <<<'{{ includeTemplate "base/packages/collect-packages" (dict "root" . "manager" "system" "format" "install") }}')"
  ubuntu_pkgs="$(chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data '{"host":{"arch":"amd64","distro":{"family":"linux","id":"ubuntu"},"type":"desktop"}}' \
    execute-template <<<'{{ includeTemplate "base/packages/collect-packages" (dict "root" . "manager" "system" "format" "install") }}')"
  ! printf '%s' "$wsl_pkgs" | grep -qw 'docker-ce' || fail "WSL system packages unexpectedly include docker-ce: $wsl_pkgs"
  printf '%s' "$ubuntu_pkgs" | grep -qw 'docker-ce' || fail "Ubuntu desktop system packages missing docker-ce: $ubuntu_pkgs"

  # Claude migration script is gated on toolchains.claude
  local scripts_off scripts_on
  scripts_off="$(chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data '{"toolchains":{"claude":false}}' managed --include scripts)"
  scripts_on="$(chezmoi --config "$cfg" --source "$REPO_ROOT" --override-data '{"toolchains":{"claude":true}}' managed --include scripts)"
  ! printf '%s\n' "$scripts_off" | grep -Fq '05_migrate-claude-dir.sh' || fail "claude=false unexpectedly includes 05_migrate-claude-dir.sh"
  printf '%s\n' "$scripts_on" | grep -Fq '05_migrate-claude-dir.sh' || fail "claude=true missing 05_migrate-claude-dir.sh"
}

@test "Claude gopls-lsp plugin is gated on toolchains.golang in settings and manifest" {
  local out="$BATS_TEST_TMPDIR/claude-go"
  mkdir -p "$out"

  render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" "$out/settings-on.json" '{"host":{"profile":"personal"},"toolchains":{"golang":true}}'
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_dcg/claude-managed.json.tmpl" "$out/manifest-on.json" '{"host":{"profile":"personal"},"toolchains":{"golang":true}}'
  jq -e '.enabledPlugins["gopls-lsp@claude-plugins-official"] == true' "$out/settings-on.json" >/dev/null
  jq -e '.enabledPlugins["gopls-lsp@claude-plugins-official"] == true' "$out/manifest-on.json" >/dev/null

  render_with_data "$REPO_ROOT/home/private_dot_config/claude/modify_settings.json" "$out/settings-off.json" '{"host":{"profile":"personal"},"toolchains":{"golang":false}}'
  render_with_data "$REPO_ROOT/home/private_dot_config/exact_dcg/claude-managed.json.tmpl" "$out/manifest-off.json" '{"host":{"profile":"personal"},"toolchains":{"golang":false}}'
  jq -e '.enabledPlugins | has("gopls-lsp@claude-plugins-official") | not' "$out/settings-off.json" >/dev/null
  jq -e '.enabledPlugins | has("gopls-lsp@claude-plugins-official") | not' "$out/manifest-off.json" >/dev/null
}

@test "Colima template follows the kubernetes toolchain and keeps Traefik on both profiles" {
  local out="$BATS_TEST_TMPDIR/colima"
  local tmpl="$REPO_ROOT/home/private_dot_config/exact_colima/exact__templates/default.yaml.tmpl"
  mkdir -p "$out"

  render_with_data "$tmpl" "$out/work.yaml" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"work"},"toolchains":{"kubernetes":true}}'
  yq -o=json "$out/work.yaml" | jq -e '.kubernetes.enabled == true and (.kubernetes.k3sArgs | length == 0)' >/dev/null

  render_with_data "$tmpl" "$out/personal.yaml" '{"host":{"arch":"amd64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"},"toolchains":{"kubernetes":true}}'
  yq -o=json "$out/personal.yaml" | jq -e '.kubernetes.enabled == true and (.kubernetes.k3sArgs | length == 0)' >/dev/null

  render_with_data "$tmpl" "$out/off.yaml" '{"host":{"arch":"arm64","distro":{"family":"darwin","id":"darwin"},"profile":"personal"},"toolchains":{"kubernetes":false}}'
  yq -o=json "$out/off.yaml" | jq -e '.kubernetes.enabled == false' >/dev/null
}

@test "zsh plugin externals render tracking default branches with exact=true and a weekly refreshPeriod" {
  local out="$BATS_TEST_TMPDIR/zsh-externals.toml"
  render_with_data "$REPO_ROOT/home/.chezmoiexternals/zsh.toml.tmpl" "$out"

  python3 - "$out" <<'PY'
import re, sys, tomllib

data = tomllib.loads(open(sys.argv[1], "rb").read().decode("utf-8"))
expected = {
    ".config/zsh/plugins/zsh-autosuggestions",
    ".config/zsh/plugins/zsh-syntax-highlighting",
    ".config/zsh/plugins/fzf-tab",
}
assert set(data.keys()) == expected, f"unexpected targets: {set(data.keys())}"
# Track-latest policy (docs/agents/chezmoi.md): branch refs, never SHA pins.
branch_re = re.compile(r"^https://github\.com/[^/]+/[^/]+/archive/(master|main)\.tar\.gz$")
for target, entry in data.items():
    assert entry.get("type") == "archive", f"{target}: type != archive"
    assert entry.get("exact") is True, f"{target}: exact != true"
    assert entry.get("refreshPeriod") == "168h", f"{target}: refreshPeriod != 168h: {entry.get('refreshPeriod')}"
    assert branch_re.match(entry.get("url", "")), f"{target}: url does not track a default branch: {entry.get('url')}"
PY
}
