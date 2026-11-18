test_that("parse_ticket_cost parses Brazilian and English ticket strings", {
  expect_equal(parse_ticket_cost("Gr\u00e1tis")$price_type, "free")
  expect_equal(parse_ticket_cost("Entrada franca")$price_type, "free")
  expect_equal(parse_ticket_cost("R$ 0,00")$price_type, "free")

  expect_equal(parse_ticket_cost("Contribui\u00e7\u00e3o volunt\u00e1ria")$price_type, "donation")
  expect_equal(parse_ticket_cost("1kg de alimento n\u00e3o perec\u00edvel")$price_type, "donation")

  paid1 <- parse_ticket_cost("A partir de R$ 45,00")
  expect_equal(paid1$price_type, "paid")
  expect_equal(paid1$price, 45)

  paid2 <- parse_ticket_cost("Inteira R$ 1.250,50")
  expect_equal(paid2$price_type, "paid")
  expect_equal(paid2$price, 1250.5)

  expect_equal(parse_ticket_cost("")$price_type, "unknown")
  expect_equal(parse_ticket_cost("Consulte valores")$price_type, "unknown")
})

test_that("parse_jsonld_events and ingest_html_payload extract Schema.org Events", {
  html_doc <- '
  <html><head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "MusicEvent",
    "name": "Show de Bossa Nova no Sesc Pompeia",
    "description": "Apresentacao ao vivo de jazz e bossa nova.",
    "startDate": "2026-12-15T20:30:00-03:00",
    "url": "https://www.sympla.com.br/evento/bossa-sesc-123",
    "location": {
      "@type": "Place",
      "name": "Sesc Pompeia",
      "geo": {
        "@type": "GeoCoordinates",
        "latitude": -23.5258,
        "longitude": -46.6834
      }
    },
    "offers": {
      "@type": "Offer",
      "price": "R$ 60,00",
      "priceCurrency": "BRL"
    }
  }
  </script>
  </head><body></body></html>
  '

  ev <- parse_jsonld_events(html_doc, default_city = "S\u00e3o Paulo - SP", source = "sympla")
  expect_equal(nrow(ev), 1L)
  expect_equal(ev$title, "Show de Bossa Nova no Sesc Pompeia")
  expect_equal(ev$venue, "Sesc Pompeia")
  expect_equal(ev$price_type, "paid")
  expect_equal(ev$price, 60)
  expect_equal(ev$category, "music")

  con <- db_connect(":memory:")
  on.exit(DBI::dbDisconnect(con))
  res1 <- ingest_html_payload(con, html_doc, city = "S\u00e3o Paulo - SP", source = "sympla")
  expect_equal(res1$extracted, 1L)
  expect_equal(res1$inserted, 1L)

  # Idempotent second run
  res2 <- ingest_html_payload(con, html_doc, city = "S\u00e3o Paulo - SP", source = "sympla")
  expect_equal(res2$inserted, 0L)
})

test_that("scraper_specs returns definitions for all external catalog sites", {
  specs <- scraper_specs()
  expect_true(all(external_site_catalog()$name %in% names(specs)))
})
