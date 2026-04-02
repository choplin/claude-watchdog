///|
pub(all) struct HookContext {
  session_id : String
  cwd : String
  event : String
  tool_name : String
  session_name : String
  state : String
  prev_state : String
  pane_id : String
  pane_terminal : String
} derive(Show)

///|
/// Check if a hook config matches the given context.
fn matches_hook(hook : @config.HookConfig, ctx : HookContext) -> Bool {
  if hook.on_event != "" {
    return hook.on_event == ctx.event
  }
  match hook.on_state_change {
    None => false
    Some(sc) => {
      // Must have an actual state transition
      if ctx.prev_state == ctx.state {
        return false
      }
      if ctx.prev_state == "" && ctx.state == "" {
        return false
      }
      // Check from constraint
      if sc.from != "" && sc.from != ctx.prev_state {
        return false
      }
      // Check to constraint
      if sc.to != "" && sc.to != ctx.state {
        return false
      }
      true
    }
  }
}

///|
/// Fire user hooks that match the given context.
pub fn fire_user_hooks(cfg : @config.Config?, ctx : HookContext) -> Unit {
  let config = match cfg {
    None => return
    Some(c) => c
  }
  for hook in config.hooks {
    if matches_hook(hook, ctx) {
      let env_pairs = [
        "MONITOR_SESSION_ID=\{ctx.session_id}",
        "MONITOR_CWD=\{ctx.cwd}",
        "MONITOR_EVENT=\{ctx.event}",
        "MONITOR_TOOL_NAME=\{ctx.tool_name}",
        "MONITOR_SESSION_NAME=\{ctx.session_name}",
        "MONITOR_STATE=\{ctx.state}",
        "MONITOR_PREV_STATE=\{ctx.prev_state}",
        "MONITOR_PANE_ID=\{ctx.pane_id}",
        "MONITOR_PANE_TERMINAL=\{ctx.pane_terminal}",
      ]
      @ffi.spawn_detached(hook.command, env_pairs)
    }
  }
}
