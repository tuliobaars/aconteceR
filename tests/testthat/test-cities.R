test_that("the bundled city list loads and is well formed", {
  cities <- load_cities()
  expect_named(cities, c("id", "label", "city", "state", "country", "lat", "lon"))
  expect_equal(anyDuplicated(cities$id), 0L)
  expect_equal(anyDuplicated(cities$label), 0L)
  expect_true(all(cities$lat >= -34 & cities$lat <= 6))
  expect_true(all(cities$lon >= -75 & cities$lon <= -32))
  expect_true("Florian\u00f3polis - SC" %in% cities$label)
})

test_that("city helpers", {
  cities <- load_cities()
  choices <- city_choices(cities)
  expect_equal(names(choices), cities$label)
  expect_equal(unname(choices), as.character(cities$id))
  expect_equal(nrow(find_city(cities, "999")), 0L)
  expect_equal(find_city(cities, default_city(cities))$label, "S\u00e3o Paulo - SP")
})

test_that("load_cities explains what is wrong with a bad file", {
  expect_error(load_cities("/no/such/file.csv"), "not found")
  bad <- tempfile(fileext = ".csv")
  writeLines(c("city,state,country,lat", "A,B,C,1"), bad)
  expect_error(load_cities(bad), "missing columns")
  unlink(bad)
})
