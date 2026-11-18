# Small helpers shared across the package. Nothing here touches Shiny state.

# Returns `y` when `x` is NULL, empty, or a single NA; otherwise `x`.
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || (length(x) == 1L && is.na(x))) y else x
}

# Accent folding for search, written with \u escapes so the source stays ASCII.
# The two strings must have the same number of characters (tested).
.accents_from <- paste0(
  "\u00e1\u00e0\u00e2\u00e3\u00e4",
  "\u00e9\u00e8\u00ea\u00eb",
  "\u00ed\u00ec\u00ee\u00ef",
  "\u00f3\u00f2\u00f4\u00f5\u00f6",
  "\u00fa\u00f9\u00fb\u00fc",
  "\u00e7\u00f1"
)
.accents_to <- "aaaaaeeeeiiiiooooouuuucn"

# Lower-case and remove common Latin diacritics: "Florian\u00f3polis" matches
# "florianopolis".
normalize_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  chartr(.accents_from, .accents_to, tolower(x))
}

# Character vector with NA replaced by "".
chr0 <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

# Keep only http(s) links. Anything else (javascript:, data:, relative paths,
# text with spaces) becomes NA, so it can never end up in an href.
safe_url <- function(x) {
  x <- trimws(as.character(x %||% NA_character_))
  ok <- !is.na(x) & grepl("^https?://[^[:space:]]+$", x, ignore.case = TRUE)
  x[!ok] <- NA_character_
  x
}

# Escape text before it goes into an HTML string (leaflet popups and labels are
# HTML). htmltools tags escape on their own; plain strings do not.
escape_html <- function(x) {
  htmltools::htmlEscape(chr0(x), attribute = TRUE)
}

# Locale number formatting with the dictionary's decimal and thousands marks:
# format_number(1250.5, 2, "pt") -> "1.250,50"; "en" -> "1,250.50". Mirrors
# AC.fmt.number in inst/www/ac-core.js.
format_number <- function(x, digits = 0L, lang = "en") {
  x <- as.numeric(x)
  out <- rep("", length(x))
  ok <- is.finite(x)
  if (!any(ok)) return(out)
  s <- formatC(abs(x[ok]), format = "f", digits = digits)
  int <- sub("\\..*$", "", s)
  frac <- if (digits > 0) sub("^[^.]*\\.", "", s) else rep("", length(s))
  int <- gsub("(\\d)(?=(\\d{3})+$)", paste0("\\1", tr("big_mark", lang)), int, perl = TRUE)
  num <- ifelse(nzchar(frac), paste0(int, tr("decimal_mark", lang), frac), int)
  out[ok] <- paste0(ifelse(x[ok] < 0, "-", ""), num)
  out
}

currency_symbol <- function(currency) {
  cur <- toupper(chr0(currency))
  sym <- c(BRL = "R$", USD = "US$", EUR = "\u20ac", GBP = "\u00a3")[cur]
  ifelse(is.na(sym), cur, sym)
}

# "R$ 40,00" (pt) / "R$ 40.00" (en)
format_money <- function(amount, currency = "BRL", digits = 2L, lang = "en") {
  n <- length(amount)
  paste(currency_symbol(rep_len(currency, n)), format_number(amount, digits, lang))
}

# "Free", "Donation", "R$ 40.00", "Paid" (amount not given), "Price unknown".
format_price <- function(price_type, price = NA_real_, currency = "BRL", lang = "en") {
  price_type <- as.character(price_type)
  price_type[is.na(price_type)] <- "unknown"
  n <- length(price_type)
  price <- rep_len(as.numeric(price), n)
  currency <- rep_len(as.character(currency), n)
  out <- rep(tr("price_unknown", lang), n)
  out[price_type == "free"] <- tr("price_free", lang)
  out[price_type == "donation"] <- tr("price_donation", lang)
  paid <- price_type == "paid"
  with_amount <- paid & !is.na(price)
  out[paid] <- tr("price_paid", lang)
  out[with_amount] <- format_money(price[with_amount], currency[with_amount], 2L, lang)
  out
}

cap_first <- function(x) {
  x <- as.character(x)
  paste0(toupper(substr(x, 1L, 1L)), substring(x, 2L))
}

# "Sáb, 05 dez · 20:00" / "Sat, 05 Dec · 20:00". Event times are stored as
# local wall-clock text ("YYYY-MM-DD HH:MM") and never converted between time
# zones. Names come from the dictionary, so the output does not depend on the
# R session's locale. Mirrors AC.fmt.when.
format_when <- function(starts_at, lang = "en") {
  t <- as.POSIXlt(strptime(as.character(starts_at), "%Y-%m-%d %H:%M", tz = "UTC"))
  ok <- !is.na(t)
  out <- rep(tr("date_tbc", lang), length(ok))
  if (any(ok)) {
    tt <- t[ok]
    out[ok] <- sprintf(
      "%s, %02d %s \u00b7 %02d:%02d",
      tr("wd_short", lang)[tt$wday + 1L], tt$mday, tr("mon_short", lang)[tt$mon + 1L],
      tt$hour, tt$min
    )
  }
  out
}

# "Sábado, 5 de dezembro" / "Saturday, 5 December"
format_day_long <- function(date, lang = "en") {
  dd <- if (inherits(date, "Date")) date else as.Date(as.character(date), format = "%Y-%m-%d")
  d <- as.POSIXlt(dd)
  out <- cap_first(sprintf(
    tr("fmt_day_long", lang),
    tr("wd_long", lang)[d$wday + 1L], d$mday, tr("mon_long", lang)[d$mon + 1L]
  ))
  out[is.na(dd)] <- ""
  out
}

# Parse a "YYYY-MM-DD" input value; NULL when missing or invalid.
parse_input_date <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x) || !nzchar(x)) return(NULL)
  d <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
  if (is.na(d)) NULL else d
}

# "Dezembro de 2026" / "December 2026". Mirrors AC.fmt.monthTitle.
format_month_title <- function(year, month, lang = "en") {
  cap_first(sprintf(tr("cal_month_title", lang), tr("mon_long", lang)[as.integer(month)], as.integer(year)))
}
