\encoding{UTF-8}
\name{db_connect}
\alias{db_connect}
\alias{default_db_path}
\alias{update_events}
\title{O banco de dados de eventos}
\description{
Abre (e cria, se necessário) o banco de dados SQLite que armazena os eventos, e
atualiza os eventos de demonstração e de fontes externas para a data atual.
Todas as consultas utilizam parâmetros vinculados.
}
\usage{
db_connect(path = default_db_path())

default_db_path()

update_events(con, seed_samples = TRUE, autopopulate = TRUE,
              cities_df = load_cities(), today = Sys.Date())
}
\arguments{
  \item{path}{Caminho do arquivo, ou \code{":memory:"} para um banco temporário.}
  \item{con}{Conexão com o banco de dados obtida com \code{db_connect}.}
  \item{seed_samples}{Se \code{TRUE}, carrega ou atualiza as datas dos eventos de
    demonstração (\code{source = "sample"}).}
  \item{autopopulate}{Se \code{TRUE}, importa ou atualiza as datas dos eventos
    do catálogo de fontes externas (\code{\link{autopopulate_events}}).}
  \item{cities_df}{Tabela de cidades, consulte \code{\link{load_cities}}.}
  \item{today}{Data de referência (\code{Date}) para calcular os horários.}
}
\details{
\code{default_db_path} utiliza \code{getOption("aconteceR.db_path")} quando
definido; caso contrário, usa uma pasta de dados por usuário
(\code{tools::R_user_dir("aconteceR", "data")}), ou \code{inst/extdata} / a
pasta temporária quando o diretório não permite escrita. \code{update_events}
preserva todos os eventos adicionados pelo usuário (\code{source = "user"}).
(Versão em inglês: \code{man-en/db_connect.Rd}.)
}
\value{\code{db_connect}: uma conexão DBI. \code{default_db_path}: um caminho de
arquivo. \code{update_events}: número de eventos adicionados ou atualizados
(invisivelmente).}
\examples{
con <- db_connect(":memory:")
DBI::dbListTables(con)
DBI::dbDisconnect(con)
}
