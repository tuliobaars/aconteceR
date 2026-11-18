\encoding{UTF-8}
\name{event_categories}
\alias{event_categories}
\alias{price_types}
\alias{price_band}
\alias{price_palette}
\alias{price_band_palette}
\alias{category_palette}
\alias{event_color_modes}
\title{Categorias de eventos, preços e suas cores}
\description{
As duas formas de classificar um evento (categoria e tipo de preço), as faixas
de preço usadas pelo modo "colorir por preço", as paletas e os modos de cor do
mapa de eventos (consulte \code{\link{map_color_factor}}). (Versão em inglês:
\code{man-en/event_categories.Rd}.)
}
\usage{
event_categories(lang = "en")
price_types(lang = "en")
price_band(price_type, price = NA_real_)
price_palette()
price_band_palette()
category_palette()
event_color_modes(lang = "en")
}
\arguments{
  \item{lang}{\code{"pt"} ou \code{"en"}.}
  \item{price_type}{Vetor de caracteres: \code{"free"}, \code{"paid"}, \code{"donation"} ou \code{"unknown"}.}
  \item{price}{Preço do ingresso (reciclado até o comprimento de \code{price_type}).}
}
\value{
\code{event_categories} e \code{price_types}: vetores de caracteres nomeados
(chave = rótulo). \code{price_band}: um entre \code{"free"}, \code{"donation"},
\code{"p1"} (até R$ 30), \code{"p2"} (30 a 60), \code{"p3"} (60 a 100),
\code{"p4"} (acima de 100), \code{"paid_na"} ou \code{"unknown"} por evento. As
paletas: vetores de cores nomeados. \code{event_color_modes}: uma lista nomeada
com os modos de cor \code{price} e \code{category}.
}
\examples{
event_categories("pt")
price_band(c("free", "paid", "paid", "paid"), c(NA, 25, 45, 150))
names(event_color_modes("en"))
}
