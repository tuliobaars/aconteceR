\name{event_categories}
\alias{event_categories}
\alias{price_types}
\alias{price_band}
\alias{price_palette}
\alias{price_band_palette}
\alias{category_palette}
\alias{event_color_modes}
\title{Event categories, prices and their colours}
\description{
The two ways an event is classified (category and price type), the price bands
used by "colour by price", the palettes, and the colour modes of the events
map (see \code{\link{map_color_factor}}).
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
  \item{lang}{\code{"pt"} or \code{"en"}.}
  \item{price_type}{Character vector: \code{"free"}, \code{"paid"}, \code{"donation"} or \code{"unknown"}.}
  \item{price}{Ticket price (recycled to the length of \code{price_type}).}
}
\value{
\code{event_categories} and \code{price_types}: named character vectors
(key = label). \code{price_band}: one of \code{"free"}, \code{"donation"},
\code{"p1"} (up to R$ 30), \code{"p2"} (30 to 60), \code{"p3"} (60 to 100),
\code{"p4"} (over 100), \code{"paid_na"} or \code{"unknown"} per event. The
palettes: named colour vectors. \code{event_color_modes}: a named list with
\code{price} and \code{category} colour modes.
}
\examples{
event_categories("pt")
price_band(c("free", "paid", "paid", "paid"), c(NA, 25, 45, 150))
names(event_color_modes("en"))
}
