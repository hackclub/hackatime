// Amp plugin: forwards prompt, turn and edit events to Hackatime Desktop as
// metadata only (counts, tokens and line totals, never prompt text). Copy it
// to ~/.config/amp/plugins/ and put hackatime-ai-hook on your PATH.
import { spawn } from "node:child_process";
import type { PluginAPI, ThreadMessage } from "@ampcode/plugin";

export const description = "Sends AI activity counts to Hackatime Desktop";

const EDIT_TOOLS = new Set(["edit_file", "create_file"]);

function send(event: Record<string, unknown>) {
  const child = spawn("hackatime-ai-hook", ["amp"], { stdio: ["pipe", "ignore", "ignore"] });
  child.on("error", () => {});
  child.stdin.on("error", () => {});
  child.stdin.end(JSON.stringify(event));
}

function usage(messages: ThreadMessage[]) {
  let input_tokens = 0;
  let output_tokens = 0;
  for (const message of messages) {
    if (message.role !== "assistant" || !message.usage) continue;
    input_tokens += message.usage.inputTokens;
    output_tokens += message.usage.outputTokens;
  }
  return { input_tokens, output_tokens };
}

export default function (amp: PluginAPI) {
  const root = amp.system.workspaceRoot;
  const cwd = root ? amp.helpers.filePathFromURI(root) : process.cwd();

  amp.on("agent.start", (event) => {
    send({ hook_event_name: "UserPromptSubmit", session_id: event.thread.id, cwd });
    return {};
  });

  amp.on("agent.end", (event) => {
    send({ hook_event_name: "Stop", session_id: event.thread.id, cwd, usage: usage(event.messages) });
  });

  // The hook counts AI-written lines from an edit's old and new text.
  amp.on("tool.result", (event) => {
    if (event.status !== "done" || !EDIT_TOOLS.has(event.tool)) return;
    const input = event.input;
    send({
      hook_event_name: "PostToolUse",
      session_id: event.thread.id,
      cwd,
      tool_input: { old_string: input.old_str, new_string: input.new_str, content: input.content },
    });
  });
}
