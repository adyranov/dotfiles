// opencode-guard: OpenCode DCG plugin living in read-only ~/.config/dcg/
// (symlinked from ~/.config/opencode/plugins/dcg-guard.js for v2 auto-discovery).
// Routes bash/shell calls through `dcg hook --robot --batch` and file-writing
// calls through the shared write-axis path floors (fail closed).
import { statSync } from "node:fs";
import { resolve } from "node:path";
import { dcgBlockReason, extractPatchPaths, fileWriteBlockReason, fileWritesBlockReason } from "./guard-core.mjs";

const FILE_WRITE_TOOLS = new Set(["write", "edit", "multiedit"]);
const PATCH_TOOLS = new Set(["patch", "apply_patch"]);
const AST_WRITE_TOOLS = new Set(["ast_grep_replace"]);
const GLOB_CHARS = /[*?[\]{}]/;

function isDirectoryTarget(target, cwd) {
  try {
    const abs = (target === "~" || target.startsWith("~/")) && process.env.HOME
      ? `${process.env.HOME.replace(/\/$/, "")}${target.slice(1)}`
      : resolve(cwd || "/", target);
    return statSync(abs).isDirectory();
  } catch {
    return false;
  }
}

function checkToolCall(toolName, args) {
  const tool = String(toolName || "").toLowerCase();
  const a = args || {};
  const cwd = a.cwd ?? process.cwd();
  if (tool === "shell" || tool === "bash") return dcgBlockReason(a.command, a.cwd);
  if (PATCH_TOOLS.has(tool)) {
    const patchText = a.patchText ?? a.patch_text ?? a.patch ?? a.input;
    return fileWritesBlockReason(extractPatchPaths(patchText), cwd, tool);
  }
  if (AST_WRITE_TOOLS.has(tool)) {
    // ast_grep_replace defaults to dry-run; only guard mutating calls (dryRun === false).
    if (a.dryRun !== false && a.dry_run !== false) return null;
    const single = a.path ?? a.filePath ?? a.file_path;
    const targets = Array.isArray(a.paths)
      ? a.paths
      : single !== undefined
        ? [single]
        : [];
    const broad = targets.find((t) => typeof t === "string" && (GLOB_CHARS.test(t) || isDirectoryTarget(t, cwd)));
    if (broad) {
      return `Blocked by DCG: ${tool} mutating call targets a directory or glob (${broad}); pass explicit file paths so write-axis floors can verify every target.`;
    }
    return fileWritesBlockReason(targets, cwd, tool);
  }
  if (FILE_WRITE_TOOLS.has(tool)) {
    return fileWriteBlockReason(a.filePath ?? a.file_path ?? a.path, cwd);
  }
  return null;
}

export const DcgGuard = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (!input) return;
      const reason = checkToolCall(input.tool, output && output.args);
      if (reason) throw new Error(reason);
    },
  };
};

export const DcgGuardV2Setup = async (ctx) => {
  const registration = await ctx.tool.hook("execute.before", async (event) => {
    if (!event) return;
    const reason = checkToolCall(event.tool, event.input);
    if (reason) throw new Error(reason);
  });
  return () => registration?.dispose?.();
};

export default { id: "dcg-guard", server: DcgGuard, setup: DcgGuardV2Setup };
