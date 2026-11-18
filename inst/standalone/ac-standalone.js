/*! aconteceR standalone controller (MIT licence). The browser-only twin of
 * the Shiny server: event rules (price bands, filters, validation, search and
 * import) mirror the R functions in R/categories.R, R/events.R,
 * R/validate.R and R/providers.R. User events are stored in localStorage. */
(function () {
  "use strict";
  var AC = window.AC, util = AC.util, i18n = AC.i18n, fmt = AC.fmt, esc = util.escapeHtml;
  var t = i18n.t, tf = i18n.tf;

  /* ------------------------------------------------------- domain constants
   * Keep in sync with R/categories.R.                                       */
  var PRICE_KEYS = ["free", "paid", "donation", "unknown"];
  var CAT_KEYS = ["music", "food", "arts", "sports", "tech", "community", "other"];
  var CAT_COLORS = {
    music: "#8b5cf6", food: "#f97316", arts: "#ec4899", sports: "#22c55e",
    tech: "#0ea5e9", community: "#eab308", other: "#94a3b8"
  };
  var BAND_BREAKS = [30, 60, 100];
  var BAND_COLORS = {
    free: "#22c55e", donation: "#a855f7", p1: "#fcd34d", p2: "#f59e0b",
    p3: "#ea580c", p4: "#e11d48", paid_na: "#c08a5b", unknown: "#94a3b8"
  };
  var LIMITS = { title: 120, venue: 120, description: 2000 };
  var STORE_KEY = "aconteceR.standalone.user_events.v2";
  var OLD_STORE_KEY = "aconteceR.standalone.user_events.v1";

  function priceBand(ev) {
    var pt = ev.price_type;
    if (pt === "free") return "free";
    if (pt === "donation") return "donation";
    if (pt === "paid") {
      var p = ev.price === null || ev.price === undefined || ev.price === "" ? NaN : Number(ev.price);
      if (!isFinite(p)) return "paid_na";
      if (p <= BAND_BREAKS[0]) return "p1";
      if (p <= BAND_BREAKS[1]) return "p2";
      if (p <= BAND_BREAKS[2]) return "p3";
      return "p4";
    }
    return "unknown";
  }

  function catKey(k) { return CAT_KEYS.indexOf(k) >= 0 ? k : "other"; }
  function catLabel(k) { return t("cat_" + catKey(k)); }

  function bandLabels() {
    var m = function (x) { return fmt.money(x, "BRL", 0); };
    return {
      free: t("price_free"), donation: t("price_donation"),
      p1: tf("band_upto", m(BAND_BREAKS[0])),
      p2: tf("band_range", m(BAND_BREAKS[0]), m(BAND_BREAKS[1])),
      p3: tf("band_range", m(BAND_BREAKS[1]), m(BAND_BREAKS[2])),
      p4: tf("band_over", m(BAND_BREAKS[2])),
      paid_na: t("band_paid_na"), unknown: t("price_unknown")
    };
  }

  // Same shape as event_color_modes() in R.
  function colorModes() {
    var bl = bandLabels();
    return [
      {
        id: "price", label: t("mode_price"), title: t("price_label"), type: "factor", column: "price_band",
        levels: ["free", "donation", "p1", "p2", "p3", "p4", "paid_na", "unknown"].map(function (k) {
          return { key: k, color: BAND_COLORS[k], label: bl[k] };
        })
      },
      {
        id: "category", label: t("mode_category"), title: t("category_label"), type: "factor", column: "category",
        levels: CAT_KEYS.map(function (k) { return { key: k, color: CAT_COLORS[k], label: catLabel(k) }; })
      }
    ];
  }

  /* ------------------------------------------------------------------ data */
  function readCsv(id) {
    var el = document.getElementById(id);
    return el ? util.parseCsv(el.textContent.trim()) : [];
  }

  var CITIES = (function () {
    // ids follow file order, like load_cities() in R/cities.R
    var rows = readCsv("ac-data-cities").map(function (r, i) {
      return { id: String(i + 1), city: r.city, state: r.state, label: r.city + " - " + r.state, lat: Number(r.lat), lon: Number(r.lon) };
    });
    rows.sort(function (a, b) { return util.normalizeText(a.city).localeCompare(util.normalizeText(b.city)); });
    return rows;
  })();
  var SITES = readCsv("ac-data-sites");
  var TEMPLATES = readCsv("ac-data-templates");

  function num(x) { var n = x === null || x === undefined || x === "" ? NaN : Number(x); return isFinite(n) ? n : null; }

  // Sample dates are relative to today, so the demo never goes stale.
  var SAMPLE_EVENTS = readCsv("ac-data-events").map(function (r) {
    return {
      id: "s-" + r.sample_id, title: r.title, description: r.description, city: r.city, venue: r.venue,
      lat: Number(r.lat), lon: Number(r.lon),
      starts_at: util.addDays(util.today(), Number(r.days_from_now || 0)) + " " + r.time,
      category: r.category, price_type: r.price_type, price: r.price_type === "paid" ? num(r.price) : null,
      currency: "BRL", url: r.url, source: "sample", external_id: r.sample_id
    };
  });

  function loadUserEvents() {
    var list = [];
    try { list = JSON.parse(util.storage.get(STORE_KEY) || "[]"); } catch (e) { list = []; }
    // v1 used numeric ids that could collide with other events: re-key them once.
    try {
      var old = JSON.parse(util.storage.get(OLD_STORE_KEY) || "null");
      if (Array.isArray(old) && old.length) {
        old.forEach(function (ev, i) { ev.id = "u-v1-" + i + "-" + Date.now().toString(36); list.push(ev); });
        util.storage.set(STORE_KEY, JSON.stringify(list));
        util.storage.set(OLD_STORE_KEY, "[]");
      }
    } catch (e2) { /* ignore */ }
    return Array.isArray(list) ? list : [];
  }
  function saveUserEvents(list) { util.storage.set(STORE_KEY, JSON.stringify(list)); }

  var userEvents = loadUserEvents();
  function allEvents() { return SAMPLE_EVENTS.concat(userEvents); }
  function findEvent(id, extra) {
    id = String(id);
    var pools = [allEvents(), extra || [], PLACES];
    for (var p = 0; p < pools.length; p++) {
      for (var i = 0; i < pools[p].length; i++) if (String(pools[p][i].id) === id) return pools[p][i];
    }
    return null;
  }

  /* ---------------------------------------------------------------- places
   * Mirrors R/places.R. Sources listed in VERIFIED_SOURCES count as real data;
   * anything else (e.g. the generated demo file) shows the demo note.        */
  var PCATS = AC.places.CATEGORIES, VIBES = AC.places.VIBES;
  var VERIFIED_SOURCES = ["google_places_api", "openstreetmap"];
  var PCAT_COLORS = {
    bar: "#f59e0b", pub: "#16a34a", nightclub: "#a855f7", restaurant: "#f97316", club: "#ec4899",
    concert_house: "#e11d48", cafe_bistro: "#a16207", gastrobar: "#14b8a6", cultural_spot: "#0ea5e9", rooftop_lounge: "#6366f1"
  };
  var VIBE_COLORS = {
    chill: "#3b82f6", romantic: "#e11d48", party: "#c026d3", live_music: "#7c3aed", dance: "#db2777", casual: "#d97706",
    upscale: "#a16207", outdoor: "#16a34a", alternative: "#475569", culture: "#0891b2", friends: "#ea580c", family: "#65a30d"
  };
  var RATING_BREAKS = [0, 3.95, 4.25, 4.55, 5];
  var RULES = AC.places.compileRules(readCsv("ac-data-vibes"));

  function copy(o) { var q = {}; for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) q[k] = o[k]; return q; }

  var PLACES = readCsv("ac-data-places").map(function (r) {
    var p = copy(r);
    p.id = r.place_id;
    p.kind = "place";
    p.lat = Number(r.lat); p.lon = Number(r.lon);
    p.rating = num(r.rating !== undefined ? r.rating : r.google_rating);
    p.maps_url = r.maps_url || r.google_maps_url || null;
    p.reviews_count = num(r.reviews_count);
    p.price_level = num(r.price_level);
    p.vibe_groups = AC.places.placeVibes(p, RULES);
    p.vibe_main = p.vibe_groups[0] || null;
    return p;
  });
  function isDemoPlace(p) { return VERIFIED_SOURCES.indexOf(p.source) === -1; }

  function pcatLabel(k) { return t("pcat_" + (PCATS.indexOf(k) >= 0 ? k : "bar")); }

  // Opening status at the visitor's clock. Mirrors place_status_key() in R.
  var STATUS_COLORS = { open: "#16a34a", later: "#f59e0b", unknown: "#a5b4c8", closed: "#64748b" };
  function statusKey(st) { return st.open ? "open" : st.unknown ? "unknown" : st.daysAhead === 0 ? "later" : "closed"; }
  // OpenStreetMap has no ratings: then there is no "rating" colour mode.
  var HAS_RATINGS = PLACES.some(function (p) { return p.rating !== null; });

  function placeColorModes() {
    var n = function (x) { return fmt.number(x, 1); };
    return [
      {
        id: "category", label: t("mode_category"), title: t("category_label"), type: "factor", column: "category",
        levels: PCATS.map(function (k) { return { key: k, color: PCAT_COLORS[k], label: pcatLabel(k) }; })
      },
      {
        id: "vibe", label: t("mode_vibe"), title: t("vibe_label"), type: "factor", column: "vibe_main",
        levels: VIBES.map(function (k) { return { key: k, color: VIBE_COLORS[k], label: t("vibe_" + k) }; })
      },
      {
        id: "hours", label: t("mode_hours"), title: t("hours_label"), type: "factor", column: "status_key",
        levels: Object.keys(STATUS_COLORS).map(function (k) { return { key: k, color: STATUS_COLORS[k], label: t("status_" + k) }; })
      },
      {
        id: "rating", label: t("mode_rating"), title: t("rating_label"), type: "bins", column: "rating", na_label: t("rating_none"),
        breaks: RATING_BREAKS, colors: ["#cbd5e1", "#fcd34d", "#f59e0b", "#16a34a"],
        labels: [tf("rating_below", n(4)), n(4) + " \u2013 " + n(4.2), n(4.3) + " \u2013 " + n(4.5), tf("rating_up", n(4.6))]
      }
    ].filter(function (m) { return m.id !== "rating" || HAS_RATINGS; });
  }

  function ratingHtml(p) {
    if (p.rating === null) return "";
    return '<span class="ac-rating">' + AC.icons.star + esc(fmt.number(p.rating, 1)) +
      (p.reviews_count !== null ? " <small>(" + esc(fmt.number(p.reviews_count, 0)) + ")</small>" : "") + "</span>";
  }
  function priceLevel(p) { return p.price_level ? new Array(p.price_level + 1).join("$") : ""; }
  function vibeTags(p, n) {
    return '<div class="ac-vibe-tags">' + p.vibe_groups.slice(0, n || 3).map(function (v) {
      return '<span class="ac-vibe-tag"><i style="background:' + VIBE_COLORS[v] + '"></i>' + esc(t("vibe_" + v)) + "</span>";
    }).join("") + "</div>";
  }
  function mapsLink(p, cls) {
    return /^https?:\/\/\S+$/i.test(p.maps_url || "")
      ? '<a class="' + cls + '" href="' + esc(p.maps_url) + '" target="_blank" rel="noopener noreferrer" aria-label="' +
        esc(t("place_maps_link")) + '" title="' + esc(t("place_maps_link")) + '">' + AC.icons.external +
        (cls === "ac-ev-link" ? "" : "<span>" + esc(t("place_maps_link")) + "</span>") + "</a>" : "";
  }

  function statusClass(st) { return st.open ? "ac-place-open" : st.unknown ? "ac-place-unknown" : "ac-place-closed"; }

  // Google Maps search, website, OpenStreetMap page. Mirrors place_links() in R.
  function placeLinks(p) {
    var link = function (url, key, icon) {
      return /^https?:\/\/\S+$/i.test(url || "")
        ? '<a class="ac-linkbtn" href="' + esc(url) + '" target="_blank" rel="noopener noreferrer">' + AC.icons[icon] +
          "<span>" + esc(t(key)) + "</span></a>" : "";
    };
    var html = mapsLink(p, "ac-linkbtn") + link(p.website, "place_website", "external") + link(p.osm_url, "place_osm_link", "map");
    return html ? '<div class="ac-pop-actions">' + html + "</div>" : "";
  }

  function placePopup(p, st) {
    st = st || AC.places.status(p, new Date());
    return '<span class="ac-pop-title">' + esc(p.name) + "</span>" +
      '<span class="ac-pop-when">' + esc(pcatLabel(p.category)) + (p.neighborhood ? " \u00b7 " + esc(p.neighborhood) : "") + "</span>" +
      '<span class="ac-pop-meta"><span class="' + statusClass(st) + '">' +
      esc(AC.places.statusText(st, new Date())) + "</span>" + ratingHtml(p) +
      '<span class="ac-price-level">' + priceLevel(p) + "</span></span>" + vibeTags(p, 3) + placeLinks(p);
  }

  function placePoint(p, st) {
    st = st || AC.places.status(p, new Date());
    return {
      id: p.id, lat: p.lat, lon: p.lon, label: p.name, popup: placePopup(p, st),
      category: p.category, vibe_main: p.vibe_main, rating: p.rating, neighborhood: p.neighborhood || null,
      status_key: statusKey(st)
    };
  }

  function matchesPlace(p, q) {
    var norm = util.normalizeText(q || "").trim();
    if (!norm) return true;
    var hay = util.normalizeText([p.name, p.neighborhood, p.vibes, pcatLabel(p.category)].concat(
      p.vibe_groups.map(function (v) { return t("vibe_" + v); })).join(" "));
    return norm.split(/\s+/).every(function (term) { return hay.indexOf(term) !== -1; });
  }

  // Open first, then by rating weighted by reviews. Mirrors order_places() in R.
  function placesFiltered(now) {
    now = now || new Date();
    var c = city();
    return PLACES.filter(function (p) { return p.city === c.label; }).map(function (p) {
      var q = AC.places.quality(p.rating, p.reviews_count);
      return { p: p, st: AC.places.status(p, now), q: q === null ? 0.5 : q };
    }).filter(function (x) {
      return (!state.pCats.length || state.pCats.indexOf(x.p.category) !== -1) &&
        (!state.pVibes.length || state.pVibes.some(function (v) { return x.p.vibe_groups.indexOf(v) !== -1; })) &&
        (!state.pOpen || x.st.open) && (!state.pLate || AC.places.isOpenLate(x.p, now)) && matchesPlace(x.p, state.q);
    }).sort(function (a, b) {
      var g = function (x) { return x.st.open ? 0 : x.st.unknown ? 1 : 2; };  // open, unknown, closed
      return (g(a) - g(b)) || (b.q - a.q) || a.p.name.localeCompare(b.p.name);
    });
  }

  function placeRowHtml(x, now) {
    var p = x.p, cat = PCATS.indexOf(p.category) >= 0 ? p.category : "bar";
    return '<article class="ac-ev ac-place" data-id="' + esc(p.id) + '">' +
      '<div class="ac-ev-tile ac-pcat-' + cat + '" aria-hidden="true">' + AC.icons["pcat_" + cat] + "</div>" +
      '<div class="ac-ev-main"><h3 class="ac-ev-title"><button type="button" class="ac-ev-show" data-focus-id="' +
      esc(p.id) + '" title="' + esc(t("show_on_map")) + '">' + esc(p.name) + "</button></h3>" +
      '<p class="ac-ev-meta"><span class="' + statusClass(x.st) + '">' +
      esc(AC.places.statusText(x.st, now)) + "</span>" + (p.neighborhood ? " \u00b7 " + esc(p.neighborhood) : "") + "</p>" +
      vibeTags(p, 3) + "</div>" +
      '<div class="ac-ev-side">' + ratingHtml(p) + '<span class="ac-price-level">' + priceLevel(p) + "</span>" +
      mapsLink(p, "ac-ev-link") + "</div></article>";
  }

  /* --------------------------------------------------------------- filters */
  function matchesQuery(ev, q) {
    var norm = util.normalizeText(q || "").trim();
    if (!norm) return true;
    var hay = util.normalizeText([ev.title, ev.description, ev.venue, ev.city].filter(Boolean).join(" "));
    return norm.split(/\s+/).every(function (term) { return hay.indexOf(term) !== -1; });
  }

  // Night activity: starts at 18:00 or later, or before 05:00. When the app is
  // dark (dusk or night), they lead each day. Mirrors order_events() in R.
  function isNightActivity(ev) {
    var h = Number(String(ev.starts_at || "").slice(11, 13));
    return isFinite(h) && (h >= 18 || h < 5);
  }
  function orderForList(list) {
    var night = AC.theme.isDark();
    return list.slice().sort(function (a, b) {
      var da = String(a.starts_at).slice(0, 10), db = String(b.starts_at).slice(0, 10);
      if (da !== db) return da < db ? -1 : 1;
      if (night) {
        var na = isNightActivity(a) ? 0 : 1, nb = isNightActivity(b) ? 0 : 1;
        if (na !== nb) return na - nb;
      }
      return byStart(a, b);
    });
  }

  function byStart(a, b) {
    return String(a.starts_at).localeCompare(String(b.starts_at)) || String(a.id).localeCompare(String(b.id));
  }

  // Mirrors when_range() in R/mod_events.R.
  function whenRange(when, today) {
    today = today || util.today();
    switch (when) {
      case "today": return [today, today];
      case "weekend": {
        var w = util.parseIsoDate(today).getDay();
        if (w === 0) return [today, today];
        var sat = util.addDays(today, 6 - w);
        return [sat, util.addDays(sat, 1)];
      }
      case "7d": return [today, util.addDays(today, 7)];
      case "30d": return [today, util.addDays(today, 30)];
      case "custom": return state.custom || [today, null];
      default: return [today, null];
    }
  }

  var state = {
    cityId: null, q: "", cats: [], prices: [], when: "all", custom: null,
    picked: null, searchResults: null,
    mode: "events", pOpen: false, pLate: false, pCats: [], pVibes: [], modeColor: { events: "price", places: "category" }
  };

  function city() {
    for (var i = 0; i < CITIES.length; i++) if (CITIES[i].id === state.cityId) return CITIES[i];
    return CITIES[0];
  }

  // Text, price and category filters (the calendar adds its own dates).
  function cityEventsNoDates() {
    var c = city();
    return allEvents().filter(function (ev) {
      return ev.city === c.label &&
        (!state.prices.length || state.prices.indexOf(ev.price_type) !== -1) &&
        (!state.cats.length || state.cats.indexOf(ev.category) !== -1) &&
        matchesQuery(ev, state.q);
    }).sort(byStart);
  }

  function filtered() {
    var r = whenRange(state.when);
    return cityEventsNoDates().filter(function (ev) {
      var d = String(ev.starts_at || "").slice(0, 10);
      return (!r[0] || d >= r[0]) && (!r[1] || d <= r[1]);
    });
  }

  /* ------------------------------------------------------------- rendering */
  function popupHtml(ev) {
    var link = /^https?:\/\/\S+$/i.test(ev.url || "")
      ? '<br><a href="' + esc(ev.url) + '" target="_blank" rel="noopener noreferrer">' + esc(t("event_page")) + "</a>" : "";
    return '<span class="ac-pop-title">' + esc(ev.title) + "</span>" +
      '<span class="ac-pop-when">' + esc(fmt.when(ev.starts_at)) + "</span>" +
      '<span class="ac-pop-meta"><span class="ac-price ac-band-' + esc(priceBand(ev)) + '">' +
      esc(fmt.price(ev.price_type, ev.price, ev.currency)) + '</span><span class="ac-tag">' + esc(catLabel(ev.category)) + "</span></span>" +
      (ev.venue ? '<span class="ac-pop-venue">' + esc(ev.venue) + "</span>" : "") + link + aroundButton(ev);
  }

  // "Before & after" (AC.Decide.showAround). Mirrors around_button_html() in R.
  function aroundButton(ev) {
    var ok = ev.lat !== null && ev.lon !== null && isFinite(ev.lat) && isFinite(ev.lon) && /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/.test(ev.starts_at || "");
    if (!ok) return "";
    return '<div class="ac-pop-actions"><button type="button" class="ac-linkbtn ac-around-btn" data-ac-around="' + esc(ev.id) +
      '" data-title="' + esc(ev.title) + '" data-lat="' + esc(ev.lat) + '" data-lon="' + esc(ev.lon) +
      '" data-start="' + esc(ev.starts_at) + '">' + AC.icons.route + "<span>" + esc(t("around_link")) + "</span></button></div>";
  }

  function toPoint(ev) {
    return {
      id: ev.id, lat: ev.lat, lon: ev.lon, label: ev.title, popup: popupHtml(ev),
      price_band: priceBand(ev), category: ev.category
    };
  }

  // One event row. Same markup as event_row() in R/ui_helpers.R.
  function rowHtml(ev, showCity) {
    var cat = catKey(ev.category);
    var where = ev.venue || "";
    if (showCity && ev.city) where = where ? where + ", " + ev.city : ev.city;
    var src = ev.source && ev.source !== "user" && ev.source !== "sample"
      ? '<span class="ac-src">' + esc(ev.source) + "</span>" : "";
    var link = /^https?:\/\/\S+$/i.test(ev.url || "")
      ? '<a class="ac-ev-link" href="' + esc(ev.url) + '" target="_blank" rel="noopener noreferrer" aria-label="' +
        esc(t("event_page")) + '" title="' + esc(t("event_page")) + '">' + AC.icons.external + "</a>" : "";
    return '<article class="ac-ev" data-id="' + esc(ev.id) + '">' +
      '<div class="ac-ev-tile ac-cat-' + cat + '" aria-hidden="true">' + AC.icons["cat_" + cat] + "</div>" +
      '<div class="ac-ev-main"><h3 class="ac-ev-title"><button type="button" class="ac-ev-show" data-focus-id="' +
      esc(ev.id) + '" title="' + esc(t("show_on_map")) + '">' + esc(ev.title) + "</button></h3>" +
      '<p class="ac-ev-meta">' +
      (AC.theme.isDark() && isNightActivity(ev) ? '<span class="ac-ev-moon" title="' + esc(t("night_activity")) + '">' +
        AC.icons.moon + "</span>" : "") +
      '<span class="ac-ev-when">' + esc(fmt.when(ev.starts_at)) + "</span>" +
      (where ? " \u00b7 " + esc(where) : "") + src + "</p></div>" +
      '<div class="ac-ev-side"><span class="ac-price ac-band-' + esc(priceBand(ev)) + '">' +
      esc(fmt.price(ev.price_type, ev.price, ev.currency)) + "</span>" + link + "</div></article>";
  }

  function dayLabel(iso) {
    var today = util.today();
    if (iso === today) return t("day_today");
    if (iso === util.addDays(today, 1)) return t("day_tomorrow");
    return fmt.dayLong(iso);
  }

  // Rows grouped under sticky day headers, capped at 100.
  function listHtml(list, showCity) {
    if (!list.length) {
      return '<div class="ac-empty"><strong>' + esc(t("empty_title")) + "</strong><span>" +
        esc(t("empty_hint")) + "</span></div>";
    }
    var shown = orderForList(list).slice(0, 100), html = "", last = null, today = util.today();
    shown.forEach(function (ev) {
      var d = String(ev.starts_at || "").slice(0, 10);
      if (d !== last) {
        html += '<h4 class="ac-day' + (d === today ? " ac-day-today" : "") + '">' + esc(dayLabel(d)) + "</h4>";
        last = d;
      }
      html += rowHtml(ev, showCity);
    });
    return (list.length > shown.length ? '<div class="ac-note">' + esc(tf("showing_first", shown.length, list.length)) + "</div>" : "") + html;
  }

  var $ = function (id) { return document.getElementById(id); };
  var map, cal, decide;

  function renderChips() {
    $("f-cat").innerHTML = CAT_KEYS.map(function (k) {
      var on = state.cats.indexOf(k) >= 0;
      return '<button type="button" class="ac-chip ac-chip-cat ac-chip-' + k + (on ? " is-on" : "") + '" data-value="' + k +
        '" aria-pressed="' + on + '"><span class="ac-chip-dot ac-cat-' + k + '">' + AC.icons["cat_" + k] +
        '</span><span data-i18n="cat_' + k + '">' + esc(catLabel(k)) + "</span></button>";
    }).join("");
    var addCat = AC.chips.value($("add-cat")) || "music";
    $("add-cat").innerHTML = CAT_KEYS.map(function (k) {
      return '<button type="button" class="ac-chip' + (k === addCat ? " is-on" : "") + '" data-value="' + k + '">' +
        '<span class="ac-chip-dot ac-cat-' + k + '">' + AC.icons["cat_" + k] + "</span>" + esc(catLabel(k)) + "</button>";
    }).join("");
    var sites = AC.chips.value($("sr-sites"));
    var all = !$("sr-sites").children.length;
    $("sr-sites").innerHTML = SITES.map(function (s) {
      var on = all || sites.indexOf(s.name) >= 0;
      return '<button type="button" class="ac-chip' + (on ? " is-on" : "") + '" data-value="' + esc(s.name) + '">' +
        '<span class="ac-check-mark" aria-hidden="true">\u2713</span>' + esc(s.label) + "</button>";
    }).join("");
    if (state.when === "custom") setCustomChip();
    $("p-cat").innerHTML = PCATS.map(function (k) {
      var on = state.pCats.indexOf(k) >= 0;
      return '<button type="button" class="ac-chip ac-chip-pcat ac-chip-pcat-' + k + (on ? " is-on" : "") + '" data-value="' + k +
        '" aria-pressed="' + on + '"><span class="ac-chip-dot ac-pcat-' + k + '">' + AC.icons["pcat_" + k] +
        "</span><span>" + esc(pcatLabel(k)) + "</span></button>";
    }).join("");
    $("p-vibe").innerHTML = VIBES.map(function (k) {
      var on = state.pVibes.indexOf(k) >= 0;
      return '<button type="button" class="ac-chip ac-chip-vibe ac-chip-vibe-' + k + (on ? " is-on" : "") + '" data-value="' + k +
        '" aria-pressed="' + on + '"><span class="ac-chip-dot ac-vibe-' + k + '"></span><span>' + esc(t("vibe_" + k)) + "</span></button>";
    }).join("");
  }

  function renderPlaces() {
    var now = new Date(), list = placesFiltered(now);
    $("pl-summary").textContent = i18n.count("count_places", list.length);
    $("pl-demo").hidden = !list.some(function (x) { return isDemoPlace(x.p); });
    $("pl-osm").hidden = !list.some(function (x) { return x.p.source === "openstreetmap"; });
    $("pl-list").innerHTML = list.length ? list.slice(0, 100).map(function (x) { return placeRowHtml(x, now); }).join("")
      : '<div class="ac-empty"><strong>' + esc(t("empty_title")) + "</strong><span>" + esc(t("empty_hint")) + "</span></div>";
    if (state.mode === "places") map.setPoints(list.map(function (x) { return placePoint(x.p, x.st); }));
  }

  function decideItems() {
    var c = city(), today = util.today(), until = util.addDays(today, 9);
    var pl = PLACES.filter(function (p) { return p.city === c.label; }).map(function (p) {
      var q = copy(p);
      q.vibes = p.vibe_groups;
      q.label = p.name;
      q.popup = placePopup(p);
      return q;
    });
    var ev = allEvents().filter(function (e) {
      var d = String(e.starts_at || "").slice(0, 10);
      return e.city === c.label && d >= today && d <= until;
    }).map(function (e) {
      var q = copy(e);
      q.kind = "event";
      q.vibes = AC.places.eventVibes(e, RULES);
      q.label = e.title;
      q.popup = popupHtml(e);
      return q;
    });
    return pl.concat(ev);
  }

  function setMode(mode) {
    state.mode = mode;
    map.setColorModes(mode === "places" ? placeColorModes() : colorModes(), state.modeColor[mode]);
    if (mode === "places") renderPlaces(); else { renderList(); renderCalendar(); }
  }

  function renderList() {
    var list = filtered();
    $("ev-summary").textContent = i18n.count("count_events", list.length);
    $("ev-list").innerHTML = listHtml(list, false);
    if (state.mode === "events") map.setPoints(list.map(toPoint));
  }

  function renderCalendar() {
    cal.setColorSpec(map.colorSpec());
    cal.setItems(cityEventsNoDates().map(function (ev) {
      return {
        id: ev.id, starts_at: ev.starts_at, title: ev.title,
        meta: [fmt.price(ev.price_type, ev.price, ev.currency), catLabel(ev.category), ev.venue].filter(Boolean).join(" \u00b7 "),
        price_band: priceBand(ev), category: ev.category
      };
    }));
  }

  function renderWhere() {
    $("add-where").textContent = state.picked
      ? tf("where_picked", state.picked.lat, state.picked.lon)
      : tf("where_centre", city().label);
  }

  function renderCityName() {
    var els = document.querySelectorAll("[data-ac-city-name]");
    for (var i = 0; i < els.length; i++) els[i].textContent = city().city;
  }

  function renderSearch() {
    if (!state.searchResults) { $("sr-summary").textContent = ""; $("sr-list").innerHTML = ""; return; }
    var n = state.searchResults.length;
    $("sr-summary").textContent = tf(n === 1 ? "result_one" : "result_many", n);
    $("sr-list").innerHTML = listHtml(state.searchResults, true);
  }

  function refresh() {
    renderCityName();
    renderList();
    renderCalendar();
    renderPlaces();
    renderWhere();
    if (decide) decide.setItems(decideItems());
  }

  // The removable chip for a range picked on the calendar.
  function setCustomChip() {
    var r = state.custom;
    if (!r) return;
    var label;
    if (r[0] === r[1]) {
      var d = util.parseIsoDate(r[0]);
      label = tf("fmt_day_short", d.getDate(), t("mon_short")[d.getMonth()]);
    } else {
      var m = util.parseIsoDate(r[0]);
      label = fmt.monthTitle(m.getFullYear(), m.getMonth());
    }
    AC.chips.custom($("f-when"), label, { silent: true });
  }

  function setRange(from, to) {
    state.custom = [from, to];
    state.when = "custom";
    setCustomChip();
    renderList();
  }

  /* -------------------------------------------------- search and import */
  function siteDomain(name) {
    for (var i = 0; i < SITES.length; i++) if (SITES[i].name === name) return SITES[i].domain;
    return "https://example.org";
  }

  // Mirrors generate_site_events() in R/providers.R.
  function discover(sites, scopeLabel, query) {
    var targets = scopeLabel ? CITIES.filter(function (c) { return c.label === scopeLabel; }) : CITIES;
    var out = [];
    TEMPLATES.forEach(function (tpl) {
      if (sites.indexOf(tpl.site) === -1) return;
      targets.forEach(function (c) {
        var ext = tpl.site + "-" + tpl.suffix + "-" + c.id;
        var ev = {
          id: "x-" + ext, title: tpl.title + " - " + c.city, description: tpl.description, city: c.label,
          venue: tpl.venue + " (" + c.city + ")",
          lat: Math.round((c.lat + Number(tpl.dlat)) * 1e4) / 1e4, lon: Math.round((c.lon + Number(tpl.dlon)) * 1e4) / 1e4,
          starts_at: util.addDays(util.today(), Number(tpl.days_from_now)) + " " + tpl.time,
          category: tpl.category, price_type: tpl.price_type, price: num(tpl.price), currency: "BRL",
          url: siteDomain(tpl.site) + "/e/" + ext, source: tpl.site, external_id: ext
        };
        if (matchesQuery(ev, query)) out.push(ev);
      });
    });
    return out;
  }

  function searchInputs() {
    return {
      q: $("sr-q").value || "",
      scopeLabel: AC.chips.value($("sr-scope")) === "all" ? null : city().label,
      sites: AC.chips.value($("sr-sites"))
    };
  }

  function eventKey(ev) { return util.normalizeText(ev.title) + "|" + ev.starts_at + "|" + ev.city; }

  function runSearch() {
    var s = searchInputs();
    var local = allEvents().filter(function (ev) {
      return (!s.scopeLabel || ev.city === s.scopeLabel) && matchesQuery(ev, s.q);
    });
    var seen = {}, out = [];
    local.concat(discover(s.sites, s.scopeLabel, s.q)).forEach(function (ev) {
      var k = eventKey(ev);
      if (!seen[k]) { seen[k] = true; out.push(ev); }
    });
    state.searchResults = out.sort(byStart);
    renderSearch();
  }

  function runImport() {
    var s = searchInputs();
    var existing = {};
    allEvents().forEach(function (ev) {
      existing[eventKey(ev)] = true;
      if (ev.external_id) existing["x|" + ev.source + "|" + ev.external_id] = true;
    });
    var added = 0;
    discover(s.sites, s.scopeLabel, s.q).forEach(function (ev) {
      if (existing[eventKey(ev)] || existing["x|" + ev.source + "|" + ev.external_id]) return;
      existing[eventKey(ev)] = true;
      userEvents.push(ev);
      added++;
    });
    if (added) {
      saveUserEvents(userEvents);
      AC.ui.toast(tf("autopop_done", added, s.scopeLabel || t("scope_all")));
      refresh();
      runSearch();
    } else {
      AC.ui.toast(t("autopop_none"), { kind: "warning" });
    }
  }

  /* ------------------------------------------------------------- add form */
  // Mirrors validate_event() in R/validate.R; messages come from the dictionary.
  function validate(ev) {
    var errors = [];
    var title = (ev.title || "").trim();
    if (!title) errors.push(t("err_title_required"));
    else if (title.length > LIMITS.title) errors.push(tf("err_title_long", LIMITS.title));
    if (!(isFinite(ev.lat) && isFinite(ev.lon) && Math.abs(ev.lat) <= 90 && Math.abs(ev.lon) <= 180)) errors.push(t("err_location"));
    var m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$/.exec(ev.starts_at || "");
    var okDate = false;
    if (m) {
      var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]));
      okDate = d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3]) && Number(m[4]) < 24 && Number(m[5]) < 60;
    }
    if (!okDate) errors.push(t("err_datetime"));
    if (CAT_KEYS.indexOf(ev.category) === -1) errors.push(t("err_category"));
    if (PRICE_KEYS.indexOf(ev.price_type) === -1) errors.push(t("err_price_type"));
    if (ev.price_type === "paid" && !(isFinite(ev.price) && ev.price !== null && ev.price >= 0)) errors.push(t("err_price_amount"));
    if (ev.url && !/^https?:\/\/\S+$/i.test(ev.url)) errors.push(t("err_url"));
    if ((ev.venue || "").length > LIMITS.venue) errors.push(tf("err_venue_long", LIMITS.venue));
    if ((ev.description || "").length > LIMITS.description) errors.push(tf("err_desc_long", LIMITS.description));
    return errors;
  }

  function submitAdd(e) {
    e.preventDefault();
    var c = city();
    var loc = state.picked || { lat: c.lat, lon: c.lon };
    var pt = AC.chips.value($("add-price")) || "free";
    var amount = $("add-amount").value;
    var ev = {
      id: "u-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      title: ($("add-title").value || "").trim(),
      description: ($("add-desc").value || "").trim() || null,
      city: c.label, venue: ($("add-venue").value || "").trim() || null,
      lat: Number(loc.lat), lon: Number(loc.lon),
      starts_at: ($("add-date").value || "") + " " + ($("add-time").value || "").trim().slice(0, 5),
      category: AC.chips.value($("add-cat")) || "other", price_type: pt,
      price: pt === "paid" && amount !== "" ? Number(amount) : null,
      currency: "BRL", url: ($("add-url").value || "").trim() || null, source: "user", external_id: null
    };
    var errors = validate(ev);
    if (errors.length) { AC.ui.toast(errors.join(" "), { kind: "error", timeout: 8000 }); return; }
    var dup = allEvents().some(function (x) {
      return x.city === ev.city && x.starts_at === ev.starts_at && util.normalizeText(x.title) === util.normalizeText(ev.title);
    });
    if (dup) { AC.ui.toast(t("notif_exists"), { kind: "warning" }); return; }
    userEvents.push(ev);
    saveUserEvents(userEvents);
    ["add-title", "add-venue", "add-url", "add-desc", "add-amount"].forEach(function (id) { $(id).value = ""; });
    state.picked = null;
    map.clearPick();
    refresh();
    AC.ui.openPane("list");
    showOnMap(ev.id);
    var visible = filtered().some(function (x) { return x.id === ev.id; });
    AC.ui.toast(tf("notif_added", ev.title) + (visible ? "" : " " + t("notif_hidden")));
  }

  /* ------------------------------------------------------------ navigation */
  function setView(v) {
    AC.ui.setView(document.querySelector(".ac-view-switch"), v, "app");
  }

  function showOnMap(id) {
    var ev = findEvent(id, state.searchResults);
    if (!ev) return;
    var mode = ev.kind === "place" ? "places" : "events";
    if (mode !== state.mode) AC.chips.set($("f-mode"), mode);
    setView("map");
    if (ev.city !== city().label) {
      for (var i = 0; i < CITIES.length; i++) {
        if (CITIES[i].label === ev.city) { map.setPlace(CITIES[i].id, { source: "app", move: false }); break; }
      }
    }
    if (!map.focus(ev.id)) map.focus(ev.kind === "place" ? placePoint(ev) : toPoint(ev));
  }

  function explicitCity() {
    var want;
    try { want = new URLSearchParams(location.search).get("city"); } catch (e) { want = null; }
    if (!want) return null;
    var n = util.normalizeText(want);
    for (var i = 0; i < CITIES.length; i++) {
      var c = CITIES[i];
      if (c.id === want || util.normalizeText(c.city) === n || util.normalizeText(c.label) === n) return c.id;
    }
    return null;
  }

  function defaultCity() {
    for (var i = 0; i < CITIES.length; i++) if (util.normalizeText(CITIES[i].city) === "sao paulo") return CITIES[i].id;
    return CITIES[0].id;
  }

  /* ------------------------------------------------------------------ init */
  function init() {
    i18n.load(util.readJsonScript("ac-i18n-dict"));
    i18n.setLang(i18n.detect().lang);
    renderChips();
    AC.ui.icons(document);

    var fromUrl = explicitCity();
    state.cityId = fromUrl || defaultCity();
    $("add-date").value = util.today();

    map = new AC.PointMap($("ac-map"), {
      places: CITIES, place: state.cityId, colorModes: colorModes(), colorMode: "price",
      cluster: false, autoLocate: fromUrl ? false : true,
      placeTarget: "#ac-place-slot", modesTarget: "#ac-modes-slot", groupBy: "neighborhood",
      onPlace: function (id) {
        state.cityId = id;
        state.picked = null;
        refresh();
      },
      onColorMode: function (id) { state.modeColor[state.mode] = id; if (state.mode === "events") renderCalendar(); },
      onPick: function (p) { state.picked = p; renderWhere(); }
    });

    cal = new AC.MonthCalendar($("ac-calendar"), {
      colorSpec: map.colorSpec(),
      onItem: function (id) { showOnMap(id); },
      onShowDay: function (iso) { setRange(iso, iso); setView("map"); map.fit(); },
      onShowMonth: function (ym) {
        var p = ym.split("-");
        var last = new Date(Number(p[0]), Number(p[1]), 0).getDate();
        setRange(ym + "-01", ym + "-" + util.pad2(last));
        setView("map");
        map.fit();
      }
    });

    decide = new AC.Decide($("ac-decide"), {
      onPick: function (item) { showOnMap(item.id); },
      onRoute: function (stops) {
        if (state.mode !== "places") AC.chips.set($("f-mode"), "places");
        setView("map");
        map.setRoute(stops);
      }
    });
    $("dq-demo").hidden = !PLACES.some(isDemoPlace);
    $("dq-osm").hidden = !PLACES.some(function (p) { return p.source === "openstreetmap"; });
    refresh();
    // Opening hours change with the clock.
    setInterval(function () { renderPlaces(); }, 60 * 1000);

    i18n.onChange(function () {
      renderChips();
      map.setColorModes(state.mode === "places" ? placeColorModes() : colorModes());
      map.relabel();
      refresh();
      renderSearch();
      decide.relabel();
    });

    bind();
    try {
      var qs = new URLSearchParams(location.search);
      if (qs.get("mode") === "places") AC.chips.set($("f-mode"), "places");
      if (qs.get("view") === "calendar") setView("calendar");
    } catch (e) { /* old browser */ }
  }

  function bind() {
    document.addEventListener("click", function (e) {
      var langBtn = e.target.closest(".ac-lang-btn");
      if (langBtn) { i18n.setLang(langBtn.getAttribute("data-lang"), { persist: true }); return; }
      var show = e.target.closest("[data-focus-id]");
      if (show) { showOnMap(show.getAttribute("data-focus-id")); }
    });
    document.addEventListener("ac:chips", function (e) {
      var id = e.target.id, v = e.detail.value;
      if (id === "f-when") {
        if (v !== "custom") { state.custom = null; AC.chips.removeCustom(e.target, { silent: true }); }
        state.when = v || "all";
        renderList();
      } else if (id === "f-cat") { state.cats = v; renderList(); renderCalendar(); }
      else if (id === "f-price") { state.prices = v; renderList(); renderCalendar(); }
      else if (id === "add-price") { $("add-amount-wrap").hidden = v !== "paid"; }
      else if (id === "f-mode") { setMode(v || "events"); }
      else if (id === "p-open") { state.pOpen = v.indexOf("open") !== -1; state.pLate = v.indexOf("late") !== -1; renderPlaces(); }
      else if (id === "p-cat") { state.pCats = v; renderPlaces(); }
      else if (id === "p-vibe") { state.pVibes = v; renderPlaces(); }
    });
    // Night plans first once it gets dark.
    document.addEventListener("ac:theme", function (e) {
      if (e.detail.darkChanged) { renderList(); renderSearch(); }
    });
    // Hovering a row rings its pin.
    ["ev-list", "sr-list", "pl-list"].forEach(function (id) {
      $(id).addEventListener("mouseover", function (e) {
        var row = e.target.closest(".ac-ev");
        map.highlight(row ? row.getAttribute("data-id") : null);
      });
      $(id).addEventListener("mouseleave", function () { map.highlight(null); });
    });

    var debounce = function (fn, ms) { var h; return function () { clearTimeout(h); h = setTimeout(fn, ms); }; };
    $("ev-q").addEventListener("input", debounce(function () {
      state.q = $("ev-q").value; renderList(); renderCalendar(); renderPlaces();
    }, 150));
    $("sr-go").addEventListener("click", runSearch);
    $("sr-q").addEventListener("keydown", function (e) { if (e.key === "Enter") runSearch(); });
    $("sr-import").addEventListener("click", runImport);
    $("add-form").addEventListener("submit", submitAdd);
  }

  // Exposed for the browser smoke test (tools/smoke_standalone.py).
  window.AconteceStandalone = {
    priceBand: priceBand, validate: validate, orderForList: orderForList, isNightActivity: isNightActivity, discover: discover, filtered: filtered, whenRange: whenRange,
    state: state, cities: CITIES, places: PLACES, placesFiltered: placesFiltered, decideItems: decideItems,
    map: function () { return map; }, calendar: function () { return cal; }, decide: function () { return decide; }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
