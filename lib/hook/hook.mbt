///|
pub(all) struct HookContext {
  session_id : String
  cwd : String
  event : @session.HookEvent
  tool_name : String
  session_name : String
  state : @session.SessionState?
  prev_state : @session.SessionState?
  pane_id : String
  pane_terminal : String
} derive(Show)

///|
/// Typed hook config converted from config strings.
priv struct TypedHookConfig {
  on_event : @session.HookEvent? // None = not set
  on_state_change : TypedStateChange? // None = not set
  command : String
}

///|
priv struct TypedStateChange {
  from : @session.SessionState? // None = any
  to : @session.SessionState? // None = any
}

///|
/// Convert a config HookConfig (string-based) to a typed one.
/// Returns None if strings are invalid.
fn convert_hook(hook : @config.HookConfig) -> TypedHookConfig? {
  if hook.on_event != "" {
    let event = match @session.HookEvent::from_string(hook.on_event) {
      Some(e) => e
      None => {
        @ffi.eprintln("Error: invalid event '\{hook.on_event}'")
        return None
      }
    }
    Some(TypedHookConfig::{
      on_event: Some(event),
      on_state_change: None,
      command: hook.command,
    })
  } else {
    match hook.on_state_change {
      None => None
      Some(sc) => {
        let from = if sc.from == "" {
          None
        } else {
          match @session.SessionState::from_string(sc.from) {
            Some(s) => Some(s)
            None => {
              @ffi.eprintln("Error: invalid state '\{sc.from}'")
              return None
            }
          }
        }
        let to = if sc.to == "" {
          None
        } else {
          match @session.SessionState::from_string(sc.to) {
            Some(s) => Some(s)
            None => {
              @ffi.eprintln("Error: invalid state '\{sc.to}'")
              return None
            }
          }
        }
        Some(TypedHookConfig::{
          on_event: None,
          on_state_change: Some(TypedStateChange::{ from, to }),
          command: hook.command,
        })
      }
    }
  }
}

///|
/// Check if a typed hook config matches the given context.
fn matches_hook(hook : TypedHookConfig, ctx : HookContext) -> Bool {
  match hook.on_event {
    Some(event) => event == ctx.event
    None =>
      match hook.on_state_change {
        None => false
        Some(sc) => {
          // Must have an actual state transition
          if ctx.prev_state == ctx.state {
            return false
          }
          if ctx.prev_state is None && ctx.state is None {
            return false
          }
          // Check from constraint
          match sc.from {
            Some(from) => if ctx.prev_state != Some(from) { return false }
            None => ()
          }
          // Check to constraint
          match sc.to {
            Some(to) => if ctx.state != Some(to) { return false }
            None => ()
          }
          true
        }
      }
  }
}

///|
/// Fire user hooks that match the given context.
/// Converts config strings to enums at this boundary.
pub fn fire(cfg : @config.Config?, ctx : HookContext) -> Unit {
  let config = match cfg {
    None => return
    Some(c) => c
  }
  let state_str = match ctx.state {
    Some(s) => s.to_state_string()
    None => ""
  }
  let prev_state_str = match ctx.prev_state {
    Some(s) => s.to_state_string()
    None => ""
  }
  for hook in config.hooks {
    let typed = match convert_hook(hook) {
      Some(t) => t
      None => continue
    }
    if matches_hook(typed, ctx) {
      let env_pairs = [
        "MONITOR_SESSION_ID=\{ctx.session_id}",
        "MONITOR_CWD=\{ctx.cwd}",
        "MONITOR_EVENT=\{ctx.event.to_event_string()}",
        "MONITOR_TOOL_NAME=\{ctx.tool_name}",
        "MONITOR_SESSION_NAME=\{ctx.session_name}",
        "MONITOR_STATE=\{state_str}",
        "MONITOR_PREV_STATE=\{prev_state_str}",
        "MONITOR_PANE_ID=\{ctx.pane_id}",
        "MONITOR_PANE_TERMINAL=\{ctx.pane_terminal}",
      ]
      @ffi.spawn_detached(typed.command, env_pairs)
    }
  }
}
