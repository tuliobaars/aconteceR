\name{mod_map}
\alias{mod_map}
\alias{mod_map_ui}
\alias{mod_map_server}
\title{Reusable map module}
\description{
A Shiny module with a Leaflet map drawn in the browser: a place picker, a
colour-by switch, clustering, locate / fit / re-centre buttons, a legend with
counts, click-to-pick and fly-to-focus. It knows nothing about events, so other
projects (for example a rent and buy price map) reuse it with their own points,
colour modes and popups. Optionally it groups points by a column (for
example a neighbourhood) into one bubble per group, and draws a numbered
route between stops.
}
\usage{
mod_map_ui(id, cities, selected = NULL, color_mode = NULL, cluster = FALSE,
           auto_locate = is.null(selected), locate = TRUE, pickable = TRUE,
           zoom = 12, tiles = NULL, place_target = NULL, modes_target = NULL,
           toolbar_end = NULL, overlays = NULL, group_by = NULL)

mod_map_server(id, cities, points = shiny::reactive(NULL), color_modes = NULL,
               popup_fun = NULL, label_fun = NULL, focus = shiny::reactive(NULL),
               lang = shiny::reactive("en"), selected = NULL,
               extra_columns = character())
}
\arguments{
  \item{id}{Module id.}
  \item{cities}{Data frame of places with \code{id}, \code{label}, \code{lat}, \code{lon}
    (and optionally \code{city}, a short name), e.g. \code{\link{load_cities}()}.}
  \item{selected}{Place id to open on. \code{NULL} opens on the default place and,
    with \code{auto_locate}, moves to the place closest to the visitor.}
  \item{color_mode}{Id of the colour mode active at start (default: the first).}
  \item{cluster}{Start with clustering on.}
  \item{auto_locate}{Guess the closest place from the visitor's time zone, then from the
    browser's geolocation if allowed.}
  \item{locate}{Show the "closest place to me" button.}
  \item{pickable}{Clicking the map drops a pin and reports its coordinates.}
  \item{zoom}{Zoom level for places.}
  \item{tiles}{\code{NULL} or \code{"auto"}: key-free tiles, OpenStreetMap, or Esri's
    public street map when the page is opened from disk (OpenStreetMap wants a
    Referer). Also \code{"osm"}, \code{"esri"}, \code{list(url =, attribution =)}, or
    \code{list(light = list(...), dark = list(...))}. The colours follow the time of
    day through a CSS filter.}
  \item{place_target, modes_target}{CSS selectors of elements elsewhere on the page that
    hold the place picker and the colour-by switch; by default they sit on the map.}
  \item{toolbar_end}{Extra tags for the end of the floating map bar.}
  \item{overlays}{Named list of tags drawn over the map when the map element's
    \code{data-view} attribute equals the name (for example a calendar view).}
  \item{group_by}{Name of a point column (e.g. \code{"neighborhood"}). A switch in the
    map bar then shows one bubble per group instead of the pins: sized by count,
    coloured by the active colour mode (its most common level, or the bin of the
    median value for numeric modes), with the largest groups in the legend.
    Clicking a bubble zooms to its pins. Send the column with \code{extra_columns}.}
  \item{extra_columns}{Point columns to send to the browser besides the ones the
    colour modes read (e.g. the \code{group_by} column).}
  \item{points}{Reactive data frame with \code{id}, \code{lat}, \code{lon} and the columns
    the colour modes read.}
  \item{color_modes}{Named list of \code{\link{map_color_factor}} / \code{\link{map_color_bins}}
    specs, a function of the language returning one, or a reactive returning one
    (to switch between sets, as the app does between events and places).}
  \item{popup_fun}{Function of the points returning popup HTML (escape text with
    \code{\link{escape_html}}). It may take a \code{lang} argument.}
  \item{label_fun}{Function of the points returning plain-text hover labels.}
  \item{focus}{Reactive returning \code{list(id =, point =)} to fly to a point and open its
    popup; \code{point} is a one-row data frame used when the id is not among the points.}
  \item{lang}{Reactive language, \code{"pt"} or \code{"en"}.}
}
\value{
\code{mod_map_ui} returns a tag. \code{mod_map_server} returns a list of
reactives \code{city}, \code{clicked}, \code{selected_id}, \code{color_mode},
\code{cluster}, \code{group}, \code{located} and functions \code{clear_pick()},
\code{set_city(id)}, \code{fit()}, \code{fit_next()}, \code{show_route(stops)}
(numbered stops joined by a dotted line; \code{stops} is a data frame with
\code{lat}, \code{lon} and optional \code{label}, \code{popup}),
\code{clear_route()} and \code{set_group(on)}.
}
\examples{
places <- load_cities()
ui <- mod_map_ui("map", places, cluster = TRUE, group_by = "neighborhood")
modes <- list(
  price = map_color_bins("price_m2", breaks = c(0, 8000, 12000, Inf),
                         colors = c("#1a9850", "#fee08b", "#d73027"), label = "R$/m2"),
  deal = map_color_factor("deal", colors = c(rent = "#1b9e77", buy = "#7570b3"))
)
\dontrun{
server <- function(input, output, session) {
  map <- mod_map_server("map", places, points = shiny::reactive(listings),
                        color_modes = modes, extra_columns = "neighborhood",
                        label_fun = function(pts) pts$address)
}
}
}
