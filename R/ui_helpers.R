# Shared markup. Text goes into htmltools tags, which escape it. Rows match
# rowHtml() / listHtml() in inst/standalone/ac-standalone.js so both apps share
# one stylesheet. Icons are <span data-ac-icon="..."> placeholders that the
# browser fills in (AC.ui.icons in inst/www/ac-core.js).

ac_icon <- function(name) {
  htmltools::span(`data-ac-icon` = name, `aria-hidden` = "true")
}

category_key <- function(x) {
  x <- as.character(x)
  ifelse(!is.na(x) & x %in% names(event_categories()), x, "other")
}

# One event: a gradient category tile, the title (a button that shows the
# event on the map), when and where, the price and the event link.
event_row <- function(ev, focus_input = NULL, show_city = FALSE, lang = "en", night = FALSE) {
  link <- safe_url(ev$url)
  where <- chr0(ev$venue)
  if (show_city) where <- paste(Filter(nzchar, c(where, chr0(ev$city))), collapse = ", ")
  src <- chr0(ev$source)
  cat <- category_key(ev$category)
  band <- price_band(ev$price_type, ev$price)
  htmltools::tags$article(
    class = "ac-ev", `data-id` = ev$id, `data-input` = focus_input,
    htmltools::div(class = paste0("ac-ev-tile ac-cat-", cat), `aria-hidden` = "true", ac_icon(paste0("cat_", cat))),
    htmltools::div(
      class = "ac-ev-main",
      htmltools::tags$h3(
        class = "ac-ev-title",
        htmltools::tags$button(type = "button", class = "ac-ev-show", `data-focus-id` = ev$id,
                               title = tr("show_on_map", lang), ev$title)
      ),
      htmltools::p(
        class = "ac-ev-meta",
        if (isTRUE(night) && is_night_activity(ev$starts_at)) {
          htmltools::span(class = "ac-ev-moon", title = tr("night_activity", lang), ac_icon("moon"))
        },
        htmltools::span(class = "ac-ev-when", format_when(ev$starts_at, lang = lang)),
        if (nzchar(where)) paste0(" \u00b7 ", where),
        if (nzchar(src) && !src %in% c("user", "sample")) htmltools::span(class = "ac-src", src)
      )
    ),
    htmltools::div(
      class = "ac-ev-side",
      htmltools::span(class = paste0("ac-price ac-band-", band),
                      format_price(ev$price_type, ev$price, ev$currency, lang = lang)),
      if (!is.na(link)) {
        htmltools::tags$a(class = "ac-ev-link", href = link, target = "_blank", rel = "noopener noreferrer",
                          `aria-label` = tr("event_page", lang), title = tr("event_page", lang), ac_icon("external"))
      }
    )
  )
}

# "Hoje", "Amanhã", else "Sábado, 21 de novembro".
day_label <- function(day, lang = "en", today = Sys.Date()) {
  d <- as.Date(day)
  out <- format_day_long(d, lang)
  out[!is.na(d) & d == today] <- tr("day_today", lang)
  out[!is.na(d) & d == today + 1L] <- tr("day_tomorrow", lang)
  out
}

# Rows grouped under day headers, capped so a big city does not flood the
# page. Pass `focus_input` (a namespaced input id) so a click on a title sends
# the event id to the server. With `night = TRUE` night activities lead each
# day and carry a moon (see order_events()).
event_list <- function(ev, focus_input = NULL, show_city = FALSE, max_cards = 100L,
                       lang = "en", today = Sys.Date(), night = FALSE) {
  if (nrow(ev) == 0L) {
    return(htmltools::div(
      class = "ac-empty",
      htmltools::tags$strong(tr("empty_title", lang)),
      htmltools::span(tr("empty_hint", lang))
    ))
  }
  shown <- utils::head(order_events(ev, night), max_cards)
  days <- substr(chr0(shown$starts_at), 1L, 10L)
  items <- list()
  last <- NULL
  for (i in seq_len(nrow(shown))) {
    if (!identical(days[[i]], last)) {
      d <- as.Date(days[[i]], format = "%Y-%m-%d")
      is_today <- !is.na(d) && d == today
      items[[length(items) + 1L]] <- htmltools::tags$h4(
        class = paste("ac-day", if (is_today) "ac-day-today"),
        if (is.na(d)) tr("date_tbc", lang) else day_label(d, lang, today)
      )
      last <- days[[i]]
    }
    items[[length(items) + 1L]] <- event_row(shown[i, , drop = FALSE], focus_input = focus_input,
                                             show_city = show_city, lang = lang, night = night)
  }
  htmltools::tagList(
    if (nrow(ev) > nrow(shown)) {
      htmltools::div(class = "ac-note", tf("showing_first", lang, nrow(shown), nrow(ev)))
    },
    items
  )
}

