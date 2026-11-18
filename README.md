# aconteceR

> 🇺🇸 [Read in English](README.en.md)

Encontre eventos perto de você. O **aconteceR** abre na cidade mais próxima de
você, no seu idioma (Português do Brasil ou Inglês), e mostra o que está
acontecendo: pinos no mapa coloridos por preço ou categoria, com agrupamento
(*clustering*), calendário mensal, busca e importação de fontes de eventos e um
formulário para adicionar os seus próprios eventos.

Ele é distribuído de duas formas, construídas a partir dos mesmos arquivos:

| | Como abrir | Dados |
|---|---|---|
| **App Shiny** | `shiny::runApp()` ou `aconteceR::run_app()` | SQLite (os eventos que você adiciona são mantidos) |
| **HTML autônomo** | clique duplo em `index.html` (sem R, sem servidor) | dados de demonstração embutidos; seus eventos ficam no navegador |

## Como executar

```r
# Shiny, a partir da pasta do projeto (requer shiny, DBI, RSQLite, htmltools, jsonlite)
shiny::runApp()                       # usa app.R
pkgload::load_all(); run_app()        # faz o mesmo
run_app(default_lang = "en")          # idioma quando o navegador não indica nem PT nem EN
```

Sempre que o aplicativo é aberto (`run_app()` ou uma nova sessão no navegador),
ele executa automaticamente `update_events()` no banco SQLite
(`tools::R_user_dir("aconteceR", "data")`, ou um caminho alternativo quando esse
diretório não permite escrita) — carregando e atualizando os **1.280 eventos de
demonstração** (32 em cada uma das 40 cidades brasileiras, `source = "sample"`)
e os eventos do catálogo de fontes externas (`autopopulate_events()`) com datas
relativas a hoje, preservando os eventos criados pelo usuário — e gera novamente
o arquivo `index.html` (`build_standalone("index.html")`) para que tudo esteja o
mais atualizado possível.

Você também pode gerar o arquivo autônomo manualmente a qualquer momento após
alterar algo em `inst/`:

```r
aconteceR::build_standalone("index.html")   # ou: node tools/build-standalone.mjs
```

Ambos os geradores produzem resultados idênticos byte a byte, e um teste
automatizado verifica que eles concordam.

## Funcionalidades

