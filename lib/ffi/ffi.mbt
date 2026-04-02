///|
extern "c" fn read_stdin_ffi() -> Bytes = "moonbit_watchdog_read_stdin"

///|
#owned(path)
extern "c" fn read_file_ffi(path : Bytes) -> Bytes = "moonbit_watchdog_read_file"

///|
#owned(command)
extern "c" fn popen_ffi(command : Bytes) -> Bytes = "moonbit_watchdog_popen"

///|
#owned(command, env_pairs)
extern "c" fn spawn_detached_ffi(command : Bytes, env_pairs : Bytes) -> Unit = "moonbit_watchdog_spawn_detached"

///|
extern "c" fn isatty_ffi(fd : Int) -> Int = "moonbit_watchdog_isatty"

///|
#owned(msg)
extern "c" fn eprintln_ffi(msg : Bytes) -> Unit = "moonbit_watchdog_eprintln"

///|
extern "c" fn exit_ffi(code : Int) -> Unit = "moonbit_watchdog_exit"

///|
extern "c" fn home_dir_ffi() -> Bytes = "moonbit_watchdog_home_dir"

///|
/// Read all of stdin as a UTF-8 string.
pub fn read_stdin() -> String {
  @utf8.decode_lossy(read_stdin_ffi())
}

///|
/// Read an entire file as a UTF-8 string. Returns empty string on error.
pub fn read_file(path : String) -> String {
  @utf8.decode_lossy(read_file_ffi(@utf8.encode(path)))
}

///|
/// Run a command and capture its stdout as a UTF-8 string.
pub fn popen(command : String) -> String {
  @utf8.decode_lossy(popen_ffi(@utf8.encode(command)))
}

///|
/// Spawn a command in the background as a detached process.
/// env_pairs is a list of "KEY=VALUE" strings.
pub fn spawn_detached(command : String, env_pairs : Array[String]) -> Unit {
  let sb = StringBuilder::new()
  for pair in env_pairs {
    sb.write_string(pair)
    sb.write_char('\n')
  }
  spawn_detached_ffi(@utf8.encode(command), @utf8.encode(sb.to_string()))
}

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
  exit_ffi(code)
}

///|
/// Get the user's home directory.
pub fn home_dir() -> String {
  @utf8.decode_lossy(home_dir_ffi())
}

///|
/// Get current unix timestamp in seconds.
pub fn now_unix() -> Int64 {
  @env.now().reinterpret_as_int64() / 1000L
}
