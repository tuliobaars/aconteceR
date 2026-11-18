\encoding{UTF-8}
\name{parse_ticket_cost}
\alias{parse_ticket_cost}
\alias{parse_jsonld_events}
\alias{scraper_specs}
\alias{ingest_html_payload}
\title{Analisar e ingerir eventos a partir de páginas de eventos}
\description{
Blocos básicos para raspagem (*scraping*) real. \code{parse_ticket_cost} lê
textos de preço em Português ou Inglês ("Grátis", "A partir de R$ 45,00",
"Doação"). \code{parse_jsonld_events} extrai objetos Schema.org \code{Event} dos
blocos JSON-LD de uma página HTML. \code{ingest_html_payload} analisa uma página
e armazena seus eventos novos e válidos. \code{scraper_specs} documenta a
estratégia e os seletores de cada fonte. (Versão em inglês:
\code{man-en/parse_ticket_cost.Rd}.)
}
\usage{
parse_ticket_cost(raw_text, default_currency = "BRL")

parse_jsonld_events(html_text, default_city = "S\\u00e3o Paulo - SP",
                    default_lat = -23.5505, default_lon = -46.6333, source = "scraper")

scraper_specs()

ingest_html_payload(con, html_text, city = "S\\u00e3o Paulo - SP", lat = -23.5505,
                    lon = -46.6333, source = "sympla")
}
\arguments{
  \item{raw_text}{Texto do preço.}
  \item{default_currency}{Código da moeda usado quando o texto não especifica nenhuma.}
  \item{html_text}{HTML de uma página de eventos.}
  \item{default_city, city}{Rótulo da cidade atribuído aos eventos.}
  \item{default_lat, default_lon, lat, lon}{Coordenadas usadas quando um evento não possui coordenadas próprias.}
  \item{source}{Nome da fonte armazenado junto com os eventos.}
  \item{con}{Conexão com o banco de dados obtida com \code{\link{db_connect}}.}
}
\value{
\code{parse_ticket_cost}: \code{list(price_type, price, currency)}.
\code{parse_jsonld_events}: um data frame de eventos. \code{scraper_specs}: uma
lista por fonte. \code{ingest_html_payload}:
\code{list(extracted, inserted, events)}.
}
\examples{
parse_ticket_cost("A partir de R$ 45,00")
parse_ticket_cost("Entrada franca")
names(scraper_specs())
}
