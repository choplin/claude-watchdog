import { describe, test, expect, beforeEach, afterAll } from "vitest";
import { spawnSync } from "child_process";
import { join } from "path";
import { mkdtempSync, rmSync } from "fs";
import { tmpdir } from "os";

const testDir = mkdtempSync(join(tmpdir(), "ccm-cli-test-"));
const testDb = join(testDir, "test.db");
const cliPath = join(import.meta.dirname, "cli.ts");

function runCli(...args: string[]) {
  const result = spawnSync("node", ["--import", "tsx/esm", cliPath, ...args], {
    env: { ...process.env, CLAUDE_CODE_MONITOR_DB: testDb },
  });
  return {
    stdout: result.stdout?.toString().trim() ?? "",
    stderr: result.stderr?.toString().trim() ?? "",
    exitCode: result.status ?? -1,
  };
}

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
}

beforeEach(() => {
  resetDb();
});

afterAll(() => {
  rmSync(testDir, { recursive: true, force: true });
});

describe("CLI: update", () => {
  test("creates a session", () => {
    const result = runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "SessionStart"
    );
    expect(result.exitCode).toBe(0);

    const list = runCli("list");
    expect(list.stdout).toContain("project");
  });

  test("fails without required args", () => {
    const result = runCli("update", "--session-id", "s1");
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("--session-id, --cwd, and --event are required");
  });

  test("fails with invalid event", () => {
    const result = runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "InvalidEvent"
    );
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Invalid event");
  });

  test("accepts optional tool-name, pane-id, and pane-terminal", () => {
    const result = runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "PreToolUse",
      "--tool-name",
      "AskUserQuestion",
      "--pane-id",
      "%0",
      "--pane-terminal",
      "tmux"
    );
    expect(result.exitCode).toBe(0);
  });
});

describe("CLI: list", () => {
  test("shows 'No active sessions' when empty", () => {
    const result = runCli("list");
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toBe("No active sessions");
  });

  test("shows project name and state in text format", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/my-project",
      "--event",
      "SessionStart"
    );
    const result = runCli("list");
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("my-project");
    expect(result.stdout).toContain("waiting (input)");
  });

  test("shows running state for UserPromptSubmit", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "UserPromptSubmit"
    );
    const result = runCli("list");
    expect(result.stdout).toContain("proj");
    expect(result.stdout).toContain("running");
  });

  test("shows waiting (question) for AskUserQuestion", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "PreToolUse",
      "--tool-name",
      "AskUserQuestion"
    );
    const result = runCli("list");
    expect(result.stdout).toContain("proj");
    expect(result.stdout).toContain("waiting (question)");
  });

  test("shows elapsed time column", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "SessionStart"
    );
    const result = runCli("list");
    // Elapsed should be a short time like "0s" or "1s"
    expect(result.stdout).toMatch(/\d+s/);
  });

  test("shows pane column with terminal header when pane is set", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "SessionStart",
      "--pane-id",
      "%0",
      "--pane-terminal",
      "tmux"
    );
    const result = runCli("list");
    expect(result.stdout).toContain("TMUX");
    expect(result.stdout).toContain("%0");
  });

  test("hides pane column when no sessions have pane info", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "SessionStart"
    );
    const result = runCli("list");
    expect(result.stdout).not.toContain("PANE");
    expect(result.stdout).not.toContain("TMUX");
    expect(result.stdout).not.toContain("WEZ");
  });

  test("shows table header", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/home/user/proj",
      "--event",
      "SessionStart"
    );
    const result = runCli("list");
    expect(result.stdout).toContain("PROJECT");
    expect(result.stdout).toContain("STATE");
    expect(result.stdout).toContain("ELAPSED");
    expect(result.stdout).toContain("SESSION");
  });

  test("outputs JSON with --format json", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "SessionStart"
    );
    const result = runCli("list", "--format", "json");
    expect(result.exitCode).toBe(0);
    const parsed = JSON.parse(result.stdout);
    expect(parsed).toHaveLength(1);
    expect(parsed[0].session_id).toBe("s1");
    expect(parsed[0].interpreted_state).toBe("waiting_input");
  });

  test("JSON output includes all fields", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "PreToolUse",
      "--tool-name",
      "ExitPlanMode",
      "--pane-id",
      "%0",
      "--pane-terminal",
      "tmux"
    );
    const result = runCli("list", "--format", "json");
    const parsed = JSON.parse(result.stdout);
    expect(parsed[0]).toEqual(
      expect.objectContaining({
        session_id: "s1",
        cwd: "/path/project",
        event: "PreToolUse",
        tool_name: "ExitPlanMode",
        pane_id: "%0",
        pane_terminal: "tmux",
        interpreted_state: "waiting_approval",
      })
    );
  });
});

