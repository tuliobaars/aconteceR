\encoding{UTF-8}
\name{mod_calendar}
\alias{mod_calendar}
\alias{mod_calendar_ui}
\alias{mod_calendar_server}
\title{Módulo de calendário mensal}
\description{
Uma grade mensal desenhada no navegador, com *chips* de eventos coloridos como
os pinos do mapa, agenda diária, navegação por teclado e ações "mostrar este dia
/ mês no mapa". (Versão em inglês: \code{man-en/mod_calendar.Rd}.)
}
\usage{
mod_calendar_ui(id, color_from = NULL)

mod_calendar_server(id, events, lang = shiny::reactive("en"))
}
\arguments{
  \item{id}{Identificador do módulo.}
  \item{color_from}{Identificador do elemento de um mapa \code{\link{mod_map_ui}} (\code{"<map id>-pm"});
    o calendário passa então a acompanhar a escolha de modo de cor desse mapa.}
  \item{events}{Data frame reativo de eventos (colunas conforme retornadas pelo banco de dados,
    mais \code{price_band}). Passe eventos que não estejam limitados por um filtro de data.}
  \item{lang}{Idioma reativo, \code{"pt"} ou \code{"en"}.}
}
\value{
\code{mod_calendar_ui} retorna uma tag HTML. \code{mod_calendar_server} retorna
uma lista de reativos \code{focus} (um evento clicado), \code{show_day}
(\code{"YYYY-MM-DD"}), \code{show_month} (\code{"YYYY-MM"}), \code{month} e
\code{day}.
}
\examples{
mod_calendar_ui("calendar", color_from = "map-pm")
}
