///|
/// Manually trigger stale session cleanup.
pub fn run_reconcile(args : Array[String]) -> Unit {
  let mut format = "text"
  for i = 0; i < args.length(); {
    match args[i] {
      "--format" => {
        if i + 1 < args.length() {
          format = args[i + 1]
        }
        continue i + 2
      }
      _ => continue i + 1
    }
  }
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