| Área | Notas |
|---|---|
| **Visual** | Família Lumen / RockShiny: título de saudação com a cidade em gradiente, busca e *chips* em formato de pílula, blocos de categoria em gradiente, barra de mapa flutuante em vidro (*glassmorphism*), painéis arredondados e brilhos suaves de cor. |
| **Hora do dia** | Abre no modo claro e acompanha o relógio do visitante: hora dourada (17:30), pôr do sol (18:15), crepúsculo (18:45) e modo escuro das 19:00 às 06:00. Cada fase faz transição suave para a seguinte (cores e tonalidade do mapa), sem cortes bruscos; uma página aberta à noite percorre as fases em poucos segundos. O botão de tema alterna entre claro e escuro passando pelas mesmas fases e é lembrado durante a sessão do navegador; `?theme=light\|dark\|auto`. |
| **Noite primeiro** | Enquanto a página está no modo escuro, atividades noturnas (a partir das 18:00 ou antes das 05:00) aparecem no topo de cada dia nas listas, acompanhadas de uma lua. |
| **PT-BR / EN** | Todos os rótulos, mensagens, erros de validação, legendas, datas e preços. Botão de alternância no cabeçalho. |
| **Idioma ao abrir** | `?lang=pt\|en` → o botão de idioma, se usado nesta sessão do navegador → **Português em qualquer posição nos idiomas do navegador, uma região brasileira (`en-BR`) ou um fuso horário brasileiro → PT-BR** → Inglês, se listado → `default_lang`. `?lang=auto` esquece a escolha da sessão. |
| **Cidade mais próxima** | Estimativa instantânea pelo fuso horário (sem pedir permissão) e, em seguida, pela localização do navegador se o visitante permitir; um aviso (*toast*) informa qual cidade foi escolhida e a distância. `?city=recife` (ou um id) fixa uma cidade. Nada sai do navegador. |
| **Filtros** | Uma linha de *chips*: quando (hoje, fim de semana, 7 / 30 dias, qualquer data, além de um *chip* removível para um dia ou mês escolhido no calendário) · categorias · preço; busca no cabeçalho. |
| **Lista** | Linhas agrupadas por dia ("Hoje", "Amanhã", ...), ícone de categoria em gradiente, pílula de preço; clique no título para voar até o pino no mapa e passe o mouse para destacar o pino. |
| **Mapa** | Colorir por **preço** (grátis, doação, 4 faixas de preço de ingresso) ou **categoria** · **agrupamento** (*clusters* em formato de rosca divididos por cor) · localizar-me · ajustar visão · recentralizar · contagem ao vivo · legenda com contagens. Os blocos do mapa (*tiles*) acompanham o tema. |
| **Calendário mensal** | Grade mensal em largura total (alternância Mapa / Calendário), *chips* coloridos como os pinos, agenda do dia, "mostrar este dia / mês no mapa", navegação por teclado. Em PT-BR as semanas começam no domingo. |
| **Adicionar evento / Buscar e importar** | Botões no cabeçalho abrem esses painéis sobre a lista, mantendo o mapa clicável (clique no mapa para posicionar um novo evento). |
| **Lugares** | Alternância Eventos \| Lugares. Bares, pubs, baladas, restaurantes, casas de samba e dança, casas de show, cafés, gastrobares, espaços culturais e *rooftops*, com status de funcionamento ("Aberto até 01:00", "Abre qui às 23:00", "Horário não informado") pelo relógio do visitante, tags de *vibe*, avaliação quando disponível nos dados, e links para Google Maps, site oficial e OpenStreetMap. Filtros: aberto agora, **aberto até tarde** (ainda aberto às 02:00 de hoje), categoria, *vibe*. Cores no mapa: categoria, *vibe*, **status de funcionamento**, avaliação. |
| **Por bairro** | Um seletor na barra do mapa troca os pinos por uma bolha por bairro, dimensionada pela quantidade de lugares e colorida pelo modo de cor ativo (categoria ou *vibe* mais comum, ou a faixa da mediana); os maiores bairros aparecem na legenda; um clique aproxima o zoom. |
| **Vibes** | 12 grupos (tranquilo, romântico, festa, música ao vivo, para dançar, descontraído, sofisticado, ao ar livre, alternativo, cultural, com amigos, família) classificados a partir de palavras-chave em texto livre pelas regras em `inst/extdata/vibes.csv`. Eventos recebem *vibes* do título, descrição e categoria da mesma forma. |
| **Não sabe onde ir?** | Cinco perguntas rápidas (o quê, *vibe*, com quem, quando, orçamento); lugares e eventos classificados pelo que está aberto ou começando no horário, compatibilidade de *vibe*, avaliação ponderada por número de avaliações e orçamento, com % de afinidade e os motivos. Escolher um item leva o mapa até lá. |
| **Planejar minha noite** | Segunda aba dos resultados: jantar → drinks ou show → dançar, cada parada aberta quando você chega (uma balada que abre dentro de uma hora ajusta o horário de chegada), a no máximo 6 km da parada anterior, com tempo de caminhada (ou corrida de carro quando passa de 25 minutos a pé) e horário de chegada. "Mostrar rota no mapa" desenha as paradas numeradas. Paradas sem horário cadastrado são permitidas, mas sinalizadas. |
| **Antes e depois** | Um botão no popup de cada evento: lugares próximos ao evento abertos antes de ele começar (jantar, um drink) e depois que termina (bares, baladas), com a distância. |
| Editar / excluir eventos, contas de usuário, raspagem ao vivo (*live scraping*) | não implementado |

## Dados de lugares: OpenStreetMap

Lugares reais vêm do **OpenStreetMap** por meio da API pública Overpass. Nenhuma
conta, token ou chave de API é utilizada em qualquer parte deste repositório.

```sh
Rscript inst/scripts/fetch_places_osm.R                    # todas as 40 cidades
Rscript inst/scripts/fetch_places_osm.R --city="Recife - PE"
Rscript inst/scripts/fetch_places_osm.R --per-category=Inf --radius=15
node tools/build-standalone.mjs                            # depois atualize o index.html
```

