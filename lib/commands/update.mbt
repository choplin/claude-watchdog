///|
/// Manually register or update a session via CLI flags.
pub fn run_update(args : Array[String]) -> Unit {
  let mut session_id = ""
  let mut cwd = ""
  let mut event = ""
  let mut tool_name = ""
  let mut session_name = ""
  let mut pane_id = ""
  let mut pane_terminal = ""
  // Parse flags
  for i = 0; i < args.length(); {
    match args[i] {
      "--session-id" => {
        if i + 1 < args.length() {
          session_id = args[i + 1]
        }
        continue i + 2
      }
      "--cwd" => {
        if i + 1 < args.length() {
          cwd = args[i + 1]
        }
        continue i + 2
      }
      "--event" => {
        if i + 1 < args.length() {
          event = args[i + 1]
        }
        continue i + 2
      }
      "--tool-name" => {
        if i + 1 < args.length() {
          tool_name = args[i + 1]
        }
        continue i + 2
      }
      "--session-name" => {
        if i + 1 < args.length() {
          session_name = args[i + 1]
        }
        continue i + 2
      }
      "--pane-id" => {
        if i + 1 < args.length() {
          pane_id = args[i + 1]
        }
        continue i + 2
      }
      "--pane-terminal" => {
        if i + 1 < args.length() {
          pane_terminal = args[i + 1]
        }
        continue i + 2
      }
      _ => continue i + 1
    }
  }
  // Validate required fields
  if session_id == "" {
    @ffi.eprintln("Error: --session-id is required")
    @ffi.exit(1)
  }
  if cwd == "" {
    @ffi.eprintln("Error: --cwd is required")
    @ffi.exit(1)
  }
  if event == "" {
    @ffi.eprintln("Error: --event is required")
    @ffi.exit(1)
  }
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
