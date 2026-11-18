\encoding{UTF-8}
\name{build_standalone}
\alias{build_standalone}
\title{Gerar a edição HTML autônoma}
\description{
Grava um único arquivo HTML autossuficiente com todo o aplicativo (estilos,
scripts, Leaflet, traduções e dados de demonstração embutidos). Ele abre em
qualquer navegador sem precisar de R ou de um servidor; os blocos do mapa
precisam de conexão com a internet. As linhas do modelo na forma
\code{@@include path} são substituídas pelo conteúdo de \code{inst/path}.
}
\usage{
build_standalone(path = "index.html",
                 template = system.file("standalone", "template.html",
                                        package = "aconteceR"))
}
\arguments{
  \item{path}{Arquivo de saída.}
  \item{template}{O modelo da página, \code{inst/standalone/template.html}.}
}
\value{\code{path}, invisivelmente.}
\details{
O script \code{tools/build-standalone.mjs} no repositório-fonte gera um arquivo
idêntico byte a byte usando Node. (Versão em inglês:
\code{man-en/build_standalone.Rd}.)
}
\examples{
out <- tempfile(fileext = ".html")
build_standalone(out)
file.size(out) > 0
unlink(out)
}
