# A small places file in the OpenStreetMap schema (fixtures/places_small.csv),
# so behaviour tests do not depend on what the bundled file contains.
small_places <- function() load_places(test_path("fixtures", "places_small.csv"))

test_that("the bundled places load with vibes for every place", {
  p <- load_places()
  expect_true(all(PLACE_COLUMNS %in% names(p)))
  expect_gt(nrow(p), 0L)
  expect_true(all(p$category %in% place_category_keys()))
  expect_true(all(nzchar(p$vibe_groups)))
  expect_true(all(p$vibe_main %in% vibe_keys()))
  expect_true(all(p$city %in% load_cities()$label))
  # Demo rows are flagged; OpenStreetMap rows (fetch_osm_places()) are not.
  expect_equal(is_demo_place(p), !p$source %in% c("google_places_api", "openstreetmap"))
})

test_that("load_places explains a bad file", {
  expect_error(load_places("/no/such.csv"), "not found")
  bad <- tempfile(fileext = ".csv")
  writeLines(c("place_id,name", "x,y"), bad)
  expect_error(load_places(bad), "missing columns")
  unlink(bad)
})

test_that("vibes match at word starts, whole words with $, and category tokens", {
  rules <- data.frame(vibe = c("culture", "culture", "party", "outdoor"),
                      pattern = c("cultur", "arte$", "@nightclub", "ar-livre"))
  expect_equal(classify_vibes(c("Espa\u00e7o Cultural", "chope artesanal", "Arte urbana",
                                "x @nightclub", "Jardim ao ar livre", "Quarteto"), rules),
               c("culture", "", "culture", "party", "outdoor", ""))
  expect_equal(classify_vibes(character(), rules), character())
  expect_equal(classify_vibes("Roda de samba ao vivo @event_music"), "live_music")
  # Category tokens keep their underscore, so "@cafe_bistro" defaults apply.
  expect_equal(classify_vibes(c("Quarteto @cafe_bistro", "Quarteto @event_arts")), c("chill", "culture"))
})

test_that("day ranges wrap the week and accept lists", {
  d <- parse_open_days(c("Ter-Dom", "Qui-S\u00e1b", "Seg,Qua,Sex", "Todos", "??"))
  expect_equal(which(d[1, ]), c(1L, 3:7))
  expect_equal(which(d[2, ]), 5:7)
  expect_equal(which(d[3, ]), c(2L, 4L, 6L))
  expect_true(all(d[4, ]))
  expect_false(any(d[5, ]))
})

