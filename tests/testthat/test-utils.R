test_that("normalize_text folds case and accents", {
  expect_equal(normalize_text("S\u00e3o Paulo"), "sao paulo")
  expect_equal(normalize_text(c("Florian\u00f3polis", NA)), c("florianopolis", ""))
})

test_that("the accent tables line up", {
  expect_equal(nchar(.accents_from), nchar(.accents_to))
})

test_that("%||% falls back on NULL, empty and NA", {
  expect_equal(NULL %||% 1, 1)
  expect_equal(character() %||% "a", "a")
  expect_equal(NA %||% "a", "a")
  expect_equal("x" %||% "a", "x")
})

test_that("safe_url keeps only http(s) links", {
  expect_equal(safe_url("https://example.org/a?b=1"), "https://example.org/a?b=1")
  expect_equal(safe_url(" http://example.org "), "http://example.org")
  expect_true(is.na(safe_url("javascript:alert(1)")))
  expect_true(is.na(safe_url("//example.org")))
  expect_true(is.na(safe_url("https://exa mple.org")))
  expect_true(is.na(safe_url(NA)))
  expect_true(is.na(safe_url(NULL)))
})

test_that("escape_html escapes markup and quotes, and turns NA into empty text", {
  expect_equal(escape_html("<b>&\"x\""), "&lt;b&gt;&amp;&quot;x&quot;")
  expect_equal(escape_html(NA), "")
})

test_that("format_price covers every price type", {
  out <- format_price(
    c("free", "paid", "paid", "donation", "unknown", NA),
    c(NA, 40, NA, NA, NA, NA)
  )
  expect_equal(out, c("Free", "R$ 40.00", "Paid", "Donation", "Price unknown", "Price unknown"))
  expect_equal(format_price(character()), character())
  expect_equal(format_price("paid", 1250.5, lang = "pt"), "R$ 1.250,50")
  expect_equal(format_price("paid", 10, "USD", lang = "pt"), "US$ 10,00")
  expect_equal(format_price("paid", 10, "CLP"), "CLP 10.00")
})

test_that("numbers use the language's marks", {
  expect_equal(format_number(c(1234567.891, -5, NA), 2L, "pt"), c("1.234.567,89", "-5,00", ""))
  expect_equal(format_number(c(1234567.891, 999), 0L, "en"), c("1,234,568", "999"))
  expect_equal(format_money(30, "BRL", 0L, "pt"), "R$ 30")
})

test_that("format_when formats stored times and flags bad ones", {
  expect_equal(format_when("2026-12-05 20:00"), "Sat, 05 Dec \u00b7 20:00")
  expect_equal(format_when(c("nope", NA)), rep("Date to be confirmed", 2))
  expect_equal(format_when(c("nope", "2026-12-06 09:30"), lang = "pt"),
               c("Data a confirmar", "Dom, 06 dez \u00b7 09:30"))
  expect_equal(format_when(character()), character())
})
