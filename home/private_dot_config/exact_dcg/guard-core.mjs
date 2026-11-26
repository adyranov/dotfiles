// Shared DCG guard core imported by all agent hooks (claude, opencode, pi, omp).
// Approvals run in the operator's terminal, never in the agent:
//   built-in packs: `dcg allow <rule-id> --reason "<why>"`
//   custom packs:   `dcg allowlist add-command '<command>'`
//   inspect:        `dcg explain`
import { spawnSync } from "node:child_process";
import { lstatSync, readlinkSync, realpathSync } from "node:fs";
import { dirname, normalize } from "node:path";

const DCG_CANDIDATES = [
  `${process.env.HOME || ""}/.local/share/mise/installs/github-dicklesworthstone-destructive-command-guard/latest/dcg`,
  `${process.env.HOME || ""}/.local/share/mise/shims/dcg`,
  "/usr/local/bin/dcg",
  "dcg",
];
const DCG_TIMEOUT_MS = 10000;

// Custom-pack rule ids have no `dcg allow` route, so they take the
// exact-command allowlist; only shaped ids are interpolated.
function dcgApprovalCommand(rule, command) {
  if (typeof rule !== "string" || !/^[A-Za-z0-9._:-]+$/.test(rule)) return null;
  if (rule.startsWith("user.") || rule.startsWith("chezmoi.custom:"))
    return `dcg allowlist add-command '${String(command).split("'").join("'\\''")}'`;
  return `dcg allow ${rule} --reason "dcg-guard block ${rule} ${new Date().toISOString()}"`;
}

// Fail closed: no startable dcg, or no parsable verdict, blocks the command.
export function dcgBlockReason(command, cwd) {
  if (typeof command !== "string" || command.length === 0) return null;
  const payload = `${JSON.stringify({ tool_name: "Bash", tool_input: { command } })}\n`;
  const cleanEnv = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (!k.startsWith("DCG_")) cleanEnv[k] = v;
  }
  cleanEnv.DCG_FAIL_CLOSED = "1";
  let result = null;
  for (const candidate of DCG_CANDIDATES) {
    let probe;
    try {
      probe = spawnSync(candidate, ["hook", "--robot", "--batch"], {
        input: payload,
        encoding: "utf8",
        timeout: DCG_TIMEOUT_MS,
        cwd: typeof cwd === "string" && cwd ? cwd : undefined,
        env: cleanEnv,
      });
    } catch {
      continue;
    }
    if (probe.error && probe.status == null && !probe.signal) continue; // never started
    result = probe;
    break;
  }
  if (!result)
    return "Blocked by DCG: no candidate dcg binary could be started (fail-closed). Operator terminal: install/repair dcg, e.g. mise install github:Dicklesworthstone/destructive_command_guard";
  const line = String(result.stdout || "").trim().split("\n")[0];
  let verdict = null;
  try {
    verdict = line ? JSON.parse(line) : null;
  } catch {
    verdict = null;
  }
  const decision = verdict && verdict.decision;
  if (decision === "deny" || decision === "ask" || decision === "indeterminate") {
    const rule = verdict && verdict.rule_id;
    const approval = dcgApprovalCommand(rule, command);
    if (!approval)
      return `${(verdict && verdict.reason) || "Blocked by DCG (no rule id)"}\n\nRule: (none reported)\nApproval: not rule-approvable; operator terminal: dcg explain '<command>'`;
    return `${(verdict && verdict.reason) || `Blocked by DCG (${rule})`}\n\nRule: ${rule}\nApproval (operator terminal, not the agent): ${approval}; see: dcg explain`;
  }
  if (decision === "allow") return null;
  if (result.status === 0) return "Blocked by DCG: dcg exited 0 without a verdict (fail-closed).";
  return `Blocked by DCG: dcg ended without a verdict (exit ${result.status}${result.signal ? ` signal ${result.signal}` : ""}; fail-closed).`;
}

