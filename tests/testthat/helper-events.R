# Shared fixtures. Files named helper-*.R are loaded before the tests run.

# An input list that passes validate_event(); override fields with `...`.
good_event <- function(...) {
  ev <- list(
    title = "Jazz night", description = "Live music", city = "Curitiba - PR",
    venue = "Bar Azul", lat = -25.43, lon = -49.27,
    starts_at = "2026-12-05 20:00", category = "music", price_type = "free",
    price = NA, currency = "BRL", url = "", source = "user"
  )
  utils::modifyList(ev, list(...))
}

# The cleaned event list that db_insert_event() expects.
clean_event <- function(...) {
  res <- validate_event(good_event(...))
  stopifnot(res$ok)
  res$event
}

# A small events data frame in the shape the database returns.
make_events <- function() {
  data.frame(
    id = 1:4,
    title = c("Jazz night", "Street market", "Python workshop", "Beach clean-up"),
    description = c("Live music", "Food and crafts", NA, "Bring gloves"),
    city = "Curitiba - PR",
    venue = c("Bar Azul", NA, "Coworking", "Praia"),
    lat = -25.43, lon = -49.27,
    starts_at = c("2026-12-05 20:00", "2026-12-06 09:00", "2026-12-10 14:00", "2026-12-20 08:00"),
    category = c("music", "food", "tech", "community"),
    price_type = c("paid", "free", "paid", "donation"),
    price = c(40, NA, 80, NA),
    currency = "BRL", url = NA_character_, source = "user",
    external_id = NA_character_, created_at = "2026-11-17 10:00:00",
    stringsAsFactors = FALSE
  )
}
