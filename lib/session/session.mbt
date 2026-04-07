///|
/// Persisted state of a Claude Code session, derived from `HookEvent` at the boundary.
pub(all) enum SessionState {
  /// Idle — waiting for user input.
  WaitingInput
  /// Claude asked the user a question (`AskUserQuestion` tool).
  WaitingQuestion
  /// Claude is waiting for plan approval (`ExitPlanMode` tool).
  WaitingApproval
  /// Claude is actively working.
  Running
} derive(Show, Eq)

///|
pub fn SessionState::from_string(s : String) -> SessionState? {
  match s {
    "waiting_input" => Some(WaitingInput)
    "waiting_question" => Some(WaitingQuestion)
    "waiting_approval" => Some(WaitingApproval)
    "running" => Some(Running)
    _ => None
  }
}

///|
pub fn SessionState::to_state_string(self : SessionState) -> String {
  match self {
    WaitingInput => "waiting_input"
    WaitingQuestion => "waiting_question"
    WaitingApproval => "waiting_approval"
    Running => "running"
  }
}

///|
/// Derive the session state from a hook event and tool name.
pub fn SessionState::from_event(
  event : HookEvent,
  tool_name : String,
) -> SessionState {
  match event {
    SessionStart | Stop | SessionEnd => WaitingInput
    UserPromptSubmit => Running
    PreToolUse =>
      match tool_name {
        "AskUserQuestion" => WaitingQuestion
        "ExitPlanMode" => WaitingApproval
        _ => Running
      }
  }
}

///|
/// A tracked Claude Code session. Persisted in SQLite.
pub(all) struct Session {
  /// Unique session identifier assigned by Claude Code.
  session_id : String
  /// Working directory of the session.
  cwd : String
  /// Current state of the session.
  state : SessionState
  /// User-assigned session name ("" if absent).
  session_name : String
  /// Unix timestamp when the session was first seen.
  created_at : Int64
  /// Unix timestamp of the most recent update.
  updated_at : Int64
  /// Unix timestamp when `state` last changed.
  state_changed_at : Int64
  /// Terminal pane identifier ("" if unknown).
  pane_id : String
  /// Terminal multiplexer type, e.g. "tmux" or "wez" ("" if unknown).
  pane_terminal : String
} derive(Show, Eq)
