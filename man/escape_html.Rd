\encoding{UTF-8}
\name{escape_html}
\alias{escape_html}
\title{Escapar texto para HTML}
\description{
Escapa marcações e aspas para que textos fornecidos pelo usuário ou extraídos de
páginas sejam seguros dentro de strings HTML, como popups do mapa. \code{NA}
torna-se texto vazio. (Versão em inglês: \code{man-en/escape_html.Rd}.)
}
\usage{
escape_html(x)
}
\arguments{
  \item{x}{Vetor de caracteres.}
}
\value{Um vetor de caracteres.}
\examples{
escape_html("<b>Rock & roll</b>")
}
