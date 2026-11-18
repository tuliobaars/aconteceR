# Run from the project folder: open this file in RStudio and press Run App,
# or call shiny::runApp(). Needs shiny, DBI, RSQLite, htmltools and jsonlite.
# With pkgload installed the package is loaded from source; otherwise the
# installed package is used.
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(aconteceR)
}

run_app()
