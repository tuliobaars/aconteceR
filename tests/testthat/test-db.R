test_that("a new database has the events table", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  expect_true("events" %in% DBI::dbListTables(con))
})

test_that("events round-trip through the database", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  id <- db_insert_event(con, clean_event(price_type = "paid", price = 40))
  got <- db_fetch_events(con)
  expect_equal(nrow(got), 1L)
  expect_equal(got$id, id)
  expect_equal(got$title, "Jazz night")
  expect_equal(got$price, 40)
  expect_true(is.na(got$url))
  expect_equal(got$source, "user")
})

test_that("duplicates are detected by title, city and start", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event())
  expect_true(db_event_exists(con, "jazz night", "Curitiba - PR", "2026-12-05 20:00"))
  expect_false(db_event_exists(con, "Jazz night", "Curitiba - PR", "2026-12-05 21:00"))
  expect_false(db_event_exists(con, "Jazz night", "Recife - PE", "2026-12-05 20:00"))
})

test_that("fetching filters by city and date and sorts by start", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event(title = "Late", starts_at = "2026-12-20 20:00"))
  db_insert_event(con, clean_event(title = "Early", starts_at = "2026-12-05 20:00"))
  db_insert_event(con, clean_event(title = "Elsewhere", city = "Recife - PE"))

  all <- db_fetch_events(con)
  expect_equal(nrow(all), 3L)

  here <- db_fetch_events(con, city = "Curitiba - PR")
  expect_equal(here$title, c("Early", "Late"))

  same_day <- db_fetch_events(con, city = "Curitiba - PR",
                              from = as.Date("2026-12-05"), to = as.Date("2026-12-05"))
  expect_equal(same_day$title, "Early")

  expect_equal(nrow(db_fetch_events(con, to = as.Date("2026-12-04"))), 0L)
  expect_equal(nrow(db_fetch_events(con, from = as.Date("2026-12-06"), city = "Curitiba - PR")), 1L)
})

test_that("bound parameters keep hostile text as plain text", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  nasty <- "x'); DROP TABLE events;--"
  db_insert_event(con, clean_event(title = nasty))
  expect_true("events" %in% DBI::dbListTables(con))
  expect_equal(db_fetch_events(con)$title, nasty)
  expect_true(db_event_exists(con, nasty, "Curitiba - PR", "2026-12-05 20:00"))
})

test_that("events with an external id are never stored twice", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  ev <- clean_event(source = "demo", external_id = "abc-1")
  expect_false(is.na(db_insert_event(con, ev, ignore_duplicates = TRUE)))
  expect_true(is.na(db_insert_event(con, ev, ignore_duplicates = TRUE)))
  expect_equal(nrow(db_fetch_events(con)), 1L)
})

test_that("sample events are seeded once, relative to today", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  today <- as.Date("2026-11-17")
  expect_equal(db_seed_samples(con, today = today), 1280L)
  expect_equal(db_seed_samples(con, today = today), 0L)
  got <- db_fetch_events(con)
  expect_equal(nrow(got), 1280L)
  expect_true(all(table(got$city) >= 30L))
  expect_true(all(got$source == "sample"))
  expect_true(all(got$starts_at >= "2026-11-17"))
  expect_true(all(c("free", "paid", "donation", "unknown") %in% got$price_type))
})

test_that("demo events are dated again once they are all in the past", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event(title = "Mine", starts_at = "2026-01-02 20:00"))
  expect_equal(db_seed_samples(con, today = as.Date("2026-01-01")), 1280L)
  expect_equal(db_seed_samples(con, today = as.Date("2026-02-01")), 0L)
  expect_equal(db_seed_samples(con, today = as.Date("2027-01-01")), 1280L)
  got <- db_fetch_events(con)
  expect_equal(nrow(got), 1281L)
  expect_true(all(got$starts_at[got$source == "sample"] >= "2027-01-01"))
  expect_true("Mine" %in% got$title)
})
