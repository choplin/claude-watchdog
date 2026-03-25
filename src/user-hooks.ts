import { spawn } from "child_process";
import type { Config, HookConfig } from "./config";
import type { HookEvent, SessionState } from "./types";

export interface HookContext {
  sessionId: string;
  cwd: string;
  event: HookEvent;
  toolName: string | null;
  sessionName: string | null;
  state: SessionState | "";
  prevState: SessionState | "";
  paneId: string | null;
  paneTerminal: string | null;
}

function matchesHook(hook: HookConfig, context: HookContext): boolean {
  if (hook.on_event) {
    return hook.on_event === context.event;
  }

  if (hook.on_state_change) {
    // State-change hooks require actual state transition
    if (context.prevState === context.state) return false;
    if (context.state === "" && context.prevState === "") return false;

    const { from, to } = hook.on_state_change;
    if (from !== undefined && from !== context.prevState) return false;
    if (to !== undefined && to !== context.state) return false;
    return true;
  }

  return false;
}

function buildEnv(context: HookContext): Record<string, string> {
  const env: Record<string, string> = {
    ...process.env as Record<string, string>,
    MONITOR_SESSION_ID: context.sessionId,
    MONITOR_CWD: context.cwd,
    MONITOR_EVENT: context.event,
    MONITOR_TOOL_NAME: context.toolName ?? "",
    MONITOR_SESSION_NAME: context.sessionName ?? "",
    MONITOR_STATE: context.state,
    MONITOR_PREV_STATE: context.prevState,
    MONITOR_PANE_ID: context.paneId ?? "",
    MONITOR_PANE_TERMINAL: context.paneTerminal ?? "",
  };
  return env;
}

export function fireUserHooks(config: Config, context: HookContext): void {
  for (const hook of config.hooks) {
    try {
      if (!matchesHook(hook, context)) continue;

      const proc = spawn("/bin/sh", ["-c", hook.command], {
        env: buildEnv(context),
        stdio: "ignore",
        detached: true,
      });
      proc.unref();
    } catch {
      // Silently ignore errors
    }
  }
}
