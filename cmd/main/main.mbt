///|
async fn main {
  let app = @cli.build_app()
  let result : Result[@argparse.Matches, _] = try? app.parse()
  let matches = match result {
    Ok(m) => m
    Err(err) => {
      @ffi.eprintln(err.to_string())
      @ffi.exit(1)
      return
    }
  }
  match matches.subcommand {
    Some(("hook", m)) => @commands.run_hook(m)
    Some(("list", m)) => @commands.run_list(m)
    Some(("update", m)) => @commands.run_update(m)
    Some(("delete", m)) => @commands.run_delete(m)
    Some(("reconcile", m)) => @commands.run_reconcile(m)
    _ => ()
  }
}
