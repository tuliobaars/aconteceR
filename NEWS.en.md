> 🇧🇷 [Ler em Português](NEWS.md)

# aconteceR 0.5.0

* Places from **OpenStreetMap**: `fetch_osm_places()` queries the public
  Overpass API (no key), maps tags to the ten categories and to vibe
  keywords, merges duplicates, picks the neighbourhood, keeps the most
  complete places per category, caches raw answers and retries politely.
  `inst/scripts/fetch_places_osm.R` writes `inst/extdata/places.csv`. The old
  `inst/scripts/fetch_places.R` (a Google Places stub with a key placeholder)
  is gone; no API key appears anywhere.
* Opening hours in **OpenStreetMap syntax** (`opening_hours`), read the same
  way in R (`parse_opening_hours()`) and in the browser; the old
  `opens_at` / `closes_at` / `open_days` columns still work. Places without
  readable hours show "Horário não informado" and rank after open ones.
* New places columns: `address`, `opening_hours`, `rating` (was
  `google_rating`), `maps_url` (was `google_maps_url`), `osm_url`,
  `website`. Older files still load.
* **Plan my night** (results tab in "Can't decide?"): dinner → drinks or a
  show → dancing, open on arrival and close to each other, with walking
  times; "show the route on the map".
* **Before & after**: a button in event popups lists places near the event
  open before it starts and after it ends.
* **By neighbourhood**: a map switch (`mod_map_ui(group_by =)`) shows one
  bubble per neighbourhood, sized by count and coloured by the active mode.
* **Open late** filter chip: places still open at 02:00 tonight
  (`is_open_late()`, `filter_places(open_late =)`).
* Map colour mode **hours** (open now / later today / not listed / closed);
  the rating mode only appears when the data has ratings.
* `mod_map_server()` gains `extra_columns`, `show_route()`, `clear_route()`,
  `set_group()` and `group()`; `AC.PointMap` gains `setRoute()`,
  `clearRoute()`, `setGroup()`.
* The OpenStreetMap attribution (ODbL) is shown with OSM places.
* Fixed: `classify_vibes(character())` returns `character()`; category
  tokens with an underscore (`@cafe_bistro`, `@event_music`) now match their
  default vibes; restaurants and gastrobars got default vibes.
* Fixed: a map popup closes when its pin leaves the map (filters, mode switch).

# aconteceR 0.4.0

* Places: bars, pubs, nightclubs, restaurants, clubs, concert halls, cafés,
  gastrobars, cultural spaces and rooftops (`inst/extdata/places.csv`), in
  an Events | Places mode. Each place shows its opening status on the
  visitor's clock, a review-weighted rating, price level, vibe tags and a
  Google Maps link. Filters: open now, category, vibe. Map colours:
  category, vibe or rating.
* Vibes: 12 groups from free-text keywords via `inst/extdata/vibes.csv`
  (`classify_vibes()`), for places and events alike.
* "Can't decide?": five questions, then places and events ranked by what is
  open or starting, vibe, rating and budget, with reasons; a pick flies the
  map there.
* `load_places()`, `place_open_status()` (overnight hours, day ranges that
  wrap the week), `place_categories()`, `vibe_groups()`,
  `place_color_modes()`; R and JS share one test fixture for opening hours.
* The Shiny app reads the visitor's clock from the browser (input `clock`),
  so "open now" is right wherever the server runs.
* `mod_map_server()` accepts a reactive `color_modes`.
* The bundled places are generated demo data (see README), so the app labels
  them as such.

# aconteceR 0.3.0

* The app is called **aconteceR** everywhere (header, page title, docs).
* Time of day: the app opens in light mode and follows the visitor's clock
  through golden hour, sunset and dusk into dark from 19:00, fading each
  phase into the next (colours via registered CSS custom properties, map tiles
  via a CSS filter); a page opened at night walks through the phases. The
  theme toggle goes through the same phases and is remembered for the session.
* While the page is dark, night activities lead each day in the lists (R:
  `order_events()`, `is_night_activity()`; Shiny input `night`).
* Map tiles no longer need an API key: OpenStreetMap, or Esri's public street
  map for pages opened from disk (`tiles = "auto"`, the default).
* Lists are ordered by day and time before grouping, so search results no
  longer repeat day headers.
* Fixed: a test used a dictionary key that was removed; Rd usage lines wrapped
  to 90 characters.

# aconteceR 0.2.0

* New look in the Lumen / RockShiny family: greeting headline with the city
  in a gradient, pill search and filter chips, gradient category tiles, rows
  grouped by day, a floating glass map bar, theme-aware map tiles, light and
  dark themes.
* Less crowded layout:
  - filters are one row of chips;
  - the list is compact rows;
  - Add event and Search & import open as panes over the list, from header
    buttons;
  - the colour-by switch sits in the map header and the city picker in the
    page header;
  - the calendar takes the full width.
* The Shiny page no longer loads Bootstrap. Bootstrap's styles were loading
  after ours and turned titles dark on the dark theme.
* Language at opening: Portuguese in the browser's languages, a Brazilian
  region or a Brazilian time zone now opens PT-BR (an English browser in
  Brazil used to get English). The toggle is remembered for the browser
  session.
* `map_color_bins()` default `format` no longer calls itself.
* Rd documentation for every exported function.
* `mod_map_ui()` gains `place_target` and `modes_target`; `tiles` accepts
  `"carto"` (default), `"osm"` or light/dark pairs.

# aconteceR 0.1.0

## Interface

* Full Brazilian Portuguese and English interface with a PT-BR / EN toggle. One
  dictionary (`inst/i18n/strings.json`) now serves R and the browser. It
  covers validation errors, notifications, provider notes, legends, map
  controls, dates (`Sáb, 05 dez · 20:00`) and money (`R$ 1.250,50`), and
  formats no longer depend on the R session's locale.
* The language is detected from `?lang=`, the saved choice, then the browser
  (`Accept-Language` on the server), before `default_lang`.
* The map opens on the city closest to the visitor: a time-zone guess first,
  then browser geolocation when allowed. `?city=` pins a city.
* Reworked map toolbar: colour by **price** (free, donation and four
  ticket-price bands) or **category**, clustering with donut clusters,
  locate / fit / re-centre, live count, legend with counts.
* The monthly calendar is now a full view over the map (Map / Calendar switch
  in the toolbar), with coloured chips, a day agenda, "show this day / month on
  the map" and keyboard navigation.
* Visual refresh through the Taiga token adapter, including light and dark
  themes and a layout for small screens.

## Architecture

* Map, calendar, i18n and styles are shared browser components
  (`inst/www/ac-*.js`) used by both the Shiny app and the standalone HTML.
  The `leaflet` R package is no longer needed; Leaflet 1.3.1 is vendored.
* `mod_map` is generic: colour modes via `map_color_factor()` /
  `map_color_bins()`, plus `toolbar_end` and `overlays` slots.
* `index.html` is generated by `build_standalone()` (or
  `tools/build-standalone.mjs`) from `inst/standalone/template.html`. Demo
  dates in the standalone are now relative to today, and user events get
  unique ids (older saved events are migrated).
* Demo site list and templates moved to `inst/extdata/sites.csv` and
  `site_templates.csv`, shared by R and the standalone.

## Fixes

* Demo events are seeded once per database (in one transaction) instead of
  being re-validated on every session. They are re-dated when they have all
  passed.
* Standalone: "show on map" works for search results from other cities.
  Clusters now re-form on zoom.
