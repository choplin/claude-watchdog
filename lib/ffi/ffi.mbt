///|
extern "c" fn isatty_ffi(fd : Int) -> Int = "moonbit_watchdog_isatty"

///|
#owned(msg)
extern "c" fn eprintln_ffi(msg : Bytes) -> Unit = "moonbit_watchdog_eprintln"

///|
/// Check if stdout is a terminal.
pub fn stdout_is_tty() -> Bool {
  isatty_ffi(1) != 0
}

///|
/// Write a message to stderr.
pub fn eprintln(msg : String) -> Unit {
  eprintln_ffi(@utf8.encode(msg))
}

///|
/// Exit the process with the given code.
pub fn exit(code : Int) -> Unit {
  @sys.exit(code)
}

///|
/// Get the user's home directory.
pub fn home_dir() -> String {
  match @sys.get_env_var("HOME") {
    Some(home) => home
    None => ""
  }
}

///|
/// Get current unix timestamp in seconds.
pub fn now_unix() -> Int64 {
  @env.now().reinterpret_as_int64() / 1000L
}
