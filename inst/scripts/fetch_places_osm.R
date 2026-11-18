#!/usr/bin/env Rscript
# Download bars, pubs, clubs, restaurants, cafés, concert halls and cultural
# spots for every city in inst/extdata/cities.csv from OpenStreetMap (Overpass
# API) and write inst/extdata/places.csv.
#
# No API key, account or token is needed or used. Run from the package root:
#
#   Rscript inst/scripts/fetch_places_osm.R                 # all cities
#   Rscript inst/scripts/fetch_places_osm.R --per-category=Inf --radius=15
#   Rscript inst/scripts/fetch_places_osm.R --refresh       # ignore the cache
#   Rscript inst/scripts/fetch_places_osm.R --city="Recife - PE"
#
# Raw Overpass answers are kept in ./osm-cache (git-ignored), one JSON file per
# city, so an interrupted run continues where it stopped and re-running with a
# different --per-category needs no network at all. Expect a few minutes for
# 40 cities: the script pauses between requests, as the Overpass usage policy
# asks. Afterwards rebuild the standalone HTML (node tools/build-standalone.mjs
# or aconteceR::build_standalone()) so it embeds the new places.
#
# Data (c) OpenStreetMap contributors, ODbL 1.0
# (https://www.openstreetmap.org/copyright). places.csv is a derived database
# under the same licence; keep the attribution when you publish it.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  hit <- grep(paste0("^--", name, "(=|$)"), args, value = TRUE)
  if (!length(hit)) return(default)
  if (!grepl("=", hit[[1]])) return(TRUE)
  sub("^[^=]*=", "", hit[[1]])
}

if (file.exists("DESCRIPTION") && requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE, export_all = TRUE)
  ns <- asNamespace("aconteceR")
} else {
  ns <- asNamespace("aconteceR")  # installed package
}
out_path <- opt("out", file.path("inst", "extdata", "places.csv"))
cache_dir <- opt("cache", "osm-cache")
radius_km <- as.numeric(opt("radius", 12))
per_category <- as.numeric(opt("per-category", 30))
refresh <- isTRUE(opt("refresh", FALSE))
only_city <- opt("city", NULL)

cities <- ns$load_cities()
if (!is.null(only_city)) {
  cities <- cities[cities$label %in% strsplit(only_city, ";", fixed = TRUE)[[1]], , drop = FALSE]
  if (!nrow(cities)) stop("No city called ", only_city, " in cities.csv (use the 'City - UF' label).")
}

message(sprintf("Fetching %d cities from OpenStreetMap (radius %g km, up to %s places per category per city)",
                nrow(cities), radius_km, format(per_category)))
places <- ns$fetch_osm_places(cities, cache_dir = cache_dir, radius_km = radius_km,
                              per_category = per_category, refresh = refresh)

if (!is.null(only_city) && file.exists(out_path)) {
  # Replace only the fetched cities, keep the others.
  old <- utils::read.csv(out_path, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  if (all(ns$PLACE_COLUMNS %in% names(old))) {
    old <- old[!old$city %in% cities$label, ns$PLACE_COLUMNS, drop = FALSE]
    for (col in c("lat", "lon", "rating")) old[[col]] <- as.numeric(old[[col]])
    for (col in c("reviews_count", "price_level")) old[[col]] <- as.integer(old[[col]])
    places <- rbind(old, places)
  }
}

ns$write_places_csv(places, out_path)
counts <- table(places$category)
message(sprintf("Wrote %d places to %s", nrow(places), out_path))
message(paste(sprintf("  %-15s %5d", names(counts), as.integer(counts)), collapse = "\n"))
message(sprintf("  with opening hours: %d (%.0f%%)", sum(nzchar(places$opening_hours)),
                100 * mean(nzchar(places$opening_hours))))
message("Next: node tools/build-standalone.mjs (or aconteceR::build_standalone()) to refresh index.html.")
