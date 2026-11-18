# Events: the header search, the filter chips (when / category / price) and
# the list. The UI lives in three places on the page, so it comes in three
# parts sharing one id:
#
#   mod_events_search_ui(id)   the search box in the header
#   mod_events_filters_ui(id)  the chip row under the greeting
#   mod_events_list_ui(id)     the list pane
#
# `events` is a reactive data frame already limited to the current city;
# `night` a reactive flag (the app is dark) that puts night activities first.
# Returns list(filtered, undated, focus, set_range):
#   filtered()  events passing every filter (feeds the map)
#   undated()   events passing text, category and price but not the dates
#               (feeds the calendar, which navigates dates itself)
#   focus()     focus_request(id) when an event title is clicked
#   set_range(from, to)  filter to a day or a month picked on the calendar;
#               shows a removable chip with the range

when_choices <- function(lang = "en") {
  keys <- c("today", "weekend", "7d", "30d", "all")
  stats::setNames(lapply(keys, function(k) i18n_span(paste0("when_", k), lang)), keys)
}

mod_events_search_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  htmltools::tags$label(
    class = "ac-search",
    ac_icon("search"),
    htmltools::span(class = "ac-sr-only", `data-i18n` = "search_ph_top", tr("search_ph_top", lang)),
    htmltools::tags$input(id = ns("q"), type = "search", autocomplete = "off",
                          placeholder = tr("search_ph_top", lang), `data-i18n-ph` = "search_ph_top")
  )
}

mod_events_filters_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  price_keys <- c("free", "paid", "donation")
  htmltools::tags$nav(
    class = "ac-filters ac-only-events", `data-i18n-aria` = "filters_aria", `aria-label` = tr("filters_aria", lang),
    chipset(ns("when"), when_choices(lang), selected = "all", mode = "single", default = "all"),
    htmltools::span(class = "ac-sep", `aria-hidden` = "true"),
    category_chips(ns("cat"), lang = lang),
    htmltools::span(class = "ac-sep", `aria-hidden` = "true"),
    chipset(ns("price"),
            stats::setNames(lapply(price_keys, function(k) i18n_span(paste0("price_", k), lang)), price_keys),
            mode = "multi")
  )
}

mod_events_list_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  htmltools::div(
    class = "ac-only-events",
    htmltools::div(
      class = "ac-pane-head",
      htmltools::tags$h2(class = "ac-pane-title", `data-i18n` = "list_title", tr("list_title", lang)),
      shiny::uiOutput(ns("summary"), inline = TRUE, class = "ac-pane-count")
    ),
    # Shown while the page is dark (CSS), when night activities lead the list.
    htmltools::p(class = "ac-night-hint", ac_icon("moon"), i18n_span("night_first", lang)),
    shiny::uiOutput(ns("list"), class = "ac-pane-body")
  )
}

# The date range for a "when" chip: c(from, to); `to` is NA for no limit.
when_range <- function(when, today = Sys.Date(), custom = NULL) {
  when <- when %||% "all"
  switch(
    when,
    today = c(today, today),
    weekend = weekend_range(today),
    `7d` = c(today, today + 7L),
    `30d` = c(today, today + 30L),
    custom = if (is.null(custom)) c(today, as.Date(NA)) else as.Date(custom),
    c(today, as.Date(NA))
  )
}

# The Saturday and Sunday of "this weekend" (today only, on a Sunday).
weekend_range <- function(today = Sys.Date()) {
  wday <- as.POSIXlt(today)$wday # 0 = Sun .. 6 = Sat
  if (wday == 0L) return(c(today, today))
  sat <- today + ((6L - wday) %% 7L)
  c(sat, sat + 1L)
}

# Label of the removable chip: "5 de dez" for one day, "Dezembro de 2026" for more.
range_label <- function(from, to, lang = "en") {
  from <- as.Date(from)
  to <- as.Date(to)
  lt <- as.POSIXlt(from)
  if (identical(from, to)) {
    return(tf("fmt_day_short", lang, lt$mday, tr("mon_short", lang)[lt$mon + 1L]))
  }
  format_month_title(lt$year + 1900L, lt$mon + 1L, lang)
}

mod_events_server <- function(id, events, lang = shiny::reactive("en"), night = shiny::reactive(FALSE)) {
  shiny::moduleServer(id, function(input, output, session) {
    custom <- shiny::reactiveVal(NULL)

    set_range <- function(from, to) {
      custom(c(as.Date(from), as.Date(to)))
      session$sendInputMessage("when", list(custom = range_label(from, to, shiny::isolate(lang()))))
    }

    # Keep the custom chip's label in the current language.
    shiny::observeEvent(lang(), {
      r <- custom()
      if (!is.null(r) && identical(input$when, "custom")) {
        session$sendInputMessage("when", list(custom = range_label(r[[1]], r[[2]], lang()), silent = TRUE))
      }
    }, ignoreInit = TRUE)

    undated <- shiny::reactive({
      prices <- input$price
      filter_events(
        events(),
        query = input$q,
        price_types = if (length(prices)) prices else NULL,
        categories = input$cat
      )
    })

    filtered <- shiny::reactive({
      r <- when_range(input$when, Sys.Date(), custom())
      filter_events(undated(), from = r[[1]], to = if (is.na(r[[2]])) NULL else r[[2]])
    })

    output$summary <- shiny::renderUI({
      tr_count("count_events", nrow(filtered()), lang())
    })

    output$list <- shiny::renderUI({
      event_list(filtered(), focus_input = session$ns("focus"), lang = lang(), night = isTRUE(night()))
    })

    list(
      filtered = filtered,
      undated = undated,
      focus = shiny::reactive(focus_request(input$focus)),
      set_range = set_range
    )
  })
}
