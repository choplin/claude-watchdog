///|
/// Manually register or update a session via CLI flags.
pub fn run_update(matches : @argparse.Matches) -> Unit {
  let session_id = @cli.get_one(matches, "session-id")
  let cwd = @cli.get_one(matches, "cwd")
  let event = @cli.get_one(matches, "event")
  let tool_name = @cli.get_one(matches, "tool-name")
  let session_name = @cli.get_one(matches, "session-name")
  let pane_id = @cli.get_one(matches, "pane-id")
  let pane_terminal = @cli.get_one(matches, "pane-terminal")
  // Validate event is an update event
  match @types.HookEvent::from_string(event) {
    None => {
      @ffi.eprintln("Error: invalid event '\{event}'")
      @ffi.exit(1)
    }
    Some(e) =>
      if !e.is_update_event() {
        @ffi.eprintln("Error: event '\{event}' is not a valid update event")
        @ffi.exit(1)
      }
  }
  // Build pane info
  let pane : @types.PaneInfo? = if pane_id != "" && pane_terminal != "" {
    Some(@types.PaneInfo::{ terminal: pane_terminal, pane_id })
  } else {
    None
  }
  // Init DB and upsert
  let init_result : Result[_, _] = try? @db.init_db()
  match init_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
  let upsert_result : Result[_, _] = try? @db.upsert_session(
    session_id, cwd, event, tool_name, pane, session_name,
  )
  match upsert_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
}
