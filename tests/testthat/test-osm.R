# OpenStreetMap import. No network: the Overpass answer is a fixture and the
# download function is injected.

overpass_fixture <- function() test_path("fixtures", "overpass_sample.json")

test_that("the Overpass query asks for venues and neighbourhoods around the centre", {
  q <- overpass_query(-8.05, -34.9, 12000)
  expect_match(q, "[out:json][timeout:180];", fixed = TRUE)
  expect_match(q, "(around:12000,-8.05000,-34.90000)", fixed = TRUE)
  expect_match(q, "nightclub|restaurant", fixed = TRUE)
  expect_match(q, "[\"leisure\"=\"dance\"]", fixed = TRUE)
  expect_match(q, "place\"~\"^(suburb|neighbourhood|quarter)$", fixed = TRUE)
  expect_match(q, "out center;", fixed = TRUE)  # nodes keep lat/lon, ways get a centre
  expect_false(grepl("key", q, ignore.case = TRUE))
})

test_that("OSM tags map to the app's categories", {
  expect_equal(osm_category(list(amenity = "bar", name = "Bar do Zé")), "bar")
  expect_equal(osm_category(list(amenity = "bar", name = "Terraço Itália")), "rooftop_lounge")
  expect_equal(osm_category(list(amenity = "bar", name = "X", rooftop = "yes")), "rooftop_lounge")
  expect_equal(osm_category(list(amenity = "bar", name = "Cervejaria Y")), "pub")
  expect_equal(osm_category(list(amenity = "bar", name = "Z", microbrewery = "yes")), "pub")
  expect_equal(osm_category(list(amenity = "biergarten", name = "B")), "pub")
  expect_equal(osm_category(list(amenity = "restaurant", name = "Gastrobar W")), "gastrobar")
  expect_equal(osm_category(list(amenity = "nightclub", name = "Clube do Samba")), "club")
  expect_equal(osm_category(list(amenity = "nightclub", name = "Boate")), "nightclub")
  expect_equal(osm_category(list(leisure = "dance", name = "Salão")), "club")
  expect_equal(osm_category(list(amenity = "theatre", name = "T")), "concert_house")
  expect_equal(osm_category(list(amenity = "cinema", name = "C")), "cultural_spot")
  expect_equal(osm_category(list(tourism = "gallery", name = "G")), "cultural_spot")
  expect_equal(osm_category(list(amenity = "cafe", name = "K")), "cafe_bistro")
  expect_true(is.na(osm_category(list(amenity = "fast_food", name = "F"))))
  expect_true(is.na(osm_category(list())))
})

test_that("OSM tags become vibe keywords the classifier understands", {
  k <- osm_vibe_keywords(list(outdoor_seating = "yes", live_music = "yes", lgbtq = "welcome",
                              cuisine = "seafood;pizza;thai", dog = "yes"))
  expect_match(k, "ar-livre", fixed = TRUE)
  expect_match(k, "frutos-do-mar", fixed = TRUE)
  expect_match(k, "thai", fixed = TRUE)
  v <- classify_vibes(k)
  for (vibe in c("outdoor", "live_music", "alternative", "family")) expect_match(v, vibe, fixed = TRUE)
  expect_equal(osm_vibe_keywords(list()), "")
})

test_that("websites: bare www gets https, Instagram is the fallback, unsafe links go", {
  expect_equal(osm_website(list(website = "www.bar.com.br")), "https://www.bar.com.br")
  expect_equal(osm_website(list(`contact:website` = "https://x.example")), "https://x.example")
  expect_equal(osm_website(list(`contact:instagram` = "@barzinho.recife")), "https://www.instagram.com/barzinho.recife")
  expect_equal(osm_website(list(`contact:instagram` = "https://instagram.com/y")), "https://instagram.com/y")
  expect_equal(osm_website(list(website = "javascript:alert(1)")), "")
  expect_equal(osm_website(list(`contact:instagram` = "not a handle!")), "")
  expect_equal(osm_website(list()), "")
})

