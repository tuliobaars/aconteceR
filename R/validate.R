# Event validation. Pure functions: no Shiny, no database. The add-event form
# and the sample-data loader both go through validate_event() so that the same
# rules apply everywhere.

EVENT_LIMITS <- list(title = 120L, venue = 120L, description = 2000L)

# Accepts "YYYY-MM-DD HH:MM" (or with a "T"), returns it normalised, or NA when
# it is not a real date and time (for example 2026-02-31).
parse_starts_at <- function(x) {
  x <- trimws(as.character(x %||% NA_character_))
  x <- sub("T", " ", x, fixed = TRUE)
  shaped <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", x)
  parsed <- as.POSIXct(strptime(ifelse(shaped, x, NA_character_), "%Y-%m-%d %H:%M", tz = "UTC"))
  out <- rep(NA_character_, length(x))
  out[!is.na(parsed)] <- x[!is.na(parsed)]
  out
}

# `ev` is a list with title, description, city, venue, lat, lon, starts_at,
# category, price_type, price, currency, url, source, external_id (any may be
# missing). Returns list(ok, errors, event) where `event` is the cleaned list.
# `errors` are in `lang` ("en" or "pt"); the browser twin is validate() in
# inst/standalone/ac-standalone.js.
validate_event <- function(ev, lang = "en") {
  errors <- character()
  add_error <- function(msg) errors <<- c(errors, msg)

  text1 <- function(x) {
    x <- trimws(as.character(x %||% ""))
    if (length(x) != 1L) "" else x
  }
  num1 <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) != 1L) NA_real_ else x
  }
  na_if_empty <- function(x) if (nzchar(x)) x else NA_character_

  title <- text1(ev$title)
  if (!nzchar(title)) {
    add_error(tr("err_title_required", lang))
  } else if (nchar(title) > EVENT_LIMITS$title) {
    add_error(tf("err_title_long", lang, EVENT_LIMITS$title))
  }

  city <- text1(ev$city)
  if (!nzchar(city)) add_error(tr("err_city", lang))

  lat <- num1(ev$lat)
  lon <- num1(ev$lon)
  if (is.na(lat) || is.na(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    add_error(tr("err_location", lang))
  }

  starts_at <- parse_starts_at(text1(ev$starts_at))
  if (is.na(starts_at)) add_error(tr("err_datetime", lang))

  category <- text1(ev$category)
  if (!is_category(category)) add_error(tr("err_category", lang))

  price_type <- text1(ev$price_type)
  if (!is_price_type(price_type)) add_error(tr("err_price_type", lang))

  price <- num1(ev$price)
  if (identical(price_type, "paid")) {
    if (is.na(price) || price < 0) add_error(tr("err_price_amount", lang))
  } else {
    price <- NA_real_
  }

  currency <- toupper(text1(ev$currency))
  if (!nzchar(currency)) currency <- "BRL"
  if (!grepl("^[A-Z]{3}$", currency)) add_error(tr("err_currency", lang))

  url_raw <- text1(ev$url)
  url <- NA_character_
  if (nzchar(url_raw)) {
    url <- safe_url(url_raw)
    if (is.na(url)) add_error(tr("err_url", lang))
  }

  venue <- text1(ev$venue)
  if (nchar(venue) > EVENT_LIMITS$venue) {
    add_error(tf("err_venue_long", lang, EVENT_LIMITS$venue))
  }
  description <- text1(ev$description)
  if (nchar(description) > EVENT_LIMITS$description) {
    add_error(tf("err_desc_long", lang, EVENT_LIMITS$description))
  }

  source <- text1(ev$source)
  if (!nzchar(source)) source <- "user"

  list(
    ok = length(errors) == 0L,
    errors = errors,
    event = list(
      title = title,
      description = na_if_empty(description),
      city = city,
      venue = na_if_empty(venue),
      lat = lat,
      lon = lon,
      starts_at = starts_at,
      category = category,
      price_type = price_type,
      price = price,
      currency = currency,
      url = url,
      source = source,
      external_id = na_if_empty(text1(ev$external_id))
    )
  )
}
