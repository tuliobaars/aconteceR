test_that("event rows escape text and only link safe URLs", {
  ev <- make_events()[1:2, ]
  ev$title[1] <- "<script>alert(1)</script>"
  ev$url <- c("javascript:alert(1)", "https://example.org/x")

  html <- as.character(event_list(ev, focus_input = "events-focus", today = as.Date("2026-12-05")))
  expect_false(grepl("<script>", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", html, fixed = TRUE))
  expect_true(grepl("data-input=\"events-focus\"", html, fixed = TRUE))
  expect_true(grepl("class=\"ac-ev-show\"", html, fixed = TRUE))
  expect_false(grepl("javascript:", html, fixed = TRUE))
  expect_true(grepl("href=\"https://example.org/x\"", html, fixed = TRUE))

  plain <- as.character(event_list(ev, show_city = TRUE))
  expect_false(grepl("data-input", plain, fixed = TRUE))
  expect_true(grepl("Curitiba - PR", plain, fixed = TRUE))
})

test_that("event lists group by day, say when empty and cap long lists", {
  ev <- make_events()
  html <- as.character(event_list(ev, lang = "pt", today = as.Date("2026-12-05")))
  expect_match(html, "<h4 class=\"ac-day ac-day-today\">Hoje</h4>", fixed = TRUE)
  expect_match(html, ">Amanh\u00e3</h4>", fixed = TRUE)
  expect_match(html, ">Quinta-feira, 10 de dezembro</h4>", fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr("class=\"ac-day", html, fixed = TRUE))), 4L)

  expect_match(as.character(event_list(empty_events())), "Nothing here")
  many <- make_events()[rep(1:4, 30), ]
  many$id <- seq_len(nrow(many))
  html <- as.character(event_list(many, max_cards = 10L))
  expect_match(html, "Showing the first 10 of 120 events")
  expect_equal(lengths(regmatches(html, gregexpr("<article", html, fixed = TRUE))), 10L)
})

test_that("focus_request changes every time", {
  a <- focus_request("3")
  Sys.sleep(0.01)
  b <- focus_request("3")
  expect_equal(a$id, b$id)
  expect_false(identical(a, b))
  expect_null(focus_request(NULL))
})

test_that("rows show the category tile, price band and formatted price", {
  ev <- make_events()[1, ]
  html <- as.character(event_row(ev, lang = "pt"))
  expect_match(html, "class=\"ac-ev-tile ac-cat-music\"", fixed = TRUE)
  expect_match(html, "data-ac-icon=\"cat_music\"", fixed = TRUE)
  expect_match(html, "class=\"ac-price ac-band-p2\">R$ 40,00<", fixed = TRUE)
  expect_match(html, "S\u00e1b, 05 dez \u00b7 20:00", fixed = TRUE)
  odd <- ev
  odd$category <- "parties"
  expect_match(as.character(event_row(odd)), "ac-cat-other", fixed = TRUE)
})

test_that("at night, night rows come first and carry a moon", {
  ev <- make_events()[c(1, 1), ]
  ev$id <- 1:2
  ev$title <- c("Morning yoga", "Late jazz")
  ev$starts_at <- c("2026-12-05 09:00", "2026-12-05 21:00")
  day <- as.character(event_list(ev, lang = "en"))
  night <- as.character(event_list(ev, lang = "en", night = TRUE))
  expect_lt(regexpr("Morning yoga", day), regexpr("Late jazz", day))
  expect_lt(regexpr("Late jazz", night), regexpr("Morning yoga", night))
  expect_false(grepl("ac-ev-moon", day, fixed = TRUE))
  expect_equal(lengths(regmatches(night, gregexpr("ac-ev-moon", night, fixed = TRUE))), 1L)
})

test_that("chip sets render their values and selection", {
  html <- as.character(chipset("f", c(a = "A", b = "B"), selected = "b", mode = "single", default = "a"))
  expect_match(html, "data-mode=\"single\"", fixed = TRUE)
  expect_match(html, "data-default=\"a\"", fixed = TRUE)
  expect_match(html, "class=\"ac-chip is-on\" data-value=\"b\" aria-pressed=\"true\"", fixed = TRUE)
  cats <- as.character(category_chips("c", lang = "pt"))
  expect_match(cats, "ac-chip ac-chip-cat ac-chip-music", fixed = TRUE)
  expect_match(cats, "M\u00fasica", fixed = TRUE)
})

test_that("the when chips map to date ranges", {
  today <- as.Date("2026-12-02")
  expect_equal(when_range("today", today), c(today, today))
  expect_equal(when_range("weekend", today), as.Date(c("2026-12-05", "2026-12-06")))
  expect_equal(when_range("7d", today), c(today, today + 7L))
  expect_true(is.na(when_range("all", today)[[2]]))
  expect_true(is.na(when_range(NULL, today)[[2]]))
  expect_equal(when_range("custom", today, as.Date(c("2026-12-10", "2026-12-12"))),
               as.Date(c("2026-12-10", "2026-12-12")))
  expect_equal(range_label("2026-12-10", "2026-12-10", "pt"), "10 de dez")
  expect_equal(range_label("2026-12-01", "2026-12-31", "pt"), "Dezembro de 2026")
})