test_that("opening status matches the shared cases (also run by the browser test)", {
  cases <- utils::read.csv(test_path("fixtures", "hours_cases.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
  for (i in seq_len(nrow(cases))) {
    k <- cases[i, ]
    st <- place_open_status(k$opens_at, k$closes_at, k$open_days, k$wday, k$minutes,
                            opening_hours = k$opening_hours)
    expect_identical(st$open, k$open, info = k$note)
    expect_identical(st$to_close, if (is.na(k$to_close)) NA_integer_ else as.integer(k$to_close), info = k$note)
    expect_identical(st$days_ahead, if (is.na(k$days_ahead)) NA_integer_ else as.integer(k$days_ahead), info = k$note)
    expect_identical(place_status_text(st, k$wday, "pt"), k$text_pt, info = k$note)
  }
})

test_that("the visitor's clock comes from the browser when available", {
  expect_equal(client_clock(list(wday = 5, minutes = 1290)), list(wday = 5L, minutes = 1290L))
  ck <- client_clock(NULL)
  expect_true(ck$wday %in% 0:6)
})

test_that("places filter by category, vibe, text and opening, open ones first", {
  p <- small_places()
  tuesday_night <- list(wday = 2L, minutes = 21L * 60L)
  bars <- filter_places(p, categories = "bar")
  expect_true(all(bars$category == "bar"))
  rom <- filter_places(p, vibes = "romantic")
  expect_true(all(grepl("romantic", rom$vibe_groups)))
  open <- filter_places(p, open_now = TRUE, clock = tuesday_night)
  expect_true(all(places_status(open, tuesday_night)$open))
  expect_equal(open$place_id, paste0("osm-node-", c(1, 2, 4, 7, 8)))
  expect_equal(filter_places(p, query = "rooftop")$place_id, "osm-node-7")
  expect_equal(filter_places(p, query = "recife antigo")$place_id, "osm-node-1")
  expect_equal(nrow(filter_places(p, query = "zzzz")), 0L)
  ord <- order_places(p, clock = list(wday = 2L, minutes = 10L * 60L))
  st <- places_status(ord, list(wday = 2L, minutes = 600L))
  expect_false(is.unsorted(ifelse(st$open, 0L, ifelse(st$unknown, 1L, 2L))))
  expect_equal(ord$place_id[1:2], c("osm-node-8", "osm-node-5"))  # 24/7 first, then unknown hours
})

test_that("OpenStreetMap opening_hours parse into a week", {
  s <- parse_opening_hours(c("Mo-Fr 11:30-15:00,18:00-23:00; Sa 18:00-02:00; Su off", "24/7", "sunrise-sunset", NA))
  expect_equal(unname(s[[1]]$days[[2]][, "o"]), c(690, 1080))
  expect_equal(unname(s[[1]]$days[[7]][, "c"]), 26 * 60)
  expect_equal(nrow(s[[1]]$days[[1]]), 0L)
  expect_true(s[[2]]$always)
  expect_null(s[[3]])
  expect_null(s[[4]])
  # Legacy columns still work, and opening_hours wins when both are given.
  st <- place_open_status("18:00", "23:00", "Todos", 1L, 600L, opening_hours = c("Mo 09:00-12:00"))
  expect_true(st$open)
  st <- place_open_status("18:00", "23:00", "Todos", 1L, 600L)
  expect_false(st$open)
  expect_equal(st$to_open, 480L)
})

test_that("open late means still open at 02:00 tonight", {
  p <- data.frame(
    place_id = c("a", "b", "c", "d", "e"), name = c("A", "B", "C", "D", "E"),
    opening_hours = c("Mo-Su 18:00-03:00", "Mo-Su 18:00-01:00", "24/7", NA, "Fr-Sa 22:00-05:00"),
    opens_at = NA, closes_at = NA, open_days = NA, stringsAsFactors = FALSE
  )
  fri_night <- list(wday = 5L, minutes = 22L * 60L)
  sat_small_hours <- list(wday = 6L, minutes = 60L)  # still Friday night
  thu_night <- list(wday = 4L, minutes = 22L * 60L)
  expect_equal(place_closes_tonight(p, fri_night), c(27 * 60, 25 * 60, Inf, NA, 29 * 60))
  expect_equal(is_open_late(p, fri_night), c(TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_equal(is_open_late(p, sat_small_hours), c(TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_equal(is_open_late(p, thu_night), c(TRUE, FALSE, TRUE, FALSE, FALSE))
  p$category <- "bar"
  p$vibe_groups <- "party"
  expect_equal(filter_places(p, open_late = TRUE, clock = thu_night)$place_id, c("a", "c"))
})

test_that("review-weighted quality does not let a few reviews win", {
  expect_gt(place_quality(4.6, 3000), place_quality(4.9, 12))
  expect_equal(place_quality(c(5, 1), c(1e6, 1e6)), c(1, 0))
})

test_that("places have category, vibe and rating colour modes", {
  m <- place_color_modes("pt")
  expect_named(m, c("category", "vibe", "hours", "rating"))
  expect_named(place_color_modes("pt", rating = FALSE), c("category", "vibe", "hours"))
  p <- small_places()
  tue_10 <- list(wday = 2L, minutes = 600L)
  keys <- place_status_key(p, tue_10)
  expect_equal(keys, c("later", "later", "closed", "later", "unknown", "closed", "later", "open"))
  expect_equal(places_as_points(p, tue_10)$status_key, keys)
  expect_null(places_as_points(p)$status_key)
  expect_equal(color_mode_colors(m$hours, data.frame(status_key = c("open", "unknown")))[[1]], "#16a34a")
  expect_equal(m$hours$levels[[2]]$label, "Abre mais tarde")
  expect_equal(m$rating$type, "bins")
  expect_equal(m$rating$labels[[4]], "4,6 ou mais")
  d <- data.frame(rating = c(3.9, 4.0, 4.3, 4.9))
  expect_equal(color_mode_colors(m$rating, d), c("#cbd5e1", "#fcd34d", "#f59e0b", "#16a34a"))
})

test_that("place rows and popups escape text and show status, rating and link", {
  p <- small_places()[1, ]
  p$name <- "<b>Bar</b>"
  html <- as.character(place_list(p, clock = list(wday = 2L, minutes = 1200L), focus_input = "places-focus", lang = "pt"))
  expect_false(grepl("<b>Bar", html, fixed = TRUE))
  expect_match(html, "ac-place-open", fixed = TRUE)
  expect_match(html, "data-input=\"places-focus\"", fixed = TRUE)
  expect_match(html, "ac-ev-tile ac-pcat-bar", fixed = TRUE)
  expect_match(html, "https://www.google.com/maps/", fixed = TRUE)
  pop <- place_popup_html(p, "en", clock = list(wday = 1L, minutes = 1200L))
  expect_match(pop, "Opens tomorrow at", fixed = TRUE)
  expect_false(grepl("<b>Bar", pop, fixed = TRUE))
  expect_match(as.character(place_list(p[0, ])), "Nothing here")
  links <- place_popup_html(small_places()[1, ], "pt", clock = list(wday = 2L, minutes = 1200L))
  expect_match(links, "https://www.openstreetmap.org/node/1", fixed = TRUE)
  expect_match(links, "Ver no OpenStreetMap", fixed = TRUE)
  cafe <- small_places()[5, ]
  expect_match(place_popup_html(cafe, "pt", clock = list(wday = 2L, minutes = 600L)),
               "ac-place-unknown\">Hor\u00e1rio n\u00e3o informado", fixed = TRUE)
})

test_that("the places notes follow the data source (OpenStreetMap needs attribution)", {
  p <- small_places()
  expect_equal(places_sources(p), "osm")
  p$source[1] <- "generated"
  expect_equal(places_sources(p), c("demo", "osm"))
  expect_equal(places_sources(p[0, ]), character())
  html <- as.character(places_notes(c("demo", "osm"), "pt"))
  expect_match(html, "openstreetmap.org/copyright", fixed = TRUE)
  expect_match(html, "colaboradores do OpenStreetMap", fixed = TRUE)
  expect_match(html, "demonstra\u00e7\u00e3o", fixed = TRUE)
  expect_equal(as.character(places_notes(character(), "pt")), "")
  filters <- as.character(mod_places_filters_ui("places", "pt"))
  expect_match(filters, "data-value=\"late\"", fixed = TRUE)
  expect_match(filters, "title=\"Ainda aberto \u00e0s 02:00\" data-i18n-title=\"place_open_late_title\"", fixed = TRUE)
})

test_that("decide items carry places and events as one JSON array", {
  p <- small_places()[1:3, ]
  ev <- make_events()[1:2, ]
  items <- jsonlite::fromJSON(decide_items_json(p, ev, "pt"))
  expect_equal(nrow(items), 5L)
  expect_equal(items$kind, c(rep("place", 3), rep("event", 2)))
  expect_true(all(nzchar(items$vibes[1:3])))
  expect_equal(items$opening_hours[1:3], p$opening_hours)
  expect_true(is.na(items$rating[2]))
  expect_equal(jsonlite::fromJSON(decide_items_json(p[0, ], ev[0, ])), list())
  expect_equal(nrow(jsonlite::fromJSON(decide_items_json(NULL, ev))), 2L)
})

test_that("the places module filters with the visitor's clock and focuses a place", {
  p <- small_places()
  p <- p[p$city == "Recife - PE", ]
  shiny::testServer(mod_places_server, args = list(
    places = shiny::reactive(p), clock = shiny::reactive(list(wday = 2L, minutes = 1260L))
  ), {
    session$setInputs(open = NULL, cat = NULL, vibe = NULL)
    expect_equal(nrow(filtered()), nrow(p))
    session$setInputs(open = "open", cat = c("bar", "pub"))
    expect_equal(filtered()$place_id, c("osm-node-1", "osm-node-2"))
    session$setInputs(open = "late", cat = NULL)  # Pub closes at 02:00, the bar at 01:00
    expect_equal(filtered()$place_id, "osm-node-2")
    session$setInputs(focus = p$place_id[[1]])
    f <- session$returned$focus()
    expect_equal(f$point$id, p$place_id[[1]])
  })
})
