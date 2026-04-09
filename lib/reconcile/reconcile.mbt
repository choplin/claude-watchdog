///|
pub let default_ttl : Int64 = 86400L // 24 hours

///|
/// List active panes for a given terminal multiplexer.
/// Returns None if the command fails.
async fn list_panes(terminal : String) -> Map[String, Unit]? {
  let (cmd, args) : (String, Array[String]) = match terminal {
    "tmux" => ("tmux", ["list-panes", "-a", "-F", "#{pane_id}"])
    "wez" => ("wezterm", ["cli", "list", "--format", "json"])
    _ => return None
  }
  let result : Result[(Int, _), _] = try? @process.collect_stdout(cmd, args[:])
  let output = match result {
    Ok((_, data)) => {
      let text : Result[String, _] = try? data.text()
      match text {
        Ok(s) => s
        Err(_) => return None
      }
    }
    Err(_) => return None
  }
  if output == "" {
    return None
  }
  let panes : Map[String, Unit] = {}
  match terminal {
    "tmux" =>
      for line_view in output.split("\n") {
        let line = line_view.to_string().trim().to_string()
        if line != "" {
          panes[line] = ()
        }
      }
    "wez" => {
      // Parse JSON: [{"pane_id": 0}, ...]
      let result : Result[Json, _] = try? @json.parse(output)
      match result {
        Ok(Json::Array(arr)) =>
          for item in arr {
            match item {
              Json::Object(obj) =>
                match obj.get("pane_id") {
                  Some(Json::Number(id, ..)) => {
                    let id_str = id.to_int().to_string()
                    panes[id_str] = ()
                  }
                  _ => ()
                }
              _ => ()
            }
          }
        _ => return None
      }
    }
    _ => return None
  }
  Some(panes)
}

///|
/// Check if a session is stale.
async fn is_stale(
  session : @session.Session,
  pane_cache : Map[String, Map[String, Unit]?],
  ttl : Int64,
  now : Int64,
) -> Bool {
  if session.pane_id != "" && session.pane_terminal != "" {
    // Has pane info — check if pane still exists
    if !pane_cache.contains(session.pane_terminal) {
      pane_cache[session.pane_terminal] = list_panes(session.pane_terminal)
    }
    match pane_cache[session.pane_terminal] {
      None => false // Command failed, don't delete
      Some(panes) => !panes.contains(session.pane_id)
    }
  } else {
    // No pane info — fall back to TTL
    now - session.updated_at > ttl
  }
}

///|
/// Find duplicate sessions on the same pane.
/// Sessions are expected in updated_at DESC order; first seen per pane wins.
/// Returns a set of session IDs that are duplicates (older entries).
fn find_pane_duplicates(
  sessions : Array[@session.Session],
) -> Map[String, Unit] {
  let seen : Map[String, Unit] = {}
  let dupes : Map[String, Unit] = {}
  for session in sessions {
    if session.pane_id == "" || session.pane_terminal == "" {
      continue
    }
    let key = session.pane_terminal + ":" + session.pane_id
    if seen.contains(key) {
      dupes[session.session_id] = ()
    } else {
      seen[key] = ()
    }
  }
  dupes
}

///|
/// Remove stale sessions. Returns list of deleted session IDs.
pub async fn reconcile(ttl : Int64) -> Array[String] {
  let deleted : Array[String] = []
  let sessions_result : Result[Array[@session.Session], _] = try? @db.list_sessions()
  let sessions = match sessions_result {
    Ok(s) => s
    Err(_) => return deleted
  }
  if sessions.is_empty() {
    return deleted
  }
  let now = @ffi.now_unix()
  let pane_cache : Map[String, Map[String, Unit]?] = {}
  let pane_dupes = find_pane_duplicates(sessions)
  let cfg = @config.load_config()
  for session in sessions {
    if pane_dupes.contains(session.session_id) ||
      is_stale(session, pane_cache, ttl, now) {
      let prev_state = session.state
      let del_result : Result[Bool, _] = try? @db.delete_session(
        session.session_id,
      )
      match del_result {
        Ok(true) => {
          deleted.push(session.session_id)
          // Fire SessionEnd hook
          @hook.fire(cfg, @hook.HookContext::{
            session_id: session.session_id,
            cwd: session.cwd,
            event: @session.SessionEnd,
            tool_name: "",
            session_name: session.session_name,
            state: None,
            prev_state: Some(prev_state),
            pane_id: session.pane_id,
            pane_terminal: session.pane_terminal,
          })
        }
        _ => ()
      }
    }
  }
  deleted
}
