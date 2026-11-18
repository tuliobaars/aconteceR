\name{mod_calendar}
\alias{mod_calendar}
\alias{mod_calendar_ui}
\alias{mod_calendar_server}
\title{Monthly calendar module}
\description{
A month grid drawn in the browser, with event chips coloured like the map's
pins, a day agenda, keyboard navigation and "show this day / month on the map"
actions.
}
\usage{
mod_calendar_ui(id, color_from = NULL)

mod_calendar_server(id, events, lang = shiny::reactive("en"))
}
\arguments{
  \item{id}{Module id.}
  \item{color_from}{Element id of a \code{\link{mod_map_ui}} map (\code{"<map id>-pm"});
    the calendar then follows that map's colour-by choice.}
  \item{events}{Reactive data frame of events (columns as returned by the database,
    plus \code{price_band}). Pass events that are not limited by a date filter.}
  \item{lang}{Reactive language, \code{"pt"} or \code{"en"}.}
}
\value{
\code{mod_calendar_ui} returns a tag. \code{mod_calendar_server} returns a list
of reactives \code{focus} (a clicked event), \code{show_day} (\code{"YYYY-MM-DD"}),
\code{show_month} (\code{"YYYY-MM"}), \code{month} and \code{day}.
}
\examples{
mod_calendar_ui("calendar", color_from = "map-pm")
}
