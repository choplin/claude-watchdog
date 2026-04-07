///|
test "parse_toml_hooks: empty" {
  let result = @config.parse_toml_hooks("")
  guard result is Some(hooks) else { fail("expected Some") }
  inspect(hooks.length(), content="0")
}

///|
test "parse_toml_hooks: event hook" {
  let toml =
    #|[[hooks]]
    #|on_event = "Stop"
    #|command = "echo done"
    #|
  let result = @config.parse_toml_hooks(toml)
  guard result is Some(hooks) else { fail("expected Some") }
  inspect(hooks.length(), content="1")
  inspect(hooks[0]["on_event"], content="Stop")
  inspect(hooks[0]["command"], content="echo done")
}

///|
test "parse_toml_hooks: state change hook" {
  let toml =
    #|[[hooks]]
    #|on_state_change = { from = "running", to = "waiting_input" }
    #|command = "notify-send"
    #|
  let result = @config.parse_toml_hooks(toml)
  guard result is Some(hooks) else { fail("expected Some") }
  inspect(hooks.length(), content="1")
  inspect(hooks[0]["command"], content="notify-send")
  inspect(hooks[0]["on_state_change.from"], content="running")
  inspect(hooks[0]["on_state_change.to"], content="waiting_input")
}

///|
test "parse_toml_hooks: multiple hooks" {
  let toml =
    #|[[hooks]]
    #|on_event = "Stop"
    #|command = "echo stop"
    #|
    #|[[hooks]]
    #|on_event = "SessionStart"
    #|command = "echo start"
    #|
  let result = @config.parse_toml_hooks(toml)
  guard result is Some(hooks) else { fail("expected Some") }
  inspect(hooks.length(), content="2")
}

///|
test "parse_toml_hooks: escaped double quotes in command" {
  let toml =
    #|[[hooks]]
    #|on_event = "Stop"
    #|command = "osascript -e 'display notification \"Stop\" with title \"Claude Code \"'"
    #|
  let result = @config.parse_toml_hooks(toml)
  guard result is Some(hooks) else { fail("expected Some") }
  let expected =
    #|osascript -e 'display notification "Stop" with title "Claude Code "'
  inspect(hooks[0]["command"], content=expected)
}

///|
test "parse_toml_hooks: escaped backslash in command" {
  let toml =
    #|[[hooks]]
    #|on_event = "Stop"
    #|command = "echo hello\\world"
    #|
  let result = @config.parse_toml_hooks(toml)
  guard result is Some(hooks) else { fail("expected Some") }
  inspect(hooks[0]["command"], content="echo hello\\world")
}
