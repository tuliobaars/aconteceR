\encoding{UTF-8}
\name{mod_map}
\alias{mod_map}
\alias{mod_map_ui}
\alias{mod_map_server}
\title{Módulo de mapa reutilizável}
\description{
Um módulo Shiny com um mapa Leaflet desenhado no navegador: seletor de lugar,
alternância de modo de cor, agrupamento (*clustering*), botões de localizar /
ajustar / recentralizar, legenda com contagens, clique para escolher um ponto e
voo até o ponto selecionado. Ele não possui lógica específica de eventos, de
modo que outros projetos (por exemplo, um mapa de preços de aluguel e venda)
podem reutilizá-lo com seus próprios pontos, modos de cor e popups.
Opcionalmente, agrupa os pontos por uma coluna (por exemplo, um bairro) em uma
bolha por grupo e desenha uma rota numerada entre paradas. (Versão em inglês:
\code{man-en/mod_map.Rd}.)
}
\usage{
mod_map_ui(id, cities, selected = NULL, color_mode = NULL, cluster = FALSE,
           auto_locate = is.null(selected), locate = TRUE, pickable = TRUE,
           zoom = 12, tiles = NULL, place_target = NULL, modes_target = NULL,
           toolbar_end = NULL, overlays = NULL, group_by = NULL)

mod_map_server(id, cities, points = shiny::reactive(NULL), color_modes = NULL,
               popup_fun = NULL, label_fun = NULL, focus = shiny::reactive(NULL),
               lang = shiny::reactive("en"), selected = NULL,
               extra_columns = character())
}
\arguments{
  \item{id}{Identificador do módulo.}
  \item{cities}{Data frame de lugares com \code{id}, \code{label}, \code{lat}, \code{lon}
    (e opcionalmente \code{city}, um nome curto), ex.: \code{\link{load_cities}()}.}
  \item{selected}{Identificador do lugar onde abrir. \code{NULL} abre no lugar padrão e,
    com \code{auto_locate}, move-se para o lugar mais próximo do visitante.}
  \item{color_mode}{Identificador do modo de cor ativo ao iniciar (padrão: o primeiro).}
  \item{cluster}{Iniciar com agrupamento (*clustering*) ativado.}
  \item{auto_locate}{Estimar o lugar mais próximo pelo fuso horário do visitante e, em seguida,
    pela geolocalização do navegador se permitido.}
  \item{locate}{Exibir o botão "cidade mais próxima de mim".}
  \item{pickable}{Clicar no mapa posiciona um pino e informa suas coordenadas.}
  \item{zoom}{Nível de zoom para os lugares.}
  \item{tiles}{\code{NULL} ou \code{"auto"}: blocos sem chave de API, OpenStreetMap, ou o mapa
    de ruas público da Esri quando a página é aberta a partir do disco (o OpenStreetMap exige um
    cabeçalho Referer). Também aceita \code{"osm"}, \code{"esri"}, \code{list(url =, attribution =)},
    ou \code{list(light = list(...), dark = list(...))}. As cores acompanham a hora do dia por
    meio de um filtro CSS.}
  \item{place_target, modes_target}{Seletores CSS de elementos em outro lugar da página que
    receberão o seletor de lugar e o seletor de modo de cor; por padrão eles ficam no mapa.}
  \item{toolbar_end}{Tags extras para o final da barra flutuante do mapa.}
  \item{overlays}{Lista nomeada de tags desenhadas sobre o mapa quando o atributo
    \code{data-view} do elemento do mapa é igual ao nome (por exemplo, a visão de calendário).}
  \item{group_by}{Nome de uma coluna dos pontos (ex.: \code{"neighborhood"}). Um seletor na
    barra do mapa passa a exibir uma bolha por grupo em vez dos pinos: dimensionada pela
    contagem, colorida pelo modo de cor ativo (seu nível mais comum, ou a faixa do valor
    mediano para modos numéricos), com os maiores grupos na legenda. Clicar em uma bolha
    aproxima o zoom nos seus pinos. Envie a coluna com \code{extra_columns}.}
  \item{extra_columns}{Colunas dos pontos a enviar para o navegador além daquelas lidas pelos
    modos de cor (ex.: a coluna de \code{group_by}).}
  \item{points}{Data frame reativo com \code{id}, \code{lat}, \code{lon} e as colunas lidas
    pelos modos de cor.}
  \item{color_modes}{Lista nomeada de especificações \code{\link{map_color_factor}} /
    \code{\link{map_color_bins}}, uma função do idioma que retorne essa lista, ou um reativo
    que a retorne (para alternar entre conjuntos, como o aplicativo faz entre eventos e lugares).}
  \item{popup_fun}{Função dos pontos que retorna o HTML do popup (escape textos com
    \code{\link{escape_html}}). Pode receber um argumento \code{lang}.}
  \item{label_fun}{Função dos pontos que retorna rótulos em texto puro ao passar o mouse.}
  \item{focus}{Reativo que retorna \code{list(id =, point =)} para voar até um ponto e abrir seu
    popup; \code{point} é um data frame de uma linha usado quando o id não está entre os pontos.}
  \item{lang}{Idioma reativo, \code{"pt"} ou \code{"en"}.}
}
\value{
\code{mod_map_ui} retorna uma tag HTML. \code{mod_map_server} retorna uma lista
de reativos \code{city}, \code{clicked}, \code{selected_id}, \code{color_mode},
\code{cluster}, \code{group}, \code{located} e as funções \code{clear_pick()},
\code{set_city(id)}, \code{fit()}, \code{fit_next()}, \code{show_route(stops)}
(paradas numeradas ligadas por uma linha pontilhada; \code{stops} é um data
frame com \code{lat}, \code{lon} e opcionalmente \code{label}, \code{popup}),
\code{clear_route()} e \code{set_group(on)}.
}
\examples{
places <- load_cities()
ui <- mod_map_ui("map", places, cluster = TRUE, group_by = "neighborhood")
modes <- list(
  price = map_color_bins("price_m2", breaks = c(0, 8000, 12000, Inf),
                         colors = c("#1a9850", "#fee08b", "#d73027"), label = "R$/m2"),
  deal = map_color_factor("deal", colors = c(rent = "#1b9e77", buy = "#7570b3"))
)
\dontrun{
server <- function(input, output, session) {
  map <- mod_map_server("map", places, points = shiny::reactive(listings),
                        color_modes = modes, extra_columns = "neighborhood",
                        label_fun = function(pts) pts$address)
}
}
}
