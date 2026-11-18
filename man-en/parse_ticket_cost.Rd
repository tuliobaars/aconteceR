\name{parse_ticket_cost}
\alias{parse_ticket_cost}
\alias{parse_jsonld_events}
\alias{scraper_specs}
\alias{ingest_html_payload}
\title{Parse and ingest events from event pages}
\description{
Building blocks for real scraping. \code{parse_ticket_cost} reads Brazilian
or English price text ("Grátis", "A partir de R$ 45,00", "Doação").
\code{parse_jsonld_events} extracts Schema.org \code{Event} objects from the
JSON-LD blocks of an HTML page. \code{ingest_html_payload} parses a page and
stores its valid, new events. \code{scraper_specs} documents the strategy and
selectors per source.
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
  \item{raw_text}{Price text.}
  \item{default_currency}{Currency code used when the text names none.}
  \item{html_text}{HTML of an event page.}
  \item{default_city, city}{City label given to the events.}
  \item{default_lat, default_lon, lat, lon}{Coordinates used when an event has none.}
  \item{source}{Source name stored with the events.}
  \item{con}{Database connection from \code{\link{db_connect}}.}
}
\value{
\code{parse_ticket_cost}: \code{list(price_type, price, currency)}.
\code{parse_jsonld_events}: an events data frame. \code{scraper_specs}: a list
per source. \code{ingest_html_payload}: \code{list(extracted, inserted, events)}.
}
\examples{
parse_ticket_cost("A partir de R$ 45,00")
parse_ticket_cost("Entrada franca")
names(scraper_specs())
}
