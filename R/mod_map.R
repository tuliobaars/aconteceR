# Reusable map module. A place picker plus a Leaflet map (drawn in the browser
# by AC.PointMap, inst/www/ac-map.js) with a toolbar: colour-by switch,
# clustering, locate / fit / re-centre, a live legend, click-to-pick and
# fly-to-focus. It knows nothing about events, so another project (for example
# a rent and buy price map) reuses it by passing its own points, colour modes
# and popups (`color_modes` may also be a reactive, e.g. to switch sets):
#
#   mod_map_ui("map", places)
#   map <- mod_map_server(
#     "map", places,
#     points      = reactive(listings),          # id, lat, lon + colour columns
#     color_modes = list(
#       price = map_color_bins("price_m2", breaks = c(0, 8000, 12000, Inf),
#                              colors = c("#1a9850", "#fee08b", "#d73027"),
#                              label = "R$/m\u00b2"),
#       type  = map_color_factor("type", colors = c(apartment = "#1b9e77", house = "#d95f02"))
#     ),
#     popup_fun = function(pts) paste0("<b>", escape_html(pts$address), "</b>"),
#     label_fun = function(pts) pts$address
#   )
#   map$city(); map$clicked(); map$selected_id(); map$color_mode()
#
# `places` (the `cities` argument) is a data frame with id, label, lat, lon.
# `popup_fun(pts)` returns HTML: pass user text through escape_html(). It may
# take a `lang` argument. `label_fun(pts)` returns plain text (escaped in the
# browser). `color_modes` is a named list of map_color_factor() /
# map_color_bins() specs, or a function(lang) returning one.
#
# `group_by` (UI) names a point column, e.g. "neighborhood": a switch in the
# bar then shows one bubble per group (size = count, colour = the active
# colour mode's most common level, or the bin of the median value), and the
# largest groups in the legend. Send that column with the points through
# `extra_columns` (server), which adds any columns the browser should get.
#
# Returns list(city, clicked, selected_id, color_mode, cluster, group,
#              located, clear_pick, set_city, fit, fit_next, show_route,
#              clear_route, set_group):
#   city()         one-row data frame of the selected place
#   clicked()      list(lat, lon) of the last map click, or NULL
#   selected_id()  id of the last clicked marker, or NULL
#   color_mode()   id of the active colour mode
#   cluster()      TRUE when clustering is on
#   group()        TRUE while the group view (group_by) is on
#   located()      list(placeId, km, source, ...) after auto-locate / "locate me"
#   clear_pick(), set_city(id), fit(), fit_next() (fit to the next points update)
#   show_route(stops)  numbered stops joined by a dashed line; `stops` is a
#                      data frame with lat, lon and optional label, popup
#   clear_route(), set_group(on)

# ---------------------------------------------------------------- colour modes

# Colour by a categorical column. `colors` is named by the column's values;
# `labels` (same names, or same order) is what the legend shows.
map_color_factor <- function(column, colors, labels = names(colors), label = column,
                             title = label, na_color = "#8c8c8c", na_label = "NA") {
  stopifnot(is.character(column), length(column) == 1L, !is.null(names(colors)))
  keys <- names(colors)
  lab <- if (!is.null(names(labels))) unname(labels[keys]) else rep_len(as.character(labels), length(keys))
  lab[is.na(lab)] <- keys[is.na(lab)]
  structure(
    list(
      type = "factor", column = column, label = label, title = title,
      levels = lapply(seq_along(keys), function(i) {
        list(key = keys[[i]], color = unname(colors[[i]]), label = lab[[i]])
      }),
      na_color = na_color, na_label = na_label
    ),
    class = "ac_color_mode"
  )
}

# Colour by a numeric column cut into bins. Bins are right-closed like
# cut(): (b0, b1], (b1, b2], ... and the first bin includes b0. `breaks` may
# start with -Inf or end with Inf. One colour (and label) per bin. `format`
# turns break values into text for the generated labels. (Its default calls
# base::format() explicitly: a bare format() would call this argument.)
map_color_bins <- function(column, breaks, colors, labels = NULL, label = column,
                           title = label, na_color = "#8c8c8c", na_label = "NA",
                           format = function(x) base::format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) {
  stopifnot(is.character(column), length(column) == 1L)
  breaks <- sort(unique(as.numeric(breaks)))
  n <- length(breaks) - 1L
  if (n < 1L) stop("`breaks` needs at least two values.", call. = FALSE)
  if (length(colors) != n) stop("Give one colour per bin (", n, ").", call. = FALSE)
  lo <- breaks[-length(breaks)]
  hi <- breaks[-1L]
  if (is.null(labels)) {
    labels <- ifelse(is.infinite(hi), paste0("> ", format(lo)),
                     ifelse(is.infinite(lo), paste0("\u2264 ", format(hi)),
                            paste0(format(lo), " \u2013 ", format(hi))))
  }
  if (length(labels) != n) stop("Give one label per bin (", n, ").", call. = FALSE)
  # JSON has no Inf; a huge finite number behaves the same in the browser.
  breaks[is.infinite(breaks)] <- sign(breaks[is.infinite(breaks)]) * 1e300
  structure(
    list(
      type = "bins", column = column, label = label, title = title,
      breaks = breaks, colors = unname(as.character(colors)), labels = as.character(labels),
      na_color = na_color, na_label = na_label
    ),
    class = "ac_color_mode"
  )
}

