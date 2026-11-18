\encoding{UTF-8}
\name{osm}
\alias{osm}
\alias{fetch_osm_places}
\alias{overpass_query}
\alias{osm_category}
\alias{write_places_csv}
\title{Lugares do OpenStreetMap (API Overpass, sem necessidade de chave)}
\description{
\code{fetch_osm_places} baixa bares, pubs, baladas, restaurantes, cafés, casas
de show, teatros, cinemas, galerias e casas de dança ao redor de cada cidade a
partir do OpenStreetMap por meio da API pública Overpass, mapeia suas tags para
as dez categorias e palavras-chave de *vibe* do aplicativo, e os retorna no
formato de lugares (consulte \code{\link{load_places}}). As respostas brutas são
armazenadas em cache como JSON, um arquivo por cidade, para que uma execução
interrompida continue de onde parou e uma nova execução não precise de rede.
\code{write_places_csv} grava o resultado para \code{load_places}.
\code{overpass_query} monta a consulta Overpass QL para uma cidade e
\code{osm_category} mapeia as tags de um lugar para uma categoria.
}
\usage{
fetch_osm_places(cities = load_cities(), cache_dir = "osm-cache", radius_km = 12,
                 per_category = 30, refresh = FALSE, pause = 5, retries = 3L,
                 endpoints = OVERPASS_ENDPOINTS, user_agent = osm_user_agent(),
                 fetch = osm_download, verbose = TRUE)

write_places_csv(places, path)

overpass_query(lat, lon, radius_m = 12000, timeout = 180)

osm_category(tags)
}
\arguments{
  \item{cities}{Data frame com \code{label}, \code{lat}, \code{lon}
    (\code{\link{load_cities}}).}
  \item{cache_dir}{Pasta para as respostas brutas do Overpass.}
  \item{radius_km, radius_m}{Raio de busca ao redor do centro da cidade.}
  \item{per_category}{Número máximo de lugares mantidos por categoria e cidade,
    os mais completos primeiro (horários de funcionamento contam mais);
    \code{Inf} mantém todos.}
  \item{refresh}{Baixar novamente mesmo quando já existir resposta em cache.}
  \item{pause}{Segundos de espera entre requisições (dobrados a cada rodada de
    nova tentativa), conforme solicita a política de uso do Overpass.}
  \item{retries}{Rodadas sobre todos os servidores antes de desistir.}
  \item{endpoints}{URLs da API Overpass, tentadas em sequência.}
  \item{user_agent}{Cabeçalho User-Agent que identifica o cliente.}
  \item{fetch}{\code{function(url, destfile, user_agent)} que baixa uma URL para
    um arquivo; pode ser substituída em testes ou para uso de proxy.}
  \item{verbose}{Imprimir o progresso.}
  \item{places}{Um data frame de lugares.}
  \item{path}{Arquivo CSV de saída.}
  \item{lat, lon}{Centro da cidade.}
  \item{timeout}{Tempo limite no servidor Overpass, em segundos.}
  \item{tags}{Lista nomeada com as tags OSM de um elemento.}
}
\value{
\code{fetch_osm_places}: um data frame com as colunas de lugares; \code{rating},
\code{reviews_count} e \code{price_level} ficam vazios (o OpenStreetMap não
possui avaliações), \code{maps_url} é um link de busca no Google Maps (sem
chave), \code{osm_url} é a página do elemento e \code{source} é
\code{"openstreetmap"}. Um lugar encontrado em duas cidades próximas é mantido
na cidade mais próxima. \code{overpass_query}: uma string.
\code{osm_category}: uma chave de categoria ou \code{NA}.
}
\details{
Dados (c) contribuidores do OpenStreetMap, disponíveis sob a Open Database
Licence (ODbL 1.0, \url{https://www.openstreetmap.org/copyright}). O arquivo de
lugares resultante é um banco de dados derivado sob a mesma licença; o
aplicativo exibe a atribuição sempre que lista lugares do OpenStreetMap. O
script \code{inst/scripts/fetch_places_osm.R} executa todo o download e grava
\code{inst/extdata/places.csv}. (Versão em inglês: \code{man-en/osm.Rd}.)
}
\examples{
cat(overpass_query(-8.05, -34.9, 5000))
osm_category(list(amenity = "bar", name = "Terra\u00e7o Sunset"))
\dontrun{
# Requer internet; leva alguns minutos para todas as cidades.
places <- fetch_osm_places()
write_places_csv(places, "inst/extdata/places.csv")
}
}
