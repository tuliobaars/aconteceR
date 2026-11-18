# Places mode: filter chips (open now, open late, category, vibe) and the list. The search
# box in the header is shared with events and passed in as `query`.
#
#   places  reactive data frame of the current city's places (load_places())
#   clock   reactive list(wday, minutes): the visitor's clock (client_clock())
# Returns list(filtered, focus): the filtered, ordered places (feeds the map)
# and focus_request(id, point) when a place title is clicked.

mod_places_filters_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  pcats <- place_category_keys()
  cat_chips <- lapply(pcats, function(k) {
    htmltools::tagList(
      htmltools::span(class = paste0("ac-chip-dot ac-pcat-", k), ac_icon(paste0("pcat_", k))),
      i18n_span(paste0("pcat_", k), lang)
    )
  })
  names(cat_chips) <- pcats
  vibe_chips <- lapply(vibe_keys(), function(k) {
    htmltools::tagList(htmltools::span(class = paste0("ac-chip-dot ac-vibe-", k)), i18n_span(paste0("vibe_", k), lang))
  })
  names(vibe_chips) <- vibe_keys()
  htmltools::tags$nav(
    class = "ac-filters ac-only-places", `data-i18n-aria` = "filters_aria", `aria-label` = tr("filters_aria", lang),
    chipset(ns("open"),
            list(open = htmltools::tagList(htmltools::span(class = "ac-pm-dot"), i18n_span("place_open_now", lang)),
                 late = htmltools::tagList(ac_icon("moon"), i18n_span("place_open_late", lang))),
            mode = "multi", chip_class = c("ac-chip-open", "ac-chip-late"),
            chip_title_keys = c(NA, "place_open_late_title"), lang = lang),
    htmltools::span(class = "ac-sep", `aria-hidden` = "true"),
    chipset(ns("cat"), cat_chips, mode = "multi", chip_class = paste0("ac-chip-pcat ac-chip-pcat-", pcats)),
    htmltools::span(class = "ac-sep", `aria-hidden` = "true"),
    chipset(ns("vibe"), vibe_chips, mode = "multi", chip_class = paste0("ac-chip-vibe ac-chip-vibe-", vibe_keys()))
  )
}

# `sources`: which notes to show, from places_sources(): "demo" (generated
# demo data) and/or "osm" (OpenStreetMap, with its attribution).
mod_places_list_ui <- function(id, lang = "en", sources = character()) {
  ns <- shiny::NS(id)
  htmltools::div(
    class = "ac-only-places",
    htmltools::div(
      class = "ac-pane-head",
      htmltools::tags$h2(class = "ac-pane-title", i18n_span("places_title", lang)),
      shiny::uiOutput(ns("summary"), inline = TRUE, class = "ac-pane-count")
    ),
    places_notes(sources, lang),
    shiny::uiOutput(ns("list"), class = "ac-pane-body")
  )
}

# "demo" and/or "osm", depending on where the places come from.
places_sources <- function(places) {
  if (is.null(places) || nrow(places) == 0L) return(character())
  c(if (any(is_demo_place(places))) "demo", if (any(chr0(places$source) == "openstreetmap")) "osm")
}

# Notes above the places list: demo data, and the OpenStreetMap attribution
# (required by the ODbL) with a hint that hours may be out of date.
places_notes <- function(sources, lang = "en") {
  htmltools::tagList(
    if ("demo" %in% sources) htmltools::p(class = "ac-demo-note", ac_icon("sparkles"), i18n_span("places_demo_note", lang)),
    if ("osm" %in% sources) {
      htmltools::p(
        class = "ac-demo-note ac-osm-note", ac_icon("clock"), i18n_span("places_osm_note", lang), " ",
        htmltools::tags$a(href = "https://www.openstreetmap.org/copyright", target = "_blank", rel = "noopener noreferrer",
                          i18n_span("osm_attribution", lang))
      )
    }
  )
}

mod_places_server <- function(id, places, query = shiny::reactive(""), clock = shiny::reactive(client_clock()),
                              lang = shiny::reactive("en")) {
  shiny::moduleServer(id, function(input, output, session) {
    filtered <- shiny::reactive({
      ck <- clock()
      p <- filter_places(places(), query = query(), categories = input$cat, vibes = input$vibe,
                         open_now = "open" %in% input$open, open_late = "late" %in% input$open,
                         clock = ck, lang = lang())
      order_places(p, ck)
    })

    output$summary <- shiny::renderUI(tr_count("count_places", nrow(filtered()), lang()))
    output$list <- shiny::renderUI({
      place_list(filtered(), clock = clock(), focus_input = session$ns("focus"), lang = lang())
    })

    list(
      filtered = filtered,
      focus = shiny::reactive({
        id <- input$focus
        if (is.null(id)) return(NULL)
        p <- shiny::isolate(places())
        row <- p[p$place_id == id, , drop = FALSE]
        focus_request(id, point = if (nrow(row) == 1L) places_as_points(row, shiny::isolate(clock())) else NULL)
      })
    )
  })
}

# Places in the shape the map module draws (id = place_id), with the
# opening status at `clock` (status_key) for the "hours" colour mode.
places_as_points <- function(places, clock = NULL) {
  if (is.null(places) || nrow(places) == 0L) {
    return(data.frame(id = character(), lat = numeric(), lon = numeric(), stringsAsFactors = FALSE))
  }
  places$id <- places$place_id
  if (!is.null(clock)) places$status_key <- place_status_key(places, clock)
  places
}
