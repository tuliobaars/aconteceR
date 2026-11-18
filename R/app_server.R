# Wiring. The map module owns the city; the events of that city feed the
# Events tab; its filtered result feeds the map, and the same events without
# the date filter feed the calendar (which navigates dates itself). Clicking an
# event anywhere switches to the map view and flies to it.

app_server <- function(cities, db_path = default_db_path(), seed_samples = TRUE,
                       default_lang = "pt", places = load_places(),
                       standalone_path = "index.html") {
  force(cities)
  force(places)
  force(db_path)
  force(seed_samples)
  force(default_lang)
  force(standalone_path)

  function(input, output, session) {
    con <- db_connect(db_path)
    session$onSessionEnded(function() try(DBI::dbDisconnect(con), silent = TRUE))
    if (isTRUE(seed_samples)) {
      update_events(con, seed_samples = TRUE, autopopulate = TRUE, cities_df = cities)
    }
    if (!is.null(standalone_path) && nzchar(standalone_path)) {
      tryCatch(build_standalone(standalone_path), error = function(e) invisible(NULL))
    }

    # input$lang comes from the browser (see lang_toggle() and ac-shiny.js).
    fallback_lang <- detect_lang(session$request$HTTP_ACCEPT_LANGUAGE, default = default_lang)
    lang <- shiny::reactive(normalize_lang(input$lang %||% fallback_lang))
    # TRUE while the page is dark (dusk or night by the visitor's clock, or the
    # toggle); sent by ac-shiny.js. Night activities then lead the lists.
    night <- shiny::reactive(isTRUE(input$night))

    refresh <- shiny::reactiveVal(0L)
    map_focus <- shiny::reactiveVal(NULL)

    all_events <- shiny::reactive({
      refresh()
      db_fetch_events(con)
    })
    city_events <- shiny::reactive({
      ev <- all_events()
      ev[ev$city == map$city()$label, , drop = FALSE]
    })
    providers <- shiny::reactive(providers_default(con))

    events <- mod_events_server("events", events = city_events, lang = lang, night = night)

    # The visitor's clock (sent by the browser every minute) for opening hours.
    clock <- shiny::reactive(client_clock(input$clock))
    mode <- shiny::reactive(if (identical(input$mode, "places")) "places" else "events")
    city_places <- shiny::reactive(places[places$city == map$city()$label, , drop = FALSE])
    # OpenStreetMap has no ratings: then there is no "rating" colour mode.
    has_ratings <- any(!is.na(places$rating))
    places_mod <- mod_places_server(
      "places", places = city_places, query = shiny::reactive(input[["events-q"]] %||% ""),
      clock = clock, lang = lang
    )

    map <- mod_map_server(
      "map", cities,
      points = shiny::reactive({
        if (mode() == "places") places_as_points(places_mod$filtered(), clock()) else with_price_band(events$filtered())
      }),
      color_modes = shiny::reactive({
        if (mode() == "places") place_color_modes(lang(), rating = has_ratings) else event_color_modes(lang())
      }),
      popup_fun = function(pts, lang) {
        if ("place_id" %in% names(pts)) place_popup_html(pts, lang, clock()) else event_popup_html(pts, lang)
      },
      label_fun = function(pts) if ("name" %in% names(pts)) pts$name else pts$title,
      focus = map_focus,
      lang = lang,
      # Places carry their neighbourhood for the "By neighbourhood" view.
      extra_columns = "neighborhood"
    )

    # "Can't decide?": this city's places and the next days' events.
    mod_decide_server(
      "decide", places = city_places,
      events = shiny::reactive({
        ev <- city_events()
        day <- as.Date(substr(ev$starts_at, 1L, 10L), format = "%Y-%m-%d")
        ev[!is.na(day) & day >= Sys.Date() - 1L & day <= Sys.Date() + 9L, , drop = FALSE]
      }),
      lang = lang, clock = clock
    )

    cal <- mod_calendar_server("calendar", events = shiny::reactive(with_price_band(events$undated())), lang = lang)

    search_mod <- mod_search_server(
      "search", providers = providers, city = map$city, con = con,
      on_autopopulated = function(n) refresh(refresh() + 1L),
      lang = lang, night = night
    )

    show_view <- function(value) {
      session$sendCustomMessage("ac-view", list(target = MAP_ELEMENT_ID, value = value))
    }
    show_pane <- function(value) session$sendCustomMessage("ac-pane", list(value = value))
    show_on_map <- function(request) {
      show_view("map")
      map_focus(request)
    }

    mod_add_event_server(
      "add", con = con, city = map$city, clicked = map$clicked,
      on_added = function(new_id) {
        refresh(refresh() + 1L)
        map$clear_pick()
        show_pane("list")
        ev <- all_events()
        row <- ev[ev$id == new_id, , drop = FALSE]
        show_on_map(focus_request(new_id, point = if (nrow(row) == 1L) with_price_band(row) else NULL))
        if (!new_id %in% events$filtered()$id) {
          shiny::showNotification(tr("notif_hidden", lang()), type = "warning")
        }
      },
      lang = lang
    )

    shiny::observeEvent(events$focus(), show_on_map(events$focus()))
    shiny::observeEvent(cal$focus(), show_on_map(cal$focus()))
    shiny::observeEvent(places_mod$focus(), show_on_map(places_mod$focus()))

    # A search result may be in another city: switch to it first.
    shiny::observeEvent(search_mod$focus(), {
      f <- search_mod$focus()
      row <- f$point
      if (!is.null(row) && nrow(row) == 1L && !identical(row$city, map$city()$label)) {
        target <- cities[cities$label == row$city, , drop = FALSE]
        if (nrow(target) == 1L) map$set_city(target$id)
      }
      if (!is.null(row)) f$point <- with_price_band(row)
      show_on_map(f)
    })

    # "Show this day / month on the map": set the date filter (a removable
    # chip), then fit the map to the events once they arrive.
    shiny::observeEvent(cal$show_day(), {
      d <- as.Date(cal$show_day())
      events$set_range(d, d)
      show_view("map")
      map$fit_next()
    })
    shiny::observeEvent(cal$show_month(), {
      first <- as.Date(paste0(cal$show_month(), "-01"))
      last <- seq(first, length.out = 2L, by = "1 month")[[2]] - 1L
      events$set_range(first, last)
      show_view("map")
      map$fit_next()
    })
  }
}
