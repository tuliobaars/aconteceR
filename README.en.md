# aconteceR

> 🇧🇷 [Ler em Português](README.md)

Find events near you. aconteceR opens on the city closest to you, in your
language (Brazilian Portuguese or English), and shows what is on: pins on a map
coloured by price or category, with clustering, a monthly calendar, search and
import from event sources, and a form to add your own.

It ships two ways, built from the same assets:

| | How to open | Data |
|---|---|---|
| **Shiny app** | `shiny::runApp()` or `aconteceR::run_app()` | SQLite (events you add are kept) |
| **Standalone HTML** | double-click `index.html` (no R, no server) | bundled demo data; your events stay in the browser |

## Run it

```r
# Shiny, from the project folder (needs shiny, DBI, RSQLite, htmltools, jsonlite)
shiny::runApp()                       # uses app.R
pkgload::load_all(); run_app()        # same thing
run_app(default_lang = "en")          # language when the browser names neither PT nor EN
```

Every time the app is opened (`run_app()` or a new browser session), it
automatically runs `update_events()` on the SQLite database
(`tools::R_user_dir("aconteceR", "data")`, or a fallback when that is not
writable) — loading and refreshing the **1,280 demo events** (32 in each of 40
Brazilian cities, `source = "sample"`) and the catalog events from the external
sources (`autopopulate_events()`) relative to today while keeping user-added
events — and regenerates `index.html` (`build_standalone("index.html")`) so
everything is as up to date as possible.

You can also rebuild the standalone file manually at any time after changing
anything in `inst/`:

```r
aconteceR::build_standalone("index.html")   # or: node tools/build-standalone.mjs
```

Both builders produce byte-identical output and a test checks they agree.

## Features

| Area | Notes |
|---|---|
| **Look** | Lumen / RockShiny family: greeting headline with the city in a gradient, pill search and chips, gradient category tiles, floating glass map bar, rounded panels, soft colour glows. |
| **Time of day** | Opens in light mode and follows the visitor's clock: golden hour (17:30), sunset (18:15), dusk (18:45) and dark from 19:00 until 06:00. Each phase fades into the next (colours and map tint), never a hard cut; a page opened at night walks through them in a few seconds. The theme button goes to light or dark through the same phases and is remembered for the browser session; `?theme=light\|dark\|auto`. |
| **Night first** | While the page is dark, night activities (from 18:00, or before 05:00) lead each day in the lists, with a moon. |
| **PT-BR / EN** | Every label, message, validation error, legend, date and price. Toggle in the header. |
| **Language at opening** | `?lang=pt\|en` → the toggle, if used in this browser session → **Portuguese anywhere in the browser's languages, a Brazilian region (`en-BR`) or a Brazilian time zone → PT-BR** → English if listed → `default_lang`. `?lang=auto` forgets the session's choice. |
| **Closest city** | Instant guess from the time zone (no prompt), then the browser's location if the visitor allows it; a toast says which city and how far. `?city=recife` (or an id) pins a city. Nothing leaves the browser. |
| **Filters** | One row of chips: when (today, weekend, 7 / 30 days, any date, plus a removable chip for a day or month picked on the calendar) · categories · price; search in the header. |
| **List** | Rows grouped by day ("Hoje", "Amanhã", ...), gradient category tile, price pill; click a title to fly to it, hover rings its pin. |
| **Map** | Colour by **price** (free, donation, 4 ticket-price bands) or **category** · **clustering** (donut clusters split by colour) · locate me · fit · re-centre · live count · legend with counts. Tiles follow the theme. |
| **Monthly calendar** | Full-width month grid (Map / Calendar switch), chips coloured like the pins, day agenda, "show this day / month on the map", keyboard navigation. PT-BR weeks start on Sunday. |
| **Add event / Search & import** | Header buttons open them as panes over the list, so the map stays clickable (click to place a new event). |
| **Places** | Events \| Places switch. Bars, pubs, nightclubs, restaurants, samba and dance clubs, concert halls, cafés, gastrobars, cultural spaces and rooftops, with opening status ("Aberto até 01:00", "Abre qui às 23:00", "Horário não informado") on the visitor's clock, vibe tags, rating when the data has one, and links to Google Maps, the website and OpenStreetMap. Filters: open now, **open late** (still open at 02:00 tonight), category, vibe. Map colours: category, vibe, **opening status**, rating. |
| **By neighbourhood** | A map-bar switch swaps the pins for one bubble per neighbourhood, sized by how many places it has and coloured by the active colour mode (most common category or vibe, or the bin of the median); the largest neighbourhoods are listed in the legend; a click zooms in. |
| **Vibes** | 12 groups (chill, romantic, party, live music, dancing, laid-back, upscale, outdoors, alternative, culture, with friends, family) from free-text keywords, via the rules in `inst/extdata/vibes.csv`. Events get vibes from their title, description and category the same way. |
| **Can't decide?** | Five quick questions (what, vibe, who with, when, budget); places and events ranked by what is open or starting then, vibe match, review-weighted rating and budget, with a match % and the reasons. A pick flies the map there. |
| **Plan my night** | Second tab of the results: dinner → drinks or a show → dancing, each stop open when you arrive (a club opening within the hour moves the arrival), at most 6 km from the previous one, with walking time (or a ride when it is more than 25 minutes on foot) and the arrival time. "Show the route on the map" draws numbered stops. Stops without listed hours are allowed but flagged. |
| **Before & after** | A button in every event popup: places near the event open before it starts (dinner, a drink) and after it ends (bars, clubs), with the distance. |
| Edit / delete events, user accounts, live scraping | not built |

