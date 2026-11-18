# The city list is plain data (inst/extdata/cities.csv). Adding a city means
# adding a row: city, state, country, lat, lon (city-centre coordinates).

load_cities <- function(path = system.file("extdata", "cities.csv", package = "aconteceR")) {
  if (!nzchar(path) || !file.exists(path)) {
    stop("Cities file not found: ", path, call. = FALSE)
  }
  x <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  required <- c("city", "state", "country", "lat", "lon")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop("Cities file is missing columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  x$lat <- as.numeric(x$lat)
  x$lon <- as.numeric(x$lon)
  if (anyNA(x$lat) || anyNA(x$lon)) {
    stop("Cities file has rows without numeric lat/lon.", call. = FALSE)
  }
  x$id <- seq_len(nrow(x))
  x$label <- paste0(x$city, " - ", x$state)
  x <- x[order(normalize_text(x$city)), c("id", "label", "city", "state", "country", "lat", "lon")]
  rownames(x) <- NULL
  x
}

# Choices for a selectize input: label = id.
city_choices <- function(cities) {
  stats::setNames(as.character(cities$id), cities$label)
}

# One-row data frame for a city id (zero rows when unknown).
find_city <- function(cities, id) {
  cities[cities$id == suppressWarnings(as.integer(id)), , drop = FALSE]
}

# The city the map opens on.
default_city <- function(cities) {
  i <- which(normalize_text(cities$city) == "sao paulo")
  if (length(i)) cities$id[[i[[1]]]] else cities$id[[1]]
}
