import { describe, test, expect, afterAll } from "vitest";
import { fireUserHooks, type HookContext } from "./user-hooks";
import type { Config } from "./config";
import { unlinkSync, existsSync, readFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

function makeContext(overrides: Partial<HookContext> = {}): HookContext {
  return {
    sessionId: "test-session",
    cwd: "/test/project",
    event: "Stop",
    toolName: null,
    sessionName: null,
    state: "waiting_input",
    prevState: "running",
    paneId: null,
    paneTerminal: null,
    ...overrides,
  };
}

const tempFiles: string[] = [];
function tempFile(name: string): string {
  const p = join(tmpdir(), `ccm-hook-test-${name}-${Date.now()}`);
  tempFiles.push(p);
  return p;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

afterAll(() => {
  for (const f of tempFiles) {
    try {
      unlinkSync(f);
    } catch {}
  }
});

describe("fireUserHooks", () => {
  describe("event matching", () => {
    test("fires hook when event matches", async () => {
      const marker = tempFile("event-match");
      const config: Config = {
        hooks: [{ on_event: "Stop", command: `touch ${marker}` }],
      };
      fireUserHooks(config, makeContext({ event: "Stop" }));
      // Wait for async process
      await sleep(200);
      expect(existsSync(marker)).toBe(true);
    });

    test("does not fire hook when event does not match", async () => {
      const marker = tempFile("event-no-match");
      const config: Config = {
        hooks: [{ on_event: "SessionStart", command: `touch ${marker}` }],
      };
      fireUserHooks(config, makeContext({ event: "Stop" }));
      await sleep(200);
      expect(existsSync(marker)).toBe(false);
    });
  });

  describe("state-change matching", () => {
    test("fires when from and to both match", async () => {
      const marker = tempFile("state-both");
      const config: Config = {
        hooks: [
          {
            on_state_change: { from: "running", to: "waiting_input" },
            command: `touch ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({ state: "waiting_input", prevState: "running" })
      );
      await sleep(200);
      expect(existsSync(marker)).toBe(true);
    });

    test("fires when only to matches (from is wildcard)", async () => {
      const marker = tempFile("state-to-only");
      const config: Config = {
        hooks: [
          {
            on_state_change: { to: "waiting_question" },
            command: `touch ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({ state: "waiting_question", prevState: "running" })
      );
      await sleep(200);
      expect(existsSync(marker)).toBe(true);
    });

    test("fires when pattern is wildcard (empty object)", async () => {
      const marker = tempFile("state-wildcard");
      const config: Config = {
        hooks: [
          {
            on_state_change: {},
            command: `touch ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({ state: "waiting_input", prevState: "running" })
      );
      await sleep(200);
      expect(existsSync(marker)).toBe(true);
    });

    test("does not fire when state has not changed", async () => {
      const marker = tempFile("state-same");
      const config: Config = {
        hooks: [
          {
            on_state_change: { to: "running" },
            command: `touch ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({ state: "running", prevState: "running" })
      );
      await sleep(200);
      expect(existsSync(marker)).toBe(false);
    });

    test("does not fire when from does not match", async () => {
      const marker = tempFile("state-from-mismatch");
      const config: Config = {
        hooks: [
          {
            on_state_change: {
              from: "waiting_question",
              to: "waiting_input",
            },
            command: `touch ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({ state: "waiting_input", prevState: "running" })
      );
      await sleep(200);
      expect(existsSync(marker)).toBe(false);
    });
  });

  describe("environment variables", () => {
    test("passes context as MONITOR_ env vars", async () => {
      const marker = tempFile("env-vars");
      const config: Config = {
        hooks: [
          {
            on_event: "PreToolUse",
            command: `echo "$MONITOR_SESSION_ID|$MONITOR_CWD|$MONITOR_EVENT|$MONITOR_TOOL_NAME|$MONITOR_SESSION_NAME|$MONITOR_STATE|$MONITOR_PREV_STATE|$MONITOR_PANE_ID|$MONITOR_PANE_TERMINAL" > ${marker}`,
          },
        ],
      };
      fireUserHooks(
        config,
        makeContext({
          event: "PreToolUse",
          sessionId: "abc-123",
          cwd: "/my/project",
          toolName: "Bash",
          sessionName: "auth-refactor",
          state: "running",
          prevState: "waiting_input",
          paneId: "%0",
          paneTerminal: "tmux",
        })
      );
      await sleep(200);
      const content = readFileSync(marker, "utf-8");
      expect(content.trim()).toBe(
        "abc-123|/my/project|PreToolUse|Bash|auth-refactor|running|waiting_input|%0|tmux"
      );
    });
  });

  describe("error handling", () => {
    test("does not throw on invalid command", () => {
      const config: Config = {
        hooks: [
          { on_event: "Stop", command: "nonexistent-command-xyz-12345" },
        ],
      };
      expect(() => fireUserHooks(config, makeContext())).not.toThrow();
    });

    test("continues to fire subsequent hooks after error", async () => {
      const marker = tempFile("after-error");
      const config: Config = {
        hooks: [
          { on_event: "Stop", command: "nonexistent-command-xyz-12345" },
          { on_event: "Stop", command: `touch ${marker}` },
        ],
      };
      fireUserHooks(config, makeContext());
      await sleep(200);
      expect(existsSync(marker)).toBe(true);
    });
  });
});
