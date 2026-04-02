///|
test "detect_pane: no env vars" {
  // Save and clear env vars
  let old_tmux = @env.get_env_var("TMUX_PANE")
  let old_wez = @env.get_env_var("WEZTERM_PANE")
  @env.unset_env_var("TMUX_PANE")
  @env.unset_env_var("WEZTERM_PANE")
  inspect(@terminal.detect_pane(), content="None")
  // Restore
  match old_tmux {
    Some(v) => @env.set_env_var("TMUX_PANE", v)
    None => ()
  }
  match old_wez {
    Some(v) => @env.set_env_var("WEZTERM_PANE", v)
    None => ()
  }
}

///|
test "detect_pane: tmux" {
  let old_tmux = @env.get_env_var("TMUX_PANE")
  let old_wez = @env.get_env_var("WEZTERM_PANE")
  @env.set_env_var("TMUX_PANE", "%0")
  @env.unset_env_var("WEZTERM_PANE")
  let result = @terminal.detect_pane()
  inspect(result, content="Some({terminal: \"tmux\", pane_id: \"%0\"})")
  // Restore
  match old_tmux {
    Some(v) => @env.set_env_var("TMUX_PANE", v)
    None => @env.unset_env_var("TMUX_PANE")
  }
  match old_wez {
    Some(v) => @env.set_env_var("WEZTERM_PANE", v)
    None => ()
  }
}

///|
test "detect_pane: wezterm" {
  let old_tmux = @env.get_env_var("TMUX_PANE")
  let old_wez = @env.get_env_var("WEZTERM_PANE")
  @env.unset_env_var("TMUX_PANE")
  @env.set_env_var("WEZTERM_PANE", "3")
  let result = @terminal.detect_pane()
  inspect(result, content="Some({terminal: \"wez\", pane_id: \"3\"})")
  // Restore
  match old_tmux {
    Some(v) => @env.set_env_var("TMUX_PANE", v)
    None => ()
  }
  match old_wez {
    Some(v) => @env.set_env_var("WEZTERM_PANE", v)
    None => @env.unset_env_var("WEZTERM_PANE")
  }
}

///|
test "detect_pane: tmux priority" {
  let old_tmux = @env.get_env_var("TMUX_PANE")
  let old_wez = @env.get_env_var("WEZTERM_PANE")
  @env.set_env_var("TMUX_PANE", "%1")
  @env.set_env_var("WEZTERM_PANE", "5")
  let result = @terminal.detect_pane()
  inspect(result, content="Some({terminal: \"tmux\", pane_id: \"%1\"})")
  // Restore
  match old_tmux {
    Some(v) => @env.set_env_var("TMUX_PANE", v)
    None => @env.unset_env_var("TMUX_PANE")
  }
  match old_wez {
    Some(v) => @env.set_env_var("WEZTERM_PANE", v)
    None => @env.unset_env_var("WEZTERM_PANE")
  }
}

///|
test "format_pane" {
  inspect(@terminal.format_pane("%0"), content="%0")
  inspect(@terminal.format_pane(""), content="-")
}

///|
test "pane_column_header: no panes" {
  inspect(@terminal.pane_column_header([]), content="")
}

///|
test "pane_column_header: tmux only" {
  let sessions = [
    @types.Session::{
      session_id: "s1",
      cwd: "/tmp",
      event: "SessionStart",
      tool_name: "",
      session_name: "",
      created_at: 0L,
      updated_at: 0L,
      state_changed_at: 0L,
      pane_id: "%0",
      pane_terminal: "tmux",
    },
  ]
  inspect(@terminal.pane_column_header(sessions), content="TMUX")
}

///|
test "pane_column_header: mixed" {
  let sessions = [
    @types.Session::{
      session_id: "s1",
      cwd: "/tmp",
      event: "SessionStart",
      tool_name: "",
      session_name: "",
      created_at: 0L,
      updated_at: 0L,
      state_changed_at: 0L,
      pane_id: "%0",
      pane_terminal: "tmux",
    },
    @types.Session::{
      session_id: "s2",
      cwd: "/tmp",
      event: "SessionStart",
      tool_name: "",
      session_name: "",
      created_at: 0L,
      updated_at: 0L,
      state_changed_at: 0L,
      pane_id: "3",
      pane_terminal: "wez",
    },
  ]
  inspect(@terminal.pane_column_header(sessions), content="PANE")
}
