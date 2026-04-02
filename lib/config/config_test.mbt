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
test "parse_inline_table" {
  let result = @config.parse_inline_table(
    "{ from = \"running\", to = \"waiting_input\" }",
  )
  guard result is Some(table) else { fail("expected Some") }
  inspect(table["from"], content="running")
  inspect(table["to"], content="waiting_input")
}

///|
test "parse_inline_table: partial" {
  let result = @config.parse_inline_table("{ to = \"running\" }")
  guard result is Some(table) else { fail("expected Some") }
  inspect(table.contains("from"), content="false")
  inspect(table["to"], content="running")
}
