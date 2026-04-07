///|
/// Hook events sent by Claude Code at session lifecycle boundaries.
/// Used as the trigger for `SessionState` transitions.
pub(all) enum HookEvent {
  /// Claude Code session started.
  SessionStart
  /// Claude Code session ended.
  SessionEnd
  /// User submitted a prompt.
  UserPromptSubmit
  /// Claude is about to invoke a tool (tool name provided separately).
  PreToolUse
  /// Claude finished generating a response.
  Stop
} derive(Show, Eq)

///|
pub fn HookEvent::from_string(s : String) -> HookEvent? {
  match s {
    "SessionStart" => Some(SessionStart)
    "SessionEnd" => Some(SessionEnd)
    "UserPromptSubmit" => Some(UserPromptSubmit)
    "PreToolUse" => Some(PreToolUse)
    "Stop" => Some(Stop)
    _ => None
  }
}

///|
pub fn HookEvent::to_event_string(self : HookEvent) -> String {
  match self {
    SessionStart => "SessionStart"
    SessionEnd => "SessionEnd"
    UserPromptSubmit => "UserPromptSubmit"
    PreToolUse => "PreToolUse"
    Stop => "Stop"
  }
}

///|
/// Events that trigger a DB upsert (SessionEnd excluded).
pub fn HookEvent::is_update_event(self : HookEvent) -> Bool {
  match self {
    SessionStart | UserPromptSubmit | PreToolUse | Stop => true
    SessionEnd => false
  }
}
