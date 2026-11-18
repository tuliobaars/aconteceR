# What an event data frame looks like, and the pure functions that work on it
# (filtering, popups). The same shape comes from the database and from search
# providers, so everything downstream can treat them alike.

event_columns <- function() {
  c("id", "title", "description", "city", "venue", "lat", "lon", "starts_at",
    "category", "price_type", "price", "currency", "url", "source",
    "external_id", "created_at")
}

empty_events <- function() {
  data.frame(
    id = integer(), title = character(), description = character(),
    city = character(), venue = character(), lat = numeric(), lon = numeric(),
    starts_at = character(), category = character(), price_type = character(),
    price = numeric(), currency = character(), url = character(),
    source = character(), external_id = character(), created_at = character(),
    stringsAsFactors = FALSE
  )
}

# TRUE for events whose title, description, venue or city contain every word of
# `query` (ignoring case and accents). An empty query matches everything.
matches_query <- function(ev, query) {
  if (nrow(ev) == 0L) return(logical())
  q <- normalize_text(query %||% "")
  if (!nzchar(trimws(q))) return(rep(TRUE, nrow(ev)))
  hay <- normalize_text(paste(chr0(ev$title), chr0(ev$description), chr0(ev$venue), chr0(ev$city)))
  terms <- strsplit(trimws(q), "[[:space:]]+")[[1]]
  keep <- rep(TRUE, nrow(ev))
  for (term in terms) keep <- keep & grepl(term, hay, fixed = TRUE)
  keep
}

# Filter an events data frame.
#   price_types: NULL = any; character() = none; otherwise keys to keep.
#   categories:  NULL or empty = any; otherwise keys to keep.
#   from, to:    Dates (inclusive) or NULL.
filter_events <- function(ev, query = "", price_types = NULL, categories = NULL,
                          from = NULL, to = NULL) {
  if (nrow(ev) == 0L) return(ev)
  keep <- matches_query(ev, query)
  if (!is.null(price_types)) keep <- keep & ev$price_type %in% price_types
  if (length(categories)) keep <- keep & ev$category %in% categories
  day <- as.Date(substr(ev$starts_at, 1, 10), format = "%Y-%m-%d")
  if (!is.null(from) && !is.na(from)) keep <- keep & !is.na(day) & day >= as.Date(from)
  if (!is.null(to) && !is.na(to)) keep <- keep & !is.na(day) & day <= as.Date(to)
  ev[keep, , drop = FALSE]
}

# HTML for map popups, one string per row. Every user-supplied value goes
# through escape_html(); the link is only added when it is a safe http(s) URL.
# Same markup as popupHtml() in inst/standalone/ac-standalone.js.
event_popup_html <- function(ev, lang = "en") {
  if (nrow(ev) == 0L) return(character())
  link <- safe_url(ev$url)
  venue <- escape_html(ev$venue)
  html <- paste0(
    "<span class=\"ac-pop-title\">", escape_html(ev$title), "</span>",
    "<span class=\"ac-pop-when\">", escape_html(format_when(ev$starts_at, lang = lang)), "</span>",
    "<span class=\"ac-pop-meta\"><span class=\"ac-price ac-band-", price_band(ev$price_type, ev$price), "\">",
    escape_html(format_price(ev$price_type, ev$price, ev$currency, lang = lang)), "</span>",
    "<span class=\"ac-tag\">", escape_html(category_label(ev$category, lang = lang)), "</span></span>"
  )
  html <- ifelse(nzchar(venue), paste0(html, "<span class=\"ac-pop-venue\">", venue, "</span>"), html)
  html <- ifelse(
    !is.na(link),
    paste0(html, "<br><a href=\"", escape_html(link),
           "\" target=\"_blank\" rel=\"noopener noreferrer\">",
           escape_html(tr("event_page", lang)), "</a>"),
    html
  )
  paste0(html, around_button_html(ev, lang))
}

# "Before & after" button for event popups: opens places near the event that
# are open before it starts and after it ends (AC.Decide.showAround, in
# inst/www/ac-decide.js, reads these data attributes). Empty when the event
# has no position or start. Mirrors aroundButton() in ac-standalone.js.
around_button_html <- function(ev, lang = "en") {
  lat <- suppressWarnings(as.numeric(ev$lat))
  lon <- suppressWarnings(as.numeric(ev$lon))
  ok <- is.finite(lat) & is.finite(lon) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}", chr0(ev$starts_at))
  btn <- paste0(
    "<div class=\"ac-pop-actions\"><button type=\"button\" class=\"ac-linkbtn ac-around-btn\" data-ac-around=\"",
    escape_html(ev$id), "\" data-title=\"", escape_html(ev$title), "\" data-lat=\"", format(lat, digits = 10),
    "\" data-lon=\"", format(lon, digits = 10), "\" data-start=\"", escape_html(ev$starts_at), "\">",
    "<span data-ac-icon=\"route\"></span><span>", escape_html(tr("around_link", lang)), "</span></button></div>"
  )
  ifelse(ok, btn, "")
}

# Night activity: starts at 18:00 or later, or before 05:00.
is_night_activity <- function(starts_at) {
  h <- suppressWarnings(as.integer(substr(chr0(starts_at), 12L, 13L)))
  !is.na(h) & (h >= 18L | h < 5L)
}

# List order: by day, then by time. With `night = TRUE` (the app is dark: dusk
# or night) night activities lead each day. Mirrors orderForList() in
# inst/standalone/ac-standalone.js.
order_events <- function(ev, night = FALSE) {
  if (nrow(ev) < 2L) return(ev)
  starts <- chr0(ev$starts_at)
  later <- if (isTRUE(night)) !is_night_activity(starts) else rep(FALSE, nrow(ev))
  out <- ev[order(substr(starts, 1L, 10L), later, starts, ev$id), , drop = FALSE]
  rownames(out) <- NULL
  out
}
