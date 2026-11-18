\encoding{UTF-8}
\name{places}
\alias{places}
\alias{load_places}
\alias{classify_vibes}
\alias{place_open_status}
\alias{parse_opening_hours}
\alias{is_open_late}
\alias{place_categories}
\alias{vibe_groups}
\alias{place_color_modes}
\title{Lugares: bares, restaurantes, baladas e mais, por vibe e horário de funcionamento}
\description{
\code{load_places} lê \code{inst/extdata/places.csv} (uma linha por lugar),
verifica suas colunas e classifica cada lugar em grupos de *vibe*.
\code{classify_vibes} mapeia texto livre (palavras-chave de *vibe*, títulos,
descrições) para os grupos de *vibe* usando as regras em
\code{inst/extdata/vibes.csv}: um padrão coincide no início de uma palavra, um
\code{$} no final exige a palavra inteira, e tokens \code{@category} adicionam
valores padrão por categoria. \code{parse_opening_hours} lê strings
\code{opening_hours} do OpenStreetMap em uma grade semanal.
\code{place_open_status} informa se os lugares estão abertos em um determinado
dia da semana e horário, a partir de \code{opening_hours} quando disponível ou,
caso contrário, das colunas simples \code{opens_at} / \code{closes_at} /
\code{open_days}. \code{is_open_late} indica quais lugares ainda estão abertos
às 02:00 da madrugada de hoje. \code{place_categories} e \code{vibe_groups}
retornam os rótulos; \code{place_color_modes} retorna os modos de cor do mapa
(categoria, *vibe*, status de funcionamento e avaliação).
}
\usage{
load_places(path = system.file("extdata", "places.csv", package = "aconteceR"),
            rules = vibe_rules())

classify_vibes(text, rules = vibe_rules())

parse_opening_hours(x)

place_open_status(opens_at, closes_at, open_days, wday, minutes,
                  opening_hours = NULL)

is_open_late(places, clock)

place_categories(lang = "en")

vibe_groups(lang = "en")

place_color_modes(lang = "en", rating = TRUE)
}
\arguments{
  \item{path}{Arquivo CSV. Colunas obrigatórias: \code{place_id}, \code{name},
    \code{category}, \code{city} (um rótulo de \code{\link{load_cities}}),
    \code{lat}, \code{lon}. Opcionais: \code{vibes} (palavras-chave),
    \code{neighborhood}, \code{address}, \code{opening_hours}, \code{opens_at},
    \code{closes_at}, \code{open_days}, \code{rating}, \code{reviews_count},
    \code{price_level} (1-4), \code{maps_url}, \code{osm_url}, \code{website},
    \code{source}. Arquivos antigos com \code{google_rating} /
    \code{google_maps_url} continuam sendo carregados.
    \code{\link{fetch_osm_places}} grava neste formato.}
  \item{rules}{Data frame de regras de *vibe* com as colunas \code{vibe} e \code{pattern}.}
  \item{text}{Vetor de caracteres a classificar.}
  \item{x, opening_hours}{Strings \code{opening_hours} do OpenStreetMap, ex.:
    \code{"Mo-Sa 18:00-02:00; Su off"}. Suporta: regras separadas por \code{;}
    (regras posteriores prevalecem para seus dias), intervalos e listas de dias
    da semana em Inglês ou Português (\code{"seg-sex"}), vários intervalos de
    horário por dia, horários após a meia-noite (\code{"22:00-26:00"}), horários
    sem fim fixo (\code{"22:00+"}, lidos como quatro horas), \code{off},
    \code{24/7}. Regras com meses, semanas, feriados ou nascer/pôr do sol são
    ignoradas.}
  \item{opens_at, closes_at}{Horários como \code{"HH:MM"}; um horário de fechamento igual
    ou anterior ao de abertura estende-se após a meia-noite.}
  \item{open_days}{Dias em abreviações em Português: intervalos que cruzam a semana
    (\code{"Ter-Dom"}), listas (\code{"Seg,Qua,Sex"}) ou \code{"Todos"}.}
  \item{wday}{Dia da semana do momento consultado, de 0 (domingo) a 6.}
  \item{minutes}{Minutos após a meia-noite do momento consultado (horário local do visitante).}
  \item{places}{Um data frame de lugares (obtido com \code{load_places}).}
  \item{clock}{\code{list(wday, minutes)}: o relógio do visitante.}
  \item{lang}{\code{"pt"} ou \code{"en"}.}
  \item{rating}{Incluir o modo de cor por avaliação (omita para dados sem
    avaliações, como os do OpenStreetMap).}
}
\value{
\code{load_places}: um data frame com as colunas do arquivo mais
\code{vibe_groups} (chaves de *vibe* separadas por vírgula) e \code{vibe_main}.
\code{classify_vibes}: um vetor de caracteres com chaves de *vibe* separadas por
vírgula. \code{parse_opening_hours}: uma lista com uma grade de horários por
valor (\code{NULL} quando não for possível interpretar).
\code{place_open_status}: um data frame com \code{open}, \code{to_close},
\code{to_open} (minutos), \code{days_ahead} (0 = abre mais tarde hoje),
\code{unknown} (sem horário legível), \code{always} (24/7) e os horários
\code{opens_label} / \code{closes_label}. \code{is_open_late}: vetor lógico.
\code{place_categories}, \code{vibe_groups}: vetores de caracteres nomeados
(chave = rótulo). \code{place_color_modes}: uma lista nomeada de modos de cor
para \code{\link{mod_map_server}}.
}
\details{
Linhas cuja coluna \code{source} não seja \code{"google_places_api"} nem
\code{"openstreetmap"} são tratadas como dados de demonstração e o aplicativo
indica isso na interface. Linhas do OpenStreetMap fazem o aplicativo exibir a
atribuição ODbL. (Versão em inglês: \code{man-en/places.Rd}.)
}
\examples{
p <- load_places()
table(p$category)[1:3]
classify_vibes(c("roda de samba ao vivo", "rooftop com por-do-sol"))
# Um bar aberto das 17:00 às 01:00 de terça a domingo, em uma quarta-feira às 00:30:
place_open_status("17:00", "01:00", "Ter-Dom", wday = 3, minutes = 30)
# O mesmo usando sintaxe de horários do OpenStreetMap:
place_open_status(NA, NA, NA, wday = 3, minutes = 30, opening_hours = "Tu-Su 17:00-01:00")
is_open_late(data.frame(opening_hours = c("Mo-Su 18:00-03:00", "Mo-Su 18:00-00:00"),
                        opens_at = NA, closes_at = NA, open_days = NA),
             clock = list(wday = 5, minutes = 22 * 60))
vibe_groups("pt")
}
