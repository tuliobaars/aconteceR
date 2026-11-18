# The two ways an event is classified: what it is (category) and what it costs
# (price type). Names are the stored keys, values are the labels people see.

event_categories <- function(lang = "en") {
  c(
    music = tr("cat_music", lang),
    food = tr("cat_food", lang),
    arts = tr("cat_arts", lang),
    sports = tr("cat_sports", lang),
    tech = tr("cat_tech", lang),
    community = tr("cat_community", lang),
    other = tr("cat_other", lang)
  )
}

price_types <- function(lang = "en") {
  c(
    free = tr("price_free", lang),
    paid = tr("price_paid", lang),
    donation = tr("price_donation", lang),
    unknown = tr("price_unknown", lang)
  )
}

# Colour-blind-safe categorical colours (ColorBrewer Dark2).
price_palette <- function() {
  c(free = "#22c55e", paid = "#f59e0b", donation = "#a855f7", unknown = "#94a3b8")
}

# Pin colours per category. The list rows and chips use matching gradients
# (--ac-cat-* in inst/www/aconteceR.css); keep CAT_COLORS in
# inst/standalone/ac-standalone.js in sync.
category_palette <- function() {
  c(
    music = "#8b5cf6", food = "#f97316", arts = "#ec4899", sports = "#22c55e",
    tech = "#0ea5e9", community = "#eab308", other = "#94a3b8"
  )
}

is_category <- function(x) {
  length(x) == 1L && !is.na(x) && x %in% names(event_categories("en"))
}

is_price_type <- function(x) {
  length(x) == 1L && !is.na(x) && x %in% names(price_types("en"))
}

category_label <- function(x, lang = "en") {
  cats <- event_categories(lang)
  out <- unname(cats[as.character(x)])
  out[is.na(out)] <- tr("cat_other", lang)
  out
}

# Flip a key = label vector into label = key, the shape Shiny inputs expect.
as_choices <- function(x) {
  stats::setNames(names(x), unname(x))
}

# Price bands: what "colour by price" shows on the map and calendar. Free and
# donation events keep their own colours; paid events are split by ticket
# price on a light-to-dark ramp. Keep in sync with priceBand() in
# inst/standalone/ac-standalone.js (the browser smoke test checks both).
price_band_breaks <- function() c(30, 60, 100)

price_band <- function(price_type, price = NA_real_) {
  pt <- as.character(price_type)
  pt[is.na(pt)] <- "unknown"
  p <- rep_len(suppressWarnings(as.numeric(price)), length(pt))
  b <- price_band_breaks()
  out <- rep("unknown", length(pt))
  out[pt == "free"] <- "free"
  out[pt == "donation"] <- "donation"
  paid <- pt == "paid"
  has <- paid & !is.na(p)
  out[paid & is.na(p)] <- "paid_na"
  out[has & p <= b[[1]]] <- "p1"
  out[has & p > b[[1]] & p <= b[[2]]] <- "p2"
  out[has & p > b[[2]] & p <= b[[3]]] <- "p3"
  out[has & p > b[[3]]] <- "p4"
  out
}

price_band_palette <- function() {
  c(free = "#22c55e", donation = "#a855f7", p1 = "#fcd34d", p2 = "#f59e0b",
    p3 = "#ea580c", p4 = "#e11d48", paid_na = "#c08a5b", unknown = "#94a3b8")
}

# "Grátis", "Até R$ 30", "R$ 30 – R$ 60", ... in the chosen language.
price_band_labels <- function(lang = "en") {
  b <- price_band_breaks()
  m <- function(x) format_money(x, "BRL", 0L, lang)
  c(
    free = tr("price_free", lang),
    donation = tr("price_donation", lang),
    p1 = tf("band_upto", lang, m(b[[1]])),
    p2 = tf("band_range", lang, m(b[[1]]), m(b[[2]])),
    p3 = tf("band_range", lang, m(b[[2]]), m(b[[3]])),
    p4 = tf("band_over", lang, m(b[[3]])),
    paid_na = tr("band_paid_na", lang),
    unknown = tr("price_unknown", lang)
  )
}

# Add the price_band column the map and calendar colour by.
with_price_band <- function(ev) {
  ev$price_band <- price_band(ev$price_type, ev$price)
  ev
}

# The two colour modes of the events map ("colour by price / category").
# A function of the language, so mod_map_server() re-labels them on toggle.
event_color_modes <- function(lang = "en") {
  list(
    price = map_color_factor(
      column = "price_band", colors = price_band_palette(), labels = price_band_labels(lang),
      label = tr("mode_price", lang), title = tr("price_label", lang)
    ),
    category = map_color_factor(
      column = "category", colors = category_palette(), labels = event_categories(lang),
      label = tr("mode_category", lang), title = tr("category_label", lang)
    )
  )
}
