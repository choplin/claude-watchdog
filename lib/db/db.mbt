///|
/// Get the database file path from env or default.
pub fn get_db_path() -> String {
  match @env.get_env_var("CLAUDE_WATCHDOG_DB") {
    Some(path) => path
    None => {
      let home = @ffi.home_dir()
      if home == "" {
        "claude-watchdog.db"
      } else {
        home + "/.claude/claude-watchdog.db"
      }
    }
  }
}

///|
fn open_db() -> @sqlite3.Connection raise {
  let conn = @sqlite3.Connection::open(get_db_path())
  let pragma = conn.prepare("PRAGMA journal_mode=WAL")
  ignore(pragma.step()) // PRAGMA returns a row
  pragma.finalize()
  conn
}

///|
/// Initialize the database: create table and run migrations.
pub fn init_db() -> Unit raise {
  let conn = open_db()
  // Create table
  let create_sql =
    #|CREATE TABLE IF NOT EXISTS sessions (
    #|  session_id TEXT PRIMARY KEY,
    #|  cwd TEXT NOT NULL,
    #|  event TEXT NOT NULL,
    #|  tool_name TEXT,
    #|  session_name TEXT,
    #|  created_at INTEGER NOT NULL,
    #|  updated_at INTEGER NOT NULL,
    #|  state_changed_at INTEGER NOT NULL,
    #|  pane_id TEXT,
    #|  pane_terminal TEXT
    #|)
  let stmt = conn.prepare(create_sql)
  stmt.step_once()
  stmt.finalize()
  // Migration: rename tmux_pane to pane_id if it exists
  run_migrations(conn)
  conn.close()
}

///|
fn run_migrations(conn : @sqlite3.Connection) -> Unit raise {
  // Check if tmux_pane column exists (old schema)
  let pragma_stmt = conn.prepare("PRAGMA table_info(sessions)")
  let mut has_tmux_pane = false
  let mut has_pane_id = false
  let mut has_pane_terminal = false
  let mut has_session_name = false
  while pragma_stmt.step() {
    let col_name : String = pragma_stmt.column(index=1)
    match col_name {
      "tmux_pane" => has_tmux_pane = true
      "pane_id" => has_pane_id = true
      "pane_terminal" => has_pane_terminal = true
      "session_name" => has_session_name = true
      _ => ()
    }
  }
  pragma_stmt.finalize()
  // Migrate tmux_pane -> pane_id
  if has_tmux_pane && !has_pane_id {
    let alter = conn.prepare(
      "ALTER TABLE sessions RENAME COLUMN tmux_pane TO pane_id",
    )
    alter.step_once()
    alter.finalize()
  }
  // Add pane_terminal if missing
  if !has_pane_terminal {
    let result : Result[_, _] = try? ({
      let alter = conn.prepare(
        "ALTER TABLE sessions ADD COLUMN pane_terminal TEXT",
      )
      alter.step_once()
      alter.finalize()
    })
    match result {
      // Set existing rows with pane_id to "tmux"
      Ok(_) => {
        let update = conn.prepare(
          "UPDATE sessions SET pane_terminal = 'tmux' WHERE pane_id IS NOT NULL AND pane_id != ''",
        )
        update.step_once()
        update.finalize()
      }
      Err(_) => () // Column may already exist
    }
  }
  // Add session_name if missing
  if !has_session_name {
    let result : Result[_, _] = try? ({
      let alter = conn.prepare(
        "ALTER TABLE sessions ADD COLUMN session_name TEXT",
      )
      alter.step_once()
      alter.finalize()
    })
    ignore(result)
  }
}

