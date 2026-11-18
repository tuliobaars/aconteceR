# Search and autopopulate providers. A provider is a list with:
#   name, label  - identifiers for people and logs
#   url          - reference site URL
#   enabled      - FALSE providers are skipped and their `note` is shown
#   search       - function(query, city, from, to) returning an events data frame
#                  (see event_columns()); zero rows is fine
#   note         - optional text explaining why a provider is off
#   note_key     - optional dictionary key for `note`, so search_events() can
#                  show it in the user's language (see inst/i18n/strings.json)

provider_local <- function(con) {
  list(
    name = "local",
    label = "Saved events (SQLite)",
    url = NA_character_,
    enabled = TRUE,
    search = function(query = "", city = NULL, from = NULL, to = NULL) {
      ev <- db_fetch_events(con, city = city, from = from, to = to)
      ev[matches_query(ev, query), , drop = FALSE]
    }
  )
}

provider_online_stub <- function() {
  list(
    name = "online",
    label = "Online listings",
    url = NA_character_,
    enabled = FALSE,
    note_key = "note_online_stub",
    note = tr("note_online_stub", "en"),
    search = function(...) empty_events()
  )
}

providers_default <- function(con) {
  list(provider_local(con), provider_online_stub())
}

# Demo event sites for Search & import. The list and the event templates are
# plain data shared with the standalone HTML: inst/extdata/sites.csv and
# inst/extdata/site_templates.csv. Nothing is fetched from these sites; see
# R/ingest.R for the parsing side of real scraping.
external_site_catalog <- function(path = system.file("extdata", "sites.csv", package = "aconteceR")) {
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

site_templates <- function(path = system.file("extdata", "site_templates.csv", package = "aconteceR")) {
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Build a deterministic set of "discovered" events from a site's templates for
# the given cities (one per template and city), dated relative to `today`, so
# offline Search & import works immediately and idempotently. Mirrors
# discover() in inst/standalone/ac-standalone.js.
generate_site_events <- function(site_name, cities_df = load_cities(), today = Sys.Date(),
                                 templates = site_templates()) {
  tpl <- templates[templates$site == site_name, , drop = FALSE]
  if (nrow(tpl) == 0L || nrow(cities_df) == 0L) return(empty_events())

  cat_info <- external_site_catalog()
  dom <- cat_info$domain[cat_info$name == site_name]
  if (!length(dom)) dom <- "https://example.org"

  # City-major order: every template for the first city, then the next city.
  grid <- expand.grid(t = seq_len(nrow(tpl)), c = seq_len(nrow(cities_df)))
  tt <- tpl[grid$t, , drop = FALSE]
  cc <- cities_df[grid$c, , drop = FALSE]
  ext_id <- sprintf("%s-%s-%d", site_name, tt$suffix, as.integer(cc$id))
  out <- data.frame(
    id = -seq_len(nrow(grid)),
    title = paste0(tt$title, " - ", cc$city),
    description = tt$description,
    city = cc$label,
    venue = paste0(tt$venue, " (", cc$city, ")"),
    lat = round(cc$lat + tt$dlat, 4),
    lon = round(cc$lon + tt$dlon, 4),
    starts_at = paste(format(today + as.integer(tt$days_from_now), "%Y-%m-%d"), tt$time),
    category = tt$category,
    price_type = tt$price_type,
    price = as.numeric(tt$price),
    currency = "BRL",
    url = paste0(dom[[1]], "/e/", ext_id),
    source = site_name,
    external_id = ext_id,
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

provider_external_site <- function(site_name, enabled = TRUE, cities_df = load_cities(),
                                   today = Sys.Date()) {
  cat_info <- external_site_catalog()
  idx <- match(site_name, cat_info$name)
  label <- if (is.na(idx)) site_name else cat_info$label[[idx]]
  dom <- if (is.na(idx)) NA_character_ else cat_info$domain[[idx]]

  list(
    name = site_name,
    label = label,
    url = dom,
    enabled = isTRUE(enabled),
    note_key = if (!isTRUE(enabled)) "note_site_disabled",
    note = if (!isTRUE(enabled)) tf("note_site_disabled", "en", label) else NULL,
    search = function(query = "", city = NULL, from = NULL, to = NULL) {
      target_cities <- if (!is.null(city) && length(city) == 1L && nzchar(city)) {
        cities_df[cities_df$label == city, , drop = FALSE]
      } else {
        cities_df
      }
      if (nrow(target_cities) == 0L) return(empty_events())
      ev <- generate_site_events(site_name, cities_df = target_cities, today = today)
      filter_events(ev, query = query, from = from, to = to)
    }
  )
}

providers_catalog <- function(con, enabled_sites = external_site_catalog()$name,
                              include_local = TRUE, cities_df = load_cities()) {
  out <- list()
  if (isTRUE(include_local)) {
    out[[length(out) + 1L]] <- provider_local(con)
  }
  all_sites <- external_site_catalog()$name
  for (s in all_sites) {
    out[[length(out) + 1L]] <- provider_external_site(
      s, enabled = s %in% enabled_sites, cities_df = cities_df
    )
  }
  out
}

# Autopopulate the SQLite database from selected external sites for a city (or all cities).
# Uses validate_event() and db_insert_event(..., ignore_duplicates = TRUE) so it is safe
# and idempotent. Returns the number of newly inserted events.
autopopulate_events <- function(con, sites = external_site_catalog()$name,
                                city = NULL, query = "", cities_df = load_cities(),
                                today = Sys.Date()) {
  provs <- lapply(sites, function(s) {
    provider_external_site(s, enabled = TRUE, cities_df = cities_df, today = today)
  })
  res <- search_events(provs, query = query, city = city)
  ev <- res$events
  if (nrow(ev) == 0L) return(0L)
  added <- 0L
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(ev))) {
      r <- ev[i, , drop = FALSE]
      v <- validate_event(as.list(r))
      if (!v$ok) next
      if (db_event_exists(con, v$event$title, v$event$city, v$event$starts_at)) next
      new_id <- db_insert_event(con, v$event, ignore_duplicates = TRUE)
      if (!is.na(new_id)) added <- added + 1L
    }
  })
  added
}

# Run `query` through every enabled provider. A provider that fails is reported
# in `notes` (in `lang`) and does not stop the others. Results are merged and
# de-duplicated by title, start and city. Returns list(events, notes).
search_events <- function(providers, query = "", city = NULL, from = NULL, to = NULL, lang = "en") {
  results <- list()
  notes <- character()
  note_text <- function(p) {
    if (is.null(p$note_key)) return(p$note)
    fmt <- tr(p$note_key, lang)
    if (grepl("%s", fmt, fixed = TRUE)) sprintf(fmt, p$label) else fmt
  }
  for (p in providers) {
    if (!isTRUE(p$enabled)) {
      note <- note_text(p)
      if (!is.null(note)) notes <- c(notes, note)
      next
    }
    got <- tryCatch(
      p$search(query = query, city = city, from = from, to = to),
      error = function(e) {
        notes <<- c(notes, tf("note_provider_failed", lang, p$label, conditionMessage(e)))
        NULL
      }
    )
    if (!is.null(got) && nrow(got) > 0L) {
      results[[length(results) + 1L]] <- got[, event_columns(), drop = FALSE]
    }
  }
  events <- if (length(results)) do.call(rbind, results) else empty_events()
  if (nrow(events) > 1L) {
    key <- paste(normalize_text(events$title), events$starts_at, events$city, sep = "|")
    events <- events[!duplicated(key), , drop = FALSE]
  }
  rownames(events) <- NULL
  list(events = events, notes = notes)
}
