# Search & import: search saved events plus the demo sources, and import
# ("autopopulate") what the sources return into SQLite with one click. Shown as
# a pane over the event list. Returns list(focus): focus_request(id, point)
# when a result is clicked; `point` is the result row, so the map can show
# results from other cities.

mod_search_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  cat_df <- external_site_catalog()
  sites <- lapply(cat_df$label, function(l) {
    htmltools::tagList(htmltools::span(class = "ac-check-mark", `aria-hidden` = "true", "\u2713"), l)
  })
  names(sites) <- cat_df$name

  htmltools::tagList(
    htmltools::div(
      class = "ac-pane-form",
      with_i18n_placeholder(
        shiny::textInput(ns("q"), i18n_span("search_what", lang),
                         placeholder = tr("search_what_ph", lang), width = "100%"),
        "search_what_ph"
      ),
      htmltools::div(
        class = "ac-field",
        htmltools::span(class = "ac-label", i18n_span("search_where", lang)),
        chipset(ns("scope"),
                list(city = i18n_span("scope_city", lang), all = i18n_span("scope_all", lang)),
                selected = "city", mode = "single", default = "city", class = "ac-form-chips")
      ),
      htmltools::div(
        class = "ac-field",
        htmltools::span(class = "ac-label", i18n_span("sources_label", lang)),
        chipset(ns("sites"), sites, selected = cat_df$name, mode = "multi", class = "ac-form-chips ac-sources"),
        htmltools::p(class = "ac-hint", i18n_span("sources_hint", lang))
      ),
      htmltools::div(
        class = "ac-actions",
        shiny::actionButton(ns("go"), i18n_span("search_btn", lang), class = "ac-btn ac-btn-accent"),
        shiny::actionButton(ns("autopop"), i18n_span("autopopulate_btn", lang), class = "ac-btn")
      ),
      shiny::uiOutput(ns("notes")),
      shiny::uiOutput(ns("summary"), class = "ac-pane-count")
    ),
    shiny::uiOutput(ns("results"), class = "ac-pane-body")
  )
}

mod_search_server <- function(id, providers, city, con = NULL,
                              on_autopopulated = function(n) NULL,
                              lang = shiny::reactive("en"), night = shiny::reactive(FALSE)) {
  shiny::moduleServer(id, function(input, output, session) {
    # The saved-events provider plus the sites picked in the form.
    active_providers <- shiny::reactive({
      sel_sites <- input$sites
      if (!is.null(con) && !is.null(sel_sites)) {
        providers_catalog(con, enabled_sites = sel_sites, include_local = TRUE)
      } else {
        providers()
      }
    })

    scope_city <- function() if (identical(input$scope, "all")) NULL else city()$label

    # Capture the query on click; run it reactively so notes and rows follow
    # the language toggle without searching again by hand.
    search_args <- shiny::eventReactive(input$go, {
      list(providers = active_providers(), q = input$q, city = scope_city())
    })
    result <- shiny::reactive({
      a <- search_args()
      search_events(a$providers, query = a$q, city = a$city, lang = lang())
    })

    shiny::observeEvent(input$autopop, {
      if (is.null(con)) return(invisible(NULL))
      l <- lang()
      target <- scope_city()
      added <- autopopulate_events(con, sites = input$sites %||% character(),
                                   city = target, query = input$q %||% "")
      if (added > 0L) {
        shiny::showNotification(tf("autopop_done", l, added, target %||% tr("scope_all", l)), type = "message")
        on_autopopulated(added)
      } else {
        shiny::showNotification(tr("autopop_none", l), type = "warning")
      }
    })

    output$notes <- shiny::renderUI({
      notes <- result()$notes
      if (!length(notes)) return(NULL)
      htmltools::div(class = "ac-note", lapply(notes, htmltools::p))
    })

    output$summary <- shiny::renderUI({
      n <- nrow(result()$events)
      tf(if (n == 1L) "result_one" else "result_many", lang(), n)
    })

    output$results <- shiny::renderUI({
      event_list(result()$events, focus_input = session$ns("focus"), show_city = TRUE, lang = lang(),
                 night = isTRUE(night()))
    })

    list(
      focus = shiny::reactive({
        id <- input$focus
        if (is.null(id)) return(NULL)
        ev <- shiny::isolate(result()$events)
        row <- ev[as.character(ev$id) == as.character(id), , drop = FALSE]
        focus_request(id, point = if (nrow(row) == 1L) row else NULL)
      })
    )
  })
}
