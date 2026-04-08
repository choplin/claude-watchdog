///|
/// Manually trigger stale session cleanup.
pub async fn run_reconcile(matches : @argparse.Matches) -> Unit {
  let format = @cli.get_one(matches, "format")
  let init_result : Result[_, _] = try? @db.init_db()
  match init_result {
    Err(e) => {
      @ffi.eprintln("Error: \{e}")
      @ffi.exit(1)
    }
    Ok(_) => ()
  }
  let deleted = @reconcile.reconcile(@reconcile.default_ttl)
  if format == "json" {
    let arr : Array[Json] = deleted.map(fn(id) { Json::string(id) })
    let obj : Map[String, Json] = {}
    obj["deleted"] = Json::array(arr)
    println(Json::object(obj).stringify(indent=2))
  } else if deleted.is_empty() {
    println("No stale sessions found")
  } else {
    println("Reconciled \{deleted.length()} stale session(s)")
  }
}
