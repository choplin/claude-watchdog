///|
/// List all active sessions.
pub async fn run_list(matches : @argparse.Matches) -> Unit {
  let format = @cli.get_one(matches, "format")
  let color_mode = @cli.get_one(matches, "color")
  let no_reconcile = @cli.get_flag(matches, "no-reconcile")
  init_db_or_exit()
  // Reconcile first (unless --no-reconcile)
  if !no_reconcile {
    ignore(@reconcile.reconcile(@reconcile.default_ttl))
  }
  // Get sessions
  let sessions = list_sessions_or_exit()
  if format == "json" {
    output_json(sessions)
  } else {
    let use_color = should_color(color_mode)
    output_text(sessions, use_color)
  }
}

///|
/// Initialize the database, exiting on error.
fn init_db_or_exit() -> Unit {
  let init_result : Result[_, _] = try? @db.init_db()
  match init_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
}

///|
/// List all sessions from the database, exiting on error.
fn list_sessions_or_exit() -> Array[@session.Session] {
  let sessions_result : Result[Array[@session.Session], _] = try? @db.list_sessions()
  match sessions_result {
    Ok(s) => s
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
      []
    }
  }
}

///|
fn should_color(mode : String) -> Bool {
  match mode {
    "always" => true
    "never" => false
    _ => @ffi.stdout_is_tty() // auto
  }
}

///|
fn nullable_json_string(s : String) -> Json {
  if s == "" {
    Json::null()
  } else {
    Json::string(s)
  }
}

///|
fn output_json(sessions : Array[@session.Session]) -> Unit {
  let arr : Array[Json] = []
  for session in sessions {
    let obj : Map[String, Json] = {}
    obj["session_id"] = Json::string(session.session_id)
    obj["cwd"] = Json::string(session.cwd)
    obj["state"] = Json::string(session.state.to_state_string())
    obj["session_name"] = nullable_json_string(session.session_name)
    obj["created_at"] = Json::number(session.created_at.to_double())
    obj["updated_at"] = Json::number(session.updated_at.to_double())
    obj["state_changed_at"] = Json::number(session.state_changed_at.to_double())
    obj["pane_id"] = nullable_json_string(session.pane_id)
    obj["pane_terminal"] = nullable_json_string(session.pane_terminal)
    arr.push(Json::object(obj))
  }
  println(Json::array(arr).stringify(indent=2))
}

///|
fn output_text(sessions : Array[@session.Session], use_color : Bool) -> Unit {
  let buf = render_text(sessions, use_color)
  println(buf.to_string())
}

///|
/// Render session list as text into a StringBuilder.
fn render_text(
  sessions : Array[@session.Session],
  use_color : Bool,
) -> StringBuilder {
  let buf = StringBuilder::new()
  if sessions.is_empty() {
    buf.write_string("No active sessions")
    return buf
  }
  let now = @ffi.now_unix()
  let pane_header = @terminal.pane_column_header(sessions)
  let show_pane = pane_header != ""
  // Build rows
  let rows : Array[(String, String, String, String, String)] = []
  for session in sessions {
    let state = session.state
    let project = if session.session_name != "" {
      session.session_name
    } else {
      basename(session.cwd)
    }
    let state_display = state_icon(state, use_color) +
      " " +
      state_label(state, use_color)
    let elapsed = @interpret.format_elapsed(session.state_changed_at, now)
    let session_elapsed = @interpret.format_elapsed(session.created_at, now)
    let pane = @terminal.format_pane(session.pane_id)
    rows.push((project, state_display, elapsed, session_elapsed, pane))
  }
  // Calculate column widths
  let mut w_project = 7 // "PROJECT"
  let mut w_state = 5 // "STATE"
  let mut w_elapsed = 7 // "ELAPSED"
  let mut w_session = 7 // "SESSION"
  for row in rows {
    let (project, state_display, elapsed, session_elapsed, _) = row
    w_project = @cmp.maximum(w_project, project.length())
    w_state = @cmp.maximum(w_state, strip_ansi(state_display).length())
    w_elapsed = @cmp.maximum(w_elapsed, elapsed.length())
    w_session = @cmp.maximum(w_session, session_elapsed.length())
  }
  // Header
  buf.write_string(pad_right("PROJECT", w_project + 2))
  buf.write_string(pad_right("STATE", w_state + 2))
  buf.write_string(pad_right("ELAPSED", w_elapsed + 2))
  buf.write_string(pad_right("SESSION", w_session + 2))
  if show_pane {
    buf.write_string(pane_header)
  }
  buf.write_char('\n')
  // Rows
  for row in rows {
    let (project, state_display, elapsed, session_elapsed, pane) = row
    buf.write_string(pad_right(project, w_project + 2))
    // State needs special padding (ANSI-aware)
    let state_visible_len = strip_ansi(state_display).length()
    buf.write_string(state_display)
    for _ in 0..<(w_state + 2 - state_visible_len) {
      buf.write_char(' ')
    }
    buf.write_string(pad_right(elapsed, w_elapsed + 2))
    buf.write_string(pad_right(session_elapsed, w_session + 2))
    if show_pane {
      buf.write_string(pane)
    }
    buf.write_char('\n')
  }
  buf
}

///|
fn ansi_color(code : Int, text : String, use_color : Bool) -> String {
  if use_color {
    "\u001b[\{code}m\{text}\u001b[0m"
  } else {
    text
  }
}

///|
fn state_icon(state : @session.SessionState, use_color : Bool) -> String {
  match state {
    Running => ansi_color(32, "●", use_color) // green
    WaitingInput => ansi_color(33, "○", use_color) // yellow
    WaitingQuestion | WaitingApproval => ansi_color(35, "◆", use_color) // magenta
  }
}

///|
fn state_label(state : @session.SessionState, use_color : Bool) -> String {
  let label = @interpret.format_state(state)
  match state {
    Running => ansi_color(32, label, use_color)
    WaitingInput => ansi_color(33, label, use_color)
    WaitingQuestion | WaitingApproval => ansi_color(35, label, use_color)
  }
}

///|
fn pad_right(s : String, width : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_string(s)
  for _ in 0..<(width - s.length()) {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
/// Strip ANSI escape sequences for width calculation.
fn strip_ansi(s : String) -> String {
  let sb = StringBuilder::new()
  let mut in_escape = false
  for c in s {
    if in_escape {
      if c == 'm' {
        in_escape = false
      }
    } else if c == '\u001b' {
      in_escape = true
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Get the basename of a path.
fn basename(path : String) -> String {
  match path.rev_split_once("/") {
    Some((_, name)) => name.to_string()
    None => path
  }
}