ou no R: `places <- fetch_osm_places(); write_places_csv(places, "inst/extdata/places.csv")`.

* **O que é buscado**: elementos com nome e tag `amenity=bar|pub|biergarten|nightclub|restaurant|cafe|music_venue|theatre|arts_centre|cinema`,
  `leisure=dance` e `tourism=museum|gallery` num raio de 12 km do centro de cada cidade, além
  de nós de bairros (`place=suburb|neighbourhood|quarter`).
* **Categorias** vêm das tags e do nome (`osm_category()`): um bar com
  `rooftop=yes` ou "Terraço" no nome é um *rooftop*; "Cervejaria" ou
  `microbrewery=yes` é um pub; uma casa noturna com samba, forró ou gafieira no
  nome, ou `leisure=dance`, é um clube de dança; teatros e casas de música são
  casas de show; cinemas, centros de arte, museus e galerias são espaços culturais.
* **Vibes** vêm de tags transformadas em palavras-chave (`outdoor_seating` → ar-livre,
  `live_music` → ao-vivo, `lgbtq` → queer-friendly, `cuisine`, `description`,
  ...) e do nome, pelas mesmas regras.
* **Horários**: `opening_hours` é mantido como escrito e lido tanto pelo R quanto
  pelo navegador (sintaxe comum: intervalos de dias, vários intervalos de horário,
  horários após a meia-noite, `off`, `24/7`; regras sazonais e de feriados são
  ignoradas). Lugares sem horário legível exibem "Horário não informado" e
  aparecem depois dos lugares abertos.
* **Bairro**: `addr:suburb` / `addr:neighbourhood`, ou então o nó de bairro mais
  próximo dentro de 3 km.
* **Mantendo o arquivo enxuto**: duplicatas (um bar mapeado como ponto e como
  edifício) são mescladas, e cada cidade mantém até 30 lugares por categoria,
  priorizando os mais completos (horários legíveis têm maior peso).
  `--per-category=Inf` mantém tudo.
* **Boas práticas com o Overpass**: cabeçalho `User-Agent`, pausa entre cidades,
  novas tentativas com *back-off* em erros 429/504, um segundo servidor espelho
  e cache local (`osm-cache/`, ignorado pelo Git) para que uma nova execução não
  precise baixar nada novamente.
* **Sem avaliações**: o OpenStreetMap não possui notas de avaliação, portanto o
  modo de cor por avaliação fica oculto para dados do OSM e o recurso "Não sabe
  onde ir?" utiliza uma pontuação neutra. Cada lugar inclui um link de *busca*
  no Google Maps (sem chave) para fotos e avaliações.
* **Licença**: dados © contribuidores do OpenStreetMap, ODbL 1.0. O arquivo
  `places.csv` gerado dessa forma é um banco de dados derivado sob a licença
  ODbL; o aplicativo exibe a atribuição sempre que lista lugares do
  OpenStreetMap.

Até que você execute o script, o `places.csv` incluído caso não tenha sido
atualizado com dados do OSM é rotulado como dados de demonstração se a coluna
`source` não for `openstreetmap` (ou `google_places_api`).

## Como o projeto está organizado

O mapa, o calendário, as traduções e os estilos são escritos **uma única vez** e
compartilhados:

```
inst/i18n/strings.json      dicionário único (en + pt) para o R e o navegador
inst/www/ac-core.js         i18n, formatação PT/EN, tema, cidade mais próxima, modos de cor
inst/www/ac-map.js          AC.PointMap: mapa Leaflet genérico + barra de ferramentas (sem lógica de eventos)
inst/www/ac-calendar.js     AC.MonthCalendar: grade mensal genérica + agenda do dia
inst/www/aconteceR.css      todos os estilos, lidos através do adaptador de tokens Taiga
inst/www/ac-places.js       vibes, horários de funcionamento, ranqueamento, planejar noite, antes e depois
inst/www/ac-decide.js       AC.Decide: o quiz, seus resultados, o roteiro da noite e antes e depois
inst/www/ac-shiny.js        vínculos (bindings) Shiny para os componentes acima (apenas no app Shiny)
inst/standalone/            template.html + ac-standalone.js (gêmeo do servidor no navegador)
inst/www/vendor/leaflet/    Leaflet 1.3.1 (BSD-2), para não carregar nada de CDNs externas
```