///|
/// Insert or update a session.
pub fn upsert_session(
  session_id : String,
  cwd : String,
  event : @session.HookEvent,
  tool_name : String,
  pane : @terminal.PaneInfo?,
  session_name : String,
) -> Unit raise {
  let conn = open_db()
  let now = @ffi.now_unix()
  let pane_id = match pane {
    Some(p) => p.pane_id
    None => ""
  }
  let pane_terminal = match pane {
    Some(p) => p.terminal
    None => ""
  }
  let sql =
    #|INSERT INTO sessions (session_id, cwd, event, tool_name, session_name, created_at, updated_at, state_changed_at, pane_id, pane_terminal)
    #|VALUES (?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))
    #|ON CONFLICT(session_id) DO UPDATE SET
    #|  cwd = excluded.cwd,
    #|  event = excluded.event,
    #|  tool_name = NULLIF(excluded.tool_name, ''),
    #|  session_name = COALESCE(NULLIF(excluded.session_name, ''), sessions.session_name),
    #|  updated_at = excluded.updated_at,
    #|  state_changed_at = CASE
    #|    WHEN sessions.event != excluded.event
    #|      OR COALESCE(sessions.tool_name, '') != COALESCE(excluded.tool_name, '')
    #|    THEN excluded.updated_at
    #|    ELSE sessions.state_changed_at
    #|  END,
    #|  pane_id = COALESCE(NULLIF(excluded.pane_id, ''), sessions.pane_id),
    #|  pane_terminal = COALESCE(NULLIF(excluded.pane_terminal, ''), sessions.pane_terminal)
  let stmt = conn.prepare(sql)
  stmt.bind(index=1, session_id)
  stmt.bind(index=2, cwd)
  stmt.bind(index=3, event.to_event_string())
  stmt.bind(index=4, tool_name)
  stmt.bind(index=5, session_name)
  stmt.bind(index=6, now)
  stmt.bind(index=7, now)
  stmt.bind(index=8, now)
  stmt.bind(index=9, pane_id)
  stmt.bind(index=10, pane_terminal)
  stmt.step_once()
  stmt.finalize()
  conn.close()
}

///|
/// Get a session by ID. Returns None if not found.
pub fn get_session(session_id : String) -> @session.Session? raise {
  let conn = open_db()
  let sql =
    #|SELECT session_id, cwd, event,
    #|  COALESCE(tool_name, ''), COALESCE(session_name, ''),
    #|  created_at, updated_at, state_changed_at,
    #|  COALESCE(pane_id, ''), COALESCE(pane_terminal, '')
    #|FROM sessions WHERE session_id = ?
  let stmt = conn.prepare(sql)
  stmt.bind(index=1, session_id)
  let result = if stmt.step() { Some(read_session(stmt)) } else { None }
  stmt.finalize()
  conn.close()
  result
}

///|
/// List all sessions ordered by updated_at DESC.
pub fn list_sessions() -> Array[@session.Session] raise {
  let conn = open_db()
  let sql =
    #|SELECT session_id, cwd, event,
    #|  COALESCE(tool_name, ''), COALESCE(session_name, ''),
    #|  created_at, updated_at, state_changed_at,
    #|  COALESCE(pane_id, ''), COALESCE(pane_terminal, '')
    #|FROM sessions ORDER BY updated_at DESC
  let stmt = conn.prepare(sql)
  let sessions : Array[@session.Session] = []
  while stmt.step() {
    sessions.push(read_session(stmt))
  }
  stmt.finalize()
  conn.close()
  sessions
}

///|
/// Delete a session by ID. Returns true if deleted.
pub fn delete_session(session_id : String) -> Bool raise {
  let conn = open_db()
  // Check if exists first
  let check_sql = "SELECT 1 FROM sessions WHERE session_id = ?"
  let check_stmt = conn.prepare(check_sql)
  check_stmt.bind(index=1, session_id)
  let exists = check_stmt.step()
  check_stmt.finalize()
  if !exists {
    conn.close()
    return false
  }
  let del_sql = "DELETE FROM sessions WHERE session_id = ?"
  let del_stmt = conn.prepare(del_sql)
  del_stmt.bind(index=1, session_id)
  del_stmt.step_once()
  del_stmt.finalize()
  conn.close()
  true
}

///|
fn read_session(stmt : @sqlite3.Statement) -> @session.Session {
  let session_id : String = stmt.column(index=0)
  let cwd : String = stmt.column(index=1)
  let event_str : String = stmt.column(index=2)
  let event = match @session.HookEvent::from_string(event_str) {
    Some(e) => e
    // DB values are always written by us, so this should never happen
    None => @session.SessionStart
  }
  let tool_name : String = stmt.column(index=3)
  let session_name : String = stmt.column(index=4)
  let created_at : Int64 = stmt.column(index=5)
  let updated_at : Int64 = stmt.column(index=6)
  let state_changed_at : Int64 = stmt.column(index=7)
  let pane_id : String = stmt.column(index=8)
  let pane_terminal : String = stmt.column(index=9)
  @session.Session::{
    session_id,
    cwd,
    event,
    tool_name,
    session_name,
    created_at,
    updated_at,
    state_changed_at,
    pane_id,
    pane_terminal,
  }
}
