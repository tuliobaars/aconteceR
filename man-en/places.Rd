\name{places}
\alias{places}
\alias{load_places}
\alias{classify_vibes}
\alias{place_open_status}
\alias{parse_opening_hours}
\alias{is_open_late}
\alias{place_categories}
\alias{vibe_groups}
\alias{place_color_modes}
\title{Places: bars, restaurants, nightclubs and more, by vibe and opening hours}
\description{
\code{load_places} reads \code{inst/extdata/places.csv} (one row per place),
checks its columns and classifies every place into vibe groups.
\code{classify_vibes} maps free text (vibe keywords, titles, descriptions) to
the vibe groups with the keyword rules in \code{inst/extdata/vibes.csv}: a
pattern matches at the start of a word, a trailing \code{$} asks for the whole
word, and \code{@category} tokens add category defaults.
\code{parse_opening_hours} reads OpenStreetMap \code{opening_hours} values into
a weekly schedule. \code{place_open_status} says whether places are open at a
given weekday and time, from \code{opening_hours} when given, otherwise from
the simple \code{opens_at} / \code{closes_at} / \code{open_days} columns.
\code{is_open_late} tells which places are still open at 02:00 tonight.
\code{place_categories} and \code{vibe_groups} give the labels;
\code{place_color_modes} the map's colour modes (category, vibe, opening
status and rating).
}
\usage{
load_places(path = system.file("extdata", "places.csv", package = "aconteceR"),
            rules = vibe_rules())

classify_vibes(text, rules = vibe_rules())

parse_opening_hours(x)

place_open_status(opens_at, closes_at, open_days, wday, minutes,
                  opening_hours = NULL)

is_open_late(places, clock)

place_categories(lang = "en")

vibe_groups(lang = "en")

place_color_modes(lang = "en", rating = TRUE)
}
\arguments{
  \item{path}{CSV file. Required columns: \code{place_id}, \code{name},
    \code{category}, \code{city} (a label from \code{\link{load_cities}}),
    \code{lat}, \code{lon}. Optional: \code{vibes} (keywords),
    \code{neighborhood}, \code{address}, \code{opening_hours}, \code{opens_at},
    \code{closes_at}, \code{open_days}, \code{rating}, \code{reviews_count},
    \code{price_level} (1-4), \code{maps_url}, \code{osm_url}, \code{website},
    \code{source}. Older files with \code{google_rating} /
    \code{google_maps_url} still load. \code{\link{fetch_osm_places}} writes
    this format.}
  \item{rules}{Data frame of vibe rules with columns \code{vibe} and \code{pattern}.}
  \item{text}{Character vector to classify.}
  \item{x, opening_hours}{OpenStreetMap \code{opening_hours} strings, e.g.
    \code{"Mo-Sa 18:00-02:00; Su off"}. Supported: rules separated by
    \code{;} (later rules win for their days), weekday ranges and lists in
    English or Portuguese (\code{"seg-sex"}), several time ranges per day,
    times past midnight (\code{"22:00-26:00"}), open ends (\code{"22:00+"},
    read as four hours), \code{off}, \code{24/7}. Rules with months, weeks,
    holidays or sunrise/sunset are skipped.}
  \item{opens_at, closes_at}{Times as \code{"HH:MM"}; a closing time at or
    before the opening time runs past midnight.}
  \item{open_days}{Days in Portuguese abbreviations: ranges that wrap the week
    (\code{"Ter-Dom"}), lists (\code{"Seg,Qua,Sex"}) or \code{"Todos"}.}
  \item{wday}{Weekday of the moment, 0 (Sunday) to 6.}
  \item{minutes}{Minutes after midnight of the moment (the visitor's local time).}
  \item{places}{A places data frame (from \code{load_places}).}
  \item{clock}{\code{list(wday, minutes)}: the visitor's clock.}
  \item{lang}{\code{"pt"} or \code{"en"}.}
  \item{rating}{Include the rating colour mode (leave it out for data without
    ratings, such as OpenStreetMap).}
}
\value{
\code{load_places}: a data frame with the file's columns plus \code{vibe_groups}
(comma-separated vibe keys) and \code{vibe_main}. \code{classify_vibes}: a
character vector of comma-separated vibe keys. \code{parse_opening_hours}: a
list with one schedule per value (\code{NULL} when nothing could be read).
\code{place_open_status}: a data frame with \code{open}, \code{to_close},
\code{to_open} (minutes), \code{days_ahead} (0 = opens later today),
\code{unknown} (no readable hours), \code{always} (24/7) and the
\code{opens_label} / \code{closes_label} times. \code{is_open_late}: logical.
\code{place_categories}, \code{vibe_groups}: named character vectors (key =
label). \code{place_color_modes}: a named list of colour modes for
\code{\link{mod_map_server}}.
}
\details{
Rows whose \code{source} is not \code{"google_places_api"} or
\code{"openstreetmap"} are treated as demo data and the app says so. Until
you run \code{inst/scripts/fetch_places_osm.R}, the bundled file is generated
demo data. OpenStreetMap rows make the app show the ODbL attribution.
}
\examples{
p <- load_places()
table(p$category)[1:3]
classify_vibes(c("roda de samba ao vivo", "rooftop com por-do-sol"))
# A bar open 17:00-01:00 Tuesday to Sunday, on a Wednesday at 00:30:
place_open_status("17:00", "01:00", "Ter-Dom", wday = 3, minutes = 30)
# The same with OpenStreetMap hours:
place_open_status(NA, NA, NA, wday = 3, minutes = 30, opening_hours = "Tu-Su 17:00-01:00")
is_open_late(data.frame(opening_hours = c("Mo-Su 18:00-03:00", "Mo-Su 18:00-00:00"),
                        opens_at = NA, closes_at = NA, open_days = NA),
             clock = list(wday = 5, minutes = 22 * 60))
vibe_groups("pt")
}
