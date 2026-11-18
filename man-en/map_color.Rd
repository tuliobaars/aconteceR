\name{map_color}
\alias{map_color}
\alias{map_color_factor}
\alias{map_color_bins}
\title{Colour modes for the map and calendar}
\description{
Describe how points are coloured. \code{map_color_factor} colours by the values
of a categorical column; \code{map_color_bins} cuts a numeric column into
bins, right-closed like \code{\link{cut}}: (b0, b1], (b1, b2], and so on, with
b0 included in the first bin.
}
\usage{
map_color_factor(column, colors, labels = names(colors), label = column,
                 title = label, na_color = "#8c8c8c", na_label = "NA")

map_color_bins(column, breaks, colors, labels = NULL, label = column,
               title = label, na_color = "#8c8c8c", na_label = "NA",
               format = function(x) base::format(x, big.mark = ",",
                                                 scientific = FALSE, trim = TRUE))
}
\arguments{
  \item{column}{Name of the column in the points.}
  \item{colors}{For factors, a vector of colours named by the column's values; for bins,
    one colour per bin.}
  \item{labels}{Legend text: for factors named like \code{colors} (or in the same order);
    for bins one per bin (generated from the breaks when \code{NULL}).}
  \item{label}{Text of the colour-by button.}
  \item{title}{Legend title.}
  \item{na_color, na_label}{Colour and legend text for missing or unknown values.}
  \item{breaks}{Increasing bin edges; may start with \code{-Inf} or end with \code{Inf}.}
  \item{format}{Function turning break values into text for generated labels.}
}
\value{A list of class \code{ac_color_mode}.}
\examples{
map_color_factor("deal", colors = c(rent = "#1b9e77", buy = "#7570b3"),
                 labels = c(rent = "Aluguel", buy = "Venda"), label = "Tipo")
map_color_bins("price_m2", breaks = c(0, 8000, 12000, Inf),
               colors = c("#1a9850", "#fee08b", "#d73027"))$labels
}
