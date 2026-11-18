\encoding{UTF-8}
\name{external_site_catalog}
\alias{external_site_catalog}
\alias{autopopulate_events}
\title{Fontes de eventos de demonstração e importação}
\description{
As fontes de demonstração por trás de Buscar e importar
(\code{inst/extdata/sites.csv}) e a importação em si. As fontes são simuladas a
partir de modelos (\code{inst/extdata/site_templates.csv}); nada é baixado dos
sites externos. Os eventos importados são validados e nunca armazenados em
duplicidade. (Versão em inglês: \code{man-en/external_site_catalog.Rd}.)
}
\usage{
external_site_catalog(path = system.file("extdata", "sites.csv", package = "aconteceR"))

autopopulate_events(con, sites = external_site_catalog()$name, city = NULL,
                    query = "", cities_df = load_cities(), today = Sys.Date())
}
\arguments{
  \item{path}{Arquivo CSV com \code{name}, \code{label}, \code{domain}.}
  \item{con}{Conexão com o banco de dados obtida com \code{\link{db_connect}}.}
  \item{sites}{Nomes das fontes das quais importar.}
  \item{city}{Rótulo da cidade ("Recife - PE"), ou \code{NULL} para todas as cidades.}
  \item{query}{Importar apenas eventos que correspondam a estas palavras.}
  \item{cities_df}{Tabela de cidades, consulte \code{\link{load_cities}}.}
  \item{today}{Data de referência (\code{Date}) para gerar as datas dos eventos.}
}
\value{\code{external_site_catalog}: um data frame. \code{autopopulate_events}:
o número de eventos adicionados.}
\examples{
con <- db_connect(":memory:")
autopopulate_events(con, sites = "meetup", city = "Recife - PE")
autopopulate_events(con, sites = "meetup", city = "Recife - PE")
DBI::dbDisconnect(con)
}
