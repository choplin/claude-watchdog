///|
/// Get a single option/positional value from matches.
/// Returns empty string if not found.
pub fn get_one(matches : @argparse.Matches, name : String) -> String {
  match matches.values.get(name) {
    Some(vals) => if vals.is_empty() { "" } else { vals[0] }
    None => ""
  }
}

///|
/// Get a flag value from matches.
pub fn get_flag(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(v) => v
    None => false
  }
}
