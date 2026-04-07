///|
fn make_session(
  session_id : String,
  pane_id~ : String = "",
  pane_terminal~ : String = "",
  updated_at~ : Int64 = 0L,
) -> @session.Session {
  {
    session_id,
    cwd: "/tmp",
    event: @session.SessionStart,
    tool_name: "",
    session_name: "",
    created_at: 0L,
    updated_at,
    state_changed_at: 0L,
    pane_id,
    pane_terminal,
  }
}

///|
test "find_pane_duplicates returns empty for no sessions" {
  let dupes = find_pane_duplicates([])
  inspect(dupes.length(), content="0")
}

///|
test "find_pane_duplicates returns empty when all panes are unique" {
  let sessions = [
    make_session("s1", pane_id="%1", pane_terminal="tmux", updated_at=200L),
    make_session("s2", pane_id="%2", pane_terminal="tmux", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="0")
}

///|
test "find_pane_duplicates marks older session as duplicate" {
  let sessions = [
    make_session("s-new", pane_id="%1", pane_terminal="tmux", updated_at=200L),
    make_session("s-old", pane_id="%1", pane_terminal="tmux", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="1")
  inspect(dupes.contains("s-old"), content="true")
  inspect(dupes.contains("s-new"), content="false")
}

///|
test "find_pane_duplicates handles multiple duplicates on same pane" {
  let sessions = [
    make_session("s3", pane_id="%1", pane_terminal="tmux", updated_at=300L),
    make_session("s2", pane_id="%1", pane_terminal="tmux", updated_at=200L),
    make_session("s1", pane_id="%1", pane_terminal="tmux", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="2")
  inspect(dupes.contains("s3"), content="false")
  inspect(dupes.contains("s2"), content="true")
  inspect(dupes.contains("s1"), content="true")
}

///|
test "find_pane_duplicates skips sessions with empty pane_id" {
  let sessions = [
    make_session("s1", pane_id="", pane_terminal="tmux", updated_at=200L),
    make_session("s2", pane_id="", pane_terminal="tmux", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="0")
}

///|
test "find_pane_duplicates skips sessions with empty pane_terminal" {
  let sessions = [
    make_session("s1", pane_id="%1", pane_terminal="", updated_at=200L),
    make_session("s2", pane_id="%1", pane_terminal="", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="0")
}

///|
test "find_pane_duplicates distinguishes different terminals" {
  let sessions = [
    make_session("s1", pane_id="1", pane_terminal="tmux", updated_at=200L),
    make_session("s2", pane_id="1", pane_terminal="wez", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="0")
}

///|
test "find_pane_duplicates handles mixed unique and duplicate panes" {
  let sessions = [
    make_session("s1", pane_id="%1", pane_terminal="tmux", updated_at=400L),
    make_session("s2", pane_id="%2", pane_terminal="tmux", updated_at=300L),
    make_session("s3", pane_id="%1", pane_terminal="tmux", updated_at=200L),
    make_session("s4", pane_id="%3", pane_terminal="tmux", updated_at=100L),
  ]
  let dupes = find_pane_duplicates(sessions)
  inspect(dupes.length(), content="1")
  inspect(dupes.contains("s3"), content="true")
}
