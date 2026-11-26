// pi-guard: Pi DCG extension living in read-only ~/.config/dcg/
// (injected via `pi --extension ~/.config/dcg/pi-guard.ts` by the launcher).
// Routes bash tool calls through `dcg hook --robot --batch` and file-writing
// tool calls through the shared write-axis path floors (fail closed).
import { statSync } from "node:fs";
import { resolve } from "node:path";
import { dcgBlockReason, fileWriteBlockReason, fileWritesBlockReason } from "./guard-core.mjs";

const FILE_WRITE_TOOLS = new Set(["write", "edit"]);
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

export default function dcgGuard(pi) {
  pi.on("tool_call", async (event) => {
    if (!event) return;
    try {
      const input = event.input || {};
      const cwd = input.cwd ?? process.cwd();
      let reason = null;
      if (event.toolName === "bash") {
        reason = dcgBlockReason(input.command, input.cwd);
      } else if (FILE_WRITE_TOOLS.has(event.toolName)) {
        reason = fileWriteBlockReason(input.path ?? input.file_path, cwd);
      } else if (AST_WRITE_TOOLS.has(event.toolName)) {
        // ast_grep_replace defaults to dry-run; only guard mutating calls (dryRun === false).
        if (input.dryRun !== false) return;
        const targets = Array.isArray(input.paths)
          ? input.paths
          : (input.path ?? input.file_path) !== undefined
            ? [input.path ?? input.file_path]
            : [];
        const broad = targets.find((t) => typeof t === "string" && (GLOB_CHARS.test(t) || isDirectoryTarget(t, cwd)));
        if (broad) {
          reason = `Blocked by DCG: ast_grep_replace mutating call targets a directory or glob (${broad}); pass explicit file paths so write-axis floors can verify every target.`;
        } else {
          reason = fileWritesBlockReason(targets, cwd, event.toolName);
        }
      }
      if (reason) return { block: true, reason };
    } catch (err) {
      return {
        block: true,
        reason: `[dcg] Pi guard internal error (fail closed): ${err && err.message ? err.message : err}`,
      };
    }
  });
}
