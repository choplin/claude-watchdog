import { Database } from "bun:sqlite";
import { homedir } from "os";
import { join } from "path";
import type { Session, HookEvent } from "./types";

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
        tmux_pane TEXT
      )
    `);
  } finally {
    db.close();
  }
}

export function upsertSession(
  sessionId: string,
  cwd: string,
  event: HookEvent,
  toolName: string | null = null,
  tmuxPane: string | null = null
): void {
  const db = getDb();
  try {
    const now = Math.floor(Date.now() / 1000);
    db.run(
      `INSERT INTO sessions (session_id, cwd, event, tool_name, created_at, updated_at, tmux_pane)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(session_id) DO UPDATE SET
         cwd = excluded.cwd,
         event = excluded.event,
         tool_name = excluded.tool_name,
         updated_at = excluded.updated_at,
         tmux_pane = COALESCE(excluded.tmux_pane, sessions.tmux_pane)`,
      [sessionId, cwd, event, toolName, now, now, tmuxPane]
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
