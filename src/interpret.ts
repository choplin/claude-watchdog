import type { Session, SessionState, Summary } from "./types";

// Interpret raw event data into session state (Late Interpretation)
export function interpretState(session: Session): SessionState {
  switch (session.event) {
    case "SessionStart":
    case "Stop":
      return "waiting_input";
    case "UserPromptSubmit":
      return "running";
    case "PreToolUse":
      if (session.tool_name === "AskUserQuestion") return "waiting_question";
      if (session.tool_name === "ExitPlanMode") return "waiting_approval";
      return "running"; // Unknown tool, assume still running
    default:
      return "waiting_input";
  }
}

// Format state for display
export function formatState(state: SessionState): string {
  switch (state) {
    case "waiting_input":
      return "waiting (input)";
    case "waiting_question":
      return "waiting (question)";
    case "waiting_approval":
      return "waiting (approval)";
    case "running":
      return "running";
  }
}

// Format elapsed time from unix timestamp
export function formatElapsed(updatedAt: number): string {
  const seconds = Math.floor(Date.now() / 1000 - updatedAt);
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86400)}d`;
}

// Calculate summary from sessions
export function calculateSummary(sessions: Session[]): Summary {
  let running = 0;
  for (const session of sessions) {
    if (interpretState(session) === "running") {
      running++;
    }
  }
  return {
    total: sessions.length,
    waiting: sessions.length - running,
    running,
  };
}
