\name{external_site_catalog}
\alias{external_site_catalog}
\alias{autopopulate_events}
\title{Demo event sources and import}
\description{
The demo sources behind Search & import (\code{inst/extdata/sites.csv}) and
the import itself. The sources are simulated from templates
(\code{inst/extdata/site_templates.csv}); nothing is fetched from the sites.
Imports are validated and never stored twice.
}
\usage{
external_site_catalog(path = system.file("extdata", "sites.csv", package = "aconteceR"))

autopopulate_events(con, sites = external_site_catalog()$name, city = NULL,
                    query = "", cities_df = load_cities())
}
\arguments{
  \item{path}{CSV file with \code{name}, \code{label}, \code{domain}.}
  \item{con}{Database connection from \code{\link{db_connect}}.}
  \item{sites}{Source names to import from.}
  \item{city}{City label ("Recife - PE"), or \code{NULL} for every city.}
  \item{query}{Only import events matching these words.}
  \item{cities_df}{City table, see \code{\link{load_cities}}.}
}
\value{\code{external_site_catalog}: a data frame. \code{autopopulate_events}:
the number of events added.}
\examples{
con <- db_connect(":memory:")
autopopulate_events(con, sites = "meetup", city = "Recife - PE")
autopopulate_events(con, sites = "meetup", city = "Recife - PE")
DBI::dbDisconnect(con)
}