Código R:

| Arquivo | Função |
|---|---|
| `R/app_ui.R`, `R/app_server.R`, `R/run_app.R` | página, integração entre módulos e ponto de entrada |
| `R/mod_map.R` | módulo de mapa **reutilizável** + `map_color_factor()` / `map_color_bins()` |
| `R/mod_calendar.R` | módulo de calendário |
| `R/mod_events.R`, `R/mod_search.R`, `R/mod_add_event.R` | as três abas laterais |
| `R/i18n.R` | `tr()`, `detect_lang()`, `request_lang()` |
| `R/categories.R` | categorias, tipos de preço, **faixas de preço**, `event_color_modes()` |
| `R/places.R`, `R/mod_places.R`, `R/mod_decide.R` | lugares: carregamento, *vibes*, horários (sintaxe OSM), linhas; modo lugares; "Não sabe onde ir?" |
| `R/osm.R` | importação do OpenStreetMap: `fetch_osm_places()`, `write_places_csv()` |
| `R/db.R`, `R/validate.R`, `R/events.R`, `R/providers.R`, `R/ingest.R` | armazenamento e atualização (`update_events()`), validação, filtragem, fontes, leitura de JSON-LD |
| `R/standalone.R` | `build_standalone()` |

## Reutilizando o mapa (ex.: mapa de preços de aluguel e venda)

`mod_map` não sabe nada sobre eventos. Basta passar pontos, modos de cor e popups:

```r
ui <- mod_map_ui("map", places)            # places: id, label, lat, lon

map <- mod_map_server(
  "map", places,
  points = reactive(listings),             # id, lat, lon + as colunas usadas para colorir
  color_modes = function(lang) list(       # ou uma lista nomeada simples
    price = map_color_bins(
      "price_m2", breaks = c(0, 8000, 12000, 16000, Inf),
      colors = c("#1a9850", "#a6d96a", "#fdae61", "#d73027"),
      label = "R$/m\u00b2"                 # faixas são (a, b]; rótulos são gerados automaticamente
    ),
    deal = map_color_factor(
      "deal", colors = c(rent = "#1b9e77", buy = "#7570b3"),
      labels = c(rent = "Aluguel", buy = "Venda"), label = "Tipo"
    )
  ),
  popup_fun = function(pts) paste0("<b>", escape_html(pts$address), "</b>"),  # HTML: escapar texto
  label_fun = function(pts) pts$address                                        # texto puro
)

map$city(); map$clicked(); map$selected_id(); map$color_mode(); map$located()
map$set_city(id); map$fit(); map$clear_pick()
map$show_route(stops); map$clear_route(); map$set_group(TRUE); map$group()
```

**Agrupamento** (ex.: preço médio por bairro): `mod_map_ui(..., group_by = "neighborhood")`
mais `mod_map_server(..., extra_columns = "neighborhood")` adiciona um seletor
que exibe uma bolha por bairro. Com um modo de cor numérico
(`map_color_bins("price_m2", ...)`), cada bolha assume a cor do seu valor
**mediano**, oferecendo uma visualização de preços por bairro gratuitamente.
Chaves de texto: `group_toggle`, `group_count`, `group_top`, `group_top_list`
(valores padrão em inglês incluídos; passe os seus pelo dicionário).

Opções em `mod_map_ui()`: `selected` (abrir em um lugar específico; desativa a
localização automática), `cluster`, `auto_locate`, `locate`, `pickable`, `zoom`,
`tiles`, `place_target` / `modes_target` (seletores CSS para posicionar o
seletor de cidade e o seletor de modo de cor em outro lugar da página, como o
aplicativo faz no cabeçalho), `toolbar_end` (seus próprios controles na barra do
mapa), `overlays` (visualizações nomeadas desenhadas sobre o mapa, como o
calendário) e `group_by`. Os textos dos controles usam as chaves `pm_*` do
dicionário com fallback para inglês. Consulte `?mod_map` e `?map_color`.

