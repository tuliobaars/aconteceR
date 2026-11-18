\name{i18n}
\alias{i18n}
\alias{tr}
\alias{detect_lang}
\title{Translations and language detection}
\description{
\code{tr} looks up a string in the shared dictionary
(\code{inst/i18n/strings.json}, Brazilian Portuguese and English), falling back
to English and then to the key. \code{detect_lang} picks the language from an
HTTP \code{Accept-Language} header: Portuguese anywhere in the list, or a
Brazilian region tag such as \code{en-BR}, gives \code{"pt"}; otherwise English
if listed; else \code{default}. (The browser applies the same rule and also
looks at the time zone.)
}
\usage{
tr(key, lang = "en")

detect_lang(accept_language, default = "en")
}
\arguments{
  \item{key}{Dictionary key.}
  \item{lang}{\code{"pt"} (also \code{"pt-BR"}) or \code{"en"}; anything else means English.}
  \item{accept_language}{Header value, e.g. \code{"pt-BR,pt;q=0.9,en;q=0.8"}.}
  \item{default}{Language when the header names neither Portuguese, English nor Brazil.}
}
\value{\code{tr}: a string (or a character vector for list entries such as month
names). \code{detect_lang}: \code{"pt"} or \code{"en"}.}
\examples{
tr("tab_add", "pt")
tr("mon_short", "en")
detect_lang("en-US,en;q=0.9,pt-BR;q=0.5")
detect_lang("en-GB")
}
