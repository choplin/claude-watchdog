import { describe, test, expect } from "bun:test";
import { interpretState, formatState, calculateSummary } from "./interpret";
import type { Session } from "./types";

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    session_id: "test-session",
    cwd: "/test/project",
    event: "SessionStart",
    tool_name: null,
    updated_at: Math.floor(Date.now() / 1000),
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

describe("calculateSummary", () => {
  test("empty sessions", () => {
    expect(calculateSummary([])).toEqual({
      total: 0,
      waiting: 0,
      running: 0,
    });
  });

  test("all waiting sessions", () => {
    const sessions = [
      makeSession({ session_id: "1", event: "SessionStart" }),
      makeSession({ session_id: "2", event: "Stop" }),
      makeSession({
        session_id: "3",
        event: "PreToolUse",
        tool_name: "AskUserQuestion",
      }),
    ];
    expect(calculateSummary(sessions)).toEqual({
      total: 3,
      waiting: 3,
      running: 0,
    });
  });

  test("all running sessions", () => {
    const sessions = [
      makeSession({ session_id: "1", event: "UserPromptSubmit" }),
      makeSession({
        session_id: "2",
        event: "PreToolUse",
        tool_name: "Bash",
      }),
    ];
    expect(calculateSummary(sessions)).toEqual({
      total: 2,
      waiting: 0,
      running: 2,
    });
  });

  test("mixed states", () => {
    const sessions = [
      makeSession({ session_id: "1", event: "SessionStart" }), // waiting
      makeSession({ session_id: "2", event: "UserPromptSubmit" }), // running
      makeSession({
        session_id: "3",
        event: "PreToolUse",
        tool_name: "AskUserQuestion",
      }), // waiting
      makeSession({
        session_id: "4",
        event: "PreToolUse",
        tool_name: "ExitPlanMode",
      }), // waiting
      makeSession({ session_id: "5", event: "Stop" }), // waiting
    ];
    expect(calculateSummary(sessions)).toEqual({
      total: 5,
      waiting: 4,
      running: 1,
    });
  });
});
