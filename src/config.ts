import { parse } from "smol-toml";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { HookEvent, SessionState } from "./types";

export interface StateChangePattern {
  from?: SessionState;
  to?: SessionState;
}

export interface HookConfig {
  on_event?: HookEvent;
  on_state_change?: StateChangePattern;
  command: string;
}

export interface Config {
  hooks: HookConfig[];
}

const VALID_EVENTS: ReadonlySet<string> = new Set([
  "SessionStart",
  "SessionEnd",
  "UserPromptSubmit",
  "PreToolUse",
  "Stop",
]);

const VALID_STATES: ReadonlySet<string> = new Set([
  "waiting_input",
  "waiting_question",
  "waiting_approval",
  "running",
]);

export function getConfigPath(): string {
  const xdgConfig =
    process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config");
  return join(xdgConfig, "claude-watchdog", "config.toml");
}

export function loadConfig(): Config | null {
  const configPath = getConfigPath();
  if (!existsSync(configPath)) return null;

  let raw: string;
  try {
    raw = readFileSync(configPath, "utf-8");
  } catch (e) {
    console.error(`[claude-watchdog] Failed to read config: ${e}`);
    return null;
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = parse(raw) as Record<string, unknown>;
  } catch (e) {
    console.error(`[claude-watchdog] Failed to parse config TOML: ${e}`);
    return null;
  }

  return validateConfig(parsed);
}

export function validateConfig(
  parsed: Record<string, unknown>
): Config | null {
  const rawHooks = parsed.hooks;
  if (!Array.isArray(rawHooks)) {
    if (rawHooks === undefined) return { hooks: [] };
    console.error("[claude-watchdog] 'hooks' must be an array");
    return null;
  }

  const hooks: HookConfig[] = [];
  for (const [i, entry] of rawHooks.entries()) {
    if (typeof entry !== "object" || entry === null) {
      console.error(`[claude-watchdog] hooks[${i}]: must be an object`);
      return null;
    }

    const h = entry as Record<string, unknown>;

    if (typeof h.command !== "string" || h.command.length === 0) {
      console.error(
        `[claude-watchdog] hooks[${i}]: 'command' is required and must be a non-empty string`
      );
      return null;
    }

    const hasEvent = "on_event" in h;
    const hasStateChange = "on_state_change" in h;

    if (hasEvent && hasStateChange) {
      console.error(
        `[claude-watchdog] hooks[${i}]: 'on_event' and 'on_state_change' are mutually exclusive`
      );
      return null;
    }

    if (!hasEvent && !hasStateChange) {
      console.error(
        `[claude-watchdog] hooks[${i}]: must have 'on_event' or 'on_state_change'`
      );
      return null;
    }

    if (hasEvent) {
      if (typeof h.on_event !== "string" || !VALID_EVENTS.has(h.on_event)) {
        console.error(
          `[claude-watchdog] hooks[${i}]: invalid on_event '${h.on_event}'`
        );
        return null;
      }
      hooks.push({
        on_event: h.on_event as HookEvent,
        command: h.command,
      });
    }

    if (hasStateChange) {
      const sc = h.on_state_change;
      if (typeof sc !== "object" || sc === null) {
        console.error(
          `[claude-watchdog] hooks[${i}]: 'on_state_change' must be an object`
        );
        return null;
      }

      const pattern = sc as Record<string, unknown>;
      const from = pattern.from as string | undefined;
      const to = pattern.to as string | undefined;

      if (from !== undefined && !VALID_STATES.has(from)) {
        console.error(
          `[claude-watchdog] hooks[${i}]: invalid state '${from}' in on_state_change.from`
        );
        return null;
      }
      if (to !== undefined && !VALID_STATES.has(to)) {
        console.error(
          `[claude-watchdog] hooks[${i}]: invalid state '${to}' in on_state_change.to`
        );
        return null;
      }

      hooks.push({
        on_state_change: {
          from: from as SessionState | undefined,
          to: to as SessionState | undefined,
        },
        command: h.command,
      });
    }
  }

  return { hooks };
}
