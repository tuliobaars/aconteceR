test_that("calendar items carry what the day agenda shows", {
  ev <- with_price_band(make_events())
  items <- jsonlite::fromJSON(calendar_items_json(ev, lang = "pt"))
  expect_equal(items$id, as.character(ev$id))
  expect_equal(items$starts_at, ev$starts_at)
  expect_equal(items$meta[1], "R$ 40,00 \u00b7 M\u00fasica \u00b7 Bar Azul")
  expect_equal(items$meta[2], "Gr\u00e1tis \u00b7 Gastronomia")
  expect_equal(items$price_band, ev$price_band)
  expect_equal(calendar_items_json(ev[0, ]), "[]")
})

test_that("the calendar module reports clicks, days and months", {
  ev <- with_price_band(make_events())
  shiny::testServer(mod_calendar_server, args = list(events = shiny::reactive(ev)), {
    session$setInputs(cal_item = list(id = "3", nonce = 1))
    f <- session$returned$focus()
    expect_equal(f$id, "3")
    expect_equal(f$point$title, "Python workshop")

    session$setInputs(cal_show_day = list(date = "2026-12-10", nonce = 2))
    expect_equal(session$returned$show_day(), "2026-12-10")
    session$setInputs(cal_show_month = list(month = "2026-12", nonce = 3))
    expect_equal(session$returned$show_month(), "2026-12")
  })
})
