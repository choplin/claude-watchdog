test "get_one returns value when present" {
  let app = @argparse.Command(
    "test",
    options=[@argparse.OptionArg("name", default_values=["default"])],
  )
  let matches = try! app.parse(argv=["--name", "alice"], env={})
  assert_eq(get_one(matches, "name"), "alice")
}

test "get_one returns default when not provided" {
  let app = @argparse.Command(
    "test",
    options=[@argparse.OptionArg("name", default_values=["default"])],
  )
  let matches = try! app.parse(argv=[], env={})
  assert_eq(get_one(matches, "name"), "default")
}

test "get_one returns empty string for unknown key" {
  let app = @argparse.Command("test")
  let matches = try! app.parse(argv=[], env={})
  assert_eq(get_one(matches, "missing"), "")
}

test "get_flag returns true when set" {
  let app = @argparse.Command(
    "test", flags=[@argparse.FlagArg("verbose")],
  )
  let matches = try! app.parse(argv=["--verbose"], env={})
  assert_eq(get_flag(matches, "verbose"), true)
}

test "get_flag returns false when not set" {
  let app = @argparse.Command(
    "test", flags=[@argparse.FlagArg("verbose")],
  )
  let matches = try! app.parse(argv=[], env={})
  assert_eq(get_flag(matches, "verbose"), false)
}

test "get_flag returns false for unknown key" {
  let app = @argparse.Command("test")
  let matches = try! app.parse(argv=[], env={})
  assert_eq(get_flag(matches, "missing"), false)
}

test "build_app parses list subcommand with defaults" {
  let app = build_app()
  let matches = try! app.parse(argv=["list"], env={})
  match matches.subcommand {
    Some(("list", m)) => {
      assert_eq(get_one(m, "format"), "text")
      assert_eq(get_one(m, "color"), "auto")
      assert_eq(get_flag(m, "no-reconcile"), false)
    }
    _ => fail("expected list subcommand")
  }
}

test "build_app parses list subcommand with flags" {
  let app = build_app()
  let matches = try! app.parse(
    argv=["list", "--format", "json", "--color=always", "--no-reconcile"],
    env={},
  )
  match matches.subcommand {
    Some(("list", m)) => {
      assert_eq(get_one(m, "format"), "json")
      assert_eq(get_one(m, "color"), "always")
      assert_eq(get_flag(m, "no-reconcile"), true)
    }
    _ => fail("expected list subcommand")
  }
}

test "build_app parses delete subcommand" {
  let app = build_app()
  let matches = try! app.parse(argv=["delete", "--session-id", "abc"], env={})
  match matches.subcommand {
    Some(("delete", m)) => assert_eq(get_one(m, "session-id"), "abc")
    _ => fail("expected delete subcommand")
  }
}

test "build_app parses hook subcommand with positional args" {
  let app = build_app()
  let matches = try! app.parse(argv=["hook", "Stop", "Bash"], env={})
  match matches.subcommand {
    Some(("hook", m)) => {
      assert_eq(get_one(m, "event"), "Stop")
      assert_eq(get_one(m, "tool-name"), "Bash")
    }
    _ => fail("expected hook subcommand")
  }
}

test "build_app parses hook subcommand without optional tool-name" {
  let app = build_app()
  let matches = try! app.parse(argv=["hook", "SessionEnd"], env={})
  match matches.subcommand {
    Some(("hook", m)) => {
      assert_eq(get_one(m, "event"), "SessionEnd")
      assert_eq(get_one(m, "tool-name"), "")
    }
    _ => fail("expected hook subcommand")
  }
}

test "build_app parses update subcommand" {
  let app = build_app()
  let matches = try! app.parse(
    argv=[
      "update", "--session-id", "s1", "--cwd", "/tmp", "--event", "PostToolUse",
      "--tool-name", "Bash",
    ],
    env={},
  )
  match matches.subcommand {
    Some(("update", m)) => {
      assert_eq(get_one(m, "session-id"), "s1")
      assert_eq(get_one(m, "cwd"), "/tmp")
      assert_eq(get_one(m, "event"), "PostToolUse")
      assert_eq(get_one(m, "tool-name"), "Bash")
      assert_eq(get_one(m, "session-name"), "")
    }
    _ => fail("expected update subcommand")
  }
}

test "build_app parses reconcile subcommand" {
  let app = build_app()
  let matches = try! app.parse(argv=["reconcile", "-f", "json"], env={})
  match matches.subcommand {
    Some(("reconcile", m)) => assert_eq(get_one(m, "format"), "json")
    _ => fail("expected reconcile subcommand")
  }
}
