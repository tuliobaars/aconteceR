\encoding{UTF-8}
\name{run_app}
\alias{run_app}
\title{Executar o aplicativo Shiny aconteceR}
\description{
Inicia o aplicativo bilíngue (Português do Brasil / Inglês) de eventos e
lugares: um mapa de eventos colorido por preço ou categoria, com agrupamento
(*clustering*), calendário mensal, busca e importação de fontes de eventos e
formulário para adicionar eventos; lugares (bares, restaurantes, baladas, ...)
classificados por *vibe*; e "Não sabe onde ir?", que classifica lugares e
eventos pelo que está aberto, *vibe*, avaliação e orçamento. A página abre no
idioma do visitante e na cidade mais próxima dele. Sempre que o aplicativo é
aberto, ele atualiza automaticamente os eventos (\code{\link{update_events}}) e
gera o arquivo HTML autônomo (\code{\link{build_standalone}}).
}
\usage{
run_app(db_path = default_db_path(), seed_samples = TRUE,
        cities = load_cities(), default_lang = "pt", options = list(),
        places = load_places(), standalone_path = "index.html")
}
\arguments{
  \item{db_path}{Caminho do arquivo SQLite que armazena os eventos (consulte
    \code{\link{default_db_path}}).}
  \item{seed_samples}{Atualizar os eventos de demonstração e do catálogo de
    fontes ao abrir (\code{\link{update_events}}).}
  \item{cities}{Tabela de cidades, consulte \code{\link{load_cities}}.}
  \item{default_lang}{\code{"pt"} ou \code{"en"}: o idioma utilizado quando nem
    \code{?lang=} nem o navegador indicam Português, Inglês ou uma localidade
    brasileira.}
  \item{options}{Repassado para \code{\link[shiny]{shinyApp}}.}
  \item{places}{Tabela de lugares (bares, restaurantes, baladas, ...), consulte
    \code{\link{load_places}}.}
  \item{standalone_path}{Caminho onde gerar a edição HTML autônoma
    (\code{"index.html"} por padrão) sempre que o aplicativo é aberto; use
    \code{NULL} para pular a geração.}
}
\value{Um objeto \code{shiny.appobj}.}
\seealso{\code{\link{build_standalone}} para a edição HTML em arquivo único e
\code{\link{update_events}} para a atualização de eventos. (Versão em inglês:
\code{man-en/run_app.Rd}.)}
\examples{
\dontrun{
run_app()
run_app(default_lang = "en", db_path = tempfile(fileext = ".sqlite"))
}
}
