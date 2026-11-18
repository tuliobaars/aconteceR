# Places from OpenStreetMap, through the Overpass API. No account and no API
# key: Overpass is a free, public service, so the fetcher identifies itself
# with a User-Agent, waits between requests, retries politely on 429/504 and
# tries a second server before giving up. Raw answers are cached as JSON, one
# file per city, so a re-run (or a crash halfway through 40 cities) only
# downloads what is missing.
#
#   places <- fetch_osm_places()               # all cities in cities.csv
#   write_places_csv(places, "inst/extdata/places.csv")
#
# or run inst/scripts/fetch_places_osm.R. OpenStreetMap data is (c)
# OpenStreetMap contributors under the Open Database Licence (ODbL); the
# resulting places.csv is a derived database under the same licence and the
# app shows the attribution (see inst/COPYRIGHTS).
#
# Mapping from OSM tags to the app's ten categories is in osm_category();
# keywords for the vibe classifier (inst/extdata/vibes.csv) come from
# osm_vibe_keywords(). OSM has no ratings, so `rating` stays empty and the
# app ranks by how complete a place's data is instead.

OVERPASS_ENDPOINTS <- c(
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter"
)

osm_user_agent <- function() {
  version <- tryCatch(as.character(utils::packageVersion("aconteceR")), error = function(e) "dev")
  paste0("aconteceR/", version, " (event and nightlife map; R ", getRversion(), ")")
}

# ------------------------------------------------------------------ query

# Overpass QL for one city: venues with a name and neighbourhood nodes, within
# `radius_m` metres of the centre. `out center` gives ways and relations a
# single point.
overpass_query <- function(lat, lon, radius_m = 12000, timeout = 180) {
  around <- sprintf("(around:%d,%.5f,%.5f)", as.integer(round(radius_m)), lat, lon)
  amenity <- "bar|pub|biergarten|nightclub|restaurant|cafe|music_venue|theatre|arts_centre|cinema"
  paste0(
    "[out:json][timeout:", as.integer(timeout), "];\n(\n",
    "  nwr[\"amenity\"~\"^(", amenity, ")$\"][\"name\"]", around, ";\n",
    "  nwr[\"leisure\"=\"dance\"][\"name\"]", around, ";\n",
    "  nwr[\"tourism\"~\"^(museum|gallery)$\"][\"name\"]", around, ";\n",
    "  node[\"place\"~\"^(suburb|neighbourhood|quarter)$\"][\"name\"]", around, ";\n",
    ");\nout center;\n"
  )
}

# ------------------------------------------------------------------ fetch

# Download `url` to `destfile` with a User-Agent header. Errors on HTTP
# errors (download.file does), which the caller retries.
osm_download <- function(url, destfile, user_agent = osm_user_agent()) {
  # Big cities take a while on the server; R's default timeout is 60 s.
  old <- options(timeout = max(300, getOption("timeout", 60)))
  on.exit(options(old), add = TRUE)
  status <- utils::download.file(url, destfile, method = "libcurl", quiet = TRUE, mode = "wb",
                                 headers = c(`User-Agent` = user_agent))
  if (!identical(as.integer(status), 0L)) stop("download failed with status ", status, call. = FALSE)
  invisible(destfile)
}

# TRUE when the file is a usable Overpass answer. Overpass reports timeouts
# and memory errors inside a 200 response, in "remark".
overpass_ok <- function(path) {
  x <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(x) || is.null(x$elements)) return(FALSE)
  remark <- x$remark %||% ""
  !grepl("runtime error|timed out|out of memory", remark, ignore.case = TRUE)
}

