///|
test "HookEvent::from_string valid events" {
  inspect(
    @types.HookEvent::from_string("SessionStart"),
    content="Some(SessionStart)",
  )
  inspect(
    @types.HookEvent::from_string("SessionEnd"),
    content="Some(SessionEnd)",
  )
  inspect(
    @types.HookEvent::from_string("UserPromptSubmit"),
    content="Some(UserPromptSubmit)",
  )
  inspect(
    @types.HookEvent::from_string("PreToolUse"),
    content="Some(PreToolUse)",
  )
  inspect(@types.HookEvent::from_string("Stop"), content="Some(Stop)")
  inspect(@types.HookEvent::from_string("invalid"), content="None")
}

///|
test "HookEvent::is_update_event" {
  inspect(@types.HookEvent::SessionStart.is_update_event(), content="true")
  inspect(@types.HookEvent::UserPromptSubmit.is_update_event(), content="true")
  inspect(@types.HookEvent::PreToolUse.is_update_event(), content="true")
  inspect(@types.HookEvent::Stop.is_update_event(), content="true")
  inspect(@types.HookEvent::SessionEnd.is_update_event(), content="false")
}

///|
test "SessionState::from_string valid states" {
  inspect(
    @types.SessionState::from_string("waiting_input"),
    content="Some(WaitingInput)",
  )
  inspect(
    @types.SessionState::from_string("waiting_question"),
    content="Some(WaitingQuestion)",
  )
  inspect(
    @types.SessionState::from_string("waiting_approval"),
    content="Some(WaitingApproval)",
  )
  inspect(@types.SessionState::from_string("running"), content="Some(Running)")
  inspect(@types.SessionState::from_string("invalid"), content="None")
}

///|
test "is_valid_event" {
  inspect(@types.is_valid_event("SessionStart"), content="true")
  inspect(@types.is_valid_event("foo"), content="false")
}

///|
test "is_valid_state" {
  inspect(@types.is_valid_state("running"), content="true")
  inspect(@types.is_valid_state("bar"), content="false")
}
