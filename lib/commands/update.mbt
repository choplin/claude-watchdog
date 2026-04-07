///|
/// Manually register or update a session via CLI flags.
pub fn run_update(matches : @argparse.Matches) -> Unit {
  let session_id = @cli.get_one(matches, "session-id")
  let cwd = @cli.get_one(matches, "cwd")
  let state_str = @cli.get_one(matches, "state")
  let session_name = @cli.get_one(matches, "session-name")
  let pane_id = @cli.get_one(matches, "pane-id")
  let pane_terminal = @cli.get_one(matches, "pane-terminal")
  // Parse and validate state at the boundary
  let state = match @session.SessionState::from_string(state_str) {
    None => {
      @ffi.eprintln("Error: invalid state '\{state_str}'")
      @ffi.exit(1)
      return // unreachable
    }
    Some(s) => s
  }
  // Build pane info
  let pane : @terminal.PaneInfo? = if pane_id != "" && pane_terminal != "" {
    Some(@terminal.PaneInfo::{ terminal: pane_terminal, pane_id })
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
    session_id, cwd, state, pane, session_name,
  )
  match upsert_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
}
