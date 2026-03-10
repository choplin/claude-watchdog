import { Database } from "bun:sqlite";
import { homedir } from "os";
import { join } from "path";
import type { Session, HookEvent } from "./types";
import type { PaneInfo } from "./terminal";

function getDbPath(): string {
  return (
    process.env.CLAUDE_CODE_MONITOR_DB ??
    join(homedir(), ".claude", "claude-code-monitor.db")
  );
}

function getDb(): Database {
  const db = new Database(getDbPath(), { create: true });
  db.run("PRAGMA journal_mode = WAL");
  return db;
}

export function initDb(): void {
  const db = getDb();
  try {
    db.run(`
      CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        cwd TEXT NOT NULL,
        event TEXT NOT NULL,
        tool_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        state_changed_at INTEGER NOT NULL,
        pane_id TEXT,
        pane_terminal TEXT
      )
    `);

    // Migrate from tmux_pane to pane_id + pane_terminal
    const columns = db
      .query<{ name: string }, []>("PRAGMA table_info(sessions)")
      .all();
    if (columns.some((c) => c.name === "tmux_pane")) {
      db.run("ALTER TABLE sessions RENAME COLUMN tmux_pane TO pane_id");
      db.run("ALTER TABLE sessions ADD COLUMN pane_terminal TEXT");
      db.run(
        "UPDATE sessions SET pane_terminal = 'tmux' WHERE pane_id IS NOT NULL"
      );
    }
  } finally {
    db.close();
  }
}

export function upsertSession(
  sessionId: string,
  cwd: string,
  event: HookEvent,
  toolName: string | null = null,
  pane: PaneInfo | null = null
): void {
  const db = getDb();
  try {
    const now = Math.floor(Date.now() / 1000);
    const paneId = pane?.paneId ?? null;
    const paneTerminal = pane?.terminal ?? null;
    db.run(
      `INSERT INTO sessions (session_id, cwd, event, tool_name, created_at, updated_at, state_changed_at, pane_id, pane_terminal)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(session_id) DO UPDATE SET
         cwd = excluded.cwd,
         event = excluded.event,
         tool_name = excluded.tool_name,
         updated_at = excluded.updated_at,
         state_changed_at = CASE
           WHEN sessions.event != excluded.event
             OR COALESCE(sessions.tool_name, '') != COALESCE(excluded.tool_name, '')
           THEN excluded.updated_at
           ELSE sessions.state_changed_at
         END,
         pane_id = COALESCE(excluded.pane_id, sessions.pane_id),
         pane_terminal = COALESCE(excluded.pane_terminal, sessions.pane_terminal)`,
      [sessionId, cwd, event, toolName, now, now, now, paneId, paneTerminal]
    );
  } finally {
    db.close();
  }
}

export function listSessions(): Session[] {
  const db = getDb();
  try {
    return db
      .query<Session, []>("SELECT * FROM sessions ORDER BY updated_at DESC")
      .all();
  } finally {
    db.close();
  }
}

export function deleteSession(sessionId: string): boolean {
  const db = getDb();
  try {
    const result = db.run("DELETE FROM sessions WHERE session_id = ?", [
      sessionId,
    ]);
    return result.changes > 0;
  } finally {
    db.close();
  }
}
