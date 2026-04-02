///|
/// Detect the current terminal multiplexer pane.
/// Checks TMUX_PANE first (tmux priority), then WEZTERM_PANE.
pub fn detect_pane() -> @types.PaneInfo? {
  match @env.get_env_var("TMUX_PANE") {
    Some(pane_id) => Some(@types.PaneInfo::{ terminal: "tmux", pane_id })
    None =>
      match @env.get_env_var("WEZTERM_PANE") {
        Some(pane_id) => Some(@types.PaneInfo::{ terminal: "wez", pane_id })
        None => None
      }
  }
}

///|
/// Format a pane ID for display. Returns "-" if empty.
pub fn format_pane(pane_id : String) -> String {
  if pane_id == "" {
    "-"
  } else {
    pane_id
  }
}

///|
/// Determine the pane column header based on session terminals.
/// Returns "" if no sessions have pane info,
/// "TMUX" or "WEZ" if all from one terminal,
/// "PANE" if mixed.
pub fn pane_column_header(sessions : Array[@types.Session]) -> String {
  let mut has_tmux = false
  let mut has_wez = false
  for session in sessions {
    if session.pane_id != "" && session.pane_terminal != "" {
      match session.pane_terminal {
        "tmux" => has_tmux = true
        "wez" => has_wez = true
        _ => ()
      }
    }
  }
  if has_tmux && has_wez {
    "PANE"
  } else if has_tmux {
    "TMUX"
  } else if has_wez {
    "WEZ"
  } else {
    ""
  }
}
