\name{escape_html}
\alias{escape_html}
\title{Escape text for HTML}
\description{
Escapes markup and quotes so user or scraped text is safe inside HTML strings
such as map popups. \code{NA} becomes empty text.
}
\usage{
escape_html(x)
}
\arguments{
  \item{x}{Character vector.}
}
\value{A character vector.}
\examples{
escape_html("<b>Rock & roll</b>")
}
