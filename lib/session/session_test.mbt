///|
test "HookEvent::from_string valid events" {
  inspect(
    @session.HookEvent::from_string("SessionStart"),
    content="Some(SessionStart)",
  )
  inspect(
    @session.HookEvent::from_string("SessionEnd"),
    content="Some(SessionEnd)",
  )
  inspect(
    @session.HookEvent::from_string("UserPromptSubmit"),
    content="Some(UserPromptSubmit)",
  )
  inspect(
    @session.HookEvent::from_string("PreToolUse"),
    content="Some(PreToolUse)",
  )
  inspect(@session.HookEvent::from_string("Stop"), content="Some(Stop)")
  inspect(@session.HookEvent::from_string("invalid"), content="None")
}

///|
test "HookEvent::is_update_event" {
  inspect(@session.HookEvent::SessionStart.is_update_event(), content="true")
  inspect(@session.HookEvent::UserPromptSubmit.is_update_event(), content="true")
  inspect(@session.HookEvent::PreToolUse.is_update_event(), content="true")
  inspect(@session.HookEvent::Stop.is_update_event(), content="true")
  inspect(@session.HookEvent::SessionEnd.is_update_event(), content="false")
}

///|
test "SessionState::from_string valid states" {
  inspect(
    @session.SessionState::from_string("waiting_input"),
    content="Some(WaitingInput)",
  )
  inspect(
    @session.SessionState::from_string("waiting_question"),
    content="Some(WaitingQuestion)",
  )
  inspect(
    @session.SessionState::from_string("waiting_approval"),
    content="Some(WaitingApproval)",
  )
  inspect(@session.SessionState::from_string("running"), content="Some(Running)")
  inspect(@session.SessionState::from_string("invalid"), content="None")
}

///|
test "is_valid_event" {
  inspect(@session.is_valid_event("SessionStart"), content="true")
  inspect(@session.is_valid_event("foo"), content="false")
}

///|
test "is_valid_state" {
  inspect(@session.is_valid_state("running"), content="true")
  inspect(@session.is_valid_state("bar"), content="false")
}