## Places data: OpenStreetMap

Real places come from **OpenStreetMap** through the public Overpass API. No
account, token or API key is involved anywhere in this repository.

```sh
Rscript inst/scripts/fetch_places_osm.R                    # all 40 cities
Rscript inst/scripts/fetch_places_osm.R --city="Recife - PE"
Rscript inst/scripts/fetch_places_osm.R --per-category=Inf --radius=15
node tools/build-standalone.mjs                            # then refresh index.html
```

or in R: `places <- fetch_osm_places(); write_places_csv(places, "inst/extdata/places.csv")`.

* **What is fetched**: named `amenity=bar|pub|biergarten|nightclub|restaurant|cafe|music_venue|theatre|arts_centre|cinema`,
  `leisure=dance` and `tourism=museum|gallery` within 12 km of each city centre, plus
  neighbourhood nodes (`place=suburb|neighbourhood|quarter`).
* **Categories** come from the tags and the name (`osm_category()`): a bar with
  `rooftop=yes` or "Terraço" in the name is a rooftop; "Cervejaria" or
  `microbrewery=yes` is a pub; a nightclub with samba, forró or gafieira in
  the name, or `leisure=dance`, is a dance club; theatres and music venues are
  concert houses; cinemas, arts centres, museums and galleries are cultural spots.
* **Vibes** come from tags turned into keywords (`outdoor_seating` → ar-livre,
  `live_music` → ao-vivo, `lgbtq` → queer-friendly, `cuisine`, `description`,
  ...) and the name, through the same rules as before.
* **Hours**: `opening_hours` is kept as written and read by both R and the
  browser (common syntax: day ranges, several time ranges, past midnight,
  `off`, `24/7`; seasonal and holiday rules are skipped). Places without
  readable hours say "Horário não informado" and rank after open ones.
* **Neighbourhood**: `addr:suburb` / `addr:neighbourhood`, else the closest
  neighbourhood node within 3 km.
* **Keeping it small**: duplicates (a bar mapped as a point and as a
  building) are merged, and each city keeps up to 30 places per category, the
  most complete first (readable hours count most). `--per-category=Inf` keeps
  everything.
* **Being polite to Overpass**: a User-Agent, a pause between cities, retries
  with back-off on 429/504, a second server, and a cache (`osm-cache/`,
  git-ignored) so a re-run downloads nothing.
* **No ratings**: OpenStreetMap has none, so the rating colour mode is hidden
  for OSM data and "Can't decide?" uses a neutral score instead. Each place
  links to a Google Maps *search* (no key) for photos and reviews.