test_that("Overpass elements become places: categories, hours, neighbourhoods, links", {
  p <- osm_places_from_elements(osm_elements(overpass_fixture()), "Recife - PE")
  expect_equal(names(p), PLACE_COLUMNS)
  expect_true(all(p$source == "openstreetmap"))
  expect_true(all(p$category %in% place_category_keys()))
  # The bench has no name, fast food is not listed, neighbourhood nodes are not places.
  expect_false(any(p$name %in% c("Lanche R\u00e1pido", "Boa Viagem", "Gra\u00e7as")))
  # The node and the building of the same bar are merged; the richer one stays.
  cais <- p[normalize_text(p$name) == "bar do cais", ]
  expect_equal(nrow(cais), 1L)
  expect_equal(cais$place_id, "osm-node-101")
  expect_equal(cais$opening_hours, "Tu-Su 17:00-01:00")
  expect_equal(cais$address, "Rua do Bom Jesus, 10")
  expect_equal(cais$neighborhood, "Recife")
  expect_equal(cais$osm_url, "https://www.openstreetmap.org/node/101")
  expect_equal(cais$website, "https://bardocais.example.com")
  expect_match(cais$maps_url, "^https://www\\.google\\.com/maps/search/\\?api=1&query=Bar%20do%20Cais")
  expect_false(grepl("key=", cais$maps_url, fixed = TRUE))
  by_name <- stats::setNames(p$category, p$name)
  expect_equal(unname(by_name[c("Cervejaria Capibaribe", "Clube do Forr\u00f3", "Boate Neon", "Gastrobar da Esquina",
                                "Teatro de Santa Isabel", "Museu Cais do Sert\u00e3o", "Sky Bar Boa Viagem",
                                "Gafieira Recife")]),
               c("pub", "club", "nightclub", "gastrobar", "concert_house", "cultural_spot", "rooftop_lounge", "club"))
  # No addr:suburb -> the closest neighbourhood node.
  expect_equal(p$neighborhood[p$name == "Mar\u00e9 Alta"], "Boa Viagem")
  expect_equal(p$neighborhood[p$name == "Caf\u00e9 Leitura"], "Gra\u00e7as")
  expect_equal(p$place_id[p$name == "Teatro de Santa Isabel"], "osm-relation-108")
  # Unsafe links are dropped.
  expect_equal(p$website[p$name == "Caf\u00e9 Sem Nome Bom"], "")
  expect_true(all(is.na(p$rating)))
})

test_that("the per-category cap keeps the most complete places", {
  p <- osm_places_from_elements(osm_elements(overpass_fixture()), "Recife - PE", per_category = 1)
  expect_equal(max(table(p$category)), 1L)
  expect_equal(p$name[p$category == "bar"], "Bar do Cais")       # hours, address, website
  expect_equal(p$name[p$category == "cafe_bistro"], "Caf\u00e9 Leitura")
})

test_that("written places load back with hours and vibes", {
  p <- osm_places_from_elements(osm_elements(overpass_fixture()), "Recife - PE")
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  write_places_csv(p, path)
  back <- load_places(path)
  expect_equal(nrow(back), nrow(p))
  expect_false(any(is_demo_place(back)))
  expect_true(all(nzchar(back$vibe_groups)))
  expect_match(back$vibe_groups[back$name == "Bar do Cais"], "live_music", fixed = TRUE)
  fri <- list(wday = 5L, minutes = 23L * 60L)
  st <- places_status(back, fri)
  expect_true(st$open[back$name == "Clube do Forr\u00f3"])
  expect_true(st$unknown[back$name == "Boate Neon"])
  expect_true(st$unknown[back$name == "Sky Bar Boa Viagem"])  # sun-based hours are not read
  expect_error(write_places_csv(p[, 1:3], path), "missing columns")
})

test_that("fetching uses the cache, retries, and never needs a key", {
  # Two overlapping cities (the second centre is made up, near Boa Viagem).
  cities <- data.frame(label = c("Recife - PE", "Olinda - PE"), lat = c(-8.05, -8.11), lon = c(-34.9, -34.89))
  dir <- tempfile("osm-cache")
  on.exit(unlink(dir, recursive = TRUE))
  calls <- character()
  fails <- 1L
  fake <- function(url, destfile, user_agent) {
    calls <<- c(calls, url)
    expect_match(user_agent, "^aconteceR/")
    if (fails > 0L) {
      fails <<- fails - 1L
      stop("HTTP status was '429 Too Many Requests'")
    }
    file.copy(overpass_fixture(), destfile, overwrite = TRUE)
  }
  p <- suppressMessages(fetch_osm_places(cities, cache_dir = dir, pause = 0, fetch = fake))
  expect_equal(length(calls), 3L)  # one 429, then one request per city
  expect_match(calls[[1]], "^https://overpass-api\\.de/api/interpreter\\?data=")
  expect_match(calls[[2]], "^https://overpass\\.kumi\\.systems/")  # the retry goes to the next server
  expect_false(any(grepl("key", calls, ignore.case = TRUE)))
  # Both cities got the same answer: each place is kept once, in the closer city.
  expect_false(anyDuplicated(p$place_id) > 0L)
  expect_equal(p$city[p$place_id == "osm-node-110"], "Recife - PE")
  expect_equal(p$city[p$place_id == "osm-node-106"], "Olinda - PE")
  expect_equal(length(list.files(dir, pattern = "\\.json$")), 2L)
  # Second run: everything from the cache, no requests.
  p2 <- suppressMessages(fetch_osm_places(cities, cache_dir = dir, pause = 0, fetch = fake))
  expect_equal(length(calls), 3L)
  expect_equal(p2, p)
  # A timeout reported inside a 200 answer is a failure, and so is giving up.
  timeout <- function(url, destfile, user_agent) {
    writeLines('{"elements": [], "remark": "runtime error: Query timed out in \\"query\\" at line 3"}', destfile)
  }
  expect_error(suppressMessages(fetch_osm_places(cities[1, ], cache_dir = tempfile(), pause = 0, retries = 1L,
                                                 fetch = timeout)),
               "Overpass did not answer")
})
