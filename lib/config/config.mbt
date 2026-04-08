///|
pub(all) struct Config {
  hooks : Array[HookConfig]
} derive(Show)

///|
pub(all) struct HookConfig {
  on_event : String // "" = not set
  on_state_change : StateChangePattern? // None = not set
  command : String
} derive(Show)

///|
pub(all) struct StateChangePattern {
  from : String // "" = any
  to : String // "" = any
} derive(Show)

///|
/// Get the config file path.
pub fn get_config_path() -> String {
  let config_home = match @env.get_env_var("XDG_CONFIG_HOME") {
    Some(xdg) => xdg
    None => {
      let home = @ffi.home_dir()
      if home == "" {
        ".config"
      } else {
        home + "/.config"
      }
    }
  }
  config_home + "/claude-watchdog/config.toml"
}

///|
/// Load and validate the config file. Returns None if not found or invalid.
pub async fn load_config() -> Config? {
  let path = get_config_path()
  if !@fs.exists(path) {
    return None
  }
  let data = @fs.read_file(path)
  let content = data.text()
  if content == "" {
    return None
  }
  match parse_toml_hooks(content) {
    None => {
      @ffi.eprintln("Error: failed to parse config file")
      None
    }
    Some(raw_hooks) => validate_config(raw_hooks)
  }
}

///|
/// Validate raw hook config maps into typed Config.
fn validate_config(raw_hooks : Array[Map[String, String]]) -> Config? {
  let hooks : Array[HookConfig] = []
  for raw in raw_hooks {
    let command = raw.get("command")
    match command {
      None => {
        @ffi.eprintln("Error: hook missing 'command' field")
        return None
      }
      Some(cmd) =>
        if cmd == "" {
          @ffi.eprintln("Error: hook 'command' must not be empty")
          return None
        }
    }
    let has_on_event = raw.contains("on_event")
    // Inline tables are flattened to dotted keys (e.g. "on_state_change.from")
    let has_on_state_change = raw.contains("on_state_change.from") ||
      raw.contains("on_state_change.to")
    // Must have exactly one trigger
    if has_on_event && has_on_state_change {
      @ffi.eprintln(
        "Error: hook cannot have both 'on_event' and 'on_state_change'",
      )
      return None
    }
    if !has_on_event && !has_on_state_change {
      @ffi.eprintln(
        "Error: hook must have either 'on_event' or 'on_state_change'",
      )
      return None
    }
    if has_on_event {
      let event_str = raw["on_event"]
      hooks.push(HookConfig::{
        on_event: event_str,
        on_state_change: None,
        command: command.unwrap(),
      })
    } else {
      let from = match raw.get("on_state_change.from") {
        Some(v) => v
        None => ""
      }
      let to = match raw.get("on_state_change.to") {
        Some(v) => v
        None => ""
      }
      hooks.push(HookConfig::{
        on_event: "",
        on_state_change: Some(StateChangePattern::{ from, to }),
        command: command.unwrap(),
      })
    }
  }
  Some(Config::{ hooks, })
}
