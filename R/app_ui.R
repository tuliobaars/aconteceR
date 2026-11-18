# Page layout, the same as inst/standalone/template.html:
#
#   header   logo · search · city · + Add event · Search & import · PT/EN · theme
#   hero     "Boa noite, <city>", a tagline and "Can't decide?"
#   filters  Events | Places, then chips: when / category / price (events)
#            or open now / category / vibe (places)
#   content  list panel (event list, or the Add / Search panes over it)
#            stage: Map | Calendar switch, colour-by, the map and the calendar
#
# No Bootstrap: the page is plain htmltools, so the only styles are ours
# (inst/www/aconteceR.css) and nothing overrides their colours. Shiny adds its
# own scripts when it serves the page.
#
# The UI is a function of the request, so the first paint is already in the
# visitor's language (?lang=, else Accept-Language, else `default_lang`); the
# browser then refines it (Brazilian region or time zone -> PT-BR, a language
# picked earlier in the session).

ac_dependency <- function() {
  htmltools::htmlDependency(
    name = "aconteceR-assets",
    version = "0.5.0",
    src = c(file = system.file("www", package = "aconteceR")),
    stylesheet = c("vendor/leaflet/leaflet.css", "taiga-tokens.css", "aconteceR.css"),
    script = c("vendor/leaflet/leaflet.js", "ac-core.js", "ac-map.js", "ac-calendar.js",
               "ac-places.js", "ac-decide.js", "ac-shiny.js")
  )
}

# Id of the map's root element for mod_map_ui("map", ...); the view switch and
# the calendar point at it.
MAP_ELEMENT_ID <- "map-pm"

app_ui <- function(cities, default_lang = "pt", places = NULL) {
  force(cities)
  force(default_lang)
  sources <- places_sources(places)
  function(request) {
    app_page(cities, lang = request_lang(request, default = default_lang), place_sources = sources)
  }
}

# Events | Places switch; data-app-mode makes the browser set data-mode on
# .ac-app, which shows the matching filters and list (see aconteceR.css).
mode_switch <- function(lang = "en") {
  htmltools::tagAppendAttributes(
    chipset("mode", list(
      events = htmltools::tagList(ac_icon("calendar"), i18n_span("mode_events", lang)),
      places = htmltools::tagList(ac_icon("pin"), i18n_span("mode_places", lang))
    ), selected = "events", mode = "single", default = "events", class = "ac-mode",
    aria_label = tr("mode_aria", lang)),
    `data-app-mode` = NA
  )
}

lang_toggle <- function(lang) {
  btn <- function(code, html_lang, title, text) {
    on <- identical(lang, code)
    htmltools::tags$button(
      type = "button", class = paste("ac-lang-btn", if (on) "is-active"),
      `data-lang` = code, lang = html_lang, title = title,
      `aria-pressed` = if (on) "true" else "false", text
    )
  }
  htmltools::div(
    class = "ac-lang", role = "group",
    `data-i18n-aria` = "lang_group_aria", `aria-label` = tr("lang_group_aria", lang),
    btn("pt", "pt-BR", "Portugu\u00eas (Brasil)", "PT"),
    btn("en", "en", "English", "EN"),
    # Shiny input `lang`, driven by the buttons (see ac-shiny.js).
    htmltools::tags$input(type = "hidden", id = "lang", class = "ac-lang-input",
                          value = lang, `data-server-lang` = lang)
  )
}

view_switch <- function(target, input_id = "view", lang = "en") {
  btn <- function(value, icon, key, on) {
    htmltools::tags$button(
      type = "button", class = paste("ac-seg-btn", if (on) "is-active"),
      `data-value` = value, `aria-pressed` = if (on) "true" else "false",
      ac_icon(icon), i18n_span(key, lang)
    )
  }
  htmltools::div(
    class = "ac-seg ac-view-switch", role = "group",
    `data-target` = target, `data-input-id` = input_id,
    `data-i18n-aria` = "view_aria", `aria-label` = tr("view_aria", lang),
    btn("map", "map", "view_map", TRUE),
    btn("calendar", "calendar", "view_calendar", FALSE)
  )
}

pane <- function(name, ..., title_key = NULL, lang = "en") {
  htmltools::div(
    class = "ac-pane", `data-pane` = name, hidden = if (name != "list") NA,
    if (!is.null(title_key)) {
      htmltools::div(
        class = "ac-pane-head",
        htmltools::tags$button(
          type = "button", class = "ac-iconbtn ac-iconbtn-sm", `data-open-pane` = "list",
          `data-i18n-aria` = "back", `data-i18n-title` = "back",
          `aria-label` = tr("back", lang), title = tr("back", lang), ac_icon("back")
        ),
        htmltools::tags$h2(class = "ac-pane-title", i18n_span(title_key, lang))
      )
    },
    ...
  )
}