**Blocos do mapa (*Map tiles*).** Apenas fontes sem chave de API: blocos padrão
do OpenStreetMap, ou o mapa de ruas público da Esri quando a página é aberta a
partir do disco (`file://`), pois a política de blocos do OpenStreetMap exige um
cabeçalho `Referer`, que arquivos locais não enviam. Passe `tiles = "osm"`,
`"esri"` ou a sua própria `list(url =, attribution =)` para escolher. As cores
acompanham a hora do dia por meio de um filtro CSS sobre os blocos, de modo que
um único conjunto de blocos atende aos temas claro e escuro. (Os mapas-base da
CARTO, usados anteriormente, agora exigem chave de API.)

O componente de navegador também funciona sem Shiny:
`new AC.PointMap(el, {places, colorModes, onPlace, ...})`.

## Adicionando ou alterando textos

Edite **ambos** os idiomas `en` e `pt` em `inst/i18n/strings.json`. No R, use
`tr("key", lang)` / `tf("key", lang, ...)`; na marcação HTML, use
`i18n_span("key", lang)` para que o navegador possa trocar o texto
instantaneamente ao alternar o idioma. Os testes falham se os dois idiomas
divergirem (chaves faltando ou placeholders `%s`/`%d` diferentes).

## Design: tokens

Todas as cores, fontes, raios de borda e espaçamentos são lidos através de um
**adaptador de duas camadas**:

1. `inst/www/taiga-tokens.css` define os tokens `--tg-*`.
2. O bloco inicial de `inst/www/aconteceR.css` mapeia esses tokens para
   `--ac-*`, cada um com um valor de fallback. Todos os componentes usam apenas
   `--ac-*`.

Os valores dos tokens seguem a família Lumen, calibrados visualmente a partir
dos projetos Lumen (lumenJourney, QuantSkill, teal_neue) e RockShiny:
- fundos quase pretos / branco-quente com brilhos suaves em violeta, rosa e âmbar;
- gradiente pôr do sol (âmbar → rosa → violeta) para a marca e a saudação;
- âmbar do RockShiny como cor de destaque (*accent*);
- seletores verde-iOS, controles em formato de pílula, painéis com raio de 24 px
  e tipografia de exibição do sistema.

Para usar os tokens Taiga originais, basta copiá-los sobre `taiga-tokens.css`.
Se os nomes diferirem, edite apenas o bloco adaptador.

Tokens lidos: `--tg-font-{sans, display, mono}`,
`--tg-color-{canvas, surface, surface-2, border, text, text-muted, accent,
accent-contrast, accent-ink, focus, danger, warning, success}`,
`--tg-gradient-brand`, `--tg-glow-{1,2,3}`, `--tg-glass`, `--tg-radius`,
`--tg-radius-lg` e `--tg-space-1..5`, com valores para o tema escuro sob
`:root[data-theme="dark"]`. As paletas de dados (faixas de preço, categorias)
ficam em `R/categories.R`, em seu equivalente JS e nos gradientes `--ac-cat-*`.

A página Shiny não carrega o Bootstrap: é construída com `htmltools` puro, para
que nenhuma outra folha de estilo sobrescreva essas cores.

## Testes

```r
devtools::test()      # R: banco de dados, validação, paridade i18n, formatos, modos de cor,
                      # horários de funcionamento, importação OpenStreetMap (fixture offline),
                      # módulos (shiny::testServer), geração do HTML autônomo
devtools::check()     # todas as funções exportadas estão documentadas em man/
```

```sh
pip install playwright && python -m playwright install chromium
python tools/smoke_standalone.py        # index.html em um navegador real
python tools/smoke_shiny_bindings.py    # ac-shiny.js contra um cliente Shiny simulado
```

## Licença

MIT, consulte `LICENSE` / `LICENSE.md`. Inclui o Leaflet 1.3.1 (BSD-2-Clause,
consulte `inst/COPYRIGHTS`). Dados cartográficos © contribuidores do
OpenStreetMap. Um arquivo `places.csv` obtido do OpenStreetMap é um banco de
dados derivado sob a licença ODbL 1.0 (consulte `inst/COPYRIGHTS`); o código
permanece sob licença MIT.
