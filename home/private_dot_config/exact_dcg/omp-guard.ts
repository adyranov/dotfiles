// omp-guard: OMP DCG extension living in read-only ~/.config/dcg/
// (injected via `omp --extension=~/.config/dcg/omp-guard.ts` by the launcher).
// Routes command-executing tool calls (bash, eval, computer) through `dcg` and
// file-writing tool calls through the shared write-axis path floors (fail closed).
import { statSync } from "node:fs";
import { resolve } from "node:path";
import { dcgBlockReason, extractOmpEditPaths, fileWriteBlockReason, fileWritesBlockReason } from "./guard-core.mjs";

const COMMAND_TOOLS = new Set(["bash", "eval", "computer"]);
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
      if (COMMAND_TOOLS.has(event.toolName)) {
        const text = event.toolName === "bash"
          ? input.command
          : event.toolName === "eval"
            ? input.code
            : JSON.stringify(input.actions ?? "");
        reason = dcgBlockReason(text, event.toolName === "bash" ? input.cwd : undefined);
      } else if (event.toolName === "write") {
        reason = fileWriteBlockReason(input.path ?? input.file_path, cwd);
      } else if (event.toolName === "edit") {
        const direct = input.path ?? input.file_path;
        if (direct !== undefined) {
          const targets = [direct];
          const moved = input.move ?? input.rename ?? input.new_path;
          if (moved !== undefined) targets.push(moved);
          reason = fileWritesBlockReason(targets, cwd, "edit");
        } else {
          reason = fileWritesBlockReason(extractOmpEditPaths(input.input ?? input.patch ?? ""), cwd, "edit");
        }
      } else if (event.toolName === "ast_edit") {
        const targets = Array.isArray(input.paths)
          ? input.paths
          : input.path !== undefined
            ? [input.path]
            : [];
        const broad = targets.find((t) => typeof t === "string" && (GLOB_CHARS.test(t) || isDirectoryTarget(t, cwd)));
        if (broad) {
          reason = `Blocked by DCG: ast_edit targets a directory or glob (${broad}); pass explicit file paths so write-axis floors can verify every target.`;
        } else {
          reason = fileWritesBlockReason(targets, cwd, "ast_edit");
        }
      }
      if (reason) return { block: true, reason };
    } catch (err) {
      return {
        block: true,
        reason: `[dcg] OMP guard internal error (fail closed): ${err && err.message ? err.message : err}`,
      };
    }
  });
}
