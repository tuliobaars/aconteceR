# The monthly calendar, drawn in the browser by AC.MonthCalendar
# (inst/www/ac-calendar.js): a month grid with coloured event chips, a day
# agenda, keyboard navigation and "show this day / month on the map".
#
# In the app it sits over the map as a second view (Map | Calendar switch in
# the map toolbar). `color_from` is the element id of the map (mod_map_ui()'s
# root, "<map id>-pm"), so the calendar always uses the map's "colour by"
# choice without a round trip to the server.
#
#   events   reactive data frame of events (with a price_band column); the
#            calendar does its own date navigation, so pass events that are
#            NOT limited by the date filter.
#   lang     reactive language ("en" or "pt").
#
# Returns list(focus, show_day, show_month, month, day):
#   focus()       focus_request(id, point) when an event is clicked
#   show_day()    "YYYY-MM-DD" when "show this day on the map" is pressed
#   show_month()  "YYYY-MM" when "show this month on the map" is pressed
#   month(), day() the displayed month and the selected day (or NULL)

mod_calendar_ui <- function(id, color_from = NULL) {
  ns <- shiny::NS(id)
  htmltools::div(
    id = ns("cal"), class = "ac-cal-host",
    `data-ac-calendar` = "1", `data-color-from` = color_from
  )
}

# One line under each title in the day agenda: "R$ 40,00 · Música · Venue".
calendar_meta <- function(ev, lang = "en") {
  if (nrow(ev) == 0L) return(character())
  parts <- cbind(
    format_price(ev$price_type, ev$price, ev$currency, lang = lang),
    category_label(ev$category, lang = lang),
    chr0(ev$venue)
  )
  apply(parts, 1L, function(p) paste(p[nzchar(p)], collapse = " \u00b7 "))
}

calendar_items_json <- function(ev, lang = "en") {
  if (is.null(ev) || nrow(ev) == 0L) return("[]")
  items <- data.frame(
    id = as.character(ev$id),
    starts_at = as.character(ev$starts_at),
    title = as.character(ev$title),
    meta = calendar_meta(ev, lang),
    price_band = if (is.null(ev$price_band)) price_band(ev$price_type, ev$price) else ev$price_band,
    category = as.character(ev$category),
    stringsAsFactors = FALSE
  )
  as.character(jsonlite::toJSON(items, dataframe = "rows", na = "null"))
}

mod_calendar_server <- function(id, events, lang = shiny::reactive("en")) {
  shiny::moduleServer(id, function(input, output, session) {
    el_id <- session$ns("cal")

    shiny::observe({
      session$sendCustomMessage("ac-cal", list(
        id = el_id, action = "items", items = calendar_items_json(events(), lang())
      ))
    })

    focus <- shiny::reactive({
      hit <- input$cal_item
      shiny::req(hit, hit$id)
      ev <- shiny::isolate(events())
      row <- ev[as.character(ev$id) == as.character(hit$id), , drop = FALSE]
      focus_request(hit$id, point = if (nrow(row) == 1L) row else NULL)
    })

    list(
      focus = focus,
      show_day = shiny::reactive({
        shiny::req(input$cal_show_day$date)
        input$cal_show_day$date
      }),
      show_month = shiny::reactive({
        shiny::req(input$cal_show_month$month)
        input$cal_show_month$month
      }),
      month = shiny::reactive(input$cal_month),
      day = shiny::reactive(input$cal_day)
    )
  })
}
