test_that("a complete event passes and comes back cleaned", {
  res <- validate_event(good_event(title = "  Jazz night  ", url = "https://example.org/jazz"))
  expect_true(res$ok)
  expect_length(res$errors, 0L)
  expect_equal(res$event$title, "Jazz night")
  expect_equal(res$event$url, "https://example.org/jazz")
  expect_true(is.na(res$event$external_id))
  expect_equal(res$event$source, "user")
})

test_that("empty optional text becomes NA", {
  res <- validate_event(good_event(venue = "", description = ""))
  expect_true(res$ok)
  expect_true(is.na(res$event$venue))
  expect_true(is.na(res$event$description))
})

test_that("title rules", {
  expect_false(validate_event(good_event(title = "  "))$ok)
  expect_false(validate_event(good_event(title = strrep("a", 121)))$ok)
  expect_true(validate_event(good_event(title = strrep("a", 120)))$ok)
})

test_that("location must be a real coordinate", {
  expect_false(validate_event(good_event(lat = 120))$ok)
  expect_false(validate_event(good_event(lon = -181))$ok)
  expect_false(validate_event(good_event(lat = NA))$ok)
  expect_true(validate_event(good_event(lat = 0, lon = 0))$ok)
})

test_that("dates must exist and are normalised", {
  expect_false(validate_event(good_event(starts_at = "2026-02-31 10:00"))$ok)
  expect_false(validate_event(good_event(starts_at = "2026-12-05 25:00"))$ok)
  expect_false(validate_event(good_event(starts_at = "5 Dec 2026"))$ok)
  expect_equal(validate_event(good_event(starts_at = "2026-12-05T20:00"))$event$starts_at,
               "2026-12-05 20:00")
})

test_that("paid events need a price; other types ignore it", {
  expect_false(validate_event(good_event(price_type = "paid", price = NA))$ok)
  expect_false(validate_event(good_event(price_type = "paid", price = -5))$ok)
  paid <- validate_event(good_event(price_type = "paid", price = 40))
  expect_true(paid$ok)
  expect_equal(paid$event$price, 40)
  free <- validate_event(good_event(price_type = "free", price = 99))
  expect_true(free$ok)
  expect_true(is.na(free$event$price))
})

test_that("links must be http(s)", {
  expect_false(validate_event(good_event(url = "javascript:alert(1)"))$ok)
  expect_false(validate_event(good_event(url = "example.org"))$ok)
  expect_true(validate_event(good_event(url = "https://example.org"))$ok)
})

test_that("unknown category and price type are rejected", {
  expect_false(validate_event(good_event(category = "parties"))$ok)
  expect_false(validate_event(good_event(price_type = "cheap"))$ok)
})

test_that("an empty event reports every missing piece", {
  res <- validate_event(list())
  expect_false(res$ok)
  expect_gte(length(res$errors), 5L)
})
