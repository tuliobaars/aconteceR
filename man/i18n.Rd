\encoding{UTF-8}
\name{i18n}
\alias{i18n}
\alias{tr}
\alias{detect_lang}
\title{Traduções e detecção de idioma}
\description{
\code{tr} busca uma string no dicionário compartilhado
(\code{inst/i18n/strings.json}, Português do Brasil e Inglês), usando Inglês e
depois a própria chave como fallback. \code{detect_lang} escolhe o idioma a
partir de um cabeçalho HTTP \code{Accept-Language}: Português em qualquer
posição da lista, ou uma tag de região brasileira como \code{en-BR}, retorna
\code{"pt"}; caso contrário, Inglês se estiver listado; ou então \code{default}.
(O navegador aplica a mesma regra e também verifica o fuso horário.) (Versão em
inglês: \code{man-en/i18n.Rd}.)
}
\usage{
tr(key, lang = "en")

detect_lang(accept_language, default = "en")
}
\arguments{
  \item{key}{Chave do dicionário.}
  \item{lang}{\code{"pt"} (ou \code{"pt-BR"}) ou \code{"en"}; qualquer outro valor resulta em Inglês.}
  \item{accept_language}{Valor do cabeçalho, ex.: \code{"pt-BR,pt;q=0.9,en;q=0.8"}.}
  \item{default}{Idioma quando o cabeçalho não menciona Português, Inglês nem Brasil.}
}
\value{\code{tr}: uma string (ou vetor de caracteres para entradas em lista,
como nomes de meses). \code{detect_lang}: \code{"pt"} ou \code{"en"}.}
\examples{
tr("tab_add", "pt")
tr("mon_short", "en")
detect_lang("en-US,en;q=0.9,pt-BR;q=0.5")
detect_lang("en-GB")
}
