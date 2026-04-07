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
  inspect(
    @session.HookEvent::UserPromptSubmit.is_update_event(),
    content="true",
  )
  inspect(@session.HookEvent::PreToolUse.is_update_event(), content="true")
  inspect(@session.HookEvent::Stop.is_update_event(), content="true")
  inspect(@session.HookEvent::SessionEnd.is_update_event(), content="false")
}
