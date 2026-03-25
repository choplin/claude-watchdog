import { describe, test, expect, vi, beforeEach, afterEach } from "vitest";
import { execFileSync } from "child_process";
import { reconcile } from "./reconcile";
import * as db from "./db";
import * as config from "./config";
import * as userHooks from "./user-hooks";
import type { Session } from "./types";

vi.mock("child_process", () => ({
  execFileSync: vi.fn(),
}));

vi.mock("./db", () => ({
  listSessions: vi.fn(),
  deleteSession: vi.fn(),
}));

vi.mock("./config", () => ({
  loadConfig: vi.fn(),
}));

vi.mock("./user-hooks", () => ({
  fireUserHooks: vi.fn(),
}));

const mockExecFileSync = vi.mocked(execFileSync);
const mockListSessions = vi.mocked(db.listSessions);
const mockDeleteSession = vi.mocked(db.deleteSession);
const mockLoadConfig = vi.mocked(config.loadConfig);
const mockFireUserHooks = vi.mocked(userHooks.fireUserHooks);

function makeSession(overrides: Partial<Session> = {}): Session {
  const now = Math.floor(Date.now() / 1000);
  return {
    session_id: "s1",
    cwd: "/test/project",
    event: "Stop",
    tool_name: null,
    session_name: null,
    created_at: now,
    updated_at: now,
    state_changed_at: now,
    pane_id: null,
    pane_terminal: null,
    ...overrides,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  mockLoadConfig.mockReturnValue(null);
  mockDeleteSession.mockReturnValue(true);
});

describe("reconcile", () => {
  test("pane exists — not deleted", () => {
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", pane_id: "%0", pane_terminal: "tmux" }),
    ]);
    mockExecFileSync.mockReturnValue("%0\n%1\n");

    const result = reconcile();

    expect(result.deleted).toEqual([]);
    expect(mockDeleteSession).not.toHaveBeenCalled();
  });

  test("pane gone — deleted", () => {
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", pane_id: "%0", pane_terminal: "tmux" }),
    ]);
    mockExecFileSync.mockReturnValue("%1\n%2\n");

    const result = reconcile();

    expect(result.deleted).toEqual(["s1"]);
    expect(mockDeleteSession).toHaveBeenCalledWith("s1");
  });

  test("no pane + within TTL — not deleted", () => {
    const now = Math.floor(Date.now() / 1000);
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", updated_at: now - 3600 }), // 1 hour ago
    ]);

    const result = reconcile();

    expect(result.deleted).toEqual([]);
    expect(mockDeleteSession).not.toHaveBeenCalled();
  });

  test("no pane + TTL exceeded — deleted", () => {
    const now = Math.floor(Date.now() / 1000);
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", updated_at: now - 90000 }), // 25 hours ago
    ]);

    const result = reconcile();

    expect(result.deleted).toEqual(["s1"]);
    expect(mockDeleteSession).toHaveBeenCalledWith("s1");
  });

  test("CLI unavailable (throws) — session skipped", () => {
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", pane_id: "%0", pane_terminal: "tmux" }),
    ]);
    mockExecFileSync.mockImplementation(() => {
      throw new Error("command not found: tmux");
    });

    const result = reconcile();

    expect(result.deleted).toEqual([]);
    expect(mockDeleteSession).not.toHaveBeenCalled();
  });

  test("mixed sessions — correct subset deleted", () => {
    const now = Math.floor(Date.now() / 1000);
    mockListSessions.mockReturnValue([
      // Pane exists — keep
      makeSession({ session_id: "s1", pane_id: "%0", pane_terminal: "tmux" }),
      // Pane gone — delete
      makeSession({ session_id: "s2", pane_id: "%5", pane_terminal: "tmux" }),
      // No pane, within TTL — keep
      makeSession({ session_id: "s3", updated_at: now - 3600 }),
      // No pane, TTL exceeded — delete
      makeSession({ session_id: "s4", updated_at: now - 90000 }),
      // CLI failed — skip
      makeSession({ session_id: "s5", pane_id: "3", pane_terminal: "wez" }),
    ]);

    // tmux returns %0 and %1 (no %5)
    mockExecFileSync.mockImplementation((cmd: string) => {
      if (cmd === "tmux") return "%0\n%1\n";
      throw new Error("command not found: wezterm");
    });

    const result = reconcile();

    expect(result.deleted.sort()).toEqual(["s2", "s4"]);
    expect(mockDeleteSession).toHaveBeenCalledTimes(2);
  });

  test("user hooks fire for deleted sessions with correct context", () => {
    const hookConfig = {
      hooks: [{ on_event: "SessionEnd" as const, command: "echo deleted" }],
    };
    mockLoadConfig.mockReturnValue(hookConfig);
    mockListSessions.mockReturnValue([
      makeSession({
        session_id: "s1",
        pane_id: "%0",
        pane_terminal: "tmux",
        cwd: "/my/project",
        event: "Stop",
      }),
    ]);
    mockExecFileSync.mockReturnValue("%1\n");

    reconcile();

    expect(mockFireUserHooks).toHaveBeenCalledWith(hookConfig, {
      sessionId: "s1",
      cwd: "/my/project",
      event: "SessionEnd",
      toolName: null,
      sessionName: null,
      state: "",
      prevState: "waiting_input", // Stop → waiting_input
      paneId: "%0",
      paneTerminal: "tmux",
    });
  });

  test("no sessions — empty result", () => {
    mockListSessions.mockReturnValue([]);

    const result = reconcile();

    expect(result.deleted).toEqual([]);
    expect(mockDeleteSession).not.toHaveBeenCalled();
    expect(mockExecFileSync).not.toHaveBeenCalled();
  });

  test("custom TTL is respected", () => {
    const now = Math.floor(Date.now() / 1000);
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", updated_at: now - 7200 }), // 2 hours ago
    ]);

    // With default TTL (24h), this would NOT be stale
    const result1 = reconcile();
    expect(result1.deleted).toEqual([]);

    // With 1h TTL, this IS stale
    const result2 = reconcile(3600);
    expect(result2.deleted).toEqual(["s1"]);
  });

  test("wezterm pane check parses JSON format", () => {
    mockListSessions.mockReturnValue([
      makeSession({ session_id: "s1", pane_id: "3", pane_terminal: "wez" }),
      makeSession({ session_id: "s2", pane_id: "99", pane_terminal: "wez" }),
    ]);
    mockExecFileSync.mockReturnValue(
      JSON.stringify([{ pane_id: 3 }, { pane_id: 5 }])
    );

    const result = reconcile();

    // s1 (pane_id "3") exists, s2 (pane_id "99") does not
    expect(result.deleted).toEqual(["s2"]);
    // wezterm CLI should be called only once
    expect(mockExecFileSync).toHaveBeenCalledTimes(1);
  });
});
