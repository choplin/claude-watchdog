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
  inspect(
    @session.SessionState::from_string("running"),
    content="Some(Running)",
  )
  inspect(@session.SessionState::from_string("invalid"), content="None")
}

///|
test "SessionState::from_event: SessionStart -> WaitingInput" {
  inspect(
    @session.SessionState::from_event(SessionStart, ""),
    content="WaitingInput",
  )
}

///|
test "SessionState::from_event: Stop -> WaitingInput" {
  inspect(@session.SessionState::from_event(Stop, ""), content="WaitingInput")
}

///|
test "SessionState::from_event: SessionEnd -> WaitingInput" {
  inspect(
    @session.SessionState::from_event(SessionEnd, ""),
    content="WaitingInput",
  )
}

///|
test "SessionState::from_event: UserPromptSubmit -> Running" {
  inspect(
    @session.SessionState::from_event(UserPromptSubmit, ""),
    content="Running",
  )
}

///|
test "SessionState::from_event: PreToolUse + AskUserQuestion -> WaitingQuestion" {
  inspect(
    @session.SessionState::from_event(PreToolUse, "AskUserQuestion"),
    content="WaitingQuestion",
  )
}

///|
test "SessionState::from_event: PreToolUse + ExitPlanMode -> WaitingApproval" {
  inspect(
    @session.SessionState::from_event(PreToolUse, "ExitPlanMode"),
    content="WaitingApproval",
  )
}

///|
test "SessionState::from_event: PreToolUse + other tool -> Running" {
  inspect(
    @session.SessionState::from_event(PreToolUse, "Bash"),
    content="Running",
  )
}

///|
test "SessionState::from_event: PreToolUse + empty tool -> Running" {
  inspect(@session.SessionState::from_event(PreToolUse, ""), content="Running")
}
