import { execFileSync } from "child_process";
import { listSessions, deleteSession } from "./db";
import { interpretState } from "./interpret";
import { loadConfig } from "./config";
import { fireUserHooks } from "./user-hooks";
import type { Session } from "./types";

export interface ReconcileResult {
  deleted: string[];
}

const DEFAULT_TTL = 24 * 60 * 60; // 24 hours in seconds

type PaneCache = Map<string, Set<string> | null>;

function listPanes(terminal: string): Set<string> | null {
  try {
    switch (terminal) {
      case "tmux": {
        const out = execFileSync("tmux", ["list-panes", "-a", "-F", "#{pane_id}"], {
          timeout: 3000,
          encoding: "utf-8",
          stdio: ["pipe", "pipe", "pipe"],
        });
        return new Set(out.trim().split("\n").filter(Boolean));
      }
      case "wez": {
        const out = execFileSync("wezterm", ["cli", "list", "--format", "json"], {
          timeout: 5000,
          encoding: "utf-8",
          stdio: ["pipe", "pipe", "pipe"],
        });
        const items = JSON.parse(out) as { pane_id: number }[];
        return new Set(items.map((item) => String(item.pane_id)));
      }
      default:
        return null;
    }
  } catch {
    return null;
  }
}

function isStale(
  session: Session,
  paneCache: PaneCache,
  ttl: number,
  now: number
): boolean {
  if (session.pane_id && session.pane_terminal) {
    // Lazily populate cache for this terminal type
    if (!paneCache.has(session.pane_terminal)) {
      paneCache.set(session.pane_terminal, listPanes(session.pane_terminal));
    }
    const activePanes = paneCache.get(session.pane_terminal)!;
    if (activePanes === null) {
      // CLI failed — skip (not stale)
      return false;
    }
    return !activePanes.has(session.pane_id);
  }

  // No pane info — fall back to TTL
  return now - session.updated_at > ttl;
}

export function reconcile(ttl: number = DEFAULT_TTL): ReconcileResult {
  const sessions = listSessions();
  const paneCache: PaneCache = new Map();
  const now = Math.floor(Date.now() / 1000);
  const config = loadConfig();
  const deleted: string[] = [];

  for (const session of sessions) {
    if (!isStale(session, paneCache, ttl, now)) continue;

    const prevState = interpretState(session);
    deleteSession(session.session_id);
    deleted.push(session.session_id);

    if (config) {
      fireUserHooks(config, {
        sessionId: session.session_id,
        cwd: session.cwd,
        event: "SessionEnd",
        toolName: null,
        sessionName: session.session_name,
        state: "",
        prevState,
        paneId: session.pane_id,
        paneTerminal: session.pane_terminal,
      });
    }
  }

  return { deleted };
}