# Named list of modes -> list of plain specs with an `id`, for the browser.
color_modes_payload <- function(modes) {
  if (is.null(modes) || !length(modes)) return(list())
  ids <- names(modes)
  if (is.null(ids) || any(!nzchar(ids))) stop("`color_modes` must be a named list.", call. = FALSE)
  lapply(seq_along(modes), function(i) {
    m <- unclass(modes[[i]])
    m$id <- ids[[i]]
    m
  })
}

# The colour each row gets under a mode (R twin of AC.color.resolve, handy for
# tests, exports and static maps).
color_mode_colors <- function(mode, data) {
  v <- data[[mode$column]]
  n <- nrow(data)
  if (is.null(v)) return(rep(mode$na_color, n))
  if (identical(mode$type, "bins")) {
    x <- suppressWarnings(as.numeric(v))
    i <- findInterval(x, mode$breaks, left.open = TRUE, rightmost.closed = FALSE)
    i[!is.na(x) & x == mode$breaks[[1]]] <- 1L
    out <- rep(mode$na_color, n)
    ok <- !is.na(i) & i >= 1L & i <= length(mode$colors)
    out[ok] <- mode$colors[i[ok]]
    return(out)
  }
  keys <- vapply(mode$levels, function(l) as.character(l$key), character(1))
  cols <- vapply(mode$levels, function(l) as.character(l$color), character(1))
  out <- cols[match(as.character(v), keys)]
  out[is.na(out)] <- mode$na_color
  out
}

to_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
}

# Points for the browser: id, lat, lon, label, popup + the colour columns.
map_points_json <- function(pts, columns = character(), popup = NULL, label = NULL) {
  n <- if (is.null(pts)) 0L else nrow(pts)
  if (n == 0L) return("[]")
  df <- data.frame(
    id = as.character(pts$id), lat = as.numeric(pts$lat), lon = as.numeric(pts$lon),
    label = if (is.null(label)) NA_character_ else as.character(label),
    popup = if (is.null(popup)) NA_character_ else as.character(popup),
    stringsAsFactors = FALSE
  )
  for (col in setdiff(columns, names(df))) {
    if (col %in% names(pts)) df[[col]] <- pts[[col]]
  }
  as.character(jsonlite::toJSON(df, dataframe = "rows", na = "null", digits = NA))
}

# Route stops for the browser: lat, lon, n (1, 2, ...), label, popup.
route_stops_json <- function(stops) {
  if (is.null(stops) || nrow(stops) == 0L) return("[]")
  df <- data.frame(lat = as.numeric(stops$lat), lon = as.numeric(stops$lon), n = seq_len(nrow(stops)),
                   stringsAsFactors = FALSE)
  df$label <- if (is.null(stops$label)) NA_character_ else as.character(stops$label)
  df$popup <- if (is.null(stops$popup)) NA_character_ else as.character(stops$popup)
  as.character(jsonlite::toJSON(df, dataframe = "rows", na = "null", digits = NA))
}

call_maybe_lang <- function(fun, x, lang) {
  if ("lang" %in% names(formals(fun))) fun(x, lang = lang) else fun(x)
}

default_point_label <- function(pts) {
  for (col in c("label", "title", "name")) if (col %in% names(pts)) return(as.character(pts[[col]]))
  as.character(pts$id)
}

# ------------------------------------------------------------------------- UI