# Run a query and keep the answer in `cache_file`. An existing cache file is
# reused unless `refresh = TRUE`. Tries every endpoint, `retries` rounds,
# waiting `pause` seconds and doubling the wait each round.
overpass_fetch <- function(query, cache_file, endpoints = OVERPASS_ENDPOINTS, refresh = FALSE,
                           retries = 3L, pause = 5, user_agent = osm_user_agent(), fetch = osm_download,
                           verbose = TRUE) {
  if (!refresh && file.exists(cache_file) && overpass_ok(cache_file)) return(cache_file)
  dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(cache_file, ".part")
  on.exit(unlink(tmp), add = TRUE)
  wait <- pause
  last <- "no endpoint answered"
  for (round in seq_len(max(1L, retries))) {
    for (ep in endpoints) {
      url <- paste0(ep, "?data=", utils::URLencode(query, reserved = TRUE))
      ok <- tryCatch({
        fetch(url, tmp, user_agent)
        overpass_ok(tmp)
      }, error = function(e) {
        last <<- conditionMessage(e)
        FALSE
      })
      if (isTRUE(ok)) {
        file.rename(tmp, cache_file)
        return(cache_file)
      }
      if (verbose) message("  ", sub("^https?://([^/]+).*$", "\\1", ep), ": ", last, "; trying again")
      if (wait > 0) Sys.sleep(wait)
    }
    wait <- wait * 2
  }
  stop("Overpass did not answer (", last, "). Run again later; finished cities are cached in ",
       dirname(cache_file), ".", call. = FALSE)
}

# The `elements` of a cached answer, as a list of lists (type, id, lat, lon
# or center, tags).
osm_elements <- function(path) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)$elements %||% list()
}

# ------------------------------------------------------------- tags -> row

osm_tag <- function(tags, key) {
  v <- tags[[key]]
  if (is.null(v) || !length(v) || is.na(v[[1]])) "" else as.character(v[[1]])
}

osm_yes <- function(tags, keys) {
  any(vapply(keys, function(k) osm_tag(tags, k) %in% c("yes", "only", "primary", "welcome", "friendly", "served"), TRUE))
}

# One of place_category_keys() for a set of OSM tags, or NA when the tags do
# not describe a venue the app lists.
osm_category <- function(tags) {
  amenity <- osm_tag(tags, "amenity")
  name <- normalize_text(osm_tag(tags, "name"))
  has <- function(pattern) grepl(pattern, name, perl = TRUE)
  rooftop <- identical(osm_tag(tags, "rooftop"), "yes") || has("\\b(rooftop|roof ?top|sky ?bar|terraco|terrace)\\b")
  gastro <- has("gastro ?bar|gastropub|petiscaria")
  samba <- has("\\b(samba|forro|gafieira|pagode|dancing|clube|club social)\\b")
  beer <- osm_yes(tags, c("microbrewery", "craft_beer", "drink:craft_beer")) ||
    has("\\b(cervejaria|brewpub|brew pub|pub|beer|chopp?eria)\\b")
  leisure <- osm_tag(tags, "leisure")
  tourism <- osm_tag(tags, "tourism")
  if (identical(leisure, "dance")) return("club")
  switch(
    amenity,
    nightclub = if (samba) "club" else "nightclub",
    bar = if (rooftop) "rooftop_lounge" else if (gastro) "gastrobar" else if (beer) "pub" else "bar",
    pub = , biergarten = if (gastro) "gastrobar" else "pub",
    restaurant = if (gastro) "gastrobar" else if (rooftop) "rooftop_lounge" else "restaurant",
    cafe = "cafe_bistro",
    music_venue = , theatre = "concert_house",
    arts_centre = , cinema = "cultural_spot",
    if (tourism %in% c("museum", "gallery")) "cultural_spot" else NA_character_
  )
}

OSM_CUISINE_PT <- c(
  regional = "regional", brazilian = "brasileira comida-regional", seafood = "frutos-do-mar beira-mar",
  pizza = "pizza", italian = "italiana", japanese = "japonesa", sushi = "japonesa",
  burger = "lanches hamburguer", barbecue = "churrasco", steak_house = "churrasco", coffee_shop = "cafe barista",
  ice_cream = "sorvete", vegetarian = "vegetariano", vegan = "vegano", french = "francesa chef",
  arab = "arabe", lebanese = "arabe", mexican = "mexicana", portuguese = "portuguesa",
  snack = "petiscos lanches", tapas = "petiscos pratos-para-dividir", wine = "vinho carta-de-vinhos",
  international = "cosmopolita", fine_dining = "alta-cozinha sofisticado", breakfast = "cafe-da-manha",
  brunch = "brunch", cake = "doces-tradicionais", dessert = "doces-tradicionais"
)

