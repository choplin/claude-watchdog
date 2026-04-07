///|
fn make_session(
  event? : @session.HookEvent = SessionStart,
  tool_name? : String = "",
) -> @session.Session {
  @session.Session::{
    session_id: "test-session",
    cwd: "/test/project",
    event,
    tool_name,
    session_name: "",
    created_at: 1000L,
    updated_at: 1000L,
    state_changed_at: 1000L,
    pane_id: "",
    pane_terminal: "",
  }
}

///|
test "interpret_state: SessionStart -> WaitingInput" {
  inspect(
    @interpret.interpret_state(make_session(event=SessionStart)),
    content="WaitingInput",
  )
}

///|
test "interpret_state: Stop -> WaitingInput" {
  inspect(
    @interpret.interpret_state(make_session(event=Stop)),
    content="WaitingInput",
  )
}

///|
test "interpret_state: UserPromptSubmit -> Running" {
  inspect(
    @interpret.interpret_state(make_session(event=UserPromptSubmit)),
    content="Running",
  )
}

///|
test "interpret_state: PreToolUse + AskUserQuestion -> WaitingQuestion" {
  inspect(
    @interpret.interpret_state(
      make_session(event=PreToolUse, tool_name="AskUserQuestion"),
    ),
    content="WaitingQuestion",
  )
}

///|
test "interpret_state: PreToolUse + ExitPlanMode -> WaitingApproval" {
  inspect(
    @interpret.interpret_state(
      make_session(event=PreToolUse, tool_name="ExitPlanMode"),
    ),
    content="WaitingApproval",
  )
}

///|
test "interpret_state: PreToolUse + other tool -> Running" {
  inspect(
    @interpret.interpret_state(
      make_session(event=PreToolUse, tool_name="Bash"),
    ),
    content="Running",
  )
}

///|
test "interpret_state: PreToolUse + empty tool -> Running" {
  inspect(
    @interpret.interpret_state(make_session(event=PreToolUse)),
    content="Running",
  )
}

///|
test "interpret_state: SessionEnd -> WaitingInput" {
  inspect(
    @interpret.interpret_state(make_session(event=SessionEnd)),
    content="WaitingInput",
  )
}

///|
test "format_state" {
  inspect(
    @interpret.format_state(@session.WaitingInput),
    content="waiting (input)",
  )
  inspect(
    @interpret.format_state(@session.WaitingQuestion),
    content="waiting (question)",
  )
  inspect(
    @interpret.format_state(@session.WaitingApproval),
    content="waiting (approval)",
  )
  inspect(@interpret.format_state(@session.Running), content="running")
}

///|
test "format_elapsed" {
  inspect(@interpret.format_elapsed(1000L, 1000L), content="0s")
  inspect(@interpret.format_elapsed(970L, 1000L), content="30s")
  inspect(@interpret.format_elapsed(700L, 1000L), content="5m0s")
  inspect(@interpret.format_elapsed(670L, 1000L), content="5m30s")
  inspect(@interpret.format_elapsed(0L, 3600L), content="1h0m")
  inspect(@interpret.format_elapsed(0L, 5400L), content="1h30m")
  inspect(@interpret.format_elapsed(0L, 86400L), content="1d0h0m")
  inspect(@interpret.format_elapsed(0L, 90000L), content="1d1h0m")
  // Negative (future timestamp)
  inspect(@interpret.format_elapsed(2000L, 1000L), content="0s")
}
