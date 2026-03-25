import { initDb, upsertSession, deleteSession, getSession } from "../db";
import { interpretState } from "../interpret";
import { loadConfig } from "../config";
import { fireUserHooks, type HookContext } from "../user-hooks";
import type { HookEvent } from "../types";
import { detectPane } from "../terminal";

const UPDATE_EVENTS: HookEvent[] = [
  "SessionStart",
  "UserPromptSubmit",
  "PreToolUse",
  "Stop",
];

export async function runHook(args: string[]): Promise<void> {
  const event = args[0] as HookEvent;
  const toolName = args[1] ?? null;

  if (!event) {
    process.exit(1);
  }

  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const input = Buffer.concat(chunks).toString();
  const data = JSON.parse(input);

  const sessionId = data.session_id;
  const cwd = data.cwd;
  const sessionName: string | null = data.session_name ?? null;
  const pane = detectPane();

  if (!sessionId) {
    process.exit(0);
  }

  const config = loadConfig();

  if (event === "SessionEnd") {
    initDb();
    const prevSession = getSession(sessionId);
    const prevState = prevSession ? interpretState(prevSession) : "";
    deleteSession(sessionId);

    if (config) {
      fireUserHooks(config, {
        sessionId,
        cwd: prevSession?.cwd ?? cwd ?? "",
        event: "SessionEnd",
        toolName: null,
        sessionName: prevSession?.session_name ?? sessionName,
        state: "",
        prevState,
        paneId: prevSession?.pane_id ?? pane?.paneId ?? null,
        paneTerminal: prevSession?.pane_terminal ?? pane?.terminal ?? null,
      });
    }
    return;
  }

  if (!cwd) {
    process.exit(0);
  }

  initDb();

  if (UPDATE_EVENTS.includes(event)) {
    const prevSession = getSession(sessionId);
    upsertSession(sessionId, cwd, event, toolName, pane, sessionName);

    if (config) {
      const newSession = getSession(sessionId)!;
      const state = interpretState(newSession);
      const prevState = prevSession ? interpretState(prevSession) : "";

      fireUserHooks(config, {
        sessionId,
        cwd,
        event,
        toolName,
        sessionName: newSession.session_name,
        state,
        prevState,
        paneId: newSession.pane_id,
        paneTerminal: newSession.pane_terminal,
      });
    }
  }
}