test_that("the events module filters by text, price, category and dates", {
  ev <- make_events()
  ev$starts_at <- paste(Sys.Date() + c(0L, 1L, 5L, 20L), "20:00")
  shiny::testServer(mod_events_server, args = list(events = shiny::reactive(ev)), {
    session$setInputs(q = "", when = "all")
    expect_equal(nrow(filtered()), 4L)

    session$setInputs(price = "free")
    expect_equal(filtered()$title, "Street market")

    session$setInputs(price = NULL, q = "workshop")
    expect_equal(filtered()$title, "Python workshop")

    session$setInputs(q = "", cat = c("music", "tech"))
    expect_equal(sort(filtered()$category), c("music", "tech"))

    session$setInputs(cat = NULL, when = "today")
    expect_equal(filtered()$id, 1L)
    session$setInputs(when = "7d")
    expect_equal(filtered()$id, 1:3)
    # The calendar gets the same events without the date filter.
    expect_equal(nrow(undated()), 4L)

    set_range(Sys.Date() + 20L, Sys.Date() + 20L)
    session$setInputs(when = "custom")
    expect_equal(filtered()$id, 4L)
  })
})

test_that("this weekend is Saturday and Sunday, or just today on a Sunday", {
  expect_equal(weekend_range(as.Date("2026-12-02")), as.Date(c("2026-12-05", "2026-12-06")))
  expect_equal(weekend_range(as.Date("2026-12-05")), as.Date(c("2026-12-05", "2026-12-06")))
  expect_equal(weekend_range(as.Date("2026-12-06")), as.Date(c("2026-12-06", "2026-12-06")))
})

test_that("Portuguese formats come from the dictionary, not the R locale", {
  expect_equal(tr("price_free", "pt"), "Gr\u00e1tis")
  expect_equal(tr("price_free", "en"), "Free")
  expect_equal(format_price("free", lang = "pt"), "Gr\u00e1tis")
  expect_equal(format_when("2026-12-05 20:00", lang = "pt"), "S\u00e1b, 05 dez \u00b7 20:00")
  expect_equal(format_when("2026-12-05 20:00", lang = "en"), "Sat, 05 Dec \u00b7 20:00")
  expect_equal(format_day_long("2026-12-05", lang = "pt"), "S\u00e1bado, 5 de dezembro")
  expect_equal(format_day_long("2026-12-05", lang = "en"), "Saturday, 5 December")
  expect_equal(format_day_long("nope", lang = "en"), "")
})

test_that("native date inputs carry their value and translatable label", {
  html <- as.character(native_input("add-date", "date", value = as.Date("2026-12-05"),
                                    aria_key = "form_date", lang = "pt"))
  expect_match(html, "type=\"date\"", fixed = TRUE)
  expect_match(html, "value=\"2026-12-05\"", fixed = TRUE)
  expect_match(html, "class=\"ac-native-input", fixed = TRUE)
  expect_match(html, "aria-label=\"Data\"", fixed = TRUE)
  expect_match(html, "data-i18n-aria=\"form_date\"", fixed = TRUE)
  expect_equal(parse_input_date("2026-12-05"), as.Date("2026-12-05"))
  expect_null(parse_input_date(""))
  expect_null(parse_input_date(NULL))
  expect_null(parse_input_date("31/12/2026"))
})

test_that("the page renders in the requested language, without Bootstrap", {
  page <- app_page(load_cities(), lang = "pt")
  html <- as.character(htmltools::renderTags(page)$html)
  expect_match(html, "data-server-lang=\"pt\"", fixed = TRUE)
  expect_match(html, "id=\"ac-i18n-dict\"", fixed = TRUE)
  expect_match(html, "data-ac-pointmap=", fixed = TRUE)
  expect_match(html, "class=\"ac-seg ac-view-switch\"", fixed = TRUE)
  expect_match(html, "data-color-from=\"map-pm\"", fixed = TRUE)
  expect_match(html, "id=\"events-when\"", fixed = TRUE)
  expect_match(html, "data-pane=\"add\" hidden", fixed = TRUE)
  expect_match(html, "O que voc\u00ea quer fazer?", fixed = TRUE)
  deps <- vapply(htmltools::findDependencies(page), function(d) d$name, "")
  expect_true("aconteceR-assets" %in% deps)
  expect_false(any(grepl("bootstrap", deps, ignore.case = TRUE)))
  en <- as.character(htmltools::renderTags(app_page(load_cities(), lang = "en"))$html)
  expect_match(en, "What do you feel like doing?", fixed = TRUE)

  ui <- app_ui(load_cities(), default_lang = "pt")
  expect_true(is.function(ui))
  req <- list(QUERY_STRING = "?lang=en", HTTP_ACCEPT_LANGUAGE = "pt-BR")
  expect_match(as.character(htmltools::renderTags(ui(req))$html), "data-server-lang=\"en\"", fixed = TRUE)
})
