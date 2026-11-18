# Persistence: one SQLite file holds every event. All queries use bound
# parameters, never string pasting, so titles like "x'); DROP TABLE events;--"
# are stored as plain text.

# Where the database lives. Override with options(aconteceR.db_path = "...").
# R_user_dir() is a per-user folder that survives restarts; if that directory is
# not writable (for example inside an offline sandbox), it falls back to
# inst/extdata/events.sqlite or tempdir().
default_db_path <- function() {
  opt <- getOption("aconteceR.db_path")
  if (!is.null(opt) && nzchar(opt)) return(opt)
  user_dir <- tools::R_user_dir("aconteceR", which = "data")
  ok <- tryCatch({
    dir.create(user_dir, recursive = TRUE, showWarnings = FALSE)
    file.access(user_dir, 2) == 0L
  }, error = function(e) FALSE)
  if (isTRUE(ok)) {
    return(file.path(user_dir, "events.sqlite"))
  }
  if (dir.exists("inst/extdata") && file.access("inst/extdata", 2) == 0L) {
    return(file.path("inst", "extdata", "events.sqlite"))
  }
  file.path(tempdir(), "aconteceR-events.sqlite")
}

# Open (and create if needed) the database. Use ":memory:" for tests.
db_connect <- function(path = default_db_path()) {
  if (!identical(path, ":memory:")) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path)
  db_init(con)
  con
}

db_init <- function(con) {
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS events (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      title       TEXT NOT NULL,
      description TEXT,
      city        TEXT NOT NULL,
      venue       TEXT,
      lat         REAL NOT NULL,
      lon         REAL NOT NULL,
      starts_at   TEXT NOT NULL,
      category    TEXT NOT NULL,
      price_type  TEXT NOT NULL,
      price       REAL,
      currency    TEXT NOT NULL DEFAULT 'BRL',
      url         TEXT,
      source      TEXT NOT NULL DEFAULT 'user',
      external_id TEXT,
      created_at  TEXT NOT NULL
    )")
  # Events from outside sources carry a stable id, so they are never stored twice.
  DBI::dbExecute(con, "
    CREATE UNIQUE INDEX IF NOT EXISTS ux_events_source_external
    ON events (source, external_id) WHERE external_id IS NOT NULL")
  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS ix_events_city_start ON events (city, starts_at)")
  invisible(con)
}

# Insert one validated event (see validate_event()). Returns the new id, or NA
# when `ignore_duplicates` is TRUE and the row already existed.
db_insert_event <- function(con, ev, ignore_duplicates = FALSE) {
  verb <- if (ignore_duplicates) "INSERT OR IGNORE" else "INSERT"
  sql <- paste0(
    verb, " INTO events (title, description, city, venue, lat, lon, starts_at, ",
    "category, price_type, price, currency, url, source, external_id, created_at) ",
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  )
  params <- unname(list(
    ev$title, ev$description, ev$city, ev$venue, ev$lat, ev$lon, ev$starts_at,
    ev$category, ev$price_type, ev$price, ev$currency, ev$url, ev$source,
    ev$external_id, format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  ))
  changed <- DBI::dbExecute(con, sql, params = params)
  if (changed == 0L) return(NA_integer_)
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id[[1]]
}

# Is there already an event with this title, city and start? (Case-insensitive
# for ASCII letters only: SQLite's lower() does not fold accents.)
db_event_exists <- function(con, title, city, starts_at) {
  res <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM events WHERE lower(title) = lower(?) AND city = ? AND starts_at = ?",
    params = list(title, city, starts_at)
  )
  res$n[[1]] > 0L
}

# Events ordered by start. `city` is the city label ("Curitiba - PR"); `from`
# and `to` are Dates (whole days, inclusive). NULL means no limit.
db_fetch_events <- function(con, city = NULL, from = NULL, to = NULL) {
  where <- character()
  params <- list()
  if (!is.null(city) && length(city) == 1L && nzchar(city)) {
    where <- c(where, "city = ?")
    params <- c(params, list(city))
  }
  if (!is.null(from) && !is.na(from)) {
    where <- c(where, "starts_at >= ?")
    params <- c(params, list(format(as.Date(from), "%Y-%m-%d 00:00")))
  }
  if (!is.null(to) && !is.na(to)) {
    where <- c(where, "starts_at <= ?")
    params <- c(params, list(format(as.Date(to), "%Y-%m-%d 23:59")))
  }
  sql <- "SELECT * FROM events"
  if (length(where)) sql <- paste(sql, "WHERE", paste(where, collapse = " AND "))
  sql <- paste(sql, "ORDER BY starts_at ASC, id ASC")
  DBI::dbGetQuery(con, sql, params = if (length(params)) unname(params) else NULL)
}

# Load the demo events from inst/extdata/sample_events.csv. Dates are relative
# to `today`, so the demo always has upcoming events. Safe to call on every
# start: when the samples are already there it returns at once; when every
# sample is in the past (an old database) they are dated again from today.
# Rows are keyed by sample_id and never duplicated. Returns how many rows were
# added.
db_seed_samples <- function(con,
                            path = system.file("extdata", "sample_events.csv", package = "aconteceR"),
                            today = Sys.Date()) {
  if (!nzchar(path) || !file.exists(path)) return(invisible(0L))
  x <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  have <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n, MAX(starts_at) AS last FROM events WHERE source = 'sample'")
  if (have$n[[1]] >= nrow(x)) {
    if (!is.na(have$last[[1]]) && have$last[[1]] >= format(today, "%Y-%m-%d")) return(invisible(0L))
    DBI::dbExecute(con, "DELETE FROM events WHERE source = 'sample'")
  }
  added <- 0L
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(x))) {
      r <- x[i, , drop = FALSE]
      res <- validate_event(list(
        title = r$title,
        description = r$description,
        city = r$city,
        venue = r$venue,
        lat = r$lat,
        lon = r$lon,
        starts_at = paste(format(today + as.integer(r$days_from_now), "%Y-%m-%d"), r$time),
        category = r$category,
        price_type = r$price_type,
        price = r$price,
        currency = "BRL",
        url = if ("url" %in% names(r)) r$url else "",
        source = "sample",
        external_id = r$sample_id
      ))
      if (!res$ok) next
      id <- db_insert_event(con, res$event, ignore_duplicates = TRUE)
      if (!is.na(id)) added <- added + 1L
    }
  })
  invisible(added)
}