# `selected`: place id to open on. When NULL the map opens on default_city()
# and, with `auto_locate`, moves to the place closest to the visitor (time-zone
# guess first, then the browser's geolocation if the visitor allows it).
# `tiles`: NULL or "auto" (key-free: OpenStreetMap, or Esri's public street
# map when the page is opened from disk, since OSM wants a Referer), "osm",
# "esri", list(url =, attribution =, subdomains =, maxZoom =), or
# list(light = list(...), dark = list(...)). The colours follow the time of day
# through a CSS filter, so one tile set serves light and dark.
# `place_target`, `modes_target`: CSS selectors of elements elsewhere on the
# page to hold the place picker and the colour-by switch (default: on the map).
# `toolbar_end`: extra tags for the end of the floating map bar.
# `overlays`: named list of tags layered over the map, shown when the map
# root's data-view attribute equals the name (see the view switch in app_ui.R).
mod_map_ui <- function(id, cities, selected = NULL, color_mode = NULL, cluster = FALSE,
                       auto_locate = is.null(selected), locate = TRUE, pickable = TRUE,
                       zoom = 12, tiles = NULL, place_target = NULL, modes_target = NULL,
                       toolbar_end = NULL, overlays = NULL, group_by = NULL) {
  ns <- shiny::NS(id)
  start <- if (is.null(selected)) default_city(cities) else selected
  name_col <- if ("city" %in% names(cities)) cities$city else cities$label
  config <- list(
    places = lapply(seq_len(nrow(cities)), function(i) {
      list(id = as.character(cities$id[[i]]), label = cities$label[[i]], name = name_col[[i]],
           lat = cities$lat[[i]], lon = cities$lon[[i]])
    }),
    place = as.character(start),
    colorMode = color_mode,
    cluster = isTRUE(cluster),
    autoLocate = isTRUE(auto_locate),
    locate = isTRUE(locate),
    pickable = isTRUE(pickable),
    zoom = zoom,
    tiles = tiles,
    placeTarget = place_target,
    modesTarget = modes_target,
    groupBy = group_by
  )
  overlay_tags <- lapply(names(overlays), function(nm) {
    htmltools::div(class = "ac-pm-overlay", `data-view-name` = nm, overlays[[nm]])
  })
  htmltools::div(
    id = ns("pm"), class = "ac-pm", `data-view` = "map",
    `data-ac-pointmap` = to_json(config),
    htmltools::div(
      class = "ac-pm-body",
      htmltools::div(class = "ac-pm-canvas"),
      overlay_tags,
      htmltools::div(class = "ac-pm-bar", htmltools::div(class = "ac-pm-bar-end", toolbar_end))
    )
  )
}

# --------------------------------------------------------------------- server

mod_map_server <- function(id, cities,
                           points = shiny::reactive(NULL),
                           color_modes = NULL,
                           popup_fun = NULL,
                           label_fun = NULL,
                           focus = shiny::reactive(NULL),
                           lang = shiny::reactive("en"),
                           selected = NULL,
                           extra_columns = character()) {
  shiny::moduleServer(id, function(input, output, session) {
    el_id <- session$ns("pm")
    send <- function(action, ...) {
      session$sendCustomMessage("ac-map", list(id = el_id, action = action, ...))
    }
    start <- if (is.null(selected)) default_city(cities) else selected

    city <- shiny::reactive({
      row <- find_city(cities, input$pm_place %||% start)
      if (nrow(row) != 1L) row <- find_city(cities, start)
      row
    })

    modes <- shiny::reactive({
      if (shiny::is.reactive(color_modes)) color_modes()
      else if (is.function(color_modes)) color_modes(lang())
      else color_modes
    })

    shiny::observe({
      send("modes", modes = to_json(color_modes_payload(modes())))
    })

    point_payload <- function(pts, l) {
      cols <- unique(c(unlist(lapply(modes(), function(m) m$column)), extra_columns))
      popup <- if (is.null(popup_fun) || nrow(pts) == 0L) NULL else call_maybe_lang(popup_fun, pts, l)
      label <- if (nrow(pts) == 0L) NULL else if (is.null(label_fun)) default_point_label(pts) else label_fun(pts)
      map_points_json(pts, cols, popup = popup, label = label)
    }

    shiny::observe({
      pts <- points()
      if (is.null(pts)) pts <- data.frame(id = character(), lat = numeric(), lon = numeric())
      send("points", points = point_payload(pts, lang()))
    })

    # Fly to a point and open its popup. focus() returns focus_request(id,
    # point); `point` (a one-row data frame) is used when the id is not among
    # the current points, e.g. a search result or an event outside the dates.
    shiny::observeEvent(focus(), {
      f <- focus()
      if (is.null(f) || is.null(f$id)) return(invisible(NULL))
      pts <- shiny::isolate(points())
      row <- NULL
      if (!is.null(pts) && nrow(pts) > 0L) {
        row <- pts[as.character(pts$id) == as.character(f$id), , drop = FALSE]
      }
      if (is.null(row) || nrow(row) != 1L) row <- f$point
      if (is.null(row) || nrow(row) != 1L) return(invisible(NULL))
      target <- jsonlite::fromJSON(point_payload(row, shiny::isolate(lang())), simplifyVector = FALSE)[[1]]
      send("focus", target = target)
    }, ignoreNULL = TRUE)

    list(
      city = city,
      clicked = shiny::reactive({
        cl <- input$pm_click
        if (is.null(cl)) NULL else list(lat = cl$lat, lon = cl$lon)
      }),
      selected_id = shiny::reactive(input$pm_marker_click$id),
      color_mode = shiny::reactive(input$pm_color_mode %||% names(modes())[1]),
      cluster = shiny::reactive(isTRUE(input$pm_cluster)),
      group = shiny::reactive(isTRUE(input$pm_group)),
      located = shiny::reactive(input$pm_located),
      clear_pick = function() send("clear_pick"),
      set_city = function(id) send("place", place = as.character(id)),
      fit = function() send("fit"),
      fit_next = function() send("fit", deferred = TRUE),
      show_route = function(stops) send("route", stops = route_stops_json(stops)),
      clear_route = function() send("clear_route"),
      set_group = function(on = TRUE) send("group", on = isTRUE(on))
    )
  })
}
