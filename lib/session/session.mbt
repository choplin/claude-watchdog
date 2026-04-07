///|
pub(all) enum HookEvent {
  SessionStart
  SessionEnd
  UserPromptSubmit
  PreToolUse
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

///|
pub fn is_valid_event(s : String) -> Bool {
  HookEvent::from_string(s) is Some(_)
}

///|
pub(all) enum SessionState {
  WaitingInput
  WaitingQuestion
  WaitingApproval
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
pub fn is_valid_state(s : String) -> Bool {
  SessionState::from_string(s) is Some(_)
}

///|
pub(all) struct Session {
  session_id : String
  cwd : String
  event : HookEvent
  tool_name : String // "" = absent
  session_name : String // "" = absent
  created_at : Int64
  updated_at : Int64
  state_changed_at : Int64
  pane_id : String // "" = absent
  pane_terminal : String // "" = absent
} derive(Show, Eq)