# Portuguese keywords for the vibe classifier (inst/extdata/vibes.csv) from a
# place's tags: "ar-livre" for outdoor seating, "ao-vivo" for live music, and
# so on, plus cuisine and the description.
osm_vibe_keywords <- function(tags) {
  k <- character()
  add <- function(cond, words) if (isTRUE(cond)) k <<- c(k, words)
  add(osm_yes(tags, "outdoor_seating"), "ar-livre mesa-na-calcada")
  add(osm_yes(tags, "live_music"), "ao-vivo")
  add(osm_yes(tags, c("lgbtq", "gay")), "queer-friendly")
  add(osm_yes(tags, c("microbrewery", "craft_beer", "drink:craft_beer")), "cerveja-artesanal brewpub")
  add(osm_yes(tags, c("cocktails", "drink:cocktail")), "coqueteis")
  add(osm_yes(tags, c("drink:wine", "wine")), "carta-de-vinhos")
  add(nzchar(osm_tag(tags, "sport")), "esportes")
  add(osm_yes(tags, "karaoke"), "karaoke divertido")
  add(osm_yes(tags, "wheelchair"), "acessivel")
  add(osm_yes(tags, c("diet:vegetarian", "diet:vegan")), "vegetariano")
  add(osm_yes(tags, "dog"), "pet-friendly")
  add(osm_tag(tags, "reservation") %in% c("required", "recommended"), "reserva")
  add(osm_yes(tags, c("kids_area", "highchair", "changing_table")), "familia")
  add(osm_tag(tags, "internet_access") %in% c("wlan", "yes", "wifi"), "wifi")
  add(osm_yes(tags, "rooftop"), "rooftop vista")
  add(nzchar(osm_tag(tags, "happy_hours")), "happy-hour")
  add(osm_tag(tags, "amenity") == "cinema", "cinema filmes")
  add(osm_tag(tags, "amenity") == "theatre", "teatro palco")
  add(osm_tag(tags, "tourism") == "museum", "historia exposicoes")
  add(osm_tag(tags, "tourism") == "gallery", "arte exposicoes")
  add(osm_tag(tags, "leisure") == "dance", "danca salao")
  cuisine <- strsplit(normalize_text(osm_tag(tags, "cuisine")), "\\s*[;,]\\s*")[[1]]
  cuisine <- cuisine[nzchar(cuisine)]
  if (length(cuisine)) {
    pt <- OSM_CUISINE_PT[cuisine]
    k <- c(k, ifelse(is.na(pt), gsub("_", "-", cuisine), pt))
  }
  desc <- osm_tag(tags, "description")
  if (!nzchar(desc)) desc <- osm_tag(tags, "description:pt")
  if (nzchar(desc)) k <- c(k, substr(desc, 1L, 200L))
  paste(unique(k), collapse = ", ")
}

# The place's website: website or contact:website (a bare "www." gets
# https://), else its Instagram page, which many Brazilian bars use instead.
osm_website <- function(tags) {
  fix <- function(u) if (grepl("^www\\.", u)) paste0("https://", u) else u
  for (key in c("website", "contact:website", "url")) {
    u <- safe_url(fix(trimws(osm_tag(tags, key))))
    if (!is.na(u)) return(u)
  }
  ig <- trimws(osm_tag(tags, "contact:instagram"))
  if (grepl("^https?://", ig)) return(if (is.na(safe_url(ig))) "" else ig)
  handle <- sub("^@", "", ig)
  if (grepl("^[A-Za-z0-9._]{1,30}$", handle)) return(paste0("https://www.instagram.com/", handle))
  ""
}

# "Rua da Aurora, 325" from addr:street + addr:housenumber.
osm_address <- function(tags) {
  street <- osm_tag(tags, "addr:street")
  number <- osm_tag(tags, "addr:housenumber")
  if (!nzchar(street)) return("")
  if (nzchar(number)) paste0(street, ", ", number) else street
}

