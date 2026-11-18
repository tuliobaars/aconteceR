\name{db_connect}
\alias{db_connect}
\alias{default_db_path}
\title{The events database}
\description{
Open (and create if needed) the SQLite database that stores events. All
queries use bound parameters.
}
\usage{
db_connect(path = default_db_path())

default_db_path()
}
\arguments{
  \item{path}{File path, or \code{":memory:"} for a temporary database.}
}
\details{
\code{default_db_path} uses \code{getOption("aconteceR.db_path")} when set,
else a per-user data folder (\code{tools::R_user_dir("aconteceR", "data")}),
else \code{inst/extdata} or the temporary folder when that is not writable.
}
\value{\code{db_connect}: a DBI connection. \code{default_db_path}: a path.}
\examples{
con <- db_connect(":memory:")
DBI::dbListTables(con)
DBI::dbDisconnect(con)
}
