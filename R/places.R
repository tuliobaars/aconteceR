# Places: bars, pubs, nightclubs, restaurants, concert halls and so on, read
# from inst/extdata/places.csv (one row per place), classified by vibe, with
# opening-hours logic. The browser twin is inst/www/ac-places.js; the two are
# tested against the same cases (tests/testthat/fixtures/hours_cases.csv).
#
# Required columns: place_id, name, category, city (a label from
# load_cities()), lat, lon. Optional: vibes (keywords), neighborhood, address,
# opening_hours (OpenStreetMap syntax, e.g. "Mo-Sa 18:00-02:00; Su off") or
# the simple opens_at / closes_at ("HH:MM") / open_days ("Ter-Dom") trio,
# rating, reviews_count, price_level (1-4), maps_url, osm_url, website,
# source. Older files with google_rating / google_maps_url still load.
# OpenStreetMap data comes from fetch_osm_places() (R/osm.R).

PLACE_COLUMNS <- c("place_id", "name", "category", "vibes", "city", "neighborhood", "address", "lat", "lon",
                   "opening_hours", "opens_at", "closes_at", "open_days", "rating", "reviews_count",
                   "price_level", "maps_url", "osm_url", "website", "source")
PLACE_REQUIRED <- c("place_id", "name", "category", "city", "lat", "lon")

# Sources whose rows are real data. Anything else is shown as demo data.
VERIFIED_PLACE_SOURCES <- c("google_places_api", "openstreetmap")

place_category_keys <- function() {
  c("bar", "pub", "nightclub", "restaurant", "club", "concert_house",
    "cafe_bistro", "gastrobar", "cultural_spot", "rooftop_lounge")
}

place_categories <- function(lang = "en") {
  keys <- place_category_keys()
  stats::setNames(vapply(keys, function(k) tr(paste0("pcat_", k), lang), ""), keys)
}

vibe_keys <- function() {
  c("chill", "romantic", "party", "live_music", "dance", "casual",
    "upscale", "outdoor", "alternative", "culture", "friends", "family")
}

vibe_groups <- function(lang = "en") {
  keys <- vibe_keys()
  stats::setNames(vapply(keys, function(k) tr(paste0("vibe_", k), lang), ""), keys)
}

# Pin colours (the list tiles use matching gradients, .ac-pcat-* / .ac-vibe-*
# in inst/www/aconteceR.css; keep PCAT_COLORS / VIBE_COLORS in
# inst/standalone/ac-standalone.js in sync).
place_palette <- function() {
  c(bar = "#f59e0b", pub = "#16a34a", nightclub = "#a855f7", restaurant = "#f97316", club = "#ec4899",
    concert_house = "#e11d48", cafe_bistro = "#a16207", gastrobar = "#14b8a6", cultural_spot = "#0ea5e9",
    rooftop_lounge = "#6366f1")
}

vibe_palette <- function() {
  c(chill = "#3b82f6", romantic = "#e11d48", party = "#c026d3", live_music = "#7c3aed", dance = "#db2777",
    casual = "#d97706", upscale = "#a16207", outdoor = "#16a34a", alternative = "#475569",
    culture = "#0891b2", friends = "#ea580c", family = "#65a30d")
}

# ------------------------------------------------------------------- vibes

