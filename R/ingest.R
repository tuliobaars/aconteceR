# Ingestion & Scraping Module (`R/ingest.R`)
#
# Architecture for extracting real events, venues, dates, and ticket costs from
# Brazilian event platforms (Sympla, Eventbrite, Meetup, Resident Advisor,
# Mapas Culturais / Municipal Agendas).
#
# Pipeline stages:
#   1. Fetch (online via httr2/curl or offline HTML/JSON snapshots)
#   2. Parse JSON-LD (`<script type="application/ld+json">` @type = "Event")
#      and fallback CSS/HTML price nodes (`rvest` / regex)
#   3. Parse Brazilian ticket price strings (`parse_ticket_cost()`) into
#      `list(price_type, price, currency)`
#   4. Geocode / resolve coordinates from JSON-LD GeoCoordinates, known city
#      venues, or city centre fallback
#   5. Validate through `validate_event()` and upsert into SQLite via
#      `db_insert_event(..., ignore_duplicates = TRUE)`

# Parse a raw Brazilian or English ticket price string (e.g. from a scraped HTML
# badge or JSON-LD offers block) into list(price_type, price, currency).
# Examples:
#   "Grátis", "Gratuito", "Entrada franca", "Free", "R$ 0,00" -> free, NA
#   "Contribuição voluntária", "Doação", "1kg de alimento", "Pague quanto puder" -> donation, NA
#   "A partir de R$ 45,00", "R$ 120,50", "BRL 80.00", "Inteira R$ 60 / Meia R$ 30" -> paid, numeric
#   "", NA, "Consulte valores" -> unknown, NA
parse_ticket_cost <- function(raw_text, default_currency = "BRL") {
  txt <- trimws(as.character(raw_text %||% ""))
  if (length(txt) != 1L || !nzchar(txt)) {
    return(list(price_type = "unknown", price = NA_real_, currency = default_currency))
  }
  norm <- normalize_text(txt)

  # Check donation / voluntary contribution patterns first
  if (grepl("doacao|donation|contribuicao|voluntari|alimento|pague quanto|solidari", norm)) {
    return(list(price_type = "donation", price = NA_real_, currency = default_currency))
  }

  # Check explicit free patterns
  if (grepl("\\b(gratis|gratuito|gratuita|entrada franca|free|isento)\\b", norm)) {
    return(list(price_type = "free", price = NA_real_, currency = default_currency))
  }

  # Extract numeric price in Brazilian ("R$ 1.250,50" or "R$ 45,00") or dot ("BRL 45.00") format
  # Look for currency or number patterns
  m <- regmatches(txt, regexpr("(?:R\\$|BRL|USD|EUR)?[[:space:]]*[0-9]{1,3}(?:\\.[0-9]{3})*(?:,[0-9]{1,2})|(?:R\\$|BRL)?[[:space:]]*[0-9]+(?:\\.[0-9]{1,2})?", txt, perl = TRUE))
  if (length(m) == 1L && nzchar(m)) {
    num_str <- gsub("[^0-9,.]", "", m)
    if (grepl(",", num_str)) {
      # Brazilian format: dots are thousands, comma is decimal
      num_str <- gsub("\\.", "", num_str)
      num_str <- sub(",", ".", num_str, fixed = TRUE)
    }
    val <- suppressWarnings(as.numeric(num_str))
    if (!is.na(val)) {
      if (val == 0) {
        return(list(price_type = "free", price = NA_real_, currency = default_currency))
      }
      return(list(price_type = "paid", price = round(val, 2), currency = default_currency))
    }
  }

  list(price_type = "unknown", price = NA_real_, currency = default_currency)
}

# Infer event category from scraped title, description, or platform tags.
infer_event_category <- function(text) {
  norm <- normalize_text(paste(text, collapse = " "))
  if (grepl("show|jazz|samba|choro|forro|concerto|orquestra|dj|festival|eletronic|bossa|mpb|rock|funk|pagode|musica|acustic", norm)) {
    return("music")
  }
  if (grepl("gastronom|feira|comida|cerveja|cafe|vinho|degustacao|culinari|food|barista|chef", norm)) {
    return("food")
  }
  if (grepl("cinema|teatro|exposicao|arte|museu|fotografia|sarau|literatura|livro|poesia|dan\\b|danca|cultural|galeria|bienal", norm)) {
    return("arts")
  }
  if (grepl("corrida|maratona|ciclismo|pedal|yoga|trilha|esporte|futebol|volei|surf|beach|xadrez|funcional|caminhada", norm)) {
    return("sports")
  }
  if (grepl("workshop|meetup|python|shiny|dados|data|tech|tecnologia|ia\\b|hack|programacao|design|software|linux|dev|seminario|curso", norm)) {
    return("tech")
  }
  if (grepl("mutirao|comunidade|adocao|horta|ecologi|voluntari|feira de troca|bazar|solidari|encontro|jogos|tabuleiro", norm)) {
    return("community")
  }
  "other"
}

