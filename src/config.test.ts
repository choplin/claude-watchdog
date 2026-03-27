import { describe, test, expect } from "vitest";
import { validateConfig, getConfigPath } from "./config";
import { join } from "path";
import { homedir } from "os";

describe("getConfigPath", () => {
  test("uses XDG_CONFIG_HOME when set", () => {
    const original = process.env.XDG_CONFIG_HOME;
    process.env.XDG_CONFIG_HOME = "/custom/config";
    try {
      expect(getConfigPath()).toBe(
        "/custom/config/claude-watchdog/config.toml"
      );
    } finally {
      if (original !== undefined) {
        process.env.XDG_CONFIG_HOME = original;
      } else {
        delete process.env.XDG_CONFIG_HOME;
      }
    }
  });

  test("falls back to ~/.config", () => {
    const original = process.env.XDG_CONFIG_HOME;
    delete process.env.XDG_CONFIG_HOME;
    try {
      expect(getConfigPath()).toBe(
        join(homedir(), ".config", "claude-watchdog", "config.toml")
      );
    } finally {
      if (original !== undefined) {
        process.env.XDG_CONFIG_HOME = original;
      }
    }
  });
});

describe("validateConfig", () => {
  test("returns empty hooks for config without hooks key", () => {
    expect(validateConfig({})).toEqual({ hooks: [] });
  });

  test("parses event-based hook", () => {
    const result = validateConfig({
      hooks: [{ on_event: "Stop", command: "echo done" }],
    });
    expect(result).toEqual({
      hooks: [{ on_event: "Stop", command: "echo done" }],
    });
  });

  test("parses state-change hook with from and to", () => {
    const result = validateConfig({
      hooks: [
        {
          on_state_change: { from: "running", to: "waiting_input" },
          command: "notify",
        },
      ],
    });
    expect(result).toEqual({
      hooks: [
        {
          on_state_change: { from: "running", to: "waiting_input" },
          command: "notify",
        },
      ],
    });
  });

  test("parses state-change hook with only to", () => {
    const result = validateConfig({
      hooks: [
        {
          on_state_change: { to: "waiting_question" },
          command: "alert",
        },
      ],
    });
    expect(result).toEqual({
      hooks: [
        {
          on_state_change: { to: "waiting_question" },
          command: "alert",
        },
      ],
    });
  });

  test("parses state-change hook with empty pattern (wildcard)", () => {
    const result = validateConfig({
      hooks: [{ on_state_change: {}, command: "log" }],
    });
    expect(result).toEqual({
      hooks: [
        {
          on_state_change: { from: undefined, to: undefined },
          command: "log",
        },
      ],
    });
  });

  test("parses multiple hooks", () => {
    const result = validateConfig({
      hooks: [
        { on_event: "SessionStart", command: "echo start" },
        { on_event: "Stop", command: "echo stop" },
        {
          on_state_change: { to: "waiting_input" },
          command: "notify",
        },
      ],
    });
    expect(result!.hooks).toHaveLength(3);
  });

  test("rejects when on_event and on_state_change both present", () => {
    const result = validateConfig({
      hooks: [
        {
          on_event: "Stop",
          on_state_change: { to: "waiting_input" },
          command: "echo",
        },
      ],
    });
    expect(result).toBeNull();
  });

  test("rejects when neither on_event nor on_state_change present", () => {
    const result = validateConfig({
      hooks: [{ command: "echo" }],
    });
    expect(result).toBeNull();
  });

  test("rejects invalid on_event value", () => {
    expect(
      validateConfig({
        hooks: [{ on_event: "InvalidEvent", command: "echo" }],
      })
    ).toBeNull();
  });

  test("rejects invalid state in on_state_change.from", () => {
    expect(
      validateConfig({
        hooks: [
          { on_state_change: { from: "invalid_state" }, command: "echo" },
        ],
      })
    ).toBeNull();
  });

  test("rejects invalid state in on_state_change.to", () => {
    expect(
      validateConfig({
        hooks: [
          { on_state_change: { to: "invalid_state" }, command: "echo" },
        ],
      })
    ).toBeNull();
  });

  test("rejects missing command", () => {
    expect(
      validateConfig({ hooks: [{ on_event: "Stop" }] })
    ).toBeNull();
  });

  test("rejects empty command", () => {
    expect(
      validateConfig({ hooks: [{ on_event: "Stop", command: "" }] })
    ).toBeNull();
  });

  test("rejects non-array hooks", () => {
    expect(validateConfig({ hooks: "not-array" })).toBeNull();
  });
});
