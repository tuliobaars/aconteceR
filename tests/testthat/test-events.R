test_that("empty_events has the documented columns", {
  expect_named(empty_events(), event_columns())
  expect_equal(nrow(empty_events()), 0L)
})

test_that("matches_query ignores case and accents and wants every word", {
  ev <- make_events()
  expect_equal(which(matches_query(ev, "AZUL")), 1L)
  expect_equal(which(matches_query(ev, "street food")), 2L)
  expect_equal(which(matches_query(ev, "praia")), 4L)
  expect_false(any(matches_query(ev, "zzz")))
  expect_true(all(matches_query(ev, "")))
  expect_true(all(matches_query(ev, NULL)))
  expect_equal(matches_query(empty_events(), "x"), logical())
})

test_that("NA fields are not searchable as the text 'NA'", {
  expect_false(any(matches_query(make_events(), "na ")))
})

test_that("filter_events combines its filters", {
  ev <- make_events()
  expect_equal(nrow(filter_events(ev)), 4L)
  expect_equal(filter_events(ev, price_types = "free")$id, 2L)
  expect_equal(nrow(filter_events(ev, price_types = character())), 0L)
  expect_equal(filter_events(ev, categories = c("music", "tech"))$id, c(1L, 3L))
  expect_equal(nrow(filter_events(ev, categories = character())), 4L)
  expect_equal(
    filter_events(ev, from = as.Date("2026-12-06"), to = as.Date("2026-12-10"))$id,
    c(2L, 3L)
  )
  expect_equal(
    filter_events(ev, query = "workshop", price_types = c("paid", "free"))$id,
    3L
  )
  expect_equal(nrow(filter_events(empty_events(), query = "x")), 0L)
})

test_that("popups escape user text and only link safe URLs", {
  ev <- make_events()[1:2, ]
  ev$title[1] <- "<img src=x onerror=alert(1)>"
  ev$url <- c("javascript:alert(1)", "https://example.org/x")
  html <- event_popup_html(ev)

  expect_length(html, 2L)
  expect_false(grepl("<img", html[1], fixed = TRUE))
  expect_true(grepl("&lt;img", html[1], fixed = TRUE))
  expect_false(grepl("javascript:", html[1], fixed = TRUE))
  expect_false(grepl("<a ", html[1], fixed = TRUE))
  expect_true(grepl("<a href=\"https://example.org/x\"", html[2], fixed = TRUE))
  expect_equal(event_popup_html(empty_events()), character())
  # "Before & after" carries what the browser needs, escaped.
  expect_match(html[1], "data-ac-around=\"1\"", fixed = TRUE)
  expect_match(html[1], "data-title=\"&lt;img src=x onerror=alert(1)&gt;\"", fixed = TRUE)
  expect_match(html[2], "data-start=\"2026-12-06 09:00\"", fixed = TRUE)
  expect_match(html[2], "data-lat=\"-25.43\"", fixed = TRUE)
  expect_match(html[2], "Before &amp; after", fixed = TRUE)
  expect_match(event_popup_html(ev, "pt")[2], "Antes e depois", fixed = TRUE)
  ev$lat[2] <- NA
  expect_false(grepl("data-ac-around", event_popup_html(ev)[2], fixed = TRUE))
})

test_that("night activities start from 18:00 or before 05:00", {
  expect_equal(is_night_activity(c("2026-12-05 17:59", "2026-12-05 18:00", "2026-12-05 23:30",
                                   "2026-12-06 01:00", "2026-12-06 05:00", NA, "nope")),
               c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
})

test_that("when it is dark, night activities lead each day", {
  ev <- make_events()[c(1, 1, 1, 2), ]
  ev$id <- 1:4
  ev$starts_at <- c("2026-12-05 09:00", "2026-12-05 21:00", "2026-12-05 14:00", "2026-12-04 23:00")
  expect_equal(order_events(ev)$id, c(4L, 1L, 3L, 2L))
  expect_equal(order_events(ev, night = TRUE)$id, c(4L, 2L, 1L, 3L))
  expect_equal(nrow(order_events(ev[0, ], night = TRUE)), 0L)
})
