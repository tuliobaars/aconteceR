\name{run_app}
\alias{run_app}
\title{Run the aconteceR Shiny app}
\description{
Starts the bilingual (Brazilian Portuguese / English) event app: a map of
events coloured by price or category, with clustering, a monthly calendar,
search and import from demo sources, and a form to add events; places (bars,
restaurants, nightclubs, ...) classified by vibe; and "Can't decide?", which
ranks places and events by what is open, vibe, rating and budget. The page opens
in the visitor's language and on the city closest to them.
}
\usage{
run_app(db_path = default_db_path(), seed_samples = TRUE,
        cities = load_cities(), default_lang = "pt", options = list(),
        places = load_places())
}
\arguments{
  \item{db_path}{Path of the SQLite file that stores events (see \code{\link{default_db_path}}).}
  \item{seed_samples}{Load the demo events on start. They are marked \code{source = "sample"}
    and are dated again once they have all passed.}
  \item{cities}{City table, see \code{\link{load_cities}}.}
  \item{default_lang}{\code{"pt"} or \code{"en"}: the language used when neither
    \code{?lang=} nor the browser names Portuguese, English or a Brazilian locale.}
  \item{options}{Passed to \code{\link[shiny]{shinyApp}}.}
  \item{places}{Places table (bars, restaurants, clubs, ...), see \code{\link{load_places}}.}
}
\value{A \code{shiny.appobj}.}
\seealso{\code{\link{build_standalone}} for the single-file HTML edition.}
\examples{
\dontrun{
run_app()
run_app(default_lang = "en", db_path = tempfile(fileext = ".sqlite"))
}
}
