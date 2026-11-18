# Build the standalone, single-file edition of the app (index.html).
#
# inst/standalone/template.html holds the page; every line of the form
#   @@include <path relative to inst/>
# is replaced by that file's lines: the shared CSS and JS in inst/www, the
# dictionary in inst/i18n and the data in inst/extdata. The result opens in
# any browser without R or a server (map tiles need the internet).
#
# tools/build-standalone.mjs does the same with Node and produces a
# byte-identical file; tests/testthat/test-standalone.R checks both agree.
build_standalone <- function(path = "index.html",
                             template = system.file("standalone", "template.html", package = "aconteceR")) {
  if (!nzchar(template) || !file.exists(template)) {
    stop("Standalone template not found: ", template, call. = FALSE)
  }
  read_lines <- function(f) {
    x <- readLines(f, encoding = "UTF-8", warn = FALSE)
    if (length(x)) x[[1]] <- sub("^\ufeff", "", x[[1]])
    x
  }
  out <- character()
  for (line in read_lines(template)) {
    m <- regmatches(line, regexec("^\\s*@@include (\\S+)\\s*$", line, perl = TRUE))[[1]]
    if (length(m) == 0L) {
      out <- c(out, line)
      next
    }
    rel <- m[[2]]
    file <- system.file(rel, package = "aconteceR")
    if (!nzchar(file)) stop("File to include not found: inst/", rel, call. = FALSE)
    content <- read_lines(file)
    # These would close the surrounding <script>, <style> or comment early.
    bad <- grepl("</script|</style|<!--|-->", content, ignore.case = TRUE, perl = TRUE)
    if (any(bad)) {
      stop("inst/", rel, " line ", which(bad)[[1]],
           " contains a sequence that would break the inlined HTML.", call. = FALSE)
    }
    out <- c(out, content)
  }
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeLines(out, con, sep = "\n", useBytes = TRUE)
  invisible(path)
}
