///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_help()
    @ffi.exit(1)
  }
  match args[1] {
    "hook" => @commands.run_hook(args[2:].to_array())
    "list" => @commands.run_list(args[2:].to_array())
    "update" => @commands.run_update(args[2:].to_array())
    "delete" => @commands.run_delete(args[2:].to_array())
    "reconcile" => @commands.run_reconcile(args[2:].to_array())
    "--help" | "-h" => print_help()
    cmd => {
      @ffi.eprintln("Unknown command: \{cmd}")
      @ffi.exit(1)
    }
  }
}

///|
fn print_help() -> Unit {
  let help =
    #|claude-watchdog - Monitor multiple Claude Code session states
    #|
    #|Usage: claude-watchdog <command> [options]
    #|
    #|Commands:
    #|  hook       Handle hook events (reads JSON from stdin)
    #|  list       List all active sessions
    #|  update     Register or update a session
    #|  delete     Delete a session
    #|  reconcile  Remove stale sessions
    #|
    #|Options:
    #|  --help, -h  Show this help message
    #|
  println(help)
}
