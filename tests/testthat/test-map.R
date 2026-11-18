test_that("factor colour modes keep keys, colours and labels together", {
  m <- map_color_factor("kind", colors = c(a = "#111111", b = "#222222"),
                        labels = c(b = "Bee", a = "Ay"), label = "Kind")
  expect_s3_class(m, "ac_color_mode")
  expect_equal(m$type, "factor")
  expect_equal(vapply(m$levels, `[[`, "", "key"), c("a", "b"))
  expect_equal(vapply(m$levels, `[[`, "", "label"), c("Ay", "Bee"))
  expect_equal(m$title, "Kind")
  expect_error(map_color_factor("kind", colors = c("#111111")), "names")
})

test_that("bin colour modes are right-closed and handle infinite breaks", {
  m <- map_color_bins("price", breaks = c(0, 10, 20, Inf), colors = c("#a", "#b", "#c"))
  expect_equal(m$labels, c("0 \u2013 10", "10 \u2013 20", "> 20"))
  expect_true(all(is.finite(m$breaks)))
  d <- data.frame(price = c(0, 10, 10.5, 20, 1e6, NA, -1))
  expect_equal(color_mode_colors(m, d), c("#a", "#a", "#b", "#b", "#c", "#8c8c8c", "#8c8c8c"))
  expect_error(map_color_bins("price", breaks = c(0, 10), colors = c("#a", "#b")), "one colour per bin")
})

test_that("factor colours resolve with a fallback for unknown values", {
  m <- event_color_modes("en")$category
  d <- data.frame(category = c("music", "nope", NA))
  expect_equal(color_mode_colors(m, d), c(category_palette()[["music"]], "#8c8c8c", "#8c8c8c"))
})

test_that("colour modes and points serialise for the browser", {
  payload <- color_modes_payload(event_color_modes("pt"))
  expect_equal(vapply(payload, `[[`, "", "id"), c("price", "category"))
  json <- jsonlite::fromJSON(to_json(payload), simplifyVector = FALSE)
  expect_equal(json[[1]]$column, "price_band")
  expect_equal(json[[1]]$label, "Pre\u00e7o")
  expect_error(color_modes_payload(list(event_color_modes()$price)), "named list")

  ev <- with_price_band(make_events())
  ev$title[1] <- "<b>x</b>"
  pts <- jsonlite::fromJSON(map_points_json(ev, c("price_band", "category"),
                                            popup = event_popup_html(ev), label = ev$title))
  expect_equal(nrow(pts), 4L)
  expect_equal(pts$id, as.character(1:4))
  expect_equal(pts$price_band, c("p2", "free", "p3", "donation"))
  expect_equal(pts$label[1], "<b>x</b>") # plain text; the browser escapes labels
  expect_false(grepl("<b>x", pts$popup[1], fixed = TRUE))
  expect_equal(map_points_json(ev[0, ], "category"), "[]")
  # Extra columns (e.g. for the group view) travel with the points.
  ev$neighborhood <- c("Centro", "Centro", NA, "Batel")
  pts <- jsonlite::fromJSON(map_points_json(ev, c("category", "neighborhood")))
  expect_equal(pts$neighborhood, c("Centro", "Centro", NA, "Batel"))
})

test_that("the map UI embeds its places and options", {
  cities <- load_cities()
  ui <- mod_map_ui("map", cities, cluster = TRUE, toolbar_end = htmltools::span("extra"),
                   overlays = list(calendar = htmltools::div("cal")))
  html <- as.character(ui)
  expect_match(html, "id=\"map-pm\"", fixed = TRUE)
  expect_match(html, "data-view-name=\"calendar\"", fixed = TRUE)
  cfg <- jsonlite::fromJSON(htmltools::tagGetAttribute(ui, "data-ac-pointmap"))
  expect_equal(nrow(cfg$places), nrow(cities))
  expect_equal(cfg$place, as.character(default_city(cities)))
  expect_true(cfg$cluster)
  expect_true(cfg$autoLocate)
  expect_false(jsonlite::fromJSON(htmltools::tagGetAttribute(
    mod_map_ui("map", cities, selected = 3), "data-ac-pointmap"))$autoLocate)
  expect_null(cfg$groupBy)
  grouped <- mod_map_ui("map", cities, group_by = "neighborhood")
  expect_equal(jsonlite::fromJSON(htmltools::tagGetAttribute(grouped, "data-ac-pointmap"))$groupBy, "neighborhood")
})

test_that("route stops serialise with numbers, labels and popups", {
  stops <- data.frame(lat = c(-8.06, -8.07), lon = c(-34.87, -34.88), label = c("1. Bar", "2. <Club>"))
  json <- jsonlite::fromJSON(route_stops_json(stops))
  expect_equal(json$n, 1:2)
  expect_equal(json$label, c("1. Bar", "2. <Club>"))  # plain text; the browser escapes it
  expect_equal(route_stops_json(stops[0, ]), "[]")
  expect_equal(route_stops_json(NULL), "[]")
})

test_that("the map module follows the browser's place and focuses points", {
  cities <- load_cities()
  ev <- with_price_band(make_events())
  shiny::testServer(mod_map_server, args = list(
    cities = cities, points = shiny::reactive(ev), color_modes = event_color_modes,
    popup_fun = event_popup_html, label_fun = function(p) p$title
  ), {
    expect_equal(city()$id, default_city(cities))
    session$setInputs(pm_place = "3")
    expect_equal(city()$id, 3L)
    session$setInputs(pm_place = "999")
    expect_equal(city()$id, default_city(cities))
    expect_equal(session$returned$color_mode(), "price")
    session$setInputs(pm_click = list(lat = -25, lon = -49, nonce = 1))
    expect_equal(session$returned$clicked(), list(lat = -25, lon = -49))
  })
})
