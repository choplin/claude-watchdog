///|
/// Handle hook events from Claude Code.
/// Reads JSON from stdin: { "session_id": "...", "cwd": "...", "session_name": "..." }
pub fn run_hook(matches : @argparse.Matches) -> Unit {
  let event_str = @cli.get_one(matches, "event")
  let tool_name = @cli.get_one(matches, "tool-name")
  // Read JSON from stdin
  let input = @ffi.read_stdin()
  let json_result : Result[Json, _] = try? @json.parse(input)
  let json = match json_result {
    Ok(j) => j
    Err(_) => {
      @ffi.eprintln("Error: failed to parse stdin JSON")
      @ffi.exit(1)
      return // unreachable
    }
  }
  let session_id = match json {
    Json::Object(obj) =>
      match obj.get("session_id") {
        Some(Json::String(s)) => s
        _ => ""
      }
    _ => ""
  }
  if session_id == "" {
    return // Silent exit for empty session_id
  }
  let cwd = match json {
    Json::Object(obj) =>
      match obj.get("cwd") {
        Some(Json::String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let session_name = match json {
    Json::Object(obj) =>
      match obj.get("session_name") {
        Some(Json::String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let cfg = @config.load_config()
  // Parse event at the boundary
  let event = match @session.HookEvent::from_string(event_str) {
    Some(e) => e
    None => return // Unknown event, silent exit
  }
  // Handle SessionEnd
  if event == @session.SessionEnd {
    let init_result : Result[_, _] = try? @db.init_db()
    match init_result {
      Err(e) => {
        @ffi.eprintln("Error: \{e}")
        @ffi.exit(1)
      }
      Ok(_) => ()
    }
    let prev_session : @session.Session? = match
      (try? @db.get_session(session_id) : Result[_, _]) {
      Ok(s) => s
      Err(_) => None
    }
    let prev_state : @session.SessionState? = match prev_session {
      Some(s) => Some(s.state)
      None => None
    }
    let prev_cwd = match prev_session {
      Some(s) => s.cwd
      None => cwd
    }
    let prev_session_name = match prev_session {
      Some(s) => s.session_name
      None => session_name
    }
    let prev_pane_id = match prev_session {
      Some(s) => s.pane_id
      None => ""
    }
    let prev_pane_terminal = match prev_session {
      Some(s) => s.pane_terminal
      None => ""
    }
    // Delete session
    ignore(try? @db.delete_session(session_id))
    // Fire hooks
    @hook.fire(cfg, @hook.HookContext::{
      session_id,
      cwd: prev_cwd,
      event,
      tool_name: "",
      session_name: prev_session_name,
      state: None,
      prev_state,
      pane_id: prev_pane_id,
      pane_terminal: prev_pane_terminal,
    })
    return
  }
  // Handle update events
  if !event.is_update_event() {
    return
  }
  if cwd == "" {
    return // Silent exit for empty cwd
  }
  let init_result : Result[_, _] = try? @db.init_db()
  match init_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
  // Get previous session for state comparison
  let prev_session : @session.Session? = match
    (try? @db.get_session(session_id) : Result[_, _]) {
    Ok(s) => s
    Err(_) => None
  }
  let prev_state : @session.SessionState? = match prev_session {
    Some(s) => Some(s.state)
    None => None
  }
  // Compute new state at boundary
  let new_state = @session.SessionState::from_event(event, tool_name)
  // Detect pane
  let pane = @terminal.detect_pane()
  // Upsert session
  let upsert_result : Result[_, _] = try? @db.upsert_session(
    session_id, cwd, new_state, pane, session_name,
  )
  match upsert_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
  // Resolve pane info
  let new_pane_id = match pane {
    Some(p) => p.pane_id
    None =>
      match prev_session {
        Some(s) => s.pane_id
        None => ""
      }
  }
  let new_pane_terminal = match pane {
    Some(p) => p.terminal
    None =>
      match prev_session {
        Some(s) => s.pane_terminal
        None => ""
      }
  }
  // Fire hooks
  @hook.fire(cfg, @hook.HookContext::{
    session_id,
    cwd,
    event,
    tool_name,
    session_name,
    state: Some(new_state),
    prev_state,
    pane_id: new_pane_id,
    pane_terminal: new_pane_terminal,
  })
}
