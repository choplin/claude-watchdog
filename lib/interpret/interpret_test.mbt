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
