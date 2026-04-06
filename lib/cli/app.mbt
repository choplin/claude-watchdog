///|
/// Build the CLI app definition.
pub fn build_app() -> @argparse.Command {
  @argparse.Command(
    "claude-watchdog",
    about="Monitor multiple Claude Code session states",
    subcommand_required=true,
    arg_required_else_help=true,
    subcommands=[
      @argparse.Command(
        "hook",
        about="Handle hook events (reads JSON from stdin)",
        positionals=[
          @argparse.PositionArg(
            "event", num_args=@argparse.ValueRange::single(),
          ),
          @argparse.PositionArg("tool-name"),
        ],
      ),
      @argparse.Command(
        "list",
        about="List all active sessions",
        options=[
          @argparse.OptionArg("format", short='f', default_values=["text"]),
          @argparse.OptionArg("color", default_values=["auto"]),
        ],
        flags=[@argparse.FlagArg("no-reconcile")],
      ),
      @argparse.Command(
        "update",
        about="Register or update a session",
        options=[
          @argparse.OptionArg("session-id", required=true),
          @argparse.OptionArg("cwd", required=true),
          @argparse.OptionArg("event", required=true),
          @argparse.OptionArg("tool-name"),
          @argparse.OptionArg("session-name"),
          @argparse.OptionArg("pane-id"),
          @argparse.OptionArg("pane-terminal"),
        ],
      ),
      @argparse.Command(
        "delete",
        about="Delete a session",
        options=[@argparse.OptionArg("session-id", required=true)],
      ),
      @argparse.Command(
        "reconcile",
        about="Remove stale sessions",
        options=[
          @argparse.OptionArg("format", short='f', default_values=["text"]),
        ],
      ),
    ],
  )
}
