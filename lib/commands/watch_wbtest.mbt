///|
test "format_datetime - epoch" {
  inspect(format_datetime(0L), content="1970-01-01 00:00:00")
}

///|
test "format_datetime - known date" {
  // 2026-04-09 10:10:45 UTC
  inspect(format_datetime(1775729445L), content="2026-04-09 10:10:45")
}

///|
test "format_datetime - end of day" {
  // 2024-12-31 23:59:59 UTC
  inspect(format_datetime(1735689599L), content="2024-12-31 23:59:59")
}

///|
test "days_to_date - epoch" {
  inspect(days_to_date(0L), content="(1970, 1, 1)")
}

///|
test "days_to_date - leap year" {
  // 2024-02-29 is day 19782 since epoch
  inspect(days_to_date(19782L), content="(2024, 2, 29)")
}
