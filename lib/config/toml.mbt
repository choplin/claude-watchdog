///|
/// Minimal TOML parser for claude-watchdog config.
/// Supports only:
///   [[hooks]] — array of tables
///   key = "value" — string values
///   key = { k1 = "v1", k2 = "v2" } — inline tables

///|
/// Parse TOML hooks config into raw key-value maps.
/// Returns None on parse error.
pub fn parse_toml_hooks(content : String) -> Array[Map[String, String]]? {
  let hooks : Array[Map[String, String]] = []
  let mut current : Map[String, String]? = None
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    let trimmed = line.trim().to_string()
    // Skip empty lines and comments
    if trimmed == "" || trimmed[0] == '#' {
      continue
    }
    // [[hooks]] — start new hook entry
    if trimmed == "[[hooks]]" {
      match current {
        Some(c) => hooks.push(c)
        None => ()
      }
      current = Some({})
      continue
    }
    // key = value within a hook
    match current {
      None => continue // ignore lines outside [[hooks]]
      Some(c) =>
        match parse_key_value(trimmed) {
          Some((key, value)) => c[key] = value
          None => return None // parse error
        }
    }
  }
  // Push the last hook
  match current {
    Some(c) => hooks.push(c)
    None => ()
  }
  Some(hooks)
}

///|
/// Parse "key = value" where value is either "string" or { inline table }.
/// For inline tables, returns the key with a special encoding:
///   on_state_change = { from = "running", to = "waiting_input" }
///   becomes: "on_state_change.from" -> "running", "on_state_change.to" -> "waiting_input"
/// Returns None on parse error.
fn parse_key_value(line : String) -> (String, String)? {
  match line.split_once("=") {
    None => None
    Some((key_view, val_view)) => {
      let key = key_view.to_string().trim().to_string()
      let val = val_view.to_string().trim().to_string()
      if val.length() == 0 {
        return None
      }
      // Quoted string value: "..."
      if val[0] == '"' {
        match parse_quoted_string(val) {
          Some(s) => Some((key, s))
          None => None
        }
      } else if val[0] == '{' {
        // This is an inline table — we need special handling
        // Return a marker so the caller can parse sub-keys
        Some((key, val))
      } else {
        // Bare value (not supported in our subset, but allow it)
        Some((key, val))
      }
    }
  }
}

///|
/// Parse a quoted string: "value" -> value
fn parse_quoted_string(s : String) -> String? {
  if s.length() < 2 {
    return None
  }
  if s[0] != '"' {
    return None
  }
  // Find closing quote
  for i in 1..<s.length() {
    if s.get_char(i) is Some('"') {
      let inner = s[1:i]
      return Some(inner.to_string())
    }
  }
  None
}

///|
/// Parse an inline table: { from = "running", to = "waiting_input" }
/// Returns a map of key-value pairs.
pub fn parse_inline_table(s : String) -> Map[String, String]? {
  let trimmed = s.trim().to_string()
  if trimmed.length() < 2 {
    return None
  }
  if trimmed[0] != '{' {
    return None
  }
  // Find the closing brace
  let inner = trimmed[1:trimmed.length() - 1].to_string()
  let result : Map[String, String] = {}
  for part_view in inner.split(",") {
    let part = part_view.to_string().trim().to_string()
    if part == "" {
      continue
    }
    match part.split_once("=") {
      None => return None
      Some((k_view, v_view)) => {
        let k = k_view.to_string().trim().to_string()
        let v = v_view.to_string().trim().to_string()
        match parse_quoted_string(v) {
          Some(parsed) => result[k] = parsed
          None => result[k] = v
        }
      }
    }
  }
  Some(result)
}
