\name{db_connect}
\alias{db_connect}
\alias{default_db_path}
\alias{update_events}
\title{The events database}
\description{
Open (and create if needed) the SQLite database that stores events, and refresh
sample and external catalog events for today. All queries use bound parameters.
}
\usage{
db_connect(path = default_db_path())

default_db_path()

update_events(con, seed_samples = TRUE, autopopulate = TRUE,
              cities_df = load_cities(), today = Sys.Date())
}
\arguments{
  \item{path}{File path, or \code{":memory:"} for a temporary database.}
  \item{con}{Database connection from \code{db_connect}.}
  \item{seed_samples}{If \code{TRUE}, load or refresh demo events (\code{source = "sample"}).}
  \item{autopopulate}{If \code{TRUE}, import or refresh external catalog events
    (\code{\link{autopopulate_events}}).}
  \item{cities_df}{City table, see \code{\link{load_cities}}.}
  \item{today}{Reference \code{Date} used to date events.}
}
\details{
\code{default_db_path} uses \code{getOption("aconteceR.db_path")} when set,
else a per-user data folder (\code{tools::R_user_dir("aconteceR", "data")}),
else \code{inst/extdata} or the temporary folder when that is not writable.
\code{update_events} preserves user-added events (\code{source = "user"}).
}
\value{\code{db_connect}: a DBI connection. \code{default_db_path}: a path.
\code{update_events}: number of events added or refreshed (invisibly).}
\examples{
con <- db_connect(":memory:")
DBI::dbListTables(con)
DBI::dbDisconnect(con)
}
