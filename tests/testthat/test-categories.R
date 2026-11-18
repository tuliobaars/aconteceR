test_that("price bands split paid events by ticket price", {
  expect_equal(
    price_band(c("free", "donation", "paid", "paid", "paid", "paid", "paid", "paid", "unknown", NA),
               c(NA, NA, 0, 30, 30.01, 60, 100.5, NA, 10, NA)),
    c("free", "donation", "p1", "p1", "p2", "p2", "p4", "paid_na", "unknown", "unknown")
  )
  expect_equal(price_band(character()), character())
  expect_setequal(names(price_band_palette()), names(price_band_labels()))
})

test_that("band labels are money in the right language", {
  expect_equal(unname(price_band_labels("pt")[c("p1", "p2", "p4")]),
               c("At\u00e9 R$ 30", "R$ 30 \u2013 R$ 60", "Acima de R$ 100"))
  expect_equal(unname(price_band_labels("en")["p1"]), "Up to R$ 30")
})

test_that("the events map offers price and category colour modes", {
  m <- event_color_modes("pt")
  expect_named(m, c("price", "category"))
  expect_equal(m$price$column, "price_band")
  expect_equal(m$category$label, "Categoria")
  expect_equal(length(m$category$levels), length(event_categories()))
  ev <- with_price_band(make_events())
  expect_equal(ev$price_band, c("p2", "free", "p3", "donation"))
})
