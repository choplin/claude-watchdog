///|
/// Delete a session by ID.
pub fn run_delete(args : Array[String]) -> Unit {
  let mut session_id = ""
  for i = 0; i < args.length(); {
    match args[i] {
      "--session-id" => {
        if i + 1 < args.length() {
          session_id = args[i + 1]
        }
        continue i + 2
      }
      _ => continue i + 1
    }
  }
  if session_id == "" {
    @ffi.eprintln("Error: --session-id is required")
    @ffi.exit(1)
  }
  let init_result : Result[_, _] = try? @db.init_db()
  match init_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
  let del_result : Result[Bool, _] = try? @db.delete_session(session_id)
  match del_result {
    Ok(true) => () // success, silent exit
    Ok(false) => {
      @ffi.eprintln("Error: session not found")
      @ffi.exit(1)
    }
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
  }
}
