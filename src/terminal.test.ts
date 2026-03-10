import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { detectPane, formatPane } from "./terminal";

describe("detectPane", () => {
  let savedTmux: string | undefined;
  let savedWez: string | undefined;

  beforeEach(() => {
    savedTmux = process.env.TMUX_PANE;
    savedWez = process.env.WEZTERM_PANE;
    delete process.env.TMUX_PANE;
    delete process.env.WEZTERM_PANE;
  });

  afterEach(() => {
    if (savedTmux !== undefined) process.env.TMUX_PANE = savedTmux;
    else delete process.env.TMUX_PANE;
    if (savedWez !== undefined) process.env.WEZTERM_PANE = savedWez;
    else delete process.env.WEZTERM_PANE;
  });

  test("returns null when no terminal multiplexer", () => {
    expect(detectPane()).toBeNull();
  });

  test("detects tmux", () => {
    process.env.TMUX_PANE = "%0";
    expect(detectPane()).toEqual({ terminal: "tmux", paneId: "%0" });
  });

  test("detects wezterm", () => {
    process.env.WEZTERM_PANE = "3";
    expect(detectPane()).toEqual({ terminal: "wez", paneId: "3" });
  });

  test("tmux takes priority over wezterm", () => {
    process.env.TMUX_PANE = "%1";
    process.env.WEZTERM_PANE = "5";
    expect(detectPane()).toEqual({ terminal: "tmux", paneId: "%1" });
  });
});

describe("formatPane", () => {
  test("formats tmux pane", () => {
    expect(formatPane({ pane_id: "%0", pane_terminal: "tmux" })).toBe(
      "tmux:%0"
    );
  });

  test("formats wezterm pane", () => {
    expect(formatPane({ pane_id: "3", pane_terminal: "wez" })).toBe("wez:3");
  });

  test("returns dash when pane_id is null", () => {
    expect(formatPane({ pane_id: null, pane_terminal: "tmux" })).toBe("-");
  });

  test("returns dash when pane_terminal is null", () => {
    expect(formatPane({ pane_id: "%0", pane_terminal: null })).toBe("-");
  });

  test("returns dash when both are null", () => {
    expect(formatPane({ pane_id: null, pane_terminal: null })).toBe("-");
  });
});