// Tool-axis file-write floors (TOOL-only: Bash/subprocess writes are not seen
// here). .git config/hooks writes can install code git runs; .claude
// instruction files are re-read by the model later. Lexical and symlink-
// resolved shapes are both policed; case-insensitive because APFS commonly is.
const WRITE_AXIS_FLOORS = [
  {
    rule: "chezmoi.custom:git-axis-write",
    verdict: "is git hook-persistence — writing git's config (config or config.worktree) can point core.hooksPath/include.path at code git runs, a hooks-dir write IS that code",
    patterns: [
      /(^|\/)\.git$/i,
      /(^|\/)[^/]*\.git(?:\/(?:modules|worktrees)\/.+)?\/(?:config|config\.worktree)$/i,
      /(^|\/)[^/]*\.git(?:\/(?:modules|worktrees)\/.+)?\/hooks(\/|$)/i,
    ],
  },
  {
    rule: "chezmoi.custom:claude-instructions-write",
    verdict: "is a Claude instruction file — a write here is prompt injection the model re-reads later (CLAUDE.md, rules, agents, commands, skills)",
    patterns: [
      /(^|\/)(?:\.config\/claude|\.claude)\/CLAUDE\.md$/i,
      /(^|\/)(?:\.config\/claude|\.claude)\/(?:rules|agents|commands|skills)(\/|$)/i,
    ],
  },
  {
    rule: "chezmoi.custom:agent-safety-controls-write",
    verdict: "is an agent safety-control or MCP execution file (DCG hook, sandbox profile, managed settings, or project .mcp.json) — modifying it weakens guardrails or injects commands",
    patterns: [
      /(^|\/)\.config\/(?:dcg|nono|agents)(\/|$)/i,
      /(^|\/)\.mcp\.json$/i,
      /(^|\/)\.claude\.json$/i,
      /(^|\/)opencode\.jsonc?$/i,
      /(^|\/)\.(?:opencode|pi|omp)(\/|$)/i,
      /(^|\/)(?:\.config\/claude|\.claude)\/(?:(?:hooks|agents)(\/|$)|settings(?:\.local)?\.json$)/i,
      /(^|\/)\.config\/opencode\/(?:(?:plugins|oh-my-opencode-slim)(\/|$)|opencode\.jsonc?$|oh-my-opencode-slim\.json$|cli\.json$)/i,
      /(^|\/)\.local\/share\/opencode\/auth\.json$/i,
      /(^|\/)(?:\.config\/(?:pi|omp)|\.(?:pi|omp))\/agent\/(?:(?:extensions|agents)(\/|$)|settings\.json$|config\.yml$|mcp\.json$|SYSTEM\.md$|APPEND_SYSTEM\.md$|models\.json$|models\.yml$|auth\.json$)/i,
    ],
  },
];
const WRITE_AXIS_APPROVAL = "Approval (operator terminal, not the agent): not dcg-rule-approvable (path axis, chezmoi-managed); operator edits the write-axis floors in home/private_dot_config/exact_dcg/guard-core.mjs and chezmoi applies; see: dcg explain";

const MAX_SYMLINK_HOPS = 32;

// Resolve an absolute path component-by-component (following existing and
// dangling symlinks before applying `..`) so `symlink/../target` resolves the
// same way the OS kernel does rather than collapsing lexically first.
function resolveOsPath(rawAbs) {
  const queue = rawAbs.split("/").filter(Boolean);
  let cur = "/";
  let hops = 0;
  while (queue.length > 0) {
    const seg = queue.shift();
    if (seg === ".") continue;
    if (seg === "..") {
      cur = dirname(cur);
      continue;
    }
    const next = cur === "/" ? `/${seg}` : `${cur}/${seg}`;
    let st = null;
    try {
      st = lstatSync(next);
    } catch {
      // Segment does not exist yet; remaining segments are literal tail unless
      // they contain `..` which still climbs over the nonexistent segment.
      cur = next;
      continue;
    }
    if (st.isSymbolicLink()) {
      hops += 1;
      if (hops > MAX_SYMLINK_HOPS) return { error: `symlink loop or >${MAX_SYMLINK_HOPS} hops while resolving ${rawAbs}` };
      const target = readlinkSync(next);
      const expanded = target.startsWith("/") ? target : `${cur === "/" ? "" : cur}/${target}`;
      if (target.startsWith("/")) cur = "/";
      const targetSegs = (target.startsWith("/") ? target : expanded.slice(cur === "/" ? 1 : cur.length + 1)).split("/").filter(Boolean);
      queue.unshift(...targetSegs);
      continue;
    }
    try {
      cur = realpathSync(next);
    } catch {
      cur = next;
    }
  }
  return { path: cur };
}

function expandHome(p) {
  if ((p === "~" || p.startsWith("~/")) && process.env.HOME) {
    return `${process.env.HOME.replace(/\/$/, "")}${p.slice(1)}`;
  }
  return p;
}