# Parse Schema.org Event JSON-LD blocks embedded inside an HTML page string.
# Sympla, Eventbrite, Meetup, and Resident Advisor all embed `<script type="application/ld+json">`
# containing structured Event metadata (`name`, `startDate`, `location`, `offers`, `url`).
parse_jsonld_events <- function(html_text, default_city = "S\u00e3o Paulo - SP",
                                default_lat = -23.5505, default_lon = -46.6333,
                                source = "scraper") {
  if (is.null(html_text) || !nzchar(html_text)) return(empty_events())
  pattern <- "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>([\\s\\S]*?)</script>"
  matches <- gregexpr(pattern, html_text, ignore.case = TRUE, perl = TRUE)
  raw_blocks <- regmatches(html_text, matches)[[1]]
  if (!length(raw_blocks)) return(empty_events())

  rows <- list()
  for (blk in raw_blocks) {
    json_str <- sub("^<script[^>]*>", "", blk, ignore.case = TRUE)
    json_str <- sub("</script>$", "", json_str, ignore.case = TRUE)
    parsed <- tryCatch(jsonlite::fromJSON(trimws(json_str), simplifyVector = FALSE),
                       error = function(e) NULL)
    if (is.null(parsed)) next

    # Normalize single object or @graph array into a flat list of items
    items <- if (!is.null(parsed$`@graph`) && is.list(parsed$`@graph`)) {
      parsed$`@graph`
    } else if (!is.null(parsed$`@type`)) {
      list(parsed)
    } else if (is.list(parsed)) {
      parsed
    } else {
      list()
    }

    for (it in items) {
      if (!is.list(it)) next
      tp <- as.character(it$`@type` %||% "")
      if (!any(grepl("Event", tp, ignore.case = TRUE))) next

      title <- as.character(it$name %||% "")
      desc <- as.character(it$description %||% "")
      url <- as.character(it$url %||% "")
      start_raw <- substr(gsub("T", " ", as.character(it$startDate %||% "")), 1, 16)

      venue <- ""
      lat <- default_lat
      lon <- default_lon
      if (is.list(it$location)) {
        venue <- as.character(it$location$name %||% "")
        if (is.list(it$location$geo)) {
          lat <- suppressWarnings(as.numeric(it$location$geo$latitude %||% default_lat))
          lon <- suppressWarnings(as.numeric(it$location$geo$longitude %||% default_lon))
        }
      }

      # Parse ticket offer(s)
      cost_info <- list(price_type = "unknown", price = NA_real_, currency = "BRL")
      if (is.list(it$offers)) {
        of <- if (!is.null(it$offers$price) || !is.null(it$offers$lowPrice)) {
          it$offers
        } else if (length(it$offers) > 0L && is.list(it$offers[[1]])) {
          it$offers[[1]]
        } else {
          list()
        }
        p_raw <- of$lowPrice %||% of$price %||% of$priceSpecification$price %||% ""
        cur <- as.character(of$priceCurrency %||% "BRL")
        if (is.numeric(p_raw)) {
          cost_info <- if (p_raw == 0) {
            list(price_type = "free", price = NA_real_, currency = cur)
          } else {
            list(price_type = "paid", price = as.numeric(p_raw), currency = cur)
          }
        } else {
          cost_info <- parse_ticket_cost(as.character(p_raw), default_currency = cur)
        }
      }

      cat_guess <- infer_event_category(c(title, desc, venue))
      ext_id <- if (nzchar(url)) paste0(source, "-", basename(url)) else NA_character_

      v <- validate_event(list(
        title = title,
        description = desc,
        city = default_city,
        venue = venue,
        lat = lat,
        lon = lon,
        starts_at = start_raw,
        category = cat_guess,
        price_type = cost_info$price_type,
        price = cost_info$price,
        currency = cost_info$currency,
        url = url,
        source = source,
        external_id = ext_id
      ))
      if (v$ok) {
        ev <- v$event
        rows[[length(rows) + 1L]] <- data.frame(
          id = -length(rows) - 1L,
          title = ev$title,
          description = ev$description %||% NA_character_,
          city = ev$city,
          venue = ev$venue %||% NA_character_,
          lat = ev$lat,
          lon = ev$lon,
          starts_at = ev$starts_at,
          category = ev$category,
          price_type = ev$price_type,
          price = ev$price,
          currency = ev$currency,
          url = ev$url %||% NA_character_,
          source = ev$source,
          external_id = ev$external_id %||% NA_character_,
          created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (!length(rows)) return(empty_events())
  do.call(rbind, rows)
}

# Site-specific scraper definitions showing CSS selectors, API endpoints, and
# JSON-LD strategies for each supported Brazilian event source.
scraper_specs <- function() {
  list(
    sympla = list(
      name = "sympla",
      label = "Sympla (sympla.com.br)",
      search_url_template = "https://www.sympla.com.br/eventos/%s?s=%s",
      strategy = "JSON-LD (<script type='application/ld+json'>) + HTML card fallback",
      selectors = list(
        card = "a.sympla-card, div[data-testid='event-card']",
        title = "h3.event-name, [data-testid='event-card-title']",
        date = "div.event-date, [data-testid='event-card-date']",
        venue = "p.event-location, [data-testid='event-card-location']",
        price = "span.event-price, [data-testid='event-card-price']"
      )
    ),
    eventbrite = list(
      name = "eventbrite",
      label = "Eventbrite Brasil (eventbrite.com.br)",
      search_url_template = "https://www.eventbrite.com.br/d/brazil--%s/%s/",
      strategy = "JSON-LD Event schema + __SERVER_DATA__ window state",
      selectors = list(
        card = "div.discover-search-desktop-card, section.event-card-details",
        title = "h2, h3.event-card__clamp-line--two",
        date = "p.event-card-date",
        venue = "p.event-card-venue",
        price = "div.event-card__price, span.eds-event-card-content__sub"
      )
    ),
    meetup = list(
      name = "meetup",
      label = "Meetup Brasil (meetup.com)",
      search_url_template = "https://www.meetup.com/find/?location=br--%s&keywords=%s",
      strategy = "JSON-LD Event array + Apollo GraphQL state (__NEXT_DATA__)",
      selectors = list(
        card = "div[data-testid='categoryResults-eventCard']",
        title = "h2, h3",
        date = "time",
        venue = "p.venueDisplay",
        price = "span[data-testid='event-price']"
      )
    ),
    resident_advisor = list(
      name = "resident_advisor",
      label = "Resident Advisor Brasil (ra.co)",
      search_url_template = "https://ra.co/events/br/%s",
      strategy = "GraphQL POST https://ra.co/graphql (GET_POPULAR_EVENTS_QUERY) + JSON-LD",
      selectors = list(
        card = "li[data-tracking-id='event-card']",
        title = "h3[data-pw-test-id='event-title']",
        date = "span.Date",
        venue = "span[data-pw-test-id='event-venue-link']",
        price = "span.Price"
      )
    ),
    agenda_cultural = list(
      name = "agenda_cultural",
      label = "Mapas Culturais / Prefeituras (mapa.cultura.gov.br)",
      search_url_template = "https://mapa.cultura.gov.br/api/event/findByLocation?@select=id,name,shortDescription,terms,occurrences",
      strategy = "Mapas Culturais Public REST API (/api/event/findByLocation) returning JSON occurrences & ticket prices",
      selectors = list(
        card = "article.objeto-item",
        title = "h1.objeto-titulo",
        date = "span.ocorrencia-data",
        venue = "a.ocorrencia-espaco",
        price = "span.ocorrencia-preco"
      )
    )
  )
}

# Full ingestion runner: takes either live URLs (when online and `httr2`/`rvest`
# are available) or raw HTML/JSON-LD payloads, extracts validated events with
# ticket prices, and stores them in SQLite.
ingest_html_payload <- function(con, html_text, city = "S\u00e3o Paulo - SP",
                                lat = -23.5505, lon = -46.6333, source = "sympla") {
  ev_df <- parse_jsonld_events(
    html_text, default_city = city, default_lat = lat, default_lon = lon, source = source
  )
  if (nrow(ev_df) == 0L) return(list(extracted = 0L, inserted = 0L, events = ev_df))

  inserted <- 0L
  for (i in seq_len(nrow(ev_df))) {
    r <- ev_df[i, , drop = FALSE]
    v <- validate_event(as.list(r))
    if (!v$ok) next
    if (db_event_exists(con, v$event$title, v$event$city, v$event$starts_at)) next
    new_id <- db_insert_event(con, v$event, ignore_duplicates = TRUE)
    if (!is.na(new_id)) inserted <- inserted + 1L
  }
  list(extracted = nrow(ev_df), inserted = inserted, events = ev_df)
}
