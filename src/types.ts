// Hook events from Claude Code (stored as-is in DB)
export type HookEvent =
  | "SessionStart"
  | "SessionEnd"
  | "UserPromptSubmit"
  | "PreToolUse"
  | "Stop";

// Tool names for PreToolUse event
export type ToolName = "AskUserQuestion" | "ExitPlanMode";

// Session record stored in database (raw event data)
export interface Session {
  session_id: string;
  cwd: string;
  event: HookEvent;
  tool_name: string | null; // Only for PreToolUse
  created_at: number; // Unix timestamp (session start)
  updated_at: number; // Unix timestamp (last event)
  state_changed_at: number; // Unix timestamp (last state change)
  tmux_pane: string | null;
}

// Interpreted session states (derived at display time)
export type SessionState =
  | "waiting_input"
  | "waiting_question"
  | "waiting_approval"
  | "running";

// CLI output formats
export type OutputFormat = "text" | "json";