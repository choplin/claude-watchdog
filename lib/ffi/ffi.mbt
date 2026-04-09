///|
extern "c" fn isatty_ffi(fd : Int) -> Int = "moonbit_watchdog_isatty"

///|
#owned(msg)
extern "c" fn eprintln_ffi(msg : Bytes) -> Unit = "moonbit_watchdog_eprintln"

///|
#owned(msg)
extern "c" fn print_flush_ffi(msg : Bytes) -> Unit = "moonbit_watchdog_print_flush"

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
/// Write a string to stdout without newline and flush.
pub fn print_flush(msg : String) -> Unit {
  print_flush_ffi(@utf8.encode(msg))
}

///|
extern "c" fn term_enable_raw_ffi() -> Unit = "moonbit_watchdog_term_enable_raw"

///|
extern "c" fn term_restore_ffi() -> Unit = "moonbit_watchdog_term_restore"

///|
extern "c" fn read_key_ffi() -> Int = "moonbit_watchdog_read_key"

///|
/// Enable raw mode on stdin for non-blocking key reads.
pub fn term_enable_raw() -> Unit {
  term_enable_raw_ffi()
}

///|
/// Restore original terminal settings.
pub fn term_restore() -> Unit {
  term_restore_ffi()
}

///|
/// Non-blocking read of a single key. Returns -1 if no input.
pub fn read_key() -> Int {
  read_key_ffi()
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
