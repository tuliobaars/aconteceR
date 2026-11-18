# "Can't decide?": a few questions, then places and events ranked by what is
# open (or starting) when you want to go, vibe, rating and budget. The quiz
# and the ranking run in the browser (AC.Decide in inst/www/ac-decide.js,
# AC.places.rank in ac-places.js) because "open now" depends on the visitor's
# clock; this module sends the current city's places and upcoming events.
# Picking a suggestion flies the map to it (handled in the browser). The same
# items feed "Plan my night" (a results tab) and "Before & after" (opened from
# event popups, see around_button_html()).

mod_decide_ui <- function(id) {
  ns <- shiny::NS(id)
  htmltools::div(id = ns("dec"), class = "ac-decide-host", `data-ac-decide` = "1")
}

# Items for the quiz: places and events with their vibes, popups and the
# fields the ranking reads.
decide_items_json <- function(places, events, lang = "en", rules = vibe_rules(), clock = client_clock()) {
  items <- list()
  if (!is.null(places) && nrow(places) > 0L) {
    items[[1]] <- data.frame(
      kind = "place", id = places$place_id, name = places$name, category = places$category,
      vibes = places$vibe_groups, lat = places$lat, lon = places$lon, label = places$name,
      popup = place_popup_html(places, lang, clock), neighborhood = places$neighborhood,
      opening_hours = places$opening_hours,
      opens_at = places$opens_at, closes_at = places$closes_at, open_days = places$open_days,
      rating = places$rating, reviews_count = places$reviews_count,
      price_level = places$price_level, maps_url = places$maps_url,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(events) && nrow(events) > 0L) {
    items[[length(items) + 1L]] <- data.frame(
      kind = "event", id = as.character(events$id), title = events$title, category = events$category,
      vibes = classify_vibes(paste(events$title, chr0(events$description), paste0("@event_", events$category)), rules),
      lat = events$lat, lon = events$lon, label = events$title, popup = event_popup_html(events, lang),
      starts_at = events$starts_at, price_type = events$price_type, price = events$price,
      currency = events$currency, venue = events$venue,
      stringsAsFactors = FALSE
    )
  }
  if (!length(items)) return("[]")
  parts <- vapply(items, function(d) as.character(jsonlite::toJSON(d, dataframe = "rows", na = "null", digits = NA)), "")
  # Two JSON arrays -> one.
  paste0("[", paste(substr(parts, 2L, nchar(parts) - 1L)[nzchar(substr(parts, 2L, nchar(parts) - 1L))], collapse = ","), "]")
}

mod_decide_server <- function(id, places, events, lang = shiny::reactive("en"),
                              clock = shiny::reactive(client_clock())) {
  shiny::moduleServer(id, function(input, output, session) {
    rules <- vibe_rules()
    shiny::observe({
      session$sendCustomMessage("ac-decide", list(
        id = session$ns("dec"), action = "items",
        items = decide_items_json(places(), events(), lang(), rules, shiny::isolate(clock()))
      ))
    })
  })
}
