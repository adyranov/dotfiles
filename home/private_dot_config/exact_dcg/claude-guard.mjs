// claude-guard: Claude Code PreToolUse hook living inside read-only ~/.config/dcg/.
// Routes Bash tool calls through `dcg hook --robot --batch` and file-writing tool
// calls through the shared write-axis path floors. Exit 2 blocks and feeds stderr
// to the model; internal errors fail closed (exit 2).
import { readFileSync } from "node:fs";
import { dcgBlockReason, fileWriteBlockReason } from "./guard-core.mjs";

const FILE_WRITE_TOOLS = ["Write", "Edit", "MultiEdit", "NotebookEdit"];

function fileWriteToolPath(toolName, args) {
  return toolName === "NotebookEdit" ? args.notebook_path : args.file_path;
}

function main() {
  const input = JSON.parse(readFileSync(0, "utf8"));
  if (!input) return;
  const args = input.tool_input || {};
  let reason = null;
  if (input.tool_name === "Bash" || input.tool_name === "Monitor") reason = dcgBlockReason(args.command, input.cwd);
  else if (FILE_WRITE_TOOLS.includes(input.tool_name))
    reason = fileWriteBlockReason(fileWriteToolPath(input.tool_name, args), input.cwd);
  if (reason) {
    console.error(reason);
    process.exit(2);
  }
}

try {
  main();
} catch (err) {
  console.error(`[dcg] PreToolUse hook internal error (fail closed): ${err && err.message ? err.message : err}`);
  process.exit(2);
}
