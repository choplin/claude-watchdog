///|
/// Parse TOML config using bobzhang/toml library.
/// Extracts [[hooks]] array-of-tables into raw key-value maps
/// for validate_config to process.
pub fn parse_toml_hooks(content : String) -> Array[Map[String, String]]? {
  let parsed = try? @toml.parse(content)
  guard parsed is Ok(TomlTable(root)) else { return None }
  guard root.get("hooks") is Some(TomlArray(hooks_arr)) else {
    return Some([])
  }
  let result : Array[Map[String, String]] = []
  for entry in hooks_arr {
    guard entry is TomlTable(table) else { return None }
    let map : Map[String, String] = {}
    for k, v in table {
      match v {
        TomlString(s) => map[k] = s
        TomlTable(inner) => {
          // Inline table (e.g. on_state_change = { from = "running", to = "waiting_input" })
          // Flatten into dotted keys: "on_state_change.from", "on_state_change.to"
          for ik, iv in inner {
            guard iv is TomlString(s) else { return None }
            map[k + "." + ik] = s
          }
        }
        _ => return None
      }
    }
    result.push(map)
  }
  Some(result)
}
