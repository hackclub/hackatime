// Amp plugin: forwards prompt and turn events to Hackatime Desktop as
// metadata only. Install with `amp plugins add ./amp-plugin.ts`.
import { spawn } from "node:child_process";

function send(event: Record<string, unknown>) {
  const child = spawn("hackatime-ai-hook", ["amp"], { stdio: ["pipe", "ignore", "ignore"] });
  child.on("error", () => {});
  child.stdin.end(JSON.stringify(event));
}

export default function (amp: any) {
  amp.on("user.message", (e: any) => send({ hook_event_name: "UserPromptSubmit", session_id: e?.threadID, cwd: process.cwd() }));
  amp.on("agent.turn.end", (e: any) =>
    send({ hook_event_name: "Stop", session_id: e?.threadID, cwd: process.cwd(), usage: e?.usage }),
  );
}
