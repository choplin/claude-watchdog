///|
/// Interpret the current state of a session based on its event and tool_name.
pub fn interpret_state(session : @session.Session) -> @session.SessionState {
  match session.event {
    SessionStart | Stop => @session.WaitingInput
    UserPromptSubmit => @session.Running
    PreToolUse =>
      match session.tool_name {
        "AskUserQuestion" => @session.WaitingQuestion
        "ExitPlanMode" => @session.WaitingApproval
        _ => @session.Running
      }
    SessionEnd => @session.WaitingInput
  }
}

///|
/// Format a session state as a human-readable label.
pub fn format_state(state : @session.SessionState) -> String {
  match state {
    WaitingInput => "waiting (input)"
    WaitingQuestion => "waiting (question)"
    WaitingApproval => "waiting (approval)"
    Running => "running"
  }
}

///|
/// Format elapsed time since a unix timestamp.
/// Returns strings like "30s", "5m30s", "1h30m", "2d0h0m".
pub fn format_elapsed(unix_ts : Int64, now : Int64) -> String {
  let mut secs = now - unix_ts
  if secs < 0L {
    secs = 0L
  }
  let days = secs / 86400L
  secs = secs % 86400L
  let hours = secs / 3600L
  secs = secs % 3600L
  let minutes = secs / 60L
  let remaining_secs = secs % 60L
  if days > 0L {
    "\{days}d\{hours}h\{minutes}m"
  } else if hours > 0L {
    "\{hours}h\{minutes}m"
  } else if minutes > 0L {
    "\{minutes}m\{remaining_secs}s"
  } else {
    "\{remaining_secs}s"
  }
}