* **Licence**: data © OpenStreetMap contributors, ODbL 1.0. `places.csv`
  built this way is a derived database under the ODbL; the app shows the
  attribution whenever it lists OpenStreetMap places.

Until you run the script, the bundled `places.csv` is the old **generated demo
file** (template names, made-up coordinates, hours and ratings) and the app
labels it as demo data. Only rows whose `source` is `openstreetmap` (or
`google_places_api`) count as real.

## How it is put together

The map, calendar, translations and styles are written **once** and shared:

```
inst/i18n/strings.json      one dictionary (en + pt) for R and the browser
inst/www/ac-core.js         i18n, PT/EN formatting, theme, closest-city, colour modes
inst/www/ac-map.js          AC.PointMap: generic Leaflet map + toolbar (no event logic)
inst/www/ac-calendar.js     AC.MonthCalendar: generic month grid + day agenda
inst/www/aconteceR.css      all styles, read through the Taiga token adapter
inst/www/ac-places.js       vibes, opening hours, ranking, plan my night, before & after
inst/www/ac-decide.js       AC.Decide: the quiz, its results, the plan and before & after
inst/www/ac-shiny.js        Shiny bindings for the above (Shiny app only)
inst/standalone/            template.html + ac-standalone.js (browser twin of the server)
inst/www/vendor/leaflet/    Leaflet 1.3.1 (BSD-2), so nothing loads from a CDN
```

R code:

| File | Does |
|---|---|
| `R/app_ui.R`, `R/app_server.R`, `R/run_app.R` | page, wiring, entry point |
| `R/mod_map.R` | **reusable** map module + `map_color_factor()` / `map_color_bins()` |
| `R/mod_calendar.R` | calendar module |
| `R/mod_events.R`, `R/mod_search.R`, `R/mod_add_event.R` | the three side tabs |
| `R/i18n.R` | `tr()`, `detect_lang()`, `request_lang()` |
| `R/categories.R` | categories, price types, **price bands**, `event_color_modes()` |
| `R/places.R`, `R/mod_places.R`, `R/mod_decide.R` | places: loading, vibes, opening hours (OSM syntax), rows; places mode; "Can't decide?" |
| `R/osm.R` | OpenStreetMap import: `fetch_osm_places()`, `write_places_csv()` |
| `R/db.R`, `R/validate.R`, `R/events.R`, `R/providers.R`, `R/ingest.R` | storage, rules, filtering, sources, JSON-LD parsing |
| `R/standalone.R` | `build_standalone()` |

## Reusing the map (e.g. the rent / buy price map)

`mod_map` knows nothing about events. Pass points, colour modes and popups:

```r
ui <- mod_map_ui("map", places)            # places: id, label, lat, lon

map <- mod_map_server(
  "map", places,
  points = reactive(listings),             # id, lat, lon + the columns you colour by
  color_modes = function(lang) list(       # or a plain named list
    price = map_color_bins(
      "price_m2", breaks = c(0, 8000, 12000, 16000, Inf),
      colors = c("#1a9850", "#a6d96a", "#fdae61", "#d73027"),
      label = "R$/m\u00b2"                 # bins are (a, b]; labels are generated
    ),
    deal = map_color_factor(
      "deal", colors = c(rent = "#1b9e77", buy = "#7570b3"),
      labels = c(rent = "Aluguel", buy = "Venda"), label = "Tipo"
    )
  ),
  popup_fun = function(pts) paste0("<b>", escape_html(pts$address), "</b>"),  # HTML: escape text
  label_fun = function(pts) pts$address                                        # plain text
)

map$city(); map$clicked(); map$selected_id(); map$color_mode(); map$located()
map$set_city(id); map$fit(); map$clear_pick()
map$show_route(stops); map$clear_route(); map$set_group(TRUE); map$group()
```

**Grouping** (e.g. average price by neighbourhood): `mod_map_ui(..., group_by
= "neighborhood")` plus `mod_map_server(..., extra_columns = "neighborhood")`
adds a switch that shows one bubble per neighbourhood. With a numeric colour
mode (`map_color_bins("price_m2", ...)`) each bubble takes the colour of its
**median** value, so the listings map gets a neighbourhood price view for
free. Text keys: `group_toggle`, `group_count`, `group_top`, `group_top_list`
(English fallbacks built in; pass your own through the dictionary).

