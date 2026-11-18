\encoding{UTF-8}
\name{load_cities}
\alias{load_cities}
\title{A lista de cidades}
\description{
Lê as cidades atendidas pelo aplicativo (\code{inst/extdata/cities.csv}: city,
state, country, lat, lon). Adicionar uma cidade significa adicionar uma linha.
(Versão em inglês: \code{man-en/load_cities.Rd}.)
}
\usage{
load_cities(path = system.file("extdata", "cities.csv", package = "aconteceR"))
}
\arguments{
  \item{path}{Arquivo CSV.}
}
\value{Um data frame com \code{id}, \code{label} ("Cidade - UF"), \code{city},
\code{state}, \code{country}, \code{lat} e \code{lon}, ordenado pelo nome da
cidade.}
\examples{
head(load_cities())
}
