\name{load_cities}
\alias{load_cities}
\title{The city list}
\description{
Reads the cities the app covers (\code{inst/extdata/cities.csv}: city, state,
country, lat, lon). Adding a city means adding a row.
}
\usage{
load_cities(path = system.file("extdata", "cities.csv", package = "aconteceR"))
}
\arguments{
  \item{path}{CSV file.}
}
\value{A data frame with \code{id}, \code{label} ("City - ST"), \code{city},
\code{state}, \code{country}, \code{lat} and \code{lon}, sorted by city name.}
\examples{
head(load_cities())
}