# How much useful data a place has; the per-category cap keeps the most
# complete places. Hours count most, because the app is about "open now".
osm_score <- function(tags) {
  hours <- osm_tag(tags, "opening_hours")
  (if (nzchar(hours) && !is.null(parse_opening_hours(hours)[[1]])) 4 else 0) +
    (if (nzchar(osm_tag(tags, "addr:street"))) 1 else 0) +
    (if (nzchar(osm_website(tags))) 1 else 0) +
    (if (nzchar(osm_tag(tags, "cuisine")) || nzchar(osm_tag(tags, "description"))) 1 else 0) +
    (if (nzchar(osm_tag(tags, "wikidata"))) 1 else 0) +
    min(1, length(tags) / 15)
}

# Google Maps search link (no key needed): opens the place by name and
# address in Google Maps, where people look for photos and reviews.
maps_search_url <- function(name, address, city) {
  q <- trimws(paste(Filter(nzchar, c(name, address, city)), collapse = ", "))
  paste0("https://www.google.com/maps/search/?api=1&query=", utils::URLencode(q, reserved = TRUE))
}

geo_distance_km <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  dlat <- (lat2 - lat1) * rad
  dlon <- (lon2 - lon1) * rad
  a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  6371 * 2 * atan2(sqrt(a), sqrt(pmax(0, 1 - a)))
}

