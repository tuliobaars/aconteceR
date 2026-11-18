# Start the app.
#   db_path       SQLite file for saved events (default: per-user data folder).
#   seed_samples  add the demo events on start (they are marked source = "sample").
#   cities        city table, see load_cities().
#   places        places table, see load_places() (bars, restaurants, clubs...).
#   default_lang  UI language ("pt" or "en") when neither ?lang= nor the
#                 browser's Accept-Language header names one of them.
#   options       passed to shiny::shinyApp().
run_app <- function(db_path = default_db_path(), seed_samples = TRUE,
                    cities = load_cities(), default_lang = "pt", options = list(),
                    places = load_places()) {
  shiny::shinyApp(
    ui = app_ui(cities, default_lang = default_lang, places = places),
    server = app_server(cities, db_path = db_path, seed_samples = seed_samples,
                        default_lang = default_lang, places = places),
    options = options
  )
}
