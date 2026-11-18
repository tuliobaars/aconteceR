/*! aconteceR core (MIT licence). Shared by the Shiny app and the standalone
 * HTML: i18n, locale-aware formatting, theme, "closest city" detection,
 * colour-mode resolution, small UI helpers. No dependencies. */
(function (global) {
  "use strict";

  var AC = global.AC = global.AC || {};

  /* ------------------------------------------------------------------ util */
  var util = AC.util = {};

  util.escapeHtml = function (s) {
    if (s === null || s === undefined) return "";
    return String(s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  };

  // Lower-case and strip diacritics: "Florianópolis" matches "florianopolis".
  util.normalizeText = function (s) {
    if (s === null || s === undefined) return "";
    return String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  };

  util.pad2 = function (n) { return (n < 10 ? "0" : "") + n; };

  // Local calendar dates as "YYYY-MM-DD" (never via toISOString, which is UTC).
  util.isoDate = function (d) {
    return d.getFullYear() + "-" + util.pad2(d.getMonth() + 1) + "-" + util.pad2(d.getDate());
  };
  util.parseIsoDate = function (s) {
    var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s || "");
    if (!m) return null;
    var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
    return isNaN(d.getTime()) ? null : d;
  };
  util.today = function () { return util.isoDate(new Date()); };
  util.addDays = function (iso, n) {
    var d = util.parseIsoDate(iso) || new Date();
    return util.isoDate(new Date(d.getFullYear(), d.getMonth(), d.getDate() + n));
  };

  util.asArray = function (x) {
    if (x === null || x === undefined) return [];
    return Array.isArray(x) ? x : [x];
  };

  // Minimal sprintf for the dictionary: %s, %d, %.Nf and %%.
  util.sprintf = function (fmt) {
    var args = Array.prototype.slice.call(arguments, 1);
    var i = 0;
    return String(fmt).replace(/%(%|s|d|\.(\d+)f)/g, function (m, kind, digits) {
      if (kind === "%") return "%";
      var v = args[i++];
      if (kind === "s") return v === null || v === undefined ? "" : String(v);
      if (kind === "d") return String(Math.round(Number(v)));
      return Number(v).toFixed(Number(digits));
    });
  };

  // RFC 4180 CSV -> array of objects keyed by the header row. "NA" and empty
  // cells become null (the R data files write NA for missing values).
  util.parseCsv = function (text) {
    var rows = [], row = [], field = "", inQuotes = false, i = 0, c;
    text = String(text || "").replace(/^\uFEFF/, "");
    while (i < text.length) {
      c = text[i];
      if (inQuotes) {
        if (c === '"') {
          if (text[i + 1] === '"') { field += '"'; i += 2; continue; }
          inQuotes = false; i++; continue;
        }
        field += c; i++; continue;
      }
      if (c === '"') { inQuotes = true; i++; continue; }
      if (c === ",") { row.push(field); field = ""; i++; continue; }
      if (c === "\r") { i++; continue; }
      if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; i++; continue; }
      field += c; i++;
    }
    if (field !== "" || row.length) { row.push(field); rows.push(row); }
    if (!rows.length) return [];
    var head = rows[0];
    var out = [];
    for (var r = 1; r < rows.length; r++) {
      if (rows[r].length === 1 && rows[r][0] === "") continue;
      var obj = {};
      for (var k = 0; k < head.length; k++) {
        var v = rows[r][k];
        obj[head[k]] = (v === undefined || v === "" || v === "NA") ? null : v;
      }
      out.push(obj);
    }
    return out;
  };

  util.readJsonScript = function (id) {
    var el = document.getElementById(id);
    if (!el) return null;
    try { return JSON.parse(el.textContent); } catch (e) { return null; }
  };

  util.storage = {
    get: function (k) { try { return global.localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { global.localStorage.setItem(k, v); } catch (e) { /* blocked */ } }
  };
  // Per-tab memory: survives reloads, forgotten when the browser session ends.
  util.session = {
    get: function (k) { try { return global.sessionStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { global.sessionStorage.setItem(k, v); } catch (e) { /* blocked */ } }
  };

  /* ------------------------------------------------------------------ i18n */
  var LANG_KEY = "aconteceR.lang";
  var i18n = AC.i18n = { dict: { en: {}, pt: {} }, lang: "en", _listeners: [] };

  i18n.normalize = function (x) {
    var s = String(x || "").toLowerCase();
    if (/^pt([-_].*)?$/.test(s)) return "pt";
    if (/^en([-_].*)?$/.test(s)) return "en";
    return null;
  };

  i18n.load = function (dict) {
    if (dict && dict.en) i18n.dict = dict;
    return i18n;
  };

  i18n.has = function (key) {
    var d = i18n.dict[i18n.lang] || {};
    return d[key] !== undefined || (i18n.dict.en || {})[key] !== undefined;
  };

  // Missing keys fall back to English, then to the key itself.
  i18n.t = function (key) {
    var d = i18n.dict[i18n.lang] || {};
    if (d[key] !== undefined) return d[key];
    var en = i18n.dict.en || {};
    return en[key] !== undefined ? en[key] : key;
  };

  i18n.tf = function (key) {
    var args = Array.prototype.slice.call(arguments, 1);
    return util.sprintf.apply(null, [i18n.t(key)].concat(args));
  };

  // Plural helper for the "_one" / "_many" key pairs.
  i18n.count = function (base, n) {
    return i18n.tf(base + (Number(n) === 1 ? "_one" : "_many"), n);
  };

  // The language to open with. In order:
  //   1. ?lang=pt|en in the URL (?lang=auto ignores a choice made earlier)
  //   2. the toggle, if the visitor used it in this browser session
  //   3. Portuguese anywhere in the browser's languages
  //   4. a Brazilian locale region (e.g. "en-BR") or a Brazilian time zone
  //   5. English anywhere in the browser's languages
  //   6. `fallback` (the server's default), else Portuguese
  // aconteceR lists events in Brazil, so any sign of Portuguese or of being in
  // Brazil opens it in PT-BR; the toggle is always one click away.
  i18n.signals = function () {
    var nav = global.navigator || {};
    var langs = (nav.languages && nav.languages.length ? nav.languages : [nav.language]).filter(Boolean);
    var intlLocale = null, tz = null;
    try { intlLocale = Intl.DateTimeFormat().resolvedOptions().locale; } catch (e) { /* no Intl */ }
    try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone; } catch (e2) { /* no Intl */ }
    return { languages: langs, locale: intlLocale, timeZone: tz };
  };

  i18n.detect = function (fallback, signals) {
    var sig = signals || i18n.signals();
    var param = null;
    try { param = new URLSearchParams(global.location.search).get("lang"); } catch (e) { /* old browser */ }
    var fromUrl = i18n.normalize(param);
    if (fromUrl) return { lang: fromUrl, source: "url" };
    if (param === "auto") util.session.set(LANG_KEY, "");
    var chosen = i18n.normalize(util.session.get(LANG_KEY));
    if (chosen) return { lang: chosen, source: "chosen" };
    var tags = sig.languages.concat(sig.locale ? [sig.locale] : []);
    var i;
    for (i = 0; i < sig.languages.length; i++) {
      if (i18n.normalize(sig.languages[i]) === "pt") return { lang: "pt", source: "language" };
    }
    for (i = 0; i < tags.length; i++) {
      if (/[-_]br$/i.test(String(tags[i]))) return { lang: "pt", source: "region" };
    }
    if (sig.timeZone && AC.geo && AC.geo.TIMEZONES[sig.timeZone]) return { lang: "pt", source: "timezone" };
    for (i = 0; i < sig.languages.length; i++) {
      if (i18n.normalize(sig.languages[i]) === "en") return { lang: "en", source: "language" };
    }
    return { lang: i18n.normalize(fallback) || "pt", source: "default" };
  };

  i18n.onChange = function (fn) { i18n._listeners.push(fn); };

  i18n.setLang = function (lang, opts) {
    opts = opts || {};
    var l = i18n.normalize(lang) || "en";
    var changed = l !== i18n.lang;
    i18n.lang = l;
    if (opts.persist) util.session.set(LANG_KEY, l);
    i18n.apply(document);
    if (AC.ui && AC.ui.greeting) AC.ui.greeting();
    if (changed || opts.force) {
      for (var i = 0; i < i18n._listeners.length; i++) {
        try { i18n._listeners[i](l); } catch (e) { if (global.console) console.error(e); }
      }
    }
    return l;
  };

  // Translate static markup:
  //   data-i18n="key"        text content
  //   data-i18n-ph="key"     placeholder (on the element or the first input inside)
  //   data-i18n-aria="key"   aria-label
  //   data-i18n-title="key"  title (tooltip)
  i18n.apply = function (root) {
    root = root || document;
    var each = function (sel, fn) {
      var els = root.querySelectorAll(sel);
      for (var i = 0; i < els.length; i++) fn(els[i]);
    };
    each("[data-i18n]", function (el) { el.textContent = i18n.t(el.getAttribute("data-i18n")); });
    each("[data-i18n-ph]", function (el) {
      var target = /^(INPUT|TEXTAREA)$/.test(el.tagName) ? el : el.querySelector("input, textarea");
      if (target) target.setAttribute("placeholder", i18n.t(el.getAttribute("data-i18n-ph")));
    });
    each("[data-i18n-aria]", function (el) { el.setAttribute("aria-label", i18n.t(el.getAttribute("data-i18n-aria"))); });
    each("[data-i18n-title]", function (el) { el.setAttribute("title", i18n.t(el.getAttribute("data-i18n-title"))); });
    each(".ac-lang-btn", function (el) {
      var on = i18n.normalize(el.getAttribute("data-lang")) === i18n.lang;
      el.classList.toggle("is-active", on);
      el.setAttribute("aria-pressed", on ? "true" : "false");
    });
    if (root === document) {
      document.documentElement.setAttribute("lang", i18n.t("html_lang"));
      var titled = document.querySelector("[data-i18n-doc-title]");
      if (titled) document.title = i18n.t(titled.getAttribute("data-i18n-doc-title"));
    }
  };

  /* ------------------------------------------------------------ formatting */
  var fmt = AC.fmt = {};
  var CURRENCY_SYMBOL = { BRL: "R$", USD: "US$", EUR: "\u20ac", GBP: "\u00a3" };

  fmt.number = function (x, digits) {
    var n = Number(x);
    if (!isFinite(n)) return "";
    digits = digits || 0;
    var parts = Math.abs(n).toFixed(digits).split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, i18n.t("big_mark"));
    return (n < 0 ? "-" : "") + parts.join(i18n.t("decimal_mark"));
  };

  fmt.money = function (amount, currency, digits) {
    var cur = String(currency || "BRL").toUpperCase();
    var sym = CURRENCY_SYMBOL[cur] || cur;
    return sym + " " + fmt.number(amount, digits === undefined ? 2 : digits);
  };

  fmt.price = function (priceType, price, currency) {
    if (priceType === "free") return i18n.t("price_free");
    if (priceType === "donation") return i18n.t("price_donation");
    if (priceType === "paid") {
      var p = price === null || price === undefined || price === "" ? NaN : Number(price);
      return isFinite(p) ? fmt.money(p, currency) : i18n.t("price_paid");
    }
    return i18n.t("price_unknown");
  };

  function capFirst(s) { s = String(s || ""); return s.charAt(0).toUpperCase() + s.slice(1); }
  fmt.capFirst = capFirst;

  // "Sáb, 05 dez · 20:00" / "Sat, 05 Dec · 20:00". Stored times are local
  // wall-clock text and are never shifted between time zones.
  fmt.when = function (startsAt) {
    var m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(startsAt || "");
    if (!m) return i18n.t("date_tbc");
    var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
    if (isNaN(d.getTime()) || d.getMonth() !== Number(m[2]) - 1) return i18n.t("date_tbc");
    return i18n.t("wd_short")[d.getDay()] + ", " + m[3] + " " + i18n.t("mon_short")[d.getMonth()] +
      " \u00b7 " + m[4] + ":" + m[5];
  };

  // "Sábado, 5 de dezembro" / "Saturday, 5 December"
  fmt.dayLong = function (iso) {
    var d = util.parseIsoDate(iso);
    if (!d) return "";
    return capFirst(util.sprintf(i18n.t("fmt_day_long"), i18n.t("wd_long")[d.getDay()], d.getDate(),
      i18n.t("mon_long")[d.getMonth()]));
  };

  // "Novembro de 2026" / "November 2026"
  fmt.monthTitle = function (year, monthIndex) {
    return capFirst(util.sprintf(i18n.t("cal_month_title"), i18n.t("mon_long")[monthIndex], year));
  };

  fmt.km = function (km) {
    return util.sprintf(i18n.t("geo_km"), fmt.number(km, km < 10 ? 1 : 0));
  };

  /* ----------------------------------------------------------------- theme
   * The look follows the visitor's clock: day (light) until golden hour, then
   * sunset, dusk and night (dark) from 19:00 until 06:00. The page always opens
   * in day and then walks through the phases to the current one, each phase
   * fading into the next (CSS transitions on the @property-registered colour
   * tokens), so there is never a hard cut. The toggle jumps to light or dark
   * through the same phases and is remembered for the browser session;
   * ?theme=light|dark|auto in the URL overrides it.                          */
  var THEME_KEY = "aconteceR.theme";
  var PHASES = ["day", "golden", "sunset", "dusk", "night"];
  var REDUCED = global.matchMedia && global.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var theme = AC.theme = { PHASES: PHASES, phase: null, _timer: null };

  // Phase for a clock time (local). Boundaries in minutes after midnight.
  theme.SCHEDULE = { dawn: 6 * 60, golden: 17 * 60 + 30, sunset: 18 * 60 + 15, dusk: 18 * 60 + 45, night: 19 * 60 };
  theme.phaseAt = function (date) {
    var d = date || new Date(), m = d.getHours() * 60 + d.getMinutes(), S = theme.SCHEDULE;
    if (m < S.dawn) return "night";
    if (m < S.golden) return "day";
    if (m < S.sunset) return "golden";
    if (m < S.dusk) return "sunset";
    if (m < S.night) return "dusk";
    return "night";
  };
  theme.isDark = function (phase) {
    var p = phase || theme.phase;
    return p === "dusk" || p === "night";
  };
  theme.current = function () { return theme.isDark() ? "dark" : "light"; };

  theme.choice = function () {
    var q = null;
    try { q = new URLSearchParams(global.location.search).get("theme"); } catch (e) { /* old browser */ }
    if (q === "auto") { util.session.set(THEME_KEY, ""); return null; }
    if (q === "light" || q === "dark") return q;
    var saved = util.session.get(THEME_KEY);
    return saved === "light" || saved === "dark" ? saved : null;
  };
  theme.target = function () {
    var c = theme.choice();
    return c ? (c === "dark" ? "night" : "day") : theme.phaseAt();
  };

  theme.apply = function (phase) {
    var root = document.documentElement, wasDark = theme.isDark();
    theme.phase = phase;
    root.setAttribute("data-phase", phase);
    root.setAttribute("data-theme", theme.isDark(phase) ? "dark" : "light");
    var btns = document.querySelectorAll(".ac-theme-toggle");
    for (var i = 0; i < btns.length; i++) btns[i].setAttribute("aria-pressed", theme.isDark(phase) ? "true" : "false");
    var detail = { phase: phase, dark: theme.isDark(phase), darkChanged: wasDark !== theme.isDark(phase) };
    var ev;
    try { ev = new CustomEvent("ac:theme", { detail: detail }); } catch (e) {
      ev = document.createEvent("CustomEvent");
      ev.initCustomEvent("ac:theme", false, false, detail);
    }
    document.dispatchEvent(ev);
  };

  // Step through the phases between the current one and `target`, holding
  // each for stepMs (also the length of each colour fade).
  theme.animateTo = function (target, opts) {
    opts = opts || {};
    clearTimeout(theme._timer);
    theme._timer = null;
    var from = PHASES.indexOf(theme.phase), to = PHASES.indexOf(target);
    if (to < 0 || from === to) return;
    if (REDUCED || from < 0) { theme.apply(target); return; }
    var ms = opts.stepMs || 900, dir = to > from ? 1 : -1, i = from;
    document.documentElement.style.setProperty("--ac-phase-ms", ms + "ms");
    (function next() {
      i += dir;
      theme.apply(PHASES[i]);
      theme._timer = i === to ? null : setTimeout(next, ms);
    })();
  };

  theme.toggle = function () {
    var next = theme.isDark() ? "light" : "dark";
    util.session.set(THEME_KEY, next);
    theme.animateTo(next === "dark" ? "night" : "day", { stepMs: 420 });
    return next;
  };

  theme.init = function () {
    var choice = theme.choice(), target = theme.target();
    if (choice || REDUCED) {
      theme.apply(target);
    } else {
      theme.apply("day");
      if (target !== "day") {
        setTimeout(function () { theme.animateTo(target, { stepMs: 950 }); }, 650);
      }
    }
    // Follow the clock while the page stays open (slow, gentle fades).
    setInterval(function () {
      if (theme.choice() || theme._timer) return;
      var t = theme.phaseAt();
      if (t !== theme.phase) theme.animateTo(t, { stepMs: 4000 });
    }, 60 * 1000);
  };
  // Open in day as early as possible (this script loads in <head>).
  theme.init();
  document.addEventListener("DOMContentLoaded", function () { theme.apply(theme.phase); });

  /* ------------------------------------------------------------------- geo */
  var geo = AC.geo = {};

  // Rough position for each Brazilian IANA time zone (its main city). Used as
  // an instant, permission-free first guess before the browser geolocation
  // answers (or when it is denied or unavailable).
  geo.TIMEZONES = {
    "America/Sao_Paulo": [-23.5505, -46.6333], "Brazil/East": [-23.5505, -46.6333],
    "America/Bahia": [-12.9777, -38.5016], "America/Fortaleza": [-3.7319, -38.5267],
    "America/Recife": [-8.0476, -34.877], "America/Maceio": [-9.6498, -35.7089],
    "America/Belem": [-1.4558, -48.5044], "America/Araguaina": [-7.1912, -48.2072],
    "America/Santarem": [-2.4385, -54.6996], "America/Manaus": [-3.119, -60.0217],
    "Brazil/West": [-3.119, -60.0217], "America/Cuiaba": [-15.601, -56.0974],
    "America/Campo_Grande": [-20.4697, -54.6201], "America/Porto_Velho": [-8.7612, -63.9004],
    "America/Boa_Vista": [2.8235, -60.6758], "America/Rio_Branco": [-9.9747, -67.8243],
    "Brazil/Acre": [-9.9747, -67.8243], "America/Eirunepe": [-6.6596, -69.8737],
    "America/Noronha": [-3.8547, -32.4247], "Brazil/DeNoronha": [-3.8547, -32.4247]
  };

  geo.timezone = function () {
    try { return Intl.DateTimeFormat().resolvedOptions().timeZone || null; } catch (e) { return null; }
  };

  geo.fromTimezone = function (tz) {
    var p = geo.TIMEZONES[tz || geo.timezone()];
    return p ? { lat: p[0], lon: p[1], source: "timezone" } : null;
  };

  geo.haversineKm = function (lat1, lon1, lat2, lon2) {
    var R = 6371, rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad, dLon = (lon2 - lon1) * rad;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
  };

  // places: [{id, lat, lon, ...}] -> {place, km} or null
  geo.nearest = function (places, lat, lon) {
    var best = null, bestKm = Infinity;
    for (var i = 0; i < places.length; i++) {
      var km = geo.haversineKm(lat, lon, Number(places[i].lat), Number(places[i].lon));
      if (km < bestKm) { bestKm = km; best = places[i]; }
    }
    return best ? { place: best, km: bestKm } : null;
  };

  // Browser geolocation. Calls back with {lat, lon, accuracy, source: "gps"}
  // or with null when unsupported, denied, insecure or timed out. Does not
  // prompt again when the permission is already denied.
  geo.locate = function (cb, opts) {
    opts = opts || {};
    var nav = global.navigator;
    if (!nav || !nav.geolocation || global.isSecureContext === false) { cb(null, "unsupported"); return; }
    var ask = function () {
      nav.geolocation.getCurrentPosition(function (pos) {
        cb({ lat: pos.coords.latitude, lon: pos.coords.longitude, accuracy: pos.coords.accuracy, source: "gps" });
      }, function (err) {
        cb(null, err && err.code === 1 ? "denied" : "failed");
      }, { enableHighAccuracy: false, timeout: opts.timeout || 10000, maximumAge: 10 * 60 * 1000 });
    };
    if (opts.skipIfDenied && nav.permissions && nav.permissions.query) {
      nav.permissions.query({ name: "geolocation" }).then(function (st) {
        if (st.state === "denied") cb(null, "denied"); else ask();
      }, ask);
    } else {
      ask();
    }
  };

  /* ----------------------------------------------------------- colour modes
   * A colour mode tells the map and calendar how to colour an item:
   *   {id, label, title, type: "factor", column,
   *    levels: [{key, color, label}], na_color, na_label}
   *   {id, label, title, type: "bins", column,
   *    breaks: [b0, b1, ..., bn], colors: [n], labels: [n], na_color, na_label}
   * Bins are right-closed like R's cut(): (b0, b1], (b1, b2], ... and the first
   * bin also includes b0.                                                     */
  var color = AC.color = {};
  var NA_COLOR = "#8c8c8c";

  color.normalize = function (spec) {
    if (!spec) return null;
    var s = {};
    for (var k in spec) if (Object.prototype.hasOwnProperty.call(spec, k)) s[k] = spec[k];
    s.na_color = s.na_color || NA_COLOR;
    s.na_label = s.na_label || "NA";
    if (s.type === "bins") {
      s.breaks = util.asArray(s.breaks).map(Number);
      s.colors = util.asArray(s.colors);
      s.labels = util.asArray(s.labels);
    } else {
      s.type = "factor";
      s.levels = util.asArray(s.levels);
    }
    return s;
  };

  color.resolve = function (spec, item) {
    if (!spec) return { key: "_na", color: NA_COLOR, label: "" };
    var v = item ? item[spec.column] : null;
    if (spec.type === "bins") {
      var x = v === null || v === undefined || v === "" ? NaN : Number(v);
      var b = spec.breaks;
      if (isFinite(x) && b.length > 1 && x >= b[0]) {
        for (var i = 0; i < b.length - 1; i++) {
          if (x <= b[i + 1]) return { key: "bin" + i, color: spec.colors[i], label: spec.labels[i] || "" };
        }
      }
      return { key: "_na", color: spec.na_color, label: spec.na_label };
    }
    var key = v === null || v === undefined ? null : String(v);
    for (var j = 0; j < spec.levels.length; j++) {
      if (String(spec.levels[j].key) === key) return spec.levels[j];
    }
    return { key: "_na", color: spec.na_color, label: spec.na_label };
  };

  // Legend rows for the levels present in `items`, in the spec's order.
  color.legend = function (spec, items) {
    if (!spec) return [];
    var counts = {};
    for (var i = 0; i < items.length; i++) {
      var r = color.resolve(spec, items[i]);
      counts[r.key] = (counts[r.key] || 0) + 1;
    }
    var rows = [];
    if (spec.type === "bins") {
      for (var b = 0; b < spec.colors.length; b++) {
        if (counts["bin" + b]) rows.push({ key: "bin" + b, color: spec.colors[b], label: spec.labels[b], count: counts["bin" + b] });
      }
    } else {
      for (var l = 0; l < spec.levels.length; l++) {
        var lv = spec.levels[l];
        if (counts[lv.key]) rows.push({ key: lv.key, color: lv.color, label: lv.label, count: counts[lv.key] });
      }
    }
    if (counts._na) rows.push({ key: "_na", color: spec.na_color, label: spec.na_label, count: counts._na });
    return rows;
  };

  // One colour for a group of items: the most common level (factor) or the
  // bin of the median value (bins). -> {key, color, label, count}
  color.summary = function (spec, items) {
    if (!spec || !items.length) return { key: "_na", color: NA_COLOR, label: "", count: 0 };
    if (spec.type === "bins") {
      var xs = [];
      for (var i = 0; i < items.length; i++) {
        var v = items[i][spec.column];
        var x = v === null || v === undefined || v === "" ? NaN : Number(v);
        if (isFinite(x)) xs.push(x);
      }
      if (!xs.length) return { key: "_na", color: spec.na_color, label: spec.na_label, count: items.length };
      xs.sort(function (a, b) { return a - b; });
      var mid = xs.length % 2 ? xs[(xs.length - 1) / 2] : (xs[xs.length / 2 - 1] + xs[xs.length / 2]) / 2;
      var probe = {};
      probe[spec.column] = mid;
      var r = color.resolve(spec, probe);
      return { key: r.key, color: r.color, label: r.label, count: xs.length, value: mid };
    }
    var rows = color.legend(spec, items), best = null;
    for (var j = 0; j < rows.length; j++) {
      if (rows[j].key === "_na" && rows.length > 1) continue;
      if (!best || rows[j].count > best.count) best = rows[j];
    }
    return best || { key: "_na", color: spec.na_color, label: spec.na_label, count: 0 };
  };

  /* ------------------------------------------------------------------ icons
   * Hand-drawn 20x20 line icons (stroke = currentColor).                    */
  var svg = function (body) {
    return '<svg class="ac-icon" viewBox="0 0 20 20" width="16" height="16" aria-hidden="true" focusable="false" ' +
      'fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + body + "</svg>";
  };
  AC.icons = {
    locate: svg('<circle cx="10" cy="10" r="5.5"/><circle cx="10" cy="10" r="1.6" fill="currentColor"/><path d="M10 1.5v3M10 15.5v3M1.5 10h3M15.5 10h3"/>'),
    fit: svg('<path d="M3 7V3h4M13 3h4v4M17 13v4h-4M7 17H3v-4"/><circle cx="10" cy="10" r="2"/>'),
    reset: svg('<path d="M10 17.5s-5.5-5-5.5-9a5.5 5.5 0 0 1 11 0c0 4-5.5 9-5.5 9z"/><circle cx="10" cy="8.5" r="2"/>'),
    map: svg('<path d="M2.5 5l5-2 5 2 5-2v12l-5 2-5-2-5 2z"/><path d="M7.5 3v12M12.5 5v12"/>'),
    calendar: svg('<rect x="2.5" y="4" width="15" height="13.5" rx="2"/><path d="M2.5 8h15M6.5 2v4M13.5 2v4"/>'),
    chevronLeft: svg('<path d="M12.5 4.5L7 10l5.5 5.5"/>'),
    chevronRight: svg('<path d="M7.5 4.5L13 10l-5.5 5.5"/>'),
    close: svg('<path d="M5 5l10 10M15 5L5 15"/>'),
    sun: svg('<circle cx="10" cy="10" r="3.5"/><path d="M10 1.5v2M10 16.5v2M1.5 10h2M16.5 10h2M4 4l1.4 1.4M14.6 14.6L16 16M4 16l1.4-1.4M14.6 5.4L16 4"/>'),
    moon: svg('<path d="M16.5 12.5A7 7 0 0 1 7.5 3.5a7 7 0 1 0 9 9z"/>'),
    layers: svg('<path d="M10 2.5l7.5 4-7.5 4-7.5-4z"/><path d="M2.5 10.5l7.5 4 7.5-4"/>'),
    search: svg('<circle cx="9" cy="9" r="5.5"/><path d="M13 13l4.5 4.5"/>'),
    plus: svg('<path d="M10 4v12M4 10h12"/>'),
    back: svg('<path d="M11.5 4.5L6 10l5.5 5.5M6.5 10H17"/>'),
    pin: svg('<path d="M10 18s-6-5.4-6-10a6 6 0 0 1 12 0c0 4.6-6 10-6 10z"/><circle cx="10" cy="8" r="2.2"/>'),
    external: svg('<path d="M8 4H4.5v11.5H16V12"/><path d="M11 3.5h5.5V9M16.5 3.5L9 11"/>'),
    inbox: svg('<path d="M3 11l2.2-6.5h9.6L17 11v5H3z"/><path d="M3 11h4l1 2h4l1-2h4"/>'),
    // Category glyphs (drawn on the gradient tiles)
    cat_music: svg('<path d="M7.5 15.5V5l9-2v10.5"/><circle cx="5.5" cy="15.5" r="2"/><circle cx="14.5" cy="13.5" r="2"/>'),
    cat_food: svg('<path d="M5 2.5v6a2 2 0 0 0 2 2v7M9 2.5v6a2 2 0 0 1-2 2M7 2.5v5"/><path d="M14.5 17.5v-15c-2 1-3 3.5-3 6.5 0 1.5.8 2.5 3 2.5"/>'),
    cat_arts: svg('<path d="M10 2.5a7.5 7.5 0 1 0 0 15c1.3 0 1.8-1 1.3-2-.6-1.2.2-2.5 1.6-2.5H15a2.5 2.5 0 0 0 2.5-2.5c0-4.4-3.4-8-7.5-8z"/><circle cx="6.5" cy="9" r="1" fill="currentColor"/><circle cx="9" cy="6" r="1" fill="currentColor"/><circle cx="13" cy="6.5" r="1" fill="currentColor"/>'),
    cat_sports: svg('<circle cx="10" cy="10" r="7.5"/><path d="M10 6.5l3.3 2.4-1.3 3.9H8l-1.3-3.9z"/><path d="M10 2.5v4M16.9 8l-3.6.9M14.5 16l-2.5-3.2M5.5 16L8 12.8M3.1 8l3.6.9"/>'),
    cat_tech: svg('<rect x="3" y="4" width="14" height="10" rx="1.5"/><path d="M7 17.5h6M10 14v3.5M8 7.5L6 9l2 1.5M12 7.5L14 9l-2 1.5"/>'),
    cat_community: svg('<circle cx="7" cy="7" r="2.5"/><circle cx="14" cy="8" r="2"/><path d="M2.5 16.5c0-2.8 2-4.5 4.5-4.5s4.5 1.7 4.5 4.5M11.5 12.3c.7-.4 1.5-.6 2.5-.6 2 0 3.5 1.4 3.5 3.8"/>'),
    cat_other: svg('<path d="M10 2.5l1.8 4.7 4.7 1.8-4.7 1.8L10 15.5l-1.8-4.7L3.5 9l4.7-1.8z"/><path d="M16 14l.7 1.8 1.8.7-1.8.7L16 19l-.7-1.8-1.8-.7 1.8-.7z"/>'),
    // Place categories
    pcat_bar: svg('<path d="M3.5 3.5h13L10 11z"/><path d="M10 11v6.5M6.5 17.5h7M13 3.5l2-1.5"/>'),
    pcat_pub: svg('<rect x="4" y="6" width="9" height="11.5" rx="1.5"/><path d="M13 9h1.8a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H13M4 6.5c0-2 2-3.5 4.5-3.5S13 4.5 13 6.5M7 10v4.5M10 10v4.5"/>'),
    pcat_nightclub: svg('<circle cx="10" cy="11" r="6"/><path d="M10 1.5V5M4 11h12M10 5c-2.4 2-2.4 10 0 12M10 5c2.4 2 2.4 10 0 12M5.5 7.5h9M5.5 14.5h9"/>'),
    pcat_restaurant: svg('<path d="M5 2.5v6a2 2 0 0 0 2 2v7M9 2.5v6a2 2 0 0 1-2 2M7 2.5v5"/><path d="M14.5 17.5v-15c-2 1-3 3.5-3 6.5 0 1.5.8 2.5 3 2.5"/>'),
    pcat_club: svg('<ellipse cx="10" cy="6.5" rx="6.5" ry="2.5"/><path d="M3.5 6.5v7c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5v-7M6 15.5l2-6.5M14 15.5l-2-6.5"/>'),
    pcat_concert_house: svg('<rect x="7.5" y="2.5" width="5" height="9" rx="2.5"/><path d="M4.5 9.5a5.5 5.5 0 0 0 11 0M10 15v3M7 18h6"/>'),
    pcat_cafe_bistro: svg('<path d="M4 8h10v4a5 5 0 0 1-10 0z"/><path d="M14 9h1.5a2 2 0 0 1 0 4H14M7 2.5c-.7 1 .7 2 0 3M10.5 2.5c-.7 1 .7 2 0 3"/>'),
    pcat_gastrobar: svg('<path d="M5.5 2.5h7c0 4-1.3 6.5-3.5 6.5S5.5 6.5 5.5 2.5zM9 9v8M6 17.5h6"/><path d="M15.5 2.5v15M14 2.5v4a1.5 1.5 0 0 0 3 0v-4"/>'),
    pcat_cultural_spot: svg('<path d="M3 8l7-5 7 5M4 8h12M5.5 8v7M8.5 8v7M11.5 8v7M14.5 8v7M3 17.5h14"/>'),
    pcat_rooftop_lounge: svg('<path d="M2.5 17.5h15M4 17.5V10h4v7.5M8 17.5V7h4v10.5M12 17.5V11h4v6.5"/><circle cx="15.5" cy="4.5" r="2"/>'),
    // Quiz options and small marks
    heart: svg('<path d="M10 16.5s-6.5-4-6.5-8.5A3.5 3.5 0 0 1 10 6a3.5 3.5 0 0 1 6.5 2c0 4.5-6.5 8.5-6.5 8.5z"/>'),
    person: svg('<circle cx="10" cy="6" r="3"/><path d="M4 17.5c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5"/>'),
    home: svg('<path d="M3 9l7-6 7 6v8.5H3z"/><path d="M8 17.5v-5h4v5"/>'),
    bolt: svg('<path d="M11 2.5L4.5 11H10l-1 6.5L15.5 9H10z"/>'),
    star: svg('<path d="M10 2.5l2.3 4.8 5.2.7-3.8 3.6.9 5.2L10 14.3l-4.6 2.5.9-5.2L2.5 8l5.2-.7z"/>'),
    sparkles: svg('<path d="M8 2.5l1.5 4 4 1.5-4 1.5-1.5 4-1.5-4-4-1.5 4-1.5z"/><path d="M15 11l.8 2.2 2.2.8-2.2.8L15 17l-.8-2.2-2.2-.8 2.2-.8z"/>'),
    walk: svg('<circle cx="11" cy="3.5" r="1.5"/><path d="M8.5 17.5l2.2-5.5-2.4-2.2 1-4.3 3.2 2.8 2.5.6M8.3 5.8L5.8 8.5v3M10.7 12l2.3 5.5"/>'),
    car: svg('<path d="M3 13.5v-3.2l2-4.8h10l2 4.8v3.2z"/><path d="M3 10.3h14"/><circle cx="6.3" cy="14.5" r="1.6"/><circle cx="13.7" cy="14.5" r="1.6"/>'),
    route: svg('<circle cx="5" cy="15" r="2"/><circle cx="15" cy="5" r="2"/><path d="M7 15h5.5a2.5 2.5 0 0 0 0-5h-5a2.5 2.5 0 0 1 0-5H13"/>'),
    hood: svg('<path d="M2.5 17.5h15"/><path d="M4 17.5V9l4-3 4 3v8.5"/><path d="M12 17.5V6.5l4 2.5v8.5"/><path d="M7 17.5v-3h2v3"/>'),
    clock: svg('<circle cx="10" cy="10" r="7.5"/><path d="M10 5.5V10l3 2"/>')
  };

  /* --------------------------------------------------------------------- ui */
  var ui = AC.ui = {};

  // A single polite live-region toast shared by every component.
  ui.toast = function (message, opts) {
    opts = opts || {};
    var el = document.getElementById("ac-toast");
    if (!el) {
      el = document.createElement("div");
      el.id = "ac-toast";
      el.className = "ac-toast";
      el.setAttribute("role", "status");
      el.setAttribute("aria-live", "polite");
      document.body.appendChild(el);
    }
    el.className = "ac-toast is-visible" + (opts.kind ? " is-" + opts.kind : "");
    el.textContent = message;
    clearTimeout(ui.toast._timer);
    ui.toast._timer = setTimeout(function () { el.className = "ac-toast"; }, opts.timeout || 5000);
  };

  // Segmented control markup: [{value, label, icon?, i18n?}]
  ui.segmentedHtml = function (name, options, active, ariaKey) {
    var html = '<div class="ac-seg" role="group" data-seg="' + util.escapeHtml(name) + '"' +
      (ariaKey ? ' data-i18n-aria="' + util.escapeHtml(ariaKey) + '"' : "") + ">";
    for (var i = 0; i < options.length; i++) {
      var o = options[i];
      var on = String(o.value) === String(active);
      html += '<button type="button" class="ac-seg-btn' + (on ? " is-active" : "") + '" data-value="' +
        util.escapeHtml(o.value) + '" aria-pressed="' + (on ? "true" : "false") + '">' +
        (o.icon || "") + "<span" + (o.i18n ? ' data-i18n="' + util.escapeHtml(o.i18n) + '"' : "") + ">" +
        util.escapeHtml(o.label) + "</span></button>";
    }
    return html + "</div>";
  };

  ui.setSegmented = function (seg, value) {
    if (!seg) return;
    var btns = seg.querySelectorAll(".ac-seg-btn");
    for (var i = 0; i < btns.length; i++) {
      var on = btns[i].getAttribute("data-value") === String(value);
      btns[i].classList.toggle("is-active", on);
      btns[i].setAttribute("aria-pressed", on ? "true" : "false");
    }
  };

  // Fill <span data-ac-icon="map"></span> placeholders with the SVG icons.
  ui.icons = function (root) {
    var els = (root || document).querySelectorAll("[data-ac-icon]");
    for (var i = 0; i < els.length; i++) {
      var svgHtml = AC.icons[els[i].getAttribute("data-ac-icon")];
      if (svgHtml && !els[i].firstChild) els[i].innerHTML = svgHtml;
    }
  };

  // View switch: <div class="ac-seg ac-view-switch" data-target="ID"> with
  // .ac-seg-btn[data-value] buttons. Sets data-view on the target element and
  // fires a bubbling "ac:view" event ({value, source}) on the switch.
  ui.setView = function (sw, value, source) {
    if (!sw) return;
    var target = document.getElementById(sw.getAttribute("data-target"));
    if (target) target.setAttribute("data-view", value);
    ui.setSegmented(sw, value);
    var ev;
    try {
      ev = new CustomEvent("ac:view", { bubbles: true, detail: { value: value, source: source || "api" } });
    } catch (e) {
      ev = document.createEvent("CustomEvent");
      ev.initCustomEvent("ac:view", true, false, { value: value, source: source || "api" });
    }
    sw.dispatchEvent(ev);
  };

  function fire(el, name, detail) {
    var ev;
    try {
      ev = new CustomEvent(name, { bubbles: true, detail: detail });
    } catch (e) {
      ev = document.createEvent("CustomEvent");
      ev.initCustomEvent(name, true, false, detail);
    }
    el.dispatchEvent(ev);
  }
  ui.fire = fire;

  /* Chip sets: the filter pills.
   *   <div class="ac-chipset" data-mode="single|multi" data-default="all">
   *     <button class="ac-chip" data-value="today">...</button> ...
   * single: exactly one chip is on; multi: any number (none = no filter).
   * A single set can hold one removable "custom" chip (e.g. a date range
   * picked on the calendar). Fires a bubbling "ac:chips" event {value}.   */
  var chips = AC.chips = {};
  chips.value = function (set) {
    var on = set.querySelectorAll(".ac-chip.is-on");
    var vals = Array.prototype.map.call(on, function (c) { return c.getAttribute("data-value"); });
    return set.getAttribute("data-mode") === "multi" ? vals : (vals[0] || set.getAttribute("data-default") || null);
  };
  chips.set = function (set, value, o) {
    var want = util.asArray(value).map(String);
    var custom = set.querySelector('.ac-chip[data-value="custom"]');
    if (custom && set.getAttribute("data-mode") !== "multi" && want.indexOf("custom") === -1) {
      custom.parentNode.removeChild(custom);
    }
    var btns = set.querySelectorAll(".ac-chip");
    for (var i = 0; i < btns.length; i++) {
      var on = want.indexOf(btns[i].getAttribute("data-value")) !== -1;
      btns[i].classList.toggle("is-on", on);
      btns[i].setAttribute("aria-pressed", on ? "true" : "false");
    }
    if (!(o && o.silent)) fire(set, "ac:chips", { value: chips.value(set), source: (o && o.source) || "api" });
  };
  // Add (or relabel) the removable custom chip and select it.
  chips.custom = function (set, label, o) {
    var c = set.querySelector('.ac-chip[data-value="custom"]');
    if (!c) {
      c = document.createElement("button");
      c.type = "button";
      c.className = "ac-chip ac-chip-custom";
      c.setAttribute("data-value", "custom");
      set.appendChild(c);
    }
    c.innerHTML = "<span>" + util.escapeHtml(label) + '</span><span class="ac-chip-x" data-chip-remove aria-hidden="true">\u00d7</span>';
    c.setAttribute("aria-label", label);
    chips.set(set, "custom", o);
  };
  chips.removeCustom = function (set, o) {
    var c = set.querySelector('.ac-chip[data-value="custom"]');
    if (c) c.parentNode.removeChild(c);
    if (!set.querySelector(".ac-chip.is-on")) chips.set(set, set.getAttribute("data-default"), o);
  };

  /* Panes: <div data-panes="list"> with children [data-pane="list|add|..."];
   * buttons [data-open-pane="add"] switch them. Fires "ac:pane" {value}. */
  ui.openPane = function (name, host) {
    host = host || document.querySelector("[data-panes]");
    if (!host) return;
    host.setAttribute("data-panes", name);
    var panes = host.querySelectorAll("[data-pane]");
    for (var i = 0; i < panes.length; i++) {
      var on = panes[i].getAttribute("data-pane") === name;
      panes[i].hidden = !on;
      if (on) panes[i].scrollTop = 0;
    }
    var openers = document.querySelectorAll("[data-open-pane]");
    for (var j = 0; j < openers.length; j++) {
      openers[j].classList.toggle("is-on", openers[j].getAttribute("data-open-pane") === name && name !== "list");
    }
    fire(host, "ac:pane", { value: name });
  };

  // A chip set with data-app-mode switches the page between modes (events /
  // places): sets data-mode on .ac-app; the calendar is for events only.
  document.addEventListener("ac:chips", function (e) {
    var set = e.target;
    if (!set.hasAttribute || !set.hasAttribute("data-app-mode")) return;
    var app = document.querySelector(".ac-app");
    if (app) app.setAttribute("data-mode", e.detail.value);
    var sw = document.querySelector(".ac-view-switch");
    if (sw && e.detail.value !== "events") ui.setView(sw, "map", "app");
  });

  // "Bom dia" / "Boa tarde" / "Boa noite" by the visitor's clock.
  ui.greeting = function () {
    var h = new Date().getHours();
    var key = h >= 5 && h < 12 ? "greet_morning" : h >= 12 && h < 18 ? "greet_afternoon" : "greet_evening";
    var els = document.querySelectorAll("[data-ac-greeting]");
    for (var i = 0; i < els.length; i++) els[i].textContent = AC.i18n.t(key);
  };

  // Delegated handlers, so they work for markup rendered at any time.
  document.addEventListener("click", function (ev) {
    if (!ev.target.closest) return;
    if (ev.target.closest(".ac-theme-toggle")) { theme.toggle(); return; }
    var b = ev.target.closest(".ac-view-switch .ac-seg-btn");
    if (b) { ui.setView(b.closest(".ac-view-switch"), b.getAttribute("data-value"), "user"); return; }
    var pane = ev.target.closest("[data-open-pane]");
    if (pane) {
      var name = pane.getAttribute("data-open-pane");
      var host = document.querySelector("[data-panes]");
      ui.openPane(host && host.getAttribute("data-panes") === name ? "list" : name, host);
      return;
    }
    var chip = ev.target.closest(".ac-chipset .ac-chip");
    if (chip) {
      var set = chip.closest(".ac-chipset");
      var v = chip.getAttribute("data-value");
      if (ev.target.closest("[data-chip-remove]")) { chips.removeCustom(set, { source: "user" }); return; }
      if (set.getAttribute("data-mode") === "multi") {
        var cur = chips.value(set);
        var k = cur.indexOf(v);
        if (k === -1) cur.push(v); else cur.splice(k, 1);
        chips.set(set, cur, { source: "user" });
      } else if (chips.value(set) !== v) {
        chips.set(set, v, { source: "user" });
      }
    }
  });
})(window);
