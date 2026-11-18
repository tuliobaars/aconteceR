\encoding{UTF-8}
\name{map_color}
\alias{map_color}
\alias{map_color_factor}
\alias{map_color_bins}
\title{Modos de cor para o mapa e o calendário}
\description{
Descreve como os pontos são coloridos. \code{map_color_factor} colore pelos
valores de uma coluna categórica; \code{map_color_bins} divide uma coluna
numérica em faixas fechadas à direita como \code{\link{cut}}: (b0, b1],
(b1, b2], e assim por diante, com b0 incluído na primeira faixa. (Versão em
inglês: \code{man-en/map_color.Rd}.)
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
  \item{column}{Nome da coluna nos pontos.}
  \item{colors}{Para fatores, um vetor de cores nomeado pelos valores da coluna; para faixas,
    uma cor por faixa.}
  \item{labels}{Texto da legenda: para fatores, nomeado como \code{colors} (ou na mesma ordem);
    para faixas, um por faixa (gerado a partir dos limites quando \code{NULL}).}
  \item{label}{Texto do botão "colorir por".}
  \item{title}{Título da legenda.}
  \item{na_color, na_label}{Cor e texto da legenda para valores ausentes ou desconhecidos.}
  \item{breaks}{Limites crescentes das faixas; pode começar com \code{-Inf} ou terminar com \code{Inf}.}
  \item{format}{Função que formata os valores dos limites como texto para os rótulos gerados.}
}
\value{Uma lista da classe \code{ac_color_mode}.}
\examples{
map_color_factor("deal", colors = c(rent = "#1b9e77", buy = "#7570b3"),
                 labels = c(rent = "Aluguel", buy = "Venda"), label = "Tipo")
map_color_bins("price_m2", breaks = c(0, 8000, 12000, Inf),
               colors = c("#1a9850", "#fee08b", "#d73027"))$labels
}