# A row of pill buttons that acts as one Shiny input (see the chipset binding
# in inst/www/ac-shiny.js). `choices` is a named vector value = label, or a
# list of tags named by value. single: one value (a string); multi: a
# character vector, NULL when nothing is selected.
chipset <- function(id, choices, selected = NULL, mode = c("single", "multi"), default = NULL,
                    class = NULL, chip_class = NULL, aria_label = NULL, chip_title_keys = NULL, lang = "en") {
  mode <- match.arg(mode)
  values <- names(choices)
  chips <- lapply(seq_along(choices), function(i) {
    v <- values[[i]]
    on <- v %in% selected
    title_key <- if (length(chip_title_keys) >= i && !is.na(chip_title_keys[[i]])) chip_title_keys[[i]] else NULL
    htmltools::tags$button(
      type = "button",
      class = paste(c("ac-chip", if (!is.null(chip_class)) chip_class[[min(i, length(chip_class))]], if (on) "is-on"),
                    collapse = " "),
      `data-value` = v, `aria-pressed` = if (on) "true" else "false",
      title = if (!is.null(title_key)) tr(title_key, lang), `data-i18n-title` = title_key,
      choices[[i]]
    )
  })
  htmltools::div(
    id = id, class = paste(c("ac-chipset", class), collapse = " "), role = "group",
    `data-mode` = mode, `data-default` = default, `aria-label` = aria_label,
    chips
  )
}

# Category chips with their gradient icon dot.
category_chips <- function(id, lang = "en", selected = NULL, mode = "multi", default = NULL,
                           class = NULL, filter_style = TRUE) {
  keys <- names(event_categories())
  labels <- lapply(keys, function(k) {
    htmltools::tagList(
      htmltools::span(class = paste0("ac-chip-dot ac-cat-", k), ac_icon(paste0("cat_", k))),
      i18n_span(paste0("cat_", k), lang)
    )
  })
  names(labels) <- keys
  chipset(id, labels, selected = selected, mode = mode, default = default, class = class,
          chip_class = if (filter_style) paste0("ac-chip-cat ac-chip-", keys) else NULL)
}

# Wrap a value so downstream observers fire again even for the same id.
# `point` (optional one-row data frame) lets the map show an item that is not
# among its current points.
focus_request <- function(id, point = NULL) {
  if (is.null(id)) return(NULL)
  list(id = id, t = as.numeric(Sys.time()), point = point)
}

# A native <input type="date|time"> bound to Shiny by ac-shiny.js (value is
# the "YYYY-MM-DD" / "HH:MM" string). Update it from the server with
# session$sendInputMessage(id, list(value = "2026-12-05")).
native_input <- function(id, type = c("date", "time"), value = NULL, label = NULL,
                         aria_key = NULL, lang = "en") {
  type <- match.arg(type)
  val <- if (is.null(value)) "" else if (inherits(value, "Date")) format(value, "%Y-%m-%d") else as.character(value)
  inp <- htmltools::tags$input(
    id = id, type = type, value = val,
    class = "ac-native-input",
    `data-i18n-aria` = aria_key,
    `aria-label` = if (!is.null(aria_key)) tr(aria_key, lang)
  )
  if (is.null(label)) return(inp)
  htmltools::div(
    class = "form-group shiny-input-container",
    htmltools::tags$label(`for` = id, class = "control-label", label),
    inp
  )
}

# Translatable placeholder on a Shiny text input (the browser swaps it).
with_i18n_placeholder <- function(tag, key) {
  htmltools::tagAppendAttributes(tag, `data-i18n-ph` = key)
}
