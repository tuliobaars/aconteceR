\name{run_app}
\alias{run_app}
\title{Run the aconteceR Shiny app}
\description{
Starts the bilingual (Brazilian Portuguese / English) event app: a map of
events coloured by price or category, with clustering, a monthly calendar,
search and import from demo sources, and a form to add events; places (bars,
restaurants, nightclubs, ...) classified by vibe; and "Can't decide?", which
ranks places and events by what is open, vibe, rating and budget. The page opens
in the visitor's language and on the city closest to them. Every time the app is
opened, it automatically updates events (\code{\link{update_events}}) and
generates the standalone HTML edition (\code{\link{build_standalone}}).
}
\usage{
run_app(db_path = default_db_path(), seed_samples = TRUE,
        cities = load_cities(), default_lang = "pt", options = list(),
        places = load_places(), standalone_path = "index.html")
}
\arguments{
  \item{db_path}{Path of the SQLite file that stores events (see \code{\link{default_db_path}}).}
  \item{seed_samples}{Update the demo and catalog events on start (\code{\link{update_events}}).}
  \item{cities}{City table, see \code{\link{load_cities}}.}
  \item{default_lang}{\code{"pt"} or \code{"en"}: the language used when neither
    \code{?lang=} nor the browser names Portuguese, English or a Brazilian locale.}
  \item{options}{Passed to \code{\link[shiny]{shinyApp}}.}
  \item{places}{Places table (bars, restaurants, clubs, ...), see \code{\link{load_places}}.}
  \item{standalone_path}{Path to generate the standalone HTML edition
    (default: \code{"index.html"}) every time the app is opened; \code{NULL} skips it.}
}
\value{A \code{shiny.appobj}.}
\seealso{\code{\link{build_standalone}} for the single-file HTML edition and
\code{\link{update_events}} for refreshing events.}
\examples{
\dontrun{
run_app()
run_app(default_lang = "en", db_path = tempfile(fileext = ".sqlite"))
}
}
