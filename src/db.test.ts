import { describe, test, expect, beforeEach, afterAll } from "bun:test";
import { join } from "path";
import { mkdtempSync, rmSync } from "fs";
import { tmpdir } from "os";
import { Database } from "bun:sqlite";
import { initDb, upsertSession, listSessions, deleteSession } from "./db";

const testDir = mkdtempSync(join(tmpdir(), "ccm-db-test-"));
const testDb = join(testDir, "test.db");
process.env.CLAUDE_CODE_MONITOR_DB = testDb;

function resetDb(): void {
  try {
    rmSync(testDb);
  } catch {}
  try {
    rmSync(`${testDb}-wal`);
  } catch {}
  try {
    rmSync(`${testDb}-shm`);
  } catch {}
  initDb();
}

beforeEach(() => {
  resetDb();
});

afterAll(() => {
  rmSync(testDir, { recursive: true, force: true });
  delete process.env.CLAUDE_CODE_MONITOR_DB;
});

describe("initDb", () => {
  test("creates sessions table", () => {
    const sessions = listSessions();
    expect(sessions).toEqual([]);
  });

  test("is idempotent", () => {
    initDb();
    expect(listSessions()).toEqual([]);
  });

  test("migrates tmux_pane to pane_id and pane_terminal", () => {
    // Create a DB with old schema
    try {
      rmSync(testDb);
    } catch {}
    const db = new Database(testDb, { create: true });
    db.run("PRAGMA journal_mode = WAL");
    db.run(`
      CREATE TABLE sessions (
        session_id TEXT PRIMARY KEY,
        cwd TEXT NOT NULL,
        event TEXT NOT NULL,
        tool_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        state_changed_at INTEGER NOT NULL,
        tmux_pane TEXT
      )
    `);
    db.run(
      `INSERT INTO sessions VALUES ('s1', '/test', 'SessionStart', NULL, 1000, 1000, 1000, '%0')`
    );
    db.run(
      `INSERT INTO sessions VALUES ('s2', '/test2', 'Stop', NULL, 2000, 2000, 2000, NULL)`
    );
    db.close();

    // Run migration
    initDb();

    const sessions = listSessions();
    const s1 = sessions.find((s) => s.session_id === "s1")!;
    const s2 = sessions.find((s) => s.session_id === "s2")!;

    expect(s1.pane_id).toBe("%0");
    expect(s1.pane_terminal).toBe("tmux");
    expect(s2.pane_id).toBeNull();
    expect(s2.pane_terminal).toBeNull();
  });
});

describe("upsertSession", () => {
  test("inserts a new session", () => {
    upsertSession("s1", "/path/project", "SessionStart");
    const sessions = listSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].session_id).toBe("s1");
    expect(sessions[0].cwd).toBe("/path/project");
    expect(sessions[0].event).toBe("SessionStart");
    expect(sessions[0].tool_name).toBeNull();
    expect(sessions[0].pane_id).toBeNull();
    expect(sessions[0].pane_terminal).toBeNull();
  });

  test("updates existing session on conflict", () => {
    upsertSession("s1", "/path/project", "SessionStart");
    upsertSession("s1", "/path/project", "UserPromptSubmit");
    const sessions = listSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].event).toBe("UserPromptSubmit");
  });

  test("stores tool_name for PreToolUse", () => {
    upsertSession("s1", "/path/project", "PreToolUse", "AskUserQuestion");
    const sessions = listSessions();
    expect(sessions[0].tool_name).toBe("AskUserQuestion");
  });

  test("overwrites tool_name on update", () => {
    upsertSession("s1", "/path/project", "PreToolUse", "AskUserQuestion");
    upsertSession("s1", "/path/project", "UserPromptSubmit", null);
    const sessions = listSessions();
    expect(sessions[0].tool_name).toBeNull();
  });

  test("preserves pane via COALESCE when new value is null", () => {
    upsertSession("s1", "/path/project", "SessionStart", null, {
      terminal: "tmux",
      paneId: "%0",
    });
    upsertSession("s1", "/path/project", "UserPromptSubmit", null, null);
    const sessions = listSessions();
    expect(sessions[0].pane_id).toBe("%0");
    expect(sessions[0].pane_terminal).toBe("tmux");
  });

  test("overwrites pane when new value is provided", () => {
    upsertSession("s1", "/path/project", "SessionStart", null, {
      terminal: "tmux",
      paneId: "%0",
    });
    upsertSession("s1", "/path/project", "UserPromptSubmit", null, {
      terminal: "wez",
      paneId: "3",
    });
    const sessions = listSessions();
    expect(sessions[0].pane_id).toBe("3");
    expect(sessions[0].pane_terminal).toBe("wez");
  });

  test("sets updated_at to current unix timestamp", () => {
    const before = Math.floor(Date.now() / 1000);
    upsertSession("s1", "/path/project", "SessionStart");
    const after = Math.floor(Date.now() / 1000);
    const sessions = listSessions();
    expect(sessions[0].updated_at).toBeGreaterThanOrEqual(before);
    expect(sessions[0].updated_at).toBeLessThanOrEqual(after);
  });

  test("handles multiple distinct sessions", () => {
    upsertSession("s1", "/path/a", "SessionStart");
    upsertSession("s2", "/path/b", "UserPromptSubmit");
    upsertSession("s3", "/path/c", "PreToolUse", "AskUserQuestion");
    const sessions = listSessions();
    expect(sessions).toHaveLength(3);
  });
});

describe("listSessions", () => {
  test("returns empty array when no sessions", () => {
    expect(listSessions()).toEqual([]);
  });

  test("returns sessions ordered by updated_at DESC", () => {
    upsertSession("s1", "/path/a", "SessionStart");
    upsertSession("s2", "/path/b", "SessionStart");
    // Update s1 so it has a newer timestamp
    upsertSession("s1", "/path/a", "UserPromptSubmit");
    const sessions = listSessions();
    expect(sessions[0].session_id).toBe("s1");
    expect(sessions[1].session_id).toBe("s2");
  });
});

describe("deleteSession", () => {
  test("deletes an existing session and returns true", () => {
    upsertSession("s1", "/path/project", "SessionStart");
    expect(deleteSession("s1")).toBe(true);
    expect(listSessions()).toHaveLength(0);
  });

  test("returns false for non-existent session", () => {
    expect(deleteSession("non-existent")).toBe(false);
  });

  test("only deletes the specified session", () => {
    upsertSession("s1", "/path/a", "SessionStart");
    upsertSession("s2", "/path/b", "SessionStart");
    deleteSession("s1");
    const sessions = listSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].session_id).toBe("s2");
  });
});
