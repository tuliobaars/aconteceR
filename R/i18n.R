# Bilingual UI strings: Brazilian Portuguese ("pt", shown as PT-BR) and English
# ("en"). The dictionary lives in inst/i18n/strings.json and is shared with the
# browser: the Shiny page and the standalone HTML embed the same file, so both
# apps always use the same words. Add a key to both languages there; the
# i18n tests check that the two languages have the same keys and placeholders.

.i18n_cache <- new.env(parent = emptyenv())

i18n_path <- function() {
  system.file("i18n", "strings.json", package = "aconteceR")
}

# The parsed dictionary: list(en = list(...), pt = list(...)). Cached.
i18n_dict <- function() {
  if (is.null(.i18n_cache$dict)) {
    path <- i18n_path()
    if (!nzchar(path) || !file.exists(path)) {
      stop("inst/i18n/strings.json not found in the aconteceR package.", call. = FALSE)
    }
    .i18n_cache$dict <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  }
  .i18n_cache$dict
}

# The raw JSON text, embedded in the Shiny page for the browser.
i18n_json <- function() {
  paste(readLines(i18n_path(), encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

# "pt", "en", or NA for anything else. Accepts "pt-BR", "pt_BR", "en-GB", ...
lang_code <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_character_)
  s <- tolower(as.character(x))
  if (grepl("^pt([-_].*)?$", s)) return("pt")
  if (grepl("^en([-_].*)?$", s)) return("en")
  NA_character_
}

# Like lang_code(), but unknown languages fall back to English.
normalize_lang <- function(lang = "en") {
  l <- lang_code(lang)
  if (is.na(l)) "en" else l
}

# Look up a string. Missing keys fall back to English, then to the key itself.
tr <- function(key, lang = "en") {
  d <- i18n_dict()
  val <- d[[normalize_lang(lang)]][[key]]
  if (is.null(val)) val <- d[["en"]][[key]]
  if (is.null(val)) key else val
}

# tr() + sprintf(): tf("count_events_many", "pt", 3L) -> "3 eventos"
tf <- function(key, lang = "en", ...) {
  sprintf(tr(key, lang), ...)
}

# Plural helper for the "_one" / "_many" key pairs.
tr_count <- function(base, n, lang = "en") {
  tf(paste0(base, if (identical(as.integer(n), 1L)) "_one" else "_many"), lang, as.integer(n))
}

# A translatable text node: the browser swaps it when the language toggles.
i18n_span <- function(key, lang = "en", ...) {
  htmltools::span(`data-i18n` = key, ..., tr(key, lang))
}

# Pick the language from an HTTP Accept-Language header. aconteceR lists events
# in Brazil, so Portuguese anywhere in the list, or any Brazilian region tag
# ("en-BR"), means PT-BR; otherwise English if listed; else `default`. Tags
# with q=0 are ignored. The browser applies the same rule and also looks at the
# time zone (see AC.i18n.detect in inst/www/ac-core.js).
#   detect_lang("pt-BR,pt;q=0.9,en;q=0.8")   -> "pt"
#   detect_lang("en-US,en;q=0.9,pt;q=0.3")   -> "pt"
#   detect_lang("en-BR")                     -> "pt"
#   detect_lang("en-GB,fr;q=0.5")            -> "en"
#   detect_lang("fr-FR", default = "pt")     -> "pt"
detect_lang <- function(accept_language, default = "en") {
  if (is.null(accept_language) || length(accept_language) != 1L || is.na(accept_language) ||
      !nzchar(accept_language)) {
    return(normalize_lang(default))
  }
  parts <- strsplit(accept_language, ",", fixed = TRUE)[[1]]
  tags <- trimws(sub(";.*$", "", parts))
  q <- vapply(parts, function(p) {
    m <- regmatches(p, regexpr("q=[0-9.]+", p))
    if (length(m)) suppressWarnings(as.numeric(sub("q=", "", m, fixed = TRUE))) else 1
  }, numeric(1), USE.NAMES = FALSE)
  q[is.na(q)] <- 0
  tags <- tags[q > 0]
  codes <- vapply(tags, lang_code, character(1), USE.NAMES = FALSE)
  if (any(codes %in% "pt") || any(grepl("[-_]br$", tags, ignore.case = TRUE))) return("pt")
  if (any(codes %in% "en")) return("en")
  normalize_lang(default)
}

# Language for an incoming page request: ?lang=pt|en wins, then the browser's
# Accept-Language header, then `default`. (The browser may still switch to a
# language the user picked earlier, which is remembered in localStorage.)
request_lang <- function(request, default = "pt") {
  qs <- request$QUERY_STRING %||% ""
  from_url <- lang_code(shiny::parseQueryString(qs)$lang)
  if (!is.na(from_url)) return(from_url)
  detect_lang(request$HTTP_ACCEPT_LANGUAGE, default = default)
}