# `place_sources`: see places_sources() ("demo" and/or "osm" notes).
app_page <- function(cities, lang = "pt", place_sources = character()) {
  lang <- normalize_lang(lang)
  htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$title(tr("doc_title", lang)),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      htmltools::tags$meta(name = "color-scheme", content = "light dark")
    ),
    ac_dependency(),
    htmltools::tags$script(type = "application/json", id = "ac-i18n-dict", htmltools::HTML(i18n_json())),
    htmltools::div(
      class = "ac-app", `data-server-lang` = lang, `data-i18n-doc-title` = "doc_title", `data-mode` = "events",
      htmltools::tags$header(
        class = "ac-top",
        htmltools::tags$a(
          class = "ac-logo", href = "#", `aria-label` = "aconteceR",
          htmltools::span(class = "ac-logo-tile", `data-ac-icon` = "pin", `aria-hidden` = "true"),
          i18n_span("app_name", lang, class = "ac-logo-name")
        ),
        mod_events_search_ui("events", lang = lang),
        htmltools::div(
          class = "ac-top-actions",
          htmltools::div(id = "ac-place-slot"),
          htmltools::tags$button(
            type = "button", class = "ac-btn ac-btn-primary", `data-open-pane` = "add",
            `data-i18n-title` = "tab_add", title = tr("tab_add", lang),
            ac_icon("plus"), i18n_span("tab_add", lang, class = "ac-btn-label")
          ),
          htmltools::tags$button(
            type = "button", class = "ac-iconbtn", `data-open-pane` = "search",
            `data-i18n-aria` = "tab_search", `data-i18n-title` = "tab_search",
            `aria-label` = tr("tab_search", lang), title = tr("tab_search", lang), ac_icon("inbox")
          ),
          lang_toggle(lang),
          htmltools::tags$button(
            type = "button", class = "ac-iconbtn ac-theme-toggle", `aria-pressed` = "false",
            `data-i18n-aria` = "theme_toggle_aria", `data-i18n-title` = "theme_toggle_aria",
            `aria-label` = tr("theme_toggle_aria", lang), title = tr("theme_toggle_aria", lang),
            htmltools::span(class = "ac-icon-sun", `data-ac-icon` = "sun"),
            htmltools::span(class = "ac-icon-moon", `data-ac-icon` = "moon")
          )
        )
      ),
      htmltools::tags$section(
        class = "ac-hero",
        htmltools::div(
          htmltools::tags$h1(
            class = "ac-hello",
            htmltools::span(`data-ac-greeting` = NA), ", ",
            htmltools::span(class = "ac-grad", `data-ac-city-name` = NA)
          ),
          htmltools::p(class = "ac-hero-sub", i18n_span("hero_sub", lang))
        ),
        htmltools::tags$button(
          type = "button", class = "ac-btn ac-btn-primary ac-decide-btn", `data-open-pane` = "decide",
          ac_icon("sparkles"), i18n_span("decide_btn", lang)
        )
      ),
      htmltools::div(
        class = "ac-filterbar",
        mode_switch(lang),
        mod_events_filters_ui("events", lang = lang),
        mod_places_filters_ui("places", lang = lang)
      ),
      htmltools::tags$main(
        class = "ac-content",
        htmltools::tags$section(
          class = "ac-panel ac-listpanel", `data-panes` = "list",
          `data-i18n-aria` = "sidebar_aria", `aria-label` = tr("sidebar_aria", lang),
          pane("list", mod_events_list_ui("events", lang = lang),
               mod_places_list_ui("places", lang = lang, sources = place_sources)),
          pane("decide", title_key = "decide_title", lang = lang,
               places_notes(place_sources, lang),
               mod_decide_ui("decide")),
          pane("search", title_key = "tab_search", lang = lang, mod_search_ui("search", lang = lang)),
          pane("add", title_key = "tab_add", lang = lang, mod_add_event_ui("add", lang = lang))
        ),
        htmltools::tags$section(
          class = "ac-panel ac-stage",
          htmltools::div(
            class = "ac-stage-head",
            view_switch(MAP_ELEMENT_ID, input_id = "view", lang = lang),
            htmltools::div(id = "ac-modes-slot")
          ),
          mod_map_ui(
            "map", cities,
            place_target = "#ac-place-slot", modes_target = "#ac-modes-slot", group_by = "neighborhood",
            overlays = list(calendar = mod_calendar_ui("calendar", color_from = MAP_ELEMENT_ID))
          )
        )
      )
    )
  )
}