describe("CLI: delete", () => {
  test("deletes an existing session", () => {
    runCli(
      "update",
      "--session-id",
      "s1",
      "--cwd",
      "/path/project",
      "--event",
      "SessionStart"
    );
    const result = runCli("delete", "--session-id", "s1");
    expect(result.exitCode).toBe(0);

    const list = runCli("list");
    expect(list.stdout).toBe("No active sessions");
  });

  test("fails without --session-id", () => {
    const result = runCli("delete");
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("--session-id is required");
  });

  test("fails for non-existent session", () => {
    const result = runCli("delete", "--session-id", "non-existent");
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Session not found");
  });
});

describe("CLI: hook", () => {
  function runHook(event: string, payload: object, toolName?: string) {
    const args = ["--import", "tsx/esm", cliPath, "hook", event];
    if (toolName) args.push(toolName);
    const result = spawnSync("node", args, {
      input: JSON.stringify(payload),
      env: { ...process.env, CLAUDE_CODE_MONITOR_DB: testDb },
    });
    return {
      stdout: result.stdout?.toString().trim() ?? "",
      stderr: result.stderr?.toString().trim() ?? "",
      exitCode: result.status ?? -1,
    };
  }

  test("creates a session via hook", () => {
    const result = runHook("SessionStart", {
      session_id: "h1",
      cwd: "/path/hook-project",
    });
    expect(result.exitCode).toBe(0);

    const list = runCli("list");
    expect(list.stdout).toContain("hook-project");
    expect(list.stdout).toContain("waiting (input)");
  });

  test("updates session state via hook", () => {
    runHook("SessionStart", { session_id: "h2", cwd: "/path/proj" });
    runHook("UserPromptSubmit", { session_id: "h2", cwd: "/path/proj" });

    const list = runCli("list");
    expect(list.stdout).toContain("running");
  });

  test("handles PreToolUse with tool name", () => {
    runHook("SessionStart", { session_id: "h3", cwd: "/path/proj" });
    runHook(
      "PreToolUse",
      { session_id: "h3", cwd: "/path/proj" },
      "AskUserQuestion"
    );

    const list = runCli("list");
    expect(list.stdout).toContain("waiting (question)");
  });

  test("deletes session on SessionEnd", () => {
    runHook("SessionStart", { session_id: "h4", cwd: "/path/proj" });
    runHook("SessionEnd", { session_id: "h4", cwd: "/path/proj" });

    const list = runCli("list");
    expect(list.stdout).toBe("No active sessions");
  });

  test("exits silently with missing session_id", () => {
    const result = runHook("SessionStart", { cwd: "/path/proj" });
    expect(result.exitCode).toBe(0);
  });

  test("exits silently with missing cwd", () => {
    const result = runHook("SessionStart", { session_id: "h5" });
    expect(result.exitCode).toBe(0);
  });

  test("deletes session on SessionEnd even without cwd", () => {
    runHook("SessionStart", { session_id: "h-no-cwd", cwd: "/path/proj" });
    runHook("SessionEnd", { session_id: "h-no-cwd" });
    const list = runCli("list");
    expect(list.stdout).toBe("No active sessions");
  });
});

describe("CLI: general", () => {
  test("shows help with --help", () => {
    const result = runCli("--help");
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("claude-watchdog");
    expect(result.stdout).toContain("Commands:");
  });

  test("shows help with -h", () => {
    const result = runCli("-h");
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("Commands:");
  });

  test("fails with unknown command", () => {
    const result = runCli("unknown");
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Unknown command: unknown");
  });
});