vibe_rules <- function(path = system.file("extdata", "vibes.csv", package = "aconteceR")) {
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Accent-folded, lower case, every run of characters other than letters,
# digits, "@" and "_" turned into "-", wrapped in "-" so patterns can anchor
# at word starts. ("_" is kept so "@cafe_bistro" stays one token.)
vibe_text <- function(x) {
  paste0("-", gsub("^-+|-+$", "", gsub("[^a-z0-9@_]+", "-", normalize_text(x))), "-")
}

# Vibe groups for each text: a comma-separated string of vibe_keys(), in that
# order. A pattern matches at the start of a word ("cultur" matches
# "cultural"); a trailing "$" asks for the whole word. "@category" tokens in
# the text pick up category defaults (see inst/extdata/vibes.csv).
classify_vibes <- function(text, rules = vibe_rules()) {
  # Checked before vibe_text(): paste0() turns a zero-length input into "--".
  if (!length(text)) return(character())
  t <- vibe_text(text)
  whole <- grepl("\\$$", rules$pattern)
  needle <- ifelse(whole, paste0("-", sub("\\$$", "", rules$pattern), "-"), paste0("-", rules$pattern))
  hits <- matrix(vapply(needle, function(n) grepl(n, t, fixed = TRUE), logical(length(t))),
                 nrow = length(t))
  keys <- vibe_keys()
  has <- vapply(keys, function(k) {
    cols <- which(rules$vibe == k)
    if (!length(cols)) return(rep(FALSE, length(t)))
    rowSums(hits[, cols, drop = FALSE]) > 0
  }, logical(length(t)))
  has <- matrix(has, nrow = length(t))
  apply(has, 1L, function(r) paste(keys[r], collapse = ","))
}

split_vibes <- function(x) {
  lapply(strsplit(chr0(x), ",", fixed = TRUE), function(v) v[nzchar(v)])
}

# Read and check the places file: fills optional columns, renames the older
# google_rating / google_maps_url, and adds vibe_groups (comma-separated vibe
# keys, from the vibes keywords and the name) and vibe_main (the first one).
load_places <- function(path = system.file("extdata", "places.csv", package = "aconteceR"),
                        rules = vibe_rules()) {
  if (!nzchar(path) || !file.exists(path)) stop("Places file not found: ", path, call. = FALSE)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = c("NA", ""))
  if ("google_rating" %in% names(x) && !"rating" %in% names(x)) names(x)[names(x) == "google_rating"] <- "rating"
  if ("google_maps_url" %in% names(x) && !"maps_url" %in% names(x)) names(x)[names(x) == "google_maps_url"] <- "maps_url"
  missing <- setdiff(PLACE_REQUIRED, names(x))
  if (length(missing)) {
    stop("Places file is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  for (col in setdiff(PLACE_COLUMNS, names(x))) x[[col]] <- rep(NA, nrow(x))
  for (col in c("lat", "lon", "rating")) x[[col]] <- suppressWarnings(as.numeric(x[[col]]))
  for (col in c("reviews_count", "price_level")) x[[col]] <- suppressWarnings(as.integer(x[[col]]))
  for (col in setdiff(PLACE_COLUMNS, c("lat", "lon", "rating", "reviews_count", "price_level"))) {
    x[[col]] <- as.character(x[[col]])
  }
  x <- x[!is.na(x$lat) & !is.na(x$lon) & !is.na(x$name), , drop = FALSE]
  x$vibe_groups <- classify_vibes(paste(chr0(x$vibes), chr0(x$name), paste0("@", x$category)), rules)
  x$vibe_main <- vapply(split_vibes(x$vibe_groups), function(v) if (length(v)) v[[1]] else NA_character_, "")
  rownames(x) <- NULL
  x
}

is_demo_place <- function(places) !chr0(places$source) %in% VERIFIED_PLACE_SOURCES

# ------------------------------------------------------------------- hours

# "Ter-Dom" -> a logical matrix, one row per input, columns Sunday..Saturday.
parse_open_days <- function(x) {
  days <- c("dom", "seg", "ter", "qua", "qui", "sex", "sab")
  x <- normalize_text(x)
  out <- matrix(FALSE, nrow = length(x), ncol = 7L)
  for (i in seq_along(x)) {
    for (part in strsplit(x[[i]], "[,;/ ]+")[[1]]) {
      if (!nzchar(part)) next
      if (part %in% c("todos", "diario", "todos-os-dias")) {
        out[i, ] <- TRUE
        next
      }
      ends <- strsplit(part, "-", fixed = TRUE)[[1]]
      a <- match(substr(ends[[1]], 1L, 3L), days)
      b <- match(substr(ends[[length(ends)]], 1L, 3L), days)
      if (is.na(a) || is.na(b)) next
      out[i, if (a <= b) a:b else c(a:7L, seq_len(b))] <- TRUE
    }
  }
  out
}

hhmm_minutes <- function(x) {
  m <- regmatches(chr0(x), regexec("^\\s*([0-9]{1,2}):([0-9]{2})\\s*$", chr0(x)))
  vapply(m, function(p) if (length(p) == 3L) as.integer(p[[2]]) * 60L + as.integer(p[[3]]) else NA_integer_, 1L)
}

hhmm_label <- function(mins) {
  m <- ((as.integer(mins) %% 1440L) + 1440L) %% 1440L
  sprintf("%02d:%02d", m %/% 60L, m %% 60L)
}

# A schedule is list(always, days): days is a list of 7 matrices (Sunday
# first) with columns o and c, minutes after midnight; c > 1440 runs past
# midnight. NULL means the hours are not known.
.hours_cache <- new.env(parent = emptyenv())
OSM_DAYS <- c(su = 0, mo = 1, tu = 2, we = 3, th = 4, fr = 5, sa = 6,
              dom = 0, seg = 1, ter = 2, qua = 3, qui = 4, sex = 5, sab = 6)
no_hours <- function() matrix(numeric(), ncol = 2L, dimnames = list(NULL, c("o", "c")))

osm_day_list <- function(sel) {
  out <- integer()
  for (part in strsplit(sel, "\\s*,\\s*", perl = TRUE)[[1]]) {
    ends <- strsplit(part, "\\s*-\\s*", perl = TRUE)[[1]]
    if (length(ends) > 2L) return(NULL)
    a <- unname(OSM_DAYS[ends[[1]]])
    b <- unname(OSM_DAYS[ends[[length(ends)]]])
    if (is.na(a) || is.na(b)) return(NULL)
    d <- a
    repeat {
      if (!d %in% out) out <- c(out, as.integer(d))
      if (d == b) break
      d <- (d + 1) %% 7
    }
  }
  out
}

osm_time_list <- function(str) {
  out <- no_hours()
  for (p in strsplit(str, "\\s*,\\s*", perl = TRUE)[[1]]) {
    m <- regmatches(p, regexec("^([0-9]{1,2}):([0-9]{2})\\s*(?:-\\s*([0-9]{1,2}):([0-9]{2})|(\\+))$",
                               p, perl = TRUE))[[1]]
    if (!length(m)) return(NULL)
    o <- as.numeric(m[[2]]) * 60 + as.numeric(m[[3]])
    c <- if (nzchar(m[[6]])) o + 240 else as.numeric(m[[4]]) * 60 + as.numeric(m[[5]])
    if (o >= 1440 || c > 2880) return(NULL)
    if (c <= o) c <- c + 1440
    out <- rbind(out, c(o = o, c = c))
  }
  out
}

# OpenStreetMap opening_hours -> schedule. Covers the common syntax: rules
# separated by ";" (later rules win for their days), weekday ranges and lists
# (English or Portuguese abbreviations), several time ranges per day, times
# past midnight ("18:00-02:00", "22:00-26:00"), open ends ("22:00+", read as
# four hours), "off", "24/7". Rules with month, week, holiday or sun-based
# selectors are skipped; nothing usable gives NULL. Mirrors AC.places.parseOSM.
parse_opening_hours <- function(x) {
  lapply(chr0(x), function(str) {
    key <- paste0("k", str)
    hit <- .hours_cache[[key]]
    if (!is.null(hit)) return(hit$value)
    value <- parse_opening_hours_one(str)
    assign(key, list(value = value), envir = .hours_cache)
    value
  })
}

parse_opening_hours_one <- function(str) {
  s <- trimws(gsub('"[^"]*"', " ", normalize_text(str)))
  # "09:00-18:00, Sa 10:00-14:00": a comma after a time starts a new rule.
  s <- gsub("([0-9])\\s*,\\s*(?=[a-z])", "\\1;", s, perl = TRUE)
  if (!nzchar(s)) return(NULL)
  full <- matrix(c(0, 1440), ncol = 2L, dimnames = list(NULL, c("o", "c")))
  if (identical(s, "24/7")) return(list(always = TRUE, days = rep(list(full), 7L)))
  days <- rep(list(no_hours()), 7L)
  used <- FALSE
  skip <- paste0("\\b(jan|feb|fev|mar|apr|abr|may|mai|jun|jul|aug|ago|sep|set|oct|out|nov|dec|dez|",
                 "week|sunrise|sunset|dawn|dusk|easter)\\b")
  sel_re <- "^([a-z]{2,3}(?:\\s*-\\s*[a-z]{2,3})?(?:\\s*,\\s*[a-z]{2,3}(?:\\s*-\\s*[a-z]{2,3})?)*)\\s*:?\\s*(.*)$"
  for (rule in strsplit(s, "\\s*(?:;|\\|\\|)\\s*", perl = TRUE)[[1]]) {
    rule <- trimws(rule)
    if (!nzchar(rule)) next
    if (grepl("^(ph|sh)\\b", rule, perl = TRUE) || grepl(skip, rule, perl = TRUE)) next
    if (identical(rule, "24/7")) {
      days <- rep(list(full), 7L)
      used <- TRUE
      next
    }
    m <- regmatches(rule, regexec(sel_re, rule, perl = TRUE))[[1]]
    sel <- if (length(m)) osm_day_list(m[[2]]) else NULL
    rest <- if (!is.null(sel)) trimws(m[[3]]) else rule
    if (is.null(sel)) sel <- 0:6
    if (grepl("^(off|closed|fechado)$", rest)) {
      for (d in sel) days[[d + 1L]] <- no_hours()
      used <- TRUE
      next
    }
    times <- if (nzchar(rest)) osm_time_list(rest) else NULL
    if (is.null(times)) next
    for (d in sel) days[[d + 1L]] <- times
    used <- TRUE
  }
  if (used) list(always = FALSE, days = days) else NULL
}

# Schedule for each place: opening_hours when given, else the simple trio.
place_schedules <- function(opening_hours, opens_at, closes_at, open_days) {
  n <- max(length(opening_hours), length(opens_at))
  if (n == 0L) return(list())
  oh <- rep_len(chr0(opening_hours), n)
  o <- hhmm_minutes(rep_len(chr0(opens_at), n))
  c <- hhmm_minutes(rep_len(chr0(closes_at), n))
  d <- parse_open_days(rep_len(chr0(open_days), n))
  from_osm <- parse_opening_hours(oh)
  lapply(seq_len(n), function(i) {
    if (nzchar(oh[[i]])) return(from_osm[[i]])
    if (is.na(o[[i]]) || is.na(c[[i]])) return(NULL)
    iv <- matrix(c(o[[i]], if (c[[i]] <= o[[i]]) c[[i]] + 1440 else c[[i]]), ncol = 2L,
                 dimnames = list(NULL, c("o", "c")))
    list(always = FALSE, days = lapply(1:7, function(k) if (d[i, k]) iv else no_hours()))
  })
}

schedule_status <- function(sch, wday, minutes) {
  out <- list(open = FALSE, unknown = FALSE, always = FALSE, to_close = NA_integer_, to_open = NA_integer_,
              days_ahead = NA_integer_, opens_label = NA_character_, closes_label = NA_character_)
  if (is.null(sch)) {
    out$unknown <- TRUE
    return(out)
  }
  if (isTRUE(sch$always)) {
    out$open <- TRUE
    out$always <- TRUE
    return(out)
  }
  today <- sch$days[[wday + 1L]]
  yest <- sch$days[[((wday + 6L) %% 7L) + 1L]]
  hit <- which(today[, "o"] <= minutes & minutes < today[, "c"])
  if (length(hit)) {
    cl <- today[hit[[1]], "c"]
    out$open <- TRUE
    out$to_close <- as.integer(cl - minutes)
    out$closes_label <- hhmm_label(cl)
    return(out)
  }
  hit <- which(yest[, "c"] > 1440 & minutes < yest[, "c"] - 1440)
  if (length(hit)) {
    cl <- yest[hit[[1]], "c"]
    out$open <- TRUE
    out$to_close <- as.integer(cl - 1440 - minutes)
    out$closes_label <- hhmm_label(cl)
    return(out)
  }
  later <- today[today[, "o"] > minutes, "o"]
  if (length(later)) {
    nx <- min(later)
    out$days_ahead <- 0L
    out$to_open <- as.integer(nx - minutes)
    out$opens_label <- hhmm_label(nx)
    return(out)
  }
  for (k in 1:7) {
    day <- sch$days[[((wday + k) %% 7L) + 1L]]
    if (nrow(day)) {
      nx <- min(day[, "o"])
      out$days_ahead <- as.integer(k)
      out$to_open <- as.integer(k * 1440 + nx - minutes)
      out$opens_label <- hhmm_label(nx)
      return(out)
    }
  }
  out
}

# Status of each place at a moment: `wday` 0 (Sunday) .. 6, `minutes` after
# midnight (the visitor's local clock). Uses `opening_hours` when given.
# Returns a data frame: open, to_close, to_open (minutes), days_ahead
# (0 = later today), unknown (hours not listed), always (24/7), and the
# opens_label / closes_label times.
place_open_status <- function(opens_at, closes_at, open_days, wday, minutes, opening_hours = NULL) {
  n <- max(length(opens_at), length(opening_hours))
  if (is.null(opening_hours)) opening_hours <- rep(NA_character_, n)
  if (is.null(opens_at)) opens_at <- rep(NA_character_, n)
  sch <- place_schedules(opening_hours, opens_at, closes_at, open_days)
  rows <- lapply(sch, schedule_status, wday = as.integer(wday), minutes = minutes)
  data.frame(
    open = vapply(rows, `[[`, logical(1), "open"),
    to_close = vapply(rows, `[[`, integer(1), "to_close"),
    to_open = vapply(rows, `[[`, integer(1), "to_open"),
    days_ahead = vapply(rows, `[[`, integer(1), "days_ahead"),
    unknown = vapply(rows, `[[`, logical(1), "unknown"),
    always = vapply(rows, `[[`, logical(1), "always"),
    opens_label = vapply(rows, `[[`, character(1), "opens_label"),
    closes_label = vapply(rows, `[[`, character(1), "closes_label"),
    stringsAsFactors = FALSE
  )
}

places_status <- function(places, clock) {
  place_open_status(places$opens_at, places$closes_at, places$open_days, clock$wday, clock$minutes,
                    opening_hours = places$opening_hours)
}

# "Aberto até 01:00", "Fecha às 23:30", "Abre às 18:00", "Abre amanhã às
# 18:00", "Abre qui às 22:00", "Aberto 24 horas", "Horário não informado",
# "Fechado". Mirrors AC.places.statusText.
place_status_text <- function(status, wday, lang = "en") {
  wd <- tr("wd_min", lang)
  vapply(seq_len(nrow(status)), function(i) {
    s <- status[i, ]
    if (isTRUE(s$unknown)) return(tr("place_hours_unknown", lang))
    if (isTRUE(s$always)) return(tr("place_open_24h", lang))
    if (isTRUE(s$open)) {
      return(if (s$to_close <= 60L) tf("place_closes_soon", lang, s$closes_label)
             else tf("place_open_until", lang, s$closes_label))
    }
    if (is.na(s$days_ahead)) return(tr("place_closed", lang))
    if (s$days_ahead == 0L) return(tf("place_opens_at", lang, s$opens_label))
    if (s$days_ahead == 1L) return(tf("place_opens_tomorrow", lang, s$opens_label))
    tf("place_opens_day", lang, wd[((wday + s$days_ahead) %% 7L) + 1L], s$opens_label)
  }, "")
}

# Latest closing time tonight in minutes after the evening's midnight (01:30
# -> 1530); before 06:00 "tonight" is the night that started the day before.
# Inf for 24/7, NA when closed tonight or unknown. Mirrors
# AC.places.closesTonight.
place_closes_tonight <- function(places, clock) {
  sch <- place_schedules(places$opening_hours, places$opens_at, places$closes_at, places$open_days)
  wd <- if (clock$minutes < 360L) (clock$wday + 6L) %% 7L else clock$wday
  vapply(sch, function(s) {
    if (is.null(s)) return(NA_real_)
    if (isTRUE(s$always)) return(Inf)
    day <- s$days[[wd + 1L]]
    if (nrow(day)) max(day[, "c"]) else NA_real_
  }, numeric(1))
}

# "Open late": still open at 02:00 tonight.
LATE_MINUTES <- 26L * 60L
is_open_late <- function(places, clock) {
  c <- place_closes_tonight(places, clock)
  !is.na(c) & c >= LATE_MINUTES
}

# The visitor's clock as list(wday, minutes), from the `clock` input the
# browser sends (see ac-shiny.js); falls back to the server's clock.
client_clock <- function(clock = NULL) {
  if (!is.null(clock$wday) && !is.null(clock$minutes)) {
    return(list(wday = as.integer(clock$wday), minutes = as.integer(clock$minutes)))
  }
  now <- as.POSIXlt(Sys.time())
  list(wday = now$wday, minutes = now$hour * 60L + now$min)
}

# Rating weighted by how many reviews back it (Bayesian average), 0..1; NA
# when there is no rating. Mirrors AC.places.quality.
place_quality <- function(rating, reviews, m = 150, prior = 4.2) {
  n <- pmax(0, as.numeric(reviews))
  n[is.na(n)] <- 0
  b <- (n * as.numeric(rating) + m * prior) / (n + m)
  pmin(1, pmax(0, (b - 3.8) / 1.1))
}

# ---------------------------------------------------------------- filters

filter_places <- function(places, query = "", categories = NULL, vibes = NULL, open_now = FALSE,
                          open_late = FALSE, clock = client_clock(), lang = "en") {
  if (nrow(places) == 0L) return(places)
  keep <- rep(TRUE, nrow(places))
  if (length(categories)) keep <- keep & places$category %in% categories
  if (length(vibes)) {
    keep <- keep & vapply(split_vibes(places$vibe_groups), function(v) any(v %in% vibes), logical(1))
  }
  q <- normalize_text(query %||% "")
  if (nzchar(trimws(q))) {
    labels <- vapply(split_vibes(places$vibe_groups), function(v) paste(vibe_groups(lang)[v], collapse = " "), "")
    hay <- normalize_text(paste(places$name, chr0(places$neighborhood), chr0(places$vibes),
                                place_categories(lang)[places$category], labels))
    for (term in strsplit(trimws(q), "[[:space:]]+")[[1]]) keep <- keep & grepl(term, hay, fixed = TRUE)
  }
  if (isTRUE(open_now)) keep <- keep & places_status(places, clock)$open
  if (isTRUE(open_late)) keep <- keep & is_open_late(places, clock)
  places[keep, , drop = FALSE]
}

# Open first, then places with unknown hours, then closed; within each, by
# review-weighted rating (unrated in the middle), then by name. Mirrors
# placesFiltered() in inst/standalone/ac-standalone.js.
order_places <- function(places, clock = client_clock()) {
  if (nrow(places) < 2L) return(places)
  st <- places_status(places, clock)
  group <- ifelse(st$open, 0L, ifelse(st$unknown, 1L, 2L))
  q <- place_quality(places$rating, places$reviews_count)
  q[is.na(q)] <- 0.5
  out <- places[order(group, -q, places$name), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# ----------------------------------------------------------- map and rows

# Pin colours by opening status (the status_key column, see
# place_status_key()); keep STATUS_COLORS in ac-standalone.js in sync.
status_palette <- function() {
  c(open = "#16a34a", later = "#f59e0b", unknown = "#a5b4c8", closed = "#64748b")
}

# "open", "later" (opens later today), "unknown" (hours not listed) or
# "closed", at the visitor's clock.
place_status_key <- function(places, clock) {
  if (nrow(places) == 0L) return(character())
  st <- places_status(places, clock)
  ifelse(st$open, "open", ifelse(st$unknown, "unknown",
                                 ifelse(!is.na(st$days_ahead) & st$days_ahead == 0L, "later", "closed")))
}

# Colour modes for places: category, vibe and opening status; rating only
# when the data has ratings (OpenStreetMap has none).
place_color_modes <- function(lang = "en", rating = TRUE) {
  n <- function(x) format_number(x, 1L, lang)
  keys <- names(status_palette())
  modes <- list(
    category = map_color_factor(
      "category", colors = place_palette(), labels = place_categories(lang),
      label = tr("mode_category", lang), title = tr("category_label", lang)
    ),
    vibe = map_color_factor(
      "vibe_main", colors = vibe_palette(), labels = vibe_groups(lang),
      label = tr("mode_vibe", lang), title = tr("vibe_label", lang)
    ),
    hours = map_color_factor(
      "status_key", colors = status_palette(),
      labels = stats::setNames(vapply(keys, function(k) tr(paste0("status_", k), lang), ""), keys),
      label = tr("mode_hours", lang), title = tr("hours_label", lang)
    ),
    rating = map_color_bins(
      "rating", breaks = c(0, 3.95, 4.25, 4.55, 5),
      colors = c("#cbd5e1", "#fcd34d", "#f59e0b", "#16a34a"),
      labels = c(tf("rating_below", lang, n(4)), paste(n(4), "\u2013", n(4.2)),
                 paste(n(4.3), "\u2013", n(4.5)), tf("rating_up", lang, n(4.6))),
      label = tr("mode_rating", lang), title = tr("rating_label", lang),
      na_label = tr("rating_none", lang)
    )
  )
  if (!isTRUE(rating)) modes$rating <- NULL
  modes
}

price_level_text <- function(level) {
  ifelse(is.na(level) | level < 1, "", strrep("$", pmax(1L, as.integer(level))))
}

place_rating_tag <- function(p, lang = "en") {
  if (is.na(p$rating)) return(NULL)
  htmltools::span(
    class = "ac-rating", ac_icon("star"), format_number(p$rating, 1L, lang),
    if (!is.na(p$reviews_count)) htmltools::tags$small(paste0("(", format_number(p$reviews_count, 0L, lang), ")"))
  )
}

place_vibe_tags <- function(vibes, lang = "en", n = 3L) {
  v <- utils::head(split_vibes(vibes)[[1]], n)
  pal <- vibe_palette()
  htmltools::div(class = "ac-vibe-tags", lapply(v, function(k) {
    htmltools::span(class = "ac-vibe-tag", htmltools::tags$i(style = paste0("background:", pal[[k]])),
                    tr(paste0("vibe_", k), lang))
  }))
}

place_maps_link <- function(url, lang = "en", compact = TRUE) {
  link <- safe_url(url)
  if (is.na(link)) return(NULL)
  htmltools::tags$a(
    class = if (compact) "ac-ev-link" else "ac-linkbtn", href = link, target = "_blank", rel = "noopener noreferrer",
    `aria-label` = tr("place_maps_link", lang), title = tr("place_maps_link", lang),
    ac_icon("external"), if (!compact) htmltools::span(tr("place_maps_link", lang))
  )
}

status_class <- function(st) {
  if (isTRUE(st$open)) "ac-place-open" else if (isTRUE(st$unknown)) "ac-place-unknown" else "ac-place-closed"
}

# One place row; same markup as placeRowHtml() in ac-standalone.js.
place_row <- function(p, status_text, st, focus_input = NULL, lang = "en") {
  cat <- if (p$category %in% place_category_keys()) p$category else "bar"
  htmltools::tags$article(
    class = "ac-ev ac-place", `data-id` = p$place_id, `data-input` = focus_input,
    htmltools::div(class = paste0("ac-ev-tile ac-pcat-", cat), `aria-hidden` = "true", ac_icon(paste0("pcat_", cat))),
    htmltools::div(
      class = "ac-ev-main",
      htmltools::tags$h3(
        class = "ac-ev-title",
        htmltools::tags$button(type = "button", class = "ac-ev-show", `data-focus-id` = p$place_id,
                               title = tr("show_on_map", lang), p$name)
      ),
      htmltools::p(
        class = "ac-ev-meta",
        htmltools::span(class = status_class(st), status_text),
        if (nzchar(chr0(p$neighborhood))) paste0(" \u00b7 ", p$neighborhood)
      ),
      place_vibe_tags(p$vibe_groups, lang)
    ),
    htmltools::div(
      class = "ac-ev-side",
      place_rating_tag(p, lang),
      htmltools::span(class = "ac-price-level", price_level_text(p$price_level)),
      place_maps_link(p$maps_url, lang)
    )
  )
}

place_list <- function(places, clock = client_clock(), focus_input = NULL, max_rows = 100L, lang = "en") {
  if (nrow(places) == 0L) {
    return(htmltools::div(
      class = "ac-empty",
      htmltools::tags$strong(tr("empty_title", lang)),
      htmltools::span(tr("empty_hint", lang))
    ))
  }
  shown <- utils::head(places, max_rows)
  st <- places_status(shown, clock)
  txt <- place_status_text(st, clock$wday, lang)
  htmltools::tagList(lapply(seq_len(nrow(shown)), function(i) {
    place_row(shown[i, , drop = FALSE], txt[[i]], st[i, ], focus_input = focus_input, lang = lang)
  }))
}

# Map popups; every text goes through escape_html().
place_popup_html <- function(places, lang = "en", clock = client_clock()) {
  if (nrow(places) == 0L) return(character())
  st <- places_status(places, clock)
  txt <- place_status_text(st, clock$wday, lang)
  vapply(seq_len(nrow(places)), function(i) {
    p <- places[i, , drop = FALSE]
    cat <- place_categories(lang)[p$category]
    as.character(htmltools::tagList(
      htmltools::span(class = "ac-pop-title", p$name),
      htmltools::span(class = "ac-pop-when", paste(Filter(nzchar, c(chr0(cat), chr0(p$neighborhood))), collapse = " \u00b7 ")),
      htmltools::span(
        class = "ac-pop-meta",
        htmltools::span(class = status_class(st[i, ]), txt[[i]]),
        place_rating_tag(p, lang),
        htmltools::span(class = "ac-price-level", price_level_text(p$price_level))
      ),
      place_vibe_tags(p$vibe_groups, lang),
      place_links(p, lang)
    ))
  }, "")
}

# Popup links: Google Maps search (photos, reviews), the place's website and
# its OpenStreetMap page. Mirrors placeLinks() in ac-standalone.js.
place_links <- function(p, lang = "en") {
  link <- function(url, key, icon = "external") {
    u <- safe_url(url)
    if (is.na(u)) return(NULL)
    htmltools::tags$a(class = "ac-linkbtn", href = u, target = "_blank", rel = "noopener noreferrer",
                      ac_icon(icon), htmltools::span(tr(key, lang)))
  }
  links <- list(
    place_maps_link(p$maps_url, lang, compact = FALSE),
    link(p$website, "place_website"),
    link(p$osm_url, "place_osm_link", "map")
  )
  links <- Filter(Negate(is.null), links)
  if (!length(links)) return(NULL)
  htmltools::div(class = "ac-pop-actions", links)
}
