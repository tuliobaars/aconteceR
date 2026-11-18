# The Add event tab. The location is the last map click, or the city centre when
# nothing was clicked. Saved events go to SQLite and stay there.
#
#   con       open database connection (see db_connect())
#   city      reactive, one-row data frame of the selected city
#   clicked   reactive, list(lat, lon) or NULL
#   on_added  function(new_id) called after a successful save
#   lang      reactive language ("en" or "pt")

mod_add_event_ui <- function(id, lang = "en") {
  ns <- shiny::NS(id)
  keys <- names(price_types())
  htmltools::div(
    class = "ac-pane-form",
    shiny::textInput(ns("title"), i18n_span("form_title", lang), width = "100%"),
    htmltools::div(
      class = "ac-row",
      native_input(ns("date"), "date", value = Sys.Date(), label = i18n_span("form_date", lang)),
      native_input(ns("time"), "time", value = "19:00", label = i18n_span("form_time", lang))
    ),
    shiny::textInput(ns("venue"), i18n_span("form_venue", lang), width = "100%"),
    htmltools::div(
      class = "ac-field",
      htmltools::span(class = "ac-label", i18n_span("category_label", lang)),
      category_chips(ns("category"), lang = lang, selected = "music", mode = "single", default = "music",
                     class = "ac-form-chips", filter_style = FALSE)
    ),
    htmltools::div(
      class = "ac-field",
      htmltools::span(class = "ac-label", i18n_span("price_label", lang)),
      chipset(ns("price_type"),
              stats::setNames(lapply(keys, function(k) i18n_span(paste0("price_", k), lang)), keys),
              selected = "free", mode = "single", default = "free", class = "ac-form-chips")
    ),
    shiny::conditionalPanel(
      condition = sprintf("input['%s'] === 'paid'", ns("price_type")),
      shiny::numericInput(ns("price"), i18n_span("form_ticket_price", lang), value = NA, min = 0, step = 1,
                          width = "100%")
    ),
    shiny::textInput(ns("url"), i18n_span("form_url", lang), placeholder = "https://", width = "100%"),
    shiny::textAreaInput(ns("description"), i18n_span("form_desc", lang), rows = 3, width = "100%"),
    shiny::uiOutput(ns("where")),
    shiny::actionButton(ns("save"), i18n_span("save_btn", lang), class = "ac-btn ac-btn-primary ac-btn-block")
  )
}

mod_add_event_server <- function(id, con, city, clicked, on_added = function(id) NULL,
                                 lang = shiny::reactive("en")) {
  shiny::moduleServer(id, function(input, output, session) {
    where <- shiny::reactiveVal(NULL)
    shiny::observeEvent(clicked(), where(clicked()))
    shiny::observeEvent(city(), where(NULL), ignoreInit = TRUE)

    output$where <- shiny::renderUI({
      l <- lang()
      w <- where()
      txt <- if (is.null(w)) tf("where_centre", l, city()$label) else tf("where_picked", l, w$lat, w$lon)
      htmltools::div(class = "ac-where", ac_icon("pin"), htmltools::span(txt))
    })

    shiny::observeEvent(input$save, {
      l <- lang()
      c1 <- city()
      w <- where()
      res <- validate_event(list(
        title = input$title,
        description = input$description,
        city = c1$label,
        venue = input$venue,
        lat = if (is.null(w)) c1$lat else w$lat,
        lon = if (is.null(w)) c1$lon else w$lon,
        starts_at = paste(input$date %||% "", substr(trimws(input$time %||% ""), 1L, 5L)),
        category = input$category,
        price_type = input$price_type,
        price = input$price,
        currency = "BRL",
        url = input$url,
        source = "user"
      ), lang = l)
      if (!res$ok) {
        shiny::showNotification(paste(res$errors, collapse = " "), type = "error", duration = 8)
        return(invisible(NULL))
      }
      ev <- res$event
      if (db_event_exists(con, ev$title, ev$city, ev$starts_at)) {
        shiny::showNotification(tr("notif_exists", l), type = "warning")
        return(invisible(NULL))
      }
      new_id <- tryCatch(db_insert_event(con, ev), error = function(e) NULL)
      if (is.null(new_id)) {
        shiny::showNotification(tr("notif_err_save", l), type = "error")
        return(invisible(NULL))
      }
      shiny::showNotification(tf("notif_added", l, ev$title), type = "message")
      shiny::updateTextInput(session, "title", value = "")
      shiny::updateTextInput(session, "venue", value = "")
      shiny::updateTextInput(session, "url", value = "")
      shiny::updateTextAreaInput(session, "description", value = "")
      session$sendInputMessage("price_type", list(value = "free"))
      shiny::updateNumericInput(session, "price", value = NA)
      where(NULL)
      on_added(new_id)
    })
  })
}
