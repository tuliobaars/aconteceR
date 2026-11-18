> 🇺🇸 [Read in English](NEWS.en.md)

# aconteceR 0.5.0

* Lugares do **OpenStreetMap**: `fetch_osm_places()` consulta a API pública
  Overpass (sem chave de API), mapeia tags para as dez categorias e palavras-chave
  de *vibe*, mescla duplicatas, identifica o bairro, mantém os lugares mais
  completos por categoria, faz cache das respostas brutas e realiza novas
  tentativas respeitando os limites do servidor. `inst/scripts/fetch_places_osm.R`
  grava `inst/extdata/places.csv`. O antigo `inst/scripts/fetch_places.R` (um
  esboço do Google Places com espaço reservado para chave) foi removido; nenhuma
  chave de API é utilizada.
* Atualização automática ao abrir o aplicativo: `run_app()` e `app_server()`
  executam `update_events()` (atualizando eventos de demonstração e do catálogo
  externo para a data atual) e geram `index.html` (`build_standalone()`) sempre
  que o aplicativo é aberto.
* Horários de funcionamento na **sintaxe do OpenStreetMap** (`opening_hours`),
  lidos da mesma forma no R (`parse_opening_hours()`) e no navegador; as colunas
  antigas `opens_at` / `closes_at` / `open_days` continuam funcionando. Lugares
  sem horários legíveis exibem "Horário não informado" e são classificados após
  os lugares abertos.
* Novas colunas de lugares: `address`, `opening_hours`, `rating` (antes
  `google_rating`), `maps_url` (antes `google_maps_url`), `osm_url`,
  `website`. Arquivos antigos continuam sendo carregados normalmente.
* **Planejar minha noite** (aba de resultados em "Não sabe onde ir?"): jantar →
  drinks ou show → dançar, abertos na chegada e próximos uns dos outros, com
  tempos de caminhada e botão "mostrar rota no mapa".
* **Antes e depois**: um botão nos popups de eventos lista lugares próximos ao
  evento abertos antes de ele começar e depois que ele termina.
* **Por bairro**: um seletor no mapa (`mod_map_ui(group_by =)`) mostra uma bolha
  por bairro, dimensionada pela quantidade e colorida pelo modo ativo.
* Filtro **Aberto até tarde**: lugares que ainda estão abertos às 02:00 da
  madrugada de hoje (`is_open_late()`, `filter_places(open_late =)`).
* Modo de cor do mapa **horário** (aberto agora / abre hoje / sem horário /
  fechado); o modo de avaliação só aparece quando os dados possuem avaliações.
* `mod_map_server()` ganha `extra_columns`, `show_route()`, `clear_route()`,
  `set_group()` e `group()`; `AC.PointMap` ganha `setRoute()`,
  `clearRoute()`, `setGroup()`.
* A atribuição do OpenStreetMap (ODbL) é exibida junto aos lugares do OSM.
* Corrigido: `classify_vibes(character())` retorna `character()`; tokens de
  categoria com sublinhado (`@cafe_bistro`, `@event_music`) agora correspondem
  às suas *vibes* padrão; restaurantes e gastrobares receberam *vibes* padrão.
* Corrigido: o popup do mapa fecha quando seu pino sai do mapa (ao filtrar ou
  trocar de modo).

# aconteceR 0.4.0

* Lugares: bares, pubs, baladas, restaurantes, clubes, casas de show, cafés,
  gastrobares, espaços culturais e *rooftops* (`inst/extdata/places.csv`), em um
  modo Eventos | Lugares. Cada lugar mostra seu status de funcionamento pelo
  relógio do visitante, avaliação ponderada por número de avaliações, faixa de
  preço, tags de *vibe* e link para o Google Maps. Filtros: aberto agora,
  categoria, *vibe*. Cores no mapa: categoria, *vibe* ou avaliação.
* Vibes: 12 grupos extraídos de palavras-chave em texto livre via
  `inst/extdata/vibes.csv` (`classify_vibes()`), tanto para lugares quanto para
  eventos.
* "Não sabe onde ir?": cinco perguntas e, em seguida, lugares e eventos
  classificados pelo que está aberto ou começando, *vibe*, avaliação e
  orçamento, com as justificativas; escolher um item leva o mapa até lá.
* `load_places()`, `place_open_status()` (horários que viram a noite, intervalos
  de dias que cruzam a semana), `place_categories()`, `vibe_groups()`,
  `place_color_modes()`; o R e o JS compartilham a mesma *fixture* de testes
  para horários de funcionamento.
* O aplicativo Shiny lê o relógio do visitante diretamente do navegador (input
  `clock`), de modo que "aberto agora" funciona corretamente independentemente
  do fuso horário do servidor.
* `mod_map_server()` aceita um `color_modes` reativo.
* Os lugares embutidos quando gerados para demonstração são identificados como
  dados de demonstração pelo aplicativo.

# aconteceR 0.3.0

* O aplicativo passa a se chamar **aconteceR** em todos os lugares (cabeçalho,
  título da página, documentação).
