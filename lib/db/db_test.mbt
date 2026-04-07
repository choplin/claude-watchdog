///|
fn setup_test_db() -> Unit raise {
  let dir = match @env.get_env_var("TMPDIR") {
    Some(v) => v
    None => "/tmp"
  }
  let db_path = dir + "/test-watchdog-" + @ffi.now_unix().to_string() + ".db"
  @env.set_env_var("CLAUDE_WATCHDOG_DB", db_path)
  @db.init_db()
}

///|
test "init_db creates table" {
  setup_test_db()
}

///|
test "upsert and get session" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp/project", SessionStart, "", None, "")
  let session = @db.get_session("s1")
  guard session is Some(s) else { fail("expected session") }
  inspect(s.session_id, content="s1")
  inspect(s.cwd, content="/tmp/project")
  inspect(s.event, content="SessionStart")
  inspect(s.tool_name, content="")
  inspect(s.session_name, content="")
}

///|
test "upsert updates event" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp/project", SessionStart, "", None, "")
  @db.upsert_session("s1", "/tmp/project", UserPromptSubmit, "", None, "")
  let session = @db.get_session("s1")
  guard session is Some(s) else { fail("expected session") }
  inspect(s.event, content="UserPromptSubmit")
}

///|
test "upsert with tool_name" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp", PreToolUse, "Bash", None, "")
  let session = @db.get_session("s1")
  guard session is Some(s) else { fail("expected session") }
  inspect(s.tool_name, content="Bash")
}

///|
test "upsert with pane info" {
  setup_test_db()
  let pane = @terminal.PaneInfo::{ terminal: "tmux", pane_id: "%0" }
  @db.upsert_session("s1", "/tmp", SessionStart, "", Some(pane), "")
  let session = @db.get_session("s1")
  guard session is Some(s) else { fail("expected session") }
  inspect(s.pane_id, content="%0")
  inspect(s.pane_terminal, content="tmux")
}

///|
test "upsert session_name coalesce" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp", SessionStart, "", None, "my-task")
  @db.upsert_session("s1", "/tmp", UserPromptSubmit, "", None, "")
  let session = @db.get_session("s1")
  guard session is Some(s) else { fail("expected session") }
  // session_name should be preserved
  inspect(s.session_name, content="my-task")
}

///|
test "list sessions returns all" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp/a", SessionStart, "", None, "")
  @db.upsert_session("s2", "/tmp/b", SessionStart, "", None, "")
  let sessions = @db.list_sessions()
  inspect(sessions.length(), content="2")
  // Both sessions should be returned
  let ids = sessions.map(fn(s) { s.session_id })
  inspect(ids.contains("s1"), content="true")
  inspect(ids.contains("s2"), content="true")
}

///|
test "delete session" {
  setup_test_db()
  @db.upsert_session("s1", "/tmp", SessionStart, "", None, "")
  let deleted = @db.delete_session("s1")
  inspect(deleted, content="true")
  let session = @db.get_session("s1")
  inspect(session, content="None")
}

///|
test "delete session not found" {
  setup_test_db()
  let deleted = @db.delete_session("nonexistent")
  inspect(deleted, content="false")
}

///|
test "get session not found" {
  setup_test_db()
  let session = @db.get_session("nonexistent")
  inspect(session, content="None")
}
