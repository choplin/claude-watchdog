import type { Session, SessionState } from "./types";

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
  let remaining = Math.floor(Date.now() / 1000 - updatedAt);
  if (remaining < 60) return `${remaining}s`;

  const d = Math.floor(remaining / 86400);
  remaining %= 86400;
  const h = Math.floor(remaining / 3600);
  remaining %= 3600;
  const m = Math.floor(remaining / 60);
  remaining %= 60;

  let result = "";
  if (d > 0) result += `${d}d`;
  if (d > 0 || h > 0) result += `${h}h`;
  result += `${m}m`;
  // Show seconds only when under 1 hour
  if (d === 0 && h === 0) result += `${remaining}s`;
  return result;
}