Options on `mod_map_ui()`: `selected` (open on a place; disables auto-locate),
`cluster`, `auto_locate`, `locate`, `pickable`, `zoom`, `tiles`,
`place_target` / `modes_target` (CSS selectors to put the place picker and the
colour-by switch elsewhere on the page, as the app does in its header),
`toolbar_end` (your own controls in the map bar), `overlays` (named views
drawn over the map, like the calendar) and `group_by`. Control text uses the `pm_*` keys in
the dictionary and falls back to English. See `?mod_map` and `?map_color`.

**Map tiles.** Key-free only: OpenStreetMap's standard tiles, or Esri's public
street map when the page is opened from disk (`file://`), because
OpenStreetMap's tile policy wants a Referer, which local files do not send.
Pass `tiles = "osm"`, `"esri"` or your own `list(url =, attribution =)` to
choose. The colours follow the time of day through a CSS filter on the tiles,
so one tile set serves light and dark. (CARTO's basemaps, used before, now ask
for an API key.)

The browser component works without Shiny too:
`new AC.PointMap(el, {places, colorModes, onPlace, ...})`.

## Adding or changing text

Edit **both** `en` and `pt` in `inst/i18n/strings.json`. In R use
`tr("key", lang)` / `tf("key", lang, ...)`; in markup use
`i18n_span("key", lang)` so the browser can swap it on toggle. The tests fail
if the two languages drift apart (missing keys, different `%s`/`%d`).

## Design: tokens

All colours, fonts, radii and spacing are read through a **two-layer adapter**:

1. `inst/www/taiga-tokens.css` defines `--tg-*` tokens.
2. The top block of `inst/www/aconteceR.css` maps them to `--ac-*`, each with a
   fallback. Every component uses `--ac-*` only.

The token values now follow the Lumen family, **read by eye from the
screenshots** of Lumen projects (lumenJourney, QuantSkill, teal_neue) and
RockShiny, not copied from the Taiga repository:
- near-black / warm off-white canvases with soft violet, pink and amber glows;
- a sunset gradient (amber → pink → violet) for the brand and the greeting;
- RockShiny's amber as the accent;
- iOS-green switches, pill controls, 24 px panels and system display type.

To use the real Taiga tokens, copy them over `taiga-tokens.css`. If names
differ, edit only the adapter block.

Tokens read: `--tg-font-{sans, display, mono}`,
`--tg-color-{canvas, surface, surface-2, border, text, text-muted, accent,
accent-contrast, accent-ink, focus, danger, warning, success}`,
`--tg-gradient-brand`, `--tg-glow-{1,2,3}`, `--tg-glass`, `--tg-radius`,
`--tg-radius-lg` and `--tg-space-1..5`, with dark values under
`:root[data-theme="dark"]`. The data palettes (price bands, categories) live in
`R/categories.R`, their JS twin and the `--ac-cat-*` gradients.

The Shiny page does not load Bootstrap: it is plain htmltools, so no other
stylesheet can override these colours.

## Tests

```r
devtools::test()      # R: database, validation, i18n parity, formats, colour modes,
                      # opening hours, OpenStreetMap import (offline fixture),
                      # modules (shiny::testServer), standalone build
devtools::check()     # exported functions are documented in man/
```

```sh
pip install playwright && python -m playwright install chromium
python tools/smoke_standalone.py        # index.html in a real browser
python tools/smoke_shiny_bindings.py    # ac-shiny.js against a mock Shiny client
```

## Licence

MIT, see `LICENSE` / `LICENSE.md`. Bundles Leaflet 1.3.1 (BSD-2-Clause, see
`inst/COPYRIGHTS`). Map data © OpenStreetMap contributors. A `places.csv`
fetched from OpenStreetMap is a derived database under the ODbL 1.0 (see
`inst/COPYRIGHTS`); the code stays MIT.
