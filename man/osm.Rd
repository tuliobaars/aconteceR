\name{osm}
\alias{osm}
\alias{fetch_osm_places}
\alias{overpass_query}
\alias{osm_category}
\alias{write_places_csv}
\title{Places from OpenStreetMap (Overpass API, no key needed)}
\description{
\code{fetch_osm_places} downloads bars, pubs, nightclubs, restaurants, cafes,
concert halls, theatres, cinemas, galleries and dance halls around each city
from OpenStreetMap through the public Overpass API, maps their tags to the
app's ten categories and vibe keywords, and returns them in the places format
(see \code{\link{load_places}}). Raw answers are cached as JSON, one file per
city, so an interrupted run continues where it stopped and a re-run needs no
network. \code{write_places_csv} writes the result for \code{load_places}.
\code{overpass_query} builds the Overpass QL for one city and
\code{osm_category} maps one place's tags to a category.
}
\usage{
fetch_osm_places(cities = load_cities(), cache_dir = "osm-cache", radius_km = 12,
                 per_category = 30, refresh = FALSE, pause = 5, retries = 3L,
                 endpoints = OVERPASS_ENDPOINTS, user_agent = osm_user_agent(),
                 fetch = osm_download, verbose = TRUE)

write_places_csv(places, path)

overpass_query(lat, lon, radius_m = 12000, timeout = 180)

osm_category(tags)
}
\arguments{
  \item{cities}{Data frame with \code{label}, \code{lat}, \code{lon}
    (\code{\link{load_cities}}).}
  \item{cache_dir}{Folder for the raw Overpass answers.}
  \item{radius_km, radius_m}{Search radius around the city centre.}
  \item{per_category}{Most places kept per category and city, the most
    complete first (opening hours count most); \code{Inf} keeps all.}
  \item{refresh}{Download again even when a cached answer exists.}
  \item{pause}{Seconds to wait between requests (doubled on each retry
    round), as the Overpass usage policy asks.}
  \item{retries}{Rounds over all endpoints before giving up.}
  \item{endpoints}{Overpass API URLs, tried in turn.}
  \item{user_agent}{User-Agent header identifying the client.}
  \item{fetch}{\code{function(url, destfile, user_agent)} that downloads a URL
    to a file; replaceable for tests or a proxy.}
  \item{verbose}{Print progress.}
  \item{places}{A places data frame.}
  \item{path}{Output CSV file.}
  \item{lat, lon}{City centre.}
  \item{timeout}{Overpass server-side timeout in seconds.}
  \item{tags}{Named list of one element's OSM tags.}
}
\value{
\code{fetch_osm_places}: a data frame with the places columns; \code{rating},
\code{reviews_count} and \code{price_level} are empty (OpenStreetMap has no
ratings), \code{maps_url} is a Google Maps search link (no key),
\code{osm_url} the element's page and \code{source} is \code{"openstreetmap"}.
A place found for two overlapping cities is kept in the closer one.
\code{overpass_query}: a string. \code{osm_category}: a category key or
\code{NA}.
}
\details{
Data (c) OpenStreetMap contributors, available under the Open Database
Licence (ODbL 1.0, \url{https://www.openstreetmap.org/copyright}). The
resulting places file is a derived database under the same licence; the app
shows the attribution whenever it lists OpenStreetMap places.
The script \code{inst/scripts/fetch_places_osm.R} runs the whole download
and writes \code{inst/extdata/places.csv}.
}
\examples{
cat(overpass_query(-8.05, -34.9, 5000))
osm_category(list(amenity = "bar", name = "Terra\u00e7o Sunset"))
\dontrun{
# Needs the internet; takes a few minutes for all cities.
places <- fetch_osm_places()
write_places_csv(places, "inst/extdata/places.csv")
}
}
