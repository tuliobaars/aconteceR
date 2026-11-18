# Start the app.
#   db_path          SQLite file for saved events (default: per-user data folder).
#   seed_samples     update demo and catalog events on start.
#   cities           city table, see load_cities().
#   places           places table, see load_places() (bars, restaurants, clubs...).
#   default_lang     UI language ("pt" or "en") when neither ?lang= nor the
#                    browser's Accept-Language header names one of them.
#   options          passed to shiny::shinyApp().
#   standalone_path  path to rebuild the standalone HTML (default: "index.html")
#                    every time the app is opened; NULL skips rebuilding.
run_app <- function(db_path = default_db_path(), seed_samples = TRUE,
                    cities = load_cities(), default_lang = "pt", options = list(),
                    places = load_places(), standalone_path = "index.html") {
  con <- db_connect(db_path)
  on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
  if (isTRUE(seed_samples)) {
    update_events(con, seed_samples = TRUE, autopopulate = TRUE, cities_df = cities)
  }
  if (!is.null(standalone_path) && nzchar(standalone_path)) {
    tryCatch(build_standalone(standalone_path), error = function(e) invisible(NULL))
  }
  shiny::shinyApp(
    ui = app_ui(cities, default_lang = default_lang, places = places),
    server = app_server(cities, db_path = db_path, seed_samples = seed_samples,
                        default_lang = default_lang, places = places,
                        standalone_path = standalone_path),
    options = options
  )
}
