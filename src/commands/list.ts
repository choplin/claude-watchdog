import { parseArgs } from "util";
import { basename } from "path";
import Table from "cli-table3";
import { listSessions } from "../db";
import { interpretState, formatState, formatElapsed } from "../interpret";
import type { OutputFormat, SessionState } from "../types";

type ColorMode = "auto" | "always" | "never";

function shouldColor(mode: ColorMode): boolean {
  if (mode === "always") return true;
  if (mode === "never") return false;
  return !!process.stdout.isTTY;
}

let useColor = shouldColor("auto");
const color = (code: number, text: string): string =>
  useColor ? `\x1b[${code}m${text}\x1b[0m` : text;

function stateIcon(state: SessionState): string {
  switch (state) {
    case "running":
      return color(32, "●");
    case "waiting_input":
      return color(33, "○");
    case "waiting_question":
    case "waiting_approval":
      return color(35, "◆");
  }
}

function stateLabel(state: SessionState): string {
  const label = formatState(state);
  switch (state) {
    case "running":
      return color(32, label);
    case "waiting_input":
      return color(33, label);
    case "waiting_question":
    case "waiting_approval":
      return color(35, label);
  }
}

export function runList(args: string[]): void {
  const { values } = parseArgs({
    args,
    options: {
      format: { type: "string", default: "text" },
      color: { type: "string", default: "auto" },
    },
  });

  const colorMode = values.color as ColorMode;
  useColor = shouldColor(colorMode);
  const format = values.format as OutputFormat;
  const sessions = listSessions();

  if (format === "json") {
    // Include interpreted state in JSON output
    const sessionsWithState = sessions.map((session) => ({
      ...session,
      interpreted_state: interpretState(session),
    }));
    console.log(JSON.stringify(sessionsWithState, null, 2));
  } else {
    if (sessions.length === 0) {
      console.log("No active sessions");
    } else {
      const table = new Table({
        head: ["PROJECT", "STATE", "ELAPSED", "PANE"],
        chars: {
          top: "",
          "top-mid": "",
          "top-left": "",
          "top-right": "",
          bottom: "",
          "bottom-mid": "",
          "bottom-left": "",
          "bottom-right": "",
          left: "",
          "left-mid": "",
          mid: "",
          "mid-mid": "",
          right: "",
          "right-mid": "",
          middle: "",
        },
        style: {
          head: [],
          border: [],
          "padding-left": 1,
          "padding-right": 1,
        },
      });

      for (const session of sessions) {
        const state = interpretState(session);
        table.push([
          basename(session.cwd),
          `${stateIcon(state)} ${stateLabel(state)}`,
          formatElapsed(session.created_at),
          session.tmux_pane ?? "-",
        ]);
      }

      console.log(table.toString());
    }
  }
}
