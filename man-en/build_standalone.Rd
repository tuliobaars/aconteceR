\name{build_standalone}
\alias{build_standalone}
\title{Build the standalone HTML edition}
\description{
Writes one self-contained HTML file with the whole app (styles, scripts,
Leaflet, translations and demo data inlined). It opens in any browser without
R or a server; map tiles need the internet. Lines of the template of the form
\code{@@include path} are replaced by the file \code{inst/path}.
}
\usage{
build_standalone(path = "index.html",
                 template = system.file("standalone", "template.html",
                                        package = "aconteceR"))
}
\arguments{
  \item{path}{Output file.}
  \item{template}{The page template, \code{inst/standalone/template.html}.}
}
\value{\code{path}, invisibly.}
\details{
\code{tools/build-standalone.mjs} in the source repository produces a
byte-identical file with Node.
}
\examples{
out <- tempfile(fileext = ".html")
build_standalone(out)
file.size(out) > 0
unlink(out)
}
