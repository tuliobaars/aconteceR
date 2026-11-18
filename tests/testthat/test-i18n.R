test_that("both languages have the same keys, placeholders and list lengths", {
  d <- i18n_dict()
  expect_setequal(names(d$en), names(d$pt))
  placeholders <- function(x) regmatches(x, gregexpr("%(\\.[0-9]+)?[sdf]", x))[[1]]
  for (key in names(d$en)) {
    en <- d$en[[key]]
    pt <- d$pt[[key]]
    expect_identical(class(en), class(pt), info = key)
    expect_identical(length(en), length(pt), info = key)
    if (is.character(en) && length(en) == 1L) {
      expect_identical(placeholders(en), placeholders(pt), info = key)
    }
  }
})

test_that("tr falls back to English and then to the key", {
  expect_equal(tr("tab_add", "pt"), "Novo evento")
  expect_equal(tr("tab_add", "pt-BR"), "Novo evento")
  expect_equal(tr("tab_add", "fr"), "Add event")
  expect_equal(tr("no_such_key", "pt"), "no_such_key")
  expect_length(tr("mon_long", "pt"), 12L)
  expect_equal(tr_count("count_events", 1L, "pt"), "1 evento")
  expect_equal(tr_count("count_events", 3L, "pt"), "3 eventos")
})

test_that("language codes are recognised", {
  expect_equal(lang_code("pt-BR"), "pt")
  expect_equal(lang_code("PT_br"), "pt")
  expect_equal(lang_code("en-GB"), "en")
  expect_true(is.na(lang_code("es")))
  expect_true(is.na(lang_code(NULL)))
  expect_true(is.na(lang_code(NA)))
  expect_equal(normalize_lang("es"), "en")
})

test_that("Accept-Language: any Portuguese or Brazil signal means PT-BR", {
  expect_equal(detect_lang("pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"), "pt")
  expect_equal(detect_lang("en-US,en;q=0.9,pt-BR;q=0.8"), "pt")
  expect_equal(detect_lang("en-BR,en;q=0.9"), "pt")
  expect_equal(detect_lang("en-US,en;q=0.9"), "en")
  expect_equal(detect_lang("fr-FR,en;q=0.2"), "en")
  expect_equal(detect_lang("pt;q=0,en;q=0.1"), "en")
  expect_equal(detect_lang("fr-FR", default = "pt"), "pt")
  expect_equal(detect_lang(NULL, default = "pt"), "pt")
  expect_equal(detect_lang("", default = "en"), "en")
})

test_that("?lang= beats the browser header", {
  expect_equal(request_lang(list(QUERY_STRING = "?lang=en", HTTP_ACCEPT_LANGUAGE = "pt-BR")), "en")
  expect_equal(request_lang(list(QUERY_STRING = "", HTTP_ACCEPT_LANGUAGE = "pt-BR,pt")), "pt")
  expect_equal(request_lang(list(QUERY_STRING = "?lang=xx", HTTP_ACCEPT_LANGUAGE = "en")), "en")
  expect_equal(request_lang(list(), default = "pt"), "pt")
})

test_that("the embedded dictionary is valid JSON and safe inside a <script>", {
  txt <- i18n_json()
  expect_silent(jsonlite::fromJSON(txt))
  expect_false(grepl("</script", txt, ignore.case = TRUE))
})

test_that("validation messages follow the language", {
  res <- validate_event(list(), lang = "pt")
  expect_true("Informe um t\u00edtulo." %in% res$errors)
  expect_true(any(grepl("^Add a title", validate_event(list())$errors)))
})