# Overpass elements -> places in PLACE_COLUMNS order, for one city.
# Neighbourhood: addr:suburb / addr:neighbourhood / addr:quarter, else the
# closest place=suburb|neighbourhood|quarter node within 3 km. Places with
# the same name within 50 m (a node and a building for one bar) are merged.
# At most `per_category` places per category, the most complete first
# (Inf keeps all).
osm_places_from_elements <- function(elements, city_label, per_category = 30) {
  empty <- empty_places()
  if (!length(elements)) return(empty)
  coords <- function(el) {
    if (!is.null(el$lat)) return(c(as.numeric(el$lat), as.numeric(el$lon)))
    if (!is.null(el$center)) return(c(as.numeric(el$center$lat), as.numeric(el$center$lon)))
    c(NA_real_, NA_real_)
  }
  hoods <- Filter(function(el) nzchar(osm_tag(el$tags %||% list(), "place")), elements)
  hood_name <- vapply(hoods, function(el) osm_tag(el$tags, "name"), "")
  hood_xy <- if (length(hoods)) do.call(rbind, lapply(hoods, coords)) else matrix(numeric(), ncol = 2L)

  rows <- lapply(elements, function(el) {
    tags <- el$tags %||% list()
    if (nzchar(osm_tag(tags, "place"))) return(NULL)
    cat <- osm_category(tags)
    name <- trimws(osm_tag(tags, "name"))
    xy <- coords(el)
    if (is.na(cat) || !nzchar(name) || anyNA(xy)) return(NULL)
    hood <- osm_tag(tags, "addr:suburb")
    if (!nzchar(hood)) hood <- osm_tag(tags, "addr:neighbourhood")
    if (!nzchar(hood)) hood <- osm_tag(tags, "addr:quarter")
    if (!nzchar(hood) && length(hoods)) {
      d <- geo_distance_km(xy[[1]], xy[[2]], hood_xy[, 1], hood_xy[, 2])
      d[is.na(d)] <- Inf
      if (min(d) <= 3) hood <- hood_name[[which.min(d)]]
    }
    address <- osm_address(tags)
    type <- el$type %||% "node"
    list(
      place_id = paste0("osm-", type, "-", el$id), name = name, category = cat,
      vibes = osm_vibe_keywords(tags), city = city_label, neighborhood = hood, address = address,
      lat = round(xy[[1]], 6), lon = round(xy[[2]], 6), opening_hours = osm_tag(tags, "opening_hours"),
      opens_at = "", closes_at = "", open_days = "", rating = NA_real_, reviews_count = NA_integer_,
      price_level = NA_integer_, maps_url = maps_search_url(name, address, sub(" - ", ", ", city_label)),
      osm_url = paste0("https://www.openstreetmap.org/", type, "/", el$id),
      website = osm_website(tags), source = "openstreetmap",
      .score = osm_score(tags)
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(empty)
  x <- as.data.frame(lapply(stats::setNames(nm = names(rows[[1]])), function(n) unlist(lapply(rows, `[[`, n))),
                     stringsAsFactors = FALSE)
  x <- osm_dedupe(x)
  x <- x[order(x$category, -x$.score, normalize_text(x$name)), , drop = FALSE]
  if (is.finite(per_category)) {
    x <- x[stats::ave(seq_len(nrow(x)), x$category, FUN = seq_along) <= per_category, , drop = FALSE]
  }
  x <- x[, PLACE_COLUMNS, drop = FALSE]
  rownames(x) <- NULL
  x
}

# A places data frame with no rows and the right column types.
empty_places <- function() {
  x <- as.data.frame(stats::setNames(rep(list(character()), length(PLACE_COLUMNS)), PLACE_COLUMNS),
                     stringsAsFactors = FALSE)
  for (col in c("lat", "lon", "rating")) x[[col]] <- numeric()
  for (col in c("reviews_count", "price_level")) x[[col]] <- integer()
  x
}

# Merge rows that share a name (accents and case ignored) within 50 m,
# keeping the most complete one.
osm_dedupe <- function(x, metres = 50) {
  if (nrow(x) < 2L) return(x)
  x <- x[order(-x$.score), , drop = FALSE]
  key <- normalize_text(x$name)
  drop <- rep(FALSE, nrow(x))
  for (k in unique(key[duplicated(key)])) {
    idx <- which(key == k)
    for (a in seq_along(idx)) {
      if (drop[idx[[a]]]) next
      for (b in idx[-seq_len(a)]) {
        if (!drop[b] && geo_distance_km(x$lat[idx[[a]]], x$lon[idx[[a]]], x$lat[b], x$lon[b]) * 1000 <= metres) {
          drop[b] <- TRUE
        }
      }
    }
  }
  x[!drop, , drop = FALSE]
}

# ------------------------------------------------------------- all cities

fetch_osm_places <- function(cities = load_cities(), cache_dir = "osm-cache", radius_km = 12,
                             per_category = 30, refresh = FALSE, pause = 5, retries = 3L,
                             endpoints = OVERPASS_ENDPOINTS, user_agent = osm_user_agent(),
                             fetch = osm_download, verbose = TRUE) {
  out <- vector("list", nrow(cities))
  for (i in seq_len(nrow(cities))) {
    ct <- cities[i, , drop = FALSE]
    slug <- gsub("[^a-z0-9]+", "-", normalize_text(ct$label))
    file <- file.path(cache_dir, sprintf("overpass-%s-%gkm.json", slug, radius_km))
    cached <- !refresh && file.exists(file)
    if (verbose) message(sprintf("[%d/%d] %s%s", i, nrow(cities), ct$label, if (cached) " (cached)" else ""))
    query <- overpass_query(ct$lat, ct$lon, radius_km * 1000)
    overpass_fetch(query, file, endpoints = endpoints, refresh = refresh, retries = retries, pause = pause,
                   user_agent = user_agent, fetch = fetch, verbose = verbose)
    out[[i]] <- osm_places_from_elements(osm_elements(file), ct$label, per_category)
    if (verbose) message(sprintf("      %d places", nrow(out[[i]])))
    # Be polite: Overpass is a shared, free service.
    if (!cached && i < nrow(cities) && pause > 0) Sys.sleep(pause)
  }
  x <- do.call(rbind, c(list(empty_places()), out))
  # Neighbouring cities (Recife and Olinda) overlap: a place belongs to the
  # city whose centre is closest.
  if (anyDuplicated(x$place_id)) {
    centre <- match(x$city, cities$label)
    d <- geo_distance_km(x$lat, x$lon, cities$lat[centre], cities$lon[centre])
    x <- x[order(x$place_id, d), , drop = FALSE]
    x <- x[!duplicated(x$place_id), , drop = FALSE]
    x <- x[order(match(x$city, cities$label), x$category), , drop = FALSE]
  }
  rownames(x) <- NULL
  x
}

# Write places in the column order load_places() expects (UTF-8, empty
# cells for missing values).
write_places_csv <- function(places, path) {
  missing <- setdiff(PLACE_COLUMNS, names(places))
  if (length(missing)) stop("places is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con))
  utils::write.csv(places[, PLACE_COLUMNS, drop = FALSE], con, row.names = FALSE, na = "")
  invisible(path)
}
