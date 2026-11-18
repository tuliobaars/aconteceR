test_that("the local provider searches saved events and the stub explains itself", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event(title = "Jazz night"))
  db_insert_event(con, clean_event(title = "Chess club", starts_at = "2026-12-06 18:00"))

  res <- search_events(providers_default(con), query = "jazz")
  expect_equal(res$events$title, "Jazz night")
  expect_length(res$notes, 1L)
  expect_match(res$notes, "not connected")
})

test_that("a failing provider is reported and the others still answer", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event())
  bad <- list(name = "bad", label = "Bad source", enabled = TRUE,
              search = function(...) stop("boom"))
  res <- search_events(list(bad, provider_local(con)), query = "")
  expect_equal(nrow(res$events), 1L)
  expect_match(res$notes, "Bad source failed: boom")
})

test_that("results from several providers are de-duplicated", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event())
  res <- search_events(list(provider_local(con), provider_local(con)))
  expect_equal(nrow(res$events), 1L)
})

test_that("searching can be limited to one city", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  db_insert_event(con, clean_event(title = "Here"))
  db_insert_event(con, clean_event(title = "There", city = "Recife - PE"))
  res <- search_events(list(provider_local(con)), city = "Recife - PE")
  expect_equal(res$events$title, "There")
  expect_equal(nrow(search_events(list(provider_local(con)))$events), 2L)
})

test_that("no enabled provider means no events and no error", {
  res <- search_events(list(provider_online_stub()))
  expect_equal(nrow(res$events), 0L)
  expect_named(res$events, event_columns())
})

test_that("external site catalog and autopopulate work idempotently", {
  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  cat_df <- external_site_catalog()
  expect_true(all(c("sympla", "eventbrite", "meetup") %in% cat_df$name))

  provs <- providers_catalog(con, enabled_sites = c("sympla", "meetup"), include_local = FALSE)
  res <- search_events(provs, city = "Curitiba - PR")
  expect_gt(nrow(res$events), 0L)
  expect_true(all(res$events$city == "Curitiba - PR"))
  expect_true(all(res$events$source %in% c("sympla", "meetup")))

  added1 <- autopopulate_events(con, sites = c("sympla", "meetup"), city = "Curitiba - PR")
  expect_equal(added1, nrow(res$events))
  added2 <- autopopulate_events(con, sites = c("sympla", "meetup"), city = "Curitiba - PR")
  expect_equal(added2, 0L)
})

test_that("demo sites and templates are shared data files", {
  sites <- external_site_catalog()
  tpl <- site_templates()
  expect_named(sites, c("name", "label", "domain"))
  expect_true(all(tpl$site %in% sites$name))
  expect_true(all(tpl$category %in% names(event_categories())))
  expect_true(all(tpl$price_type %in% names(price_types())))
  expect_true(all(!is.na(tpl$price[tpl$price_type == "paid"])))
})

test_that("generated site events are one per template and city, dated from today", {
  cities <- load_cities()[1:2, ]
  ev <- generate_site_events("sympla", cities_df = cities, today = as.Date("2026-11-17"))
  n_tpl <- sum(site_templates()$site == "sympla")
  expect_equal(nrow(ev), n_tpl * 2L)
  expect_named(ev, event_columns())
  expect_equal(ev$city, rep(cities$label, each = n_tpl))
  expect_equal(ev$external_id[1], sprintf("sympla-sym-1-%d", cities$id[1]))
  expect_equal(substr(ev$starts_at[1], 1, 10), "2026-11-21")
  expect_true(all(vapply(seq_len(nrow(ev)), function(i) validate_event(as.list(ev[i, ]))$ok, logical(1))))
  expect_equal(nrow(generate_site_events("nope", cities_df = cities)), 0L)
})

test_that("provider notes follow the language", {
  res <- search_events(list(provider_online_stub()), lang = "pt")
  expect_match(res$notes, "ainda n\u00e3o est\u00e3o conectadas")
  off <- provider_external_site("meetup", enabled = FALSE, cities_df = load_cities()[1, ])
  expect_match(search_events(list(off), lang = "pt")$notes, "est\u00e1 desativado")
  expect_match(search_events(list(off))$notes, "is disabled")
})
