///|
/// Delete a session by ID.
pub fn run_delete(matches : @argparse.Matches) -> Unit {
  let session_id = @cli.get_one(matches, "session-id")
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
