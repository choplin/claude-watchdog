import { describe, test, expect } from "bun:test";
import { interpretState, formatState, formatElapsed } from "./interpret";
import type { Session } from "./types";

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    session_id: "test-session",
    cwd: "/test/project",
    event: "SessionStart",
    tool_name: null,
    created_at: Math.floor(Date.now() / 1000),
    updated_at: Math.floor(Date.now() / 1000),
    state_changed_at: Math.floor(Date.now() / 1000),
    tmux_pane: null,
    ...overrides,
  };
}

describe("interpretState", () => {
  test("SessionStart -> waiting_input", () => {
    expect(interpretState(makeSession({ event: "SessionStart" }))).toBe(
      "waiting_input"
    );
  });

  test("Stop -> waiting_input", () => {
    expect(interpretState(makeSession({ event: "Stop" }))).toBe(
      "waiting_input"
    );
  });

  test("UserPromptSubmit -> running", () => {
    expect(interpretState(makeSession({ event: "UserPromptSubmit" }))).toBe(
      "running"
    );
  });

  test("PreToolUse with AskUserQuestion -> waiting_question", () => {
    expect(
      interpretState(
        makeSession({ event: "PreToolUse", tool_name: "AskUserQuestion" })
      )
    ).toBe("waiting_question");
  });

  test("PreToolUse with ExitPlanMode -> waiting_approval", () => {
    expect(
      interpretState(
        makeSession({ event: "PreToolUse", tool_name: "ExitPlanMode" })
      )
    ).toBe("waiting_approval");
  });

  test("PreToolUse with unknown tool -> running", () => {
    expect(
      interpretState(makeSession({ event: "PreToolUse", tool_name: "Bash" }))
    ).toBe("running");
  });

  test("PreToolUse with null tool -> running", () => {
    expect(
      interpretState(makeSession({ event: "PreToolUse", tool_name: null }))
    ).toBe("running");
  });

  test("unknown event -> waiting_input (fallback)", () => {
    expect(
      interpretState(makeSession({ event: "UnknownEvent" as any }))
    ).toBe("waiting_input");
  });
});

describe("formatState", () => {
  test("formats waiting_input", () => {
    expect(formatState("waiting_input")).toBe("waiting (input)");
  });

  test("formats waiting_question", () => {
    expect(formatState("waiting_question")).toBe("waiting (question)");
  });

  test("formats waiting_approval", () => {
    expect(formatState("waiting_approval")).toBe("waiting (approval)");
  });

  test("formats running", () => {
    expect(formatState("running")).toBe("running");
  });
});

describe("formatElapsed", () => {
  const now = Math.floor(Date.now() / 1000);

  test("under 1 minute shows seconds only", () => {
    expect(formatElapsed(now)).toBe("0s");
    expect(formatElapsed(now - 30)).toBe("30s");
  });

  test("under 1 hour shows minutes and seconds", () => {
    expect(formatElapsed(now - 300)).toBe("5m0s");
    expect(formatElapsed(now - 330)).toBe("5m30s");
  });

  test("under 1 day shows hours and minutes", () => {
    expect(formatElapsed(now - 3600)).toBe("1h0m");
    expect(formatElapsed(now - 5400)).toBe("1h30m");
  });

  test("1 day or more shows days, hours, and minutes", () => {
    expect(formatElapsed(now - 86400)).toBe("1d0h0m");
    expect(formatElapsed(now - 90000)).toBe("1d1h0m");
    expect(formatElapsed(now - 172800)).toBe("2d0h0m");
    expect(formatElapsed(now - 176400)).toBe("2d1h0m");
  });
});