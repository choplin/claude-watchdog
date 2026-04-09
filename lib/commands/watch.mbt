///|
let poll_interval_ms = 100

///|
/// Watch sessions with periodic refresh.
pub async fn run_watch(matches : @argparse.Matches) -> Unit {
  let interval_str = @cli.get_one(matches, "interval")
  let interval = @string.parse_int(interval_str) catch {
    _ => {
      @ffi.eprintln("Error: invalid interval value")
      @ffi.exit(1)
      return
    }
  }
  let no_reconcile = @cli.get_flag(matches, "no-reconcile")
  let mut show_header = !@cli.get_flag(matches, "no-header")
  init_db_or_exit()
  // Enter alternate screen buffer, hide cursor, enable raw mode for key input
  @ffi.print_flush("\u001b[?1049h\u001b[?25l")
  @ffi.term_enable_raw()
  let interval_ms = interval * 1000
  while true {
    // Build entire frame in buffer
    let buf = StringBuilder::new()
    buf.write_string("\u001b[H")
    if show_header {
      let now = @ffi.now_unix()
      let time_str = format_datetime(now)
      buf.write_string(
        "Every \{interval}s | \{time_str} | t: toggle header, q: quit",
      )
      buf.write_string("\u001b[K\n\u001b[K\n")
    }
    // Reconcile and render sessions
    if !no_reconcile {
      ignore(@reconcile.reconcile(@reconcile.default_ttl))
    }
    let sessions = list_sessions_or_exit()
    let text = render_text(sessions, true)
    // Insert clear-to-end-of-line before each newline to prevent stale content
    buf.write_string(erase_eol_before_newlines(text.to_string()))
    // Clear from cursor to end of screen (remove stale rows)
    buf.write_string("\u001b[J")
    @ffi.print_flush(buf.to_string())
    // Poll for key input during the sleep interval
    let mut elapsed = 0
    while elapsed < interval_ms {
      @async.sleep(poll_interval_ms)
      elapsed += poll_interval_ms
      match process_keys() {
        KeyAction::ToggleHeader => {
          show_header = !show_header
          break // Redraw immediately
        }
        KeyAction::Quit => {
          @ffi.term_restore()
          @ffi.print_flush("\u001b[?25h\u001b[?1049l")
          return
        }
        KeyAction::None => ()
      }
    }
  }
}

///|
priv enum KeyAction {
  None
  ToggleHeader
  Quit
}

///|
/// Drain all pending key input and return the action to take.
fn process_keys() -> KeyAction {
  let mut action = KeyAction::None
  while true {
    let key = @ffi.read_key()
    if key == -1 {
      break
    }
    // 't' or 'T' toggles header
    if key == 0x74 || key == 0x54 {
      action = ToggleHeader
    }
    // 'q', 'Q', or Ctrl+C
    if key == 0x71 || key == 0x51 || key == 0x03 {
      action = Quit
    }
  }
  action
}

///|
/// Insert ESC[K (clear to end of line) before each newline.
fn erase_eol_before_newlines(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\n' {
      buf.write_string("\u001b[K")
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// Format a unix timestamp as YYYY-MM-DD HH:MM:SS.
fn format_datetime(unix : Int64) -> String {
  let total_seconds = unix
  let seconds = (total_seconds % 60L).to_int()
  let total_minutes = total_seconds / 60L
  let minutes = (total_minutes % 60L).to_int()
  let total_hours = total_minutes / 60L
  let hours = (total_hours % 24L).to_int()
  let total_days = total_hours / 24L
  let (year, month, day) = days_to_date(total_days)
  let pad = fn(n : Int) -> String {
    if n < 10 {
      "0\{n}"
    } else {
      n.to_string()
    }
  }
  "\{year}-\{pad(month)}-\{pad(day)} \{pad(hours)}:\{pad(minutes)}:\{pad(seconds)}"
}

///|
/// Convert days since epoch to (year, month, day).
fn days_to_date(days : Int64) -> (Int, Int, Int) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = (doy - (153L * mp + 2L) / 5L + 1L).to_int()
  let m = (mp + (if mp < 10L { 3L } else { -9L })).to_int()
  let year = (y + (if m <= 2 { 1L } else { 0L })).to_int()
  (year, m, d)
}
