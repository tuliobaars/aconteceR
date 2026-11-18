test_that("every file the standalone template includes exists", {
  tpl <- readLines(system.file("standalone", "template.html", package = "aconteceR"), warn = FALSE)
  inc <- sub("^\\s*@@include (\\S+)\\s*$", "\\1", grep("^\\s*@@include ", tpl, value = TRUE))
  expect_gt(length(inc), 5L)
  for (f in inc) expect_true(nzchar(system.file(f, package = "aconteceR")), info = f)
})

test_that("build_standalone writes one self-contained file", {
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out))
  build_standalone(out)
  html <- readLines(out, encoding = "UTF-8", warn = FALSE)
  expect_false(any(grepl("@@include", html, fixed = TRUE)))
  expect_true(any(grepl("AC.PointMap = PointMap", html, fixed = TRUE)))
  expect_true(any(grepl("Leaflet 1.3.1", html, fixed = TRUE)))
  expect_false(any(grepl("<script[^>]+src=", html)))
  expect_false(any(grepl("<link[^>]+stylesheet", html)))
})

test_that("the committed index.html is up to date (R and Node builders agree)", {
  committed <- testthat::test_path("..", "..", "index.html")
  skip_if_not(file.exists(committed), "index.html is only in the source tree")
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out))
  build_standalone(out)
  expect_identical(
    readBin(out, "raw", file.size(out)),
    readBin(committed, "raw", file.size(committed)),
    label = "build_standalone() output",
    expected.label = "index.html (rebuild with aconteceR::build_standalone(\"index.html\"))"
  )
})

test_that("run_app updates events and generates standalone HTML when opened", {
  db_file <- tempfile(fileext = ".sqlite")
  html_file <- tempfile(fileext = ".html")
  on.exit(unlink(c(db_file, html_file)), add = TRUE)

  app <- run_app(
    db_path = db_file,
    cities = load_cities()[1:2, ],
    places = load_places()[1:4, ],
    standalone_path = html_file
  )
  expect_s3_class(app, "shiny.appobj")
  expect_true(file.exists(html_file))
  expect_gt(file.size(html_file), 100000)

  con <- db_connect(db_file)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  ev <- db_fetch_events(con)
  expect_gt(nrow(ev), 1280L)
  expect_true(all(c("sample", "sympla", "eventbrite", "meetup") %in% ev$source))
})
