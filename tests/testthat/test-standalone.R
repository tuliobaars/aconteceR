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