* Hora do dia: o aplicativo abre no modo claro e acompanha o relógio do
  visitante passando pela hora dourada, pôr do sol e crepúsculo até o modo
  escuro a partir das 19:00, fazendo transição suave entre cada fase (cores via
  propriedades personalizadas de CSS registradas, blocos do mapa via filtro
  CSS); uma página aberta à noite percorre as fases em sequência. O botão de
  alternância de tema passa pelas mesmas fases e é lembrado durante a sessão.
* Enquanto a página está escura, atividades noturnas aparecem no topo de cada
  dia nas listas (R: `order_events()`, `is_night_activity()`; input Shiny
  `night`).
* Os blocos do mapa não precisam mais de chave de API: OpenStreetMap, ou o mapa
  de ruas público da Esri para páginas abertas a partir do disco
  (`tiles = "auto"`, o padrão).
* As listas são ordenadas por dia e hora antes do agrupamento, evitando que
  resultados de busca repitam cabeçalhos de dia.
* Corrigido: um teste usava uma chave de dicionário que havia sido removida;
  linhas de `\usage` nos arquivos Rd ajustadas para no máximo 90 caracteres.

# aconteceR 0.2.0

* Novo visual na família Lumen / RockShiny: título de saudação com a cidade em
  gradiente, busca e *chips* de filtro em formato de pílula, ícones de categoria
  em gradiente, linhas agrupadas por dia, barra de mapa flutuante em vidro,
  blocos do mapa adaptados ao tema, temas claro e escuro.
* Layout mais limpo:
  - os filtros ficam em uma única linha de *chips*;
  - a lista usa linhas compactas;
  - Adicionar evento e Buscar e importar abrem como painéis sobre a lista, a
    partir de botões no cabeçalho;
  - o seletor "colorir por" fica no cabeçalho do mapa e o seletor de cidade no
    cabeçalho da página;
  - o calendário ocupa toda a largura.
* A página Shiny não carrega mais o Bootstrap. Os estilos do Bootstrap eram
  carregados depois dos nossos e deixavam os títulos escuros no tema escuro.
* Idioma ao abrir: Português nos idiomas do navegador, uma região brasileira ou
  um fuso horário brasileiro agora abre em PT-BR (antes, um navegador em inglês
  no Brasil abria em inglês). A escolha no seletor é lembrada durante a sessão
  do navegador.
* O argumento padrão `format` de `map_color_bins()` não chama mais a si mesmo.
* Documentação Rd para todas as funções exportadas.
* `mod_map_ui()` ganha `place_target` e `modes_target`; `tiles` aceita
  `"carto"` (padrão), `"osm"` ou pares claro/escuro.

# aconteceR 0.1.0

## Interface

* Interface completa em Português do Brasil e Inglês com seletor PT-BR / EN. Um
  único dicionário (`inst/i18n/strings.json`) atende o R e o navegador. Cobre
  erros de validação, notificações, notas de provedores, legendas, controles do
  mapa, datas (`Sáb, 05 dez · 20:00`) e valores monetários (`R$ 1.250,50`), sem
  depender do *locale* da sessão R.
* O idioma é detectado a partir de `?lang=`, da escolha salva e depois do
  navegador (`Accept-Language` no servidor), antes de recorrer a `default_lang`.
* O mapa abre na cidade mais próxima do visitante: primeiro uma estimativa pelo
  fuso horário e, quando permitido, geolocalização do navegador. `?city=` fixa
  uma cidade.
* Barra de ferramentas do mapa reformulada: colorir por **preço** (grátis,
  doação e quatro faixas de preço de ingresso) ou **categoria**, agrupamento com
  *clusters* em rosca, localizar / ajustar / recentralizar, contagem ao vivo e
  legenda com contagens.
* O calendário mensal agora é uma visualização completa sobre o mapa (alternância
  Mapa / Calendário na barra), com *chips* coloridos, agenda do dia, "mostrar
  este dia / mês no mapa" e navegação por teclado.
* Renovação visual por meio do adaptador de tokens Taiga, incluindo temas claro
  e escuro e layout responsivo para telas pequenas.

## Arquitetura

* Mapa, calendário, i18n e estilos são componentes de navegador compartilhados
  (`inst/www/ac-*.js`) usados tanto pelo aplicativo Shiny quanto pelo HTML
  autônomo. O pacote R `leaflet` não é mais necessário; o Leaflet 1.3.1 está
  embutido (*vendored*).
* `mod_map` é genérico: modos de cor via `map_color_factor()` /
  `map_color_bins()`, além de espaços para `toolbar_end` e `overlays`.
* `index.html` é gerado por `build_standalone()` (ou
  `tools/build-standalone.mjs`) a partir de `inst/standalone/template.html`. As
  datas de demonstração no arquivo autônomo são relativas a hoje, e eventos do
  usuário recebem identificadores únicos (eventos antigos salvos são migrados).
* Lista de sites de demonstração e modelos movidos para
  `inst/extdata/sites.csv` e `site_templates.csv`, compartilhados entre o R e o
  HTML autônomo.

## Correções

* Eventos de demonstração são carregados em uma única transação por banco de
  dados em vez de serem revalidados a cada sessão, e têm suas datas atualizadas
  quando ficam no passado.
* HTML autônomo: "mostrar no mapa" funciona para resultados de busca de outras
  cidades. Os *clusters* agora são recalculados ao aplicar zoom.