// Lexical path plus OS-resolved path (following existing & dangling symlinks
// before `..` collapse). Returns `{ error }` on symlink-hop overflow.
function writeAxisShapes(p, cwd) {
  const expanded = expandHome(p);
  const rawAbs = expanded.startsWith("/") ? expanded : `${cwd || ""}/${expanded}`;
  const lexical = normalize(rawAbs);
  const resolved = resolveOsPath(rawAbs);
  if (resolved.error) return { error: resolved.error };
  const shapes = resolved.path === lexical ? [lexical] : [lexical, resolved.path];
  return { shapes };
}

// Fail closed: an unusable path, or a relative path with no absolute cwd to
// anchor it, is an unchecked write and is refused.
export function fileWriteBlockReason(filePath, cwd) {
  if (typeof filePath !== "string" || filePath.length === 0)
    return `Blocked by DCG: file-write tool call carries no usable path (type ${typeof filePath}); the write-axis floors cannot check it (fail-closed).\n\nRule: chezmoi.custom:write-axis\n${WRITE_AXIS_APPROVAL}`;
  const expanded = expandHome(filePath);
  if (!expanded.startsWith("/") && !(typeof cwd === "string" && cwd.startsWith("/")))
    return `Blocked by DCG: relative write path with no absolute cwd to anchor it (cwd type ${typeof cwd}); the write-axis floors cannot check it (fail-closed).\n\nRule: chezmoi.custom:write-axis\n${WRITE_AXIS_APPROVAL}`;
  const { shapes, error } = writeAxisShapes(expanded, cwd);
  if (error)
    return `Blocked by DCG: ${error} (fail-closed).\n\nRule: chezmoi.custom:write-axis\n${WRITE_AXIS_APPROVAL}`;
  for (const floor of WRITE_AXIS_FLOORS) {
    const shape = shapes.find((s) => floor.patterns.some((re) => re.test(s)));
    if (shape)
      return `Blocked by DCG: ${shape} ${floor.verdict}.\n\nRule: ${floor.rule}\n${WRITE_AXIS_APPROVAL}`;
  }
  return null;
}

// Validate a list of write paths (for patch/multi-file/ast_edit tools); fail
// closed if no paths are present.
export function fileWritesBlockReason(paths, cwd, label = "file-write") {
  if (!Array.isArray(paths) || paths.length === 0)
    return `Blocked by DCG: ${label} tool call yielded no target paths to validate (fail-closed).\n\nRule: chezmoi.custom:write-axis\n${WRITE_AXIS_APPROVAL}`;
  for (const p of paths) {
    const reason = fileWriteBlockReason(p, cwd);
    if (reason) return reason;
  }
  return null;
}

// Extract target file paths from OpenCode/Codex `apply_patch` (`*** Add/Update/Delete File:`,
// `*** Move to:`) or unified diff (`+++`/`---`) payloads.
export function extractPatchPaths(patchText) {
  if (typeof patchText !== "string" || patchText.length === 0) return [];
  const paths = [];
  for (const line of patchText.split(/\r?\n/)) {
    let m = line.match(/^\*\*\*\s+(?:(?:Add|Update|Delete)\s+File|Move\s+to):\s*(.+?)(?:\s+\*\*\*)?$/);
    if (m && m[1]) {
      paths.push(m[1].trim());
      continue;
    }
    m = line.match(/^(?:\+\+\+|---)\s+([^\t\r\n]+)/);
    if (m && m[1]) {
      let raw = m[1].trim();
      if (raw.startsWith('"')) {
        const end = raw.indexOf('"', 1);
        raw = end > 1 ? raw.slice(1, end) : raw.slice(1);
      } else {
        raw = raw.replace(/\s+\d{4}-\d{2}-\d{2}\b.*$/, "");
      }
      const cleaned = raw.trim().replace(/^[ab]\//, "");
      if (cleaned && cleaned !== "/dev/null") paths.push(cleaned);
    }
  }
  return paths;
}

// Extract target file paths from OMP hashline `edit` (`[path#TAG]`) or patch payloads.
export function extractOmpEditPaths(text) {
  if (typeof text !== "string" || text.length === 0) return [];
  const paths = extractPatchPaths(text);
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\[([^\]#]+)#[^\]]+\]/);
    if (m && m[1]) paths.push(m[1].trim());
  }
  return paths;
}
