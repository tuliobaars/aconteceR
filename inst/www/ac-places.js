/*! aconteceR places (MIT licence). Pure logic shared by the Shiny app and the
 * standalone HTML, mirrored in R/places.R:
 *   - vibe classification from keyword rules (inst/extdata/vibes.csv)
 *   - opening hours: OpenStreetMap opening_hours, or opens_at / closes_at /
 *     open_days ("Ter-Dom"); overnight hours; open / closed text; open late
 *   - ranking for "Can't decide?" (places and events together)
 *   - plan my night (dinner -> drinks or a show -> dancing) and
 *     "before & after" an event
 * The visitor's clock drives everything, so it runs in the browser.        */
(function (global) {
  "use strict";
  var AC = global.AC, util = AC.util;
  var P = AC.places = {};

  P.CATEGORIES = ["bar", "pub", "nightclub", "restaurant", "club", "concert_house",
                  "cafe_bistro", "gastrobar", "cultural_spot", "rooftop_lounge"];
  P.VIBES = ["chill", "romantic", "party", "live_music", "dance", "casual",
             "upscale", "outdoor", "alternative", "culture", "friends", "family"];

  /* ------------------------------------------------------------------ vibes
   * Text is accent-folded, lower-cased and every run of other characters
   * becomes "-". A pattern matches at the start of a word ("cultur" matches
   * "cultural"); a trailing "$" asks for the whole word ("arte$" does not
   * match "artesanal"). "@category" tokens carry category defaults.          */
  P.vibeText = function (text) {
    return "-" + util.normalizeText(text).replace(/[^a-z0-9@_]+/g, "-").replace(/^-+|-+$/g, "") + "-";
  };

  P.compileRules = function (rows) {
    return util.asArray(rows).map(function (r) {
      var p = String(r.pattern);
      var whole = /\$$/.test(p);
      return { vibe: r.vibe, needle: "-" + (whole ? p.slice(0, -1) + "-" : p) };
    });
  };

  // -> vibe keys in P.VIBES order
  P.classify = function (text, rules) {
    var t = P.vibeText(text), hit = {};
    for (var i = 0; i < rules.length; i++) if (t.indexOf(rules[i].needle) !== -1) hit[rules[i].vibe] = true;
    return P.VIBES.filter(function (v) { return hit[v]; });
  };

  P.placeVibes = function (place, rules) { return P.classify(place.vibes + " @" + place.category, rules); };
  P.eventVibes = function (ev, rules) {
    return P.classify([ev.title, ev.description, "@event_" + ev.category].join(" "), rules);
  };

  /* ------------------------------------------------------------------ hours
   * A place's week is read from `opening_hours` (OpenStreetMap syntax) when
   * present, else from opens_at / closes_at / open_days. A schedule is
   * {days: [[{o, c}], ...7 (Sunday first)], always} with minutes after
   * midnight; c > 1440 runs past midnight. null means "hours not listed".
   * Mirrors parse_opening_hours() in R/places.R.                            */
  var DAYS = ["dom", "seg", "ter", "qua", "qui", "sex", "sab"];
  var DAYMAP = { su: 0, mo: 1, tu: 2, we: 3, th: 4, fr: 5, sa: 6,
                 dom: 0, seg: 1, ter: 2, qua: 3, qui: 4, sex: 5, sab: 6 };

  // "Ter-Dom", "Qui-Sáb", "Seg,Qua,Sex", "Todos" -> 7 booleans, Sunday first
  P.parseDays = function (str) {
    var out = [false, false, false, false, false, false, false];
    util.normalizeText(str || "").split(/[,;/ ]+/).forEach(function (part) {
      if (!part) return;
      if (/^(todos|diario|todos-os-dias)$/.test(part)) { out = out.map(function () { return true; }); return; }
      var ends = part.split("-");
      var a = DAYS.indexOf(ends[0].slice(0, 3)), b = DAYS.indexOf(ends[ends.length - 1].slice(0, 3));
      if (a < 0 || b < 0) return;
      for (var d = a; ; d = (d + 1) % 7) { out[d] = true; if (d === b) break; }
    });
    return out;
  };

  P.minutes = function (hhmm) {
    var m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm || "").trim());
    return m ? Number(m[1]) * 60 + Number(m[2]) : NaN;
  };
  P.hhmm = function (mins) {
    var m = ((mins % 1440) + 1440) % 1440;
    return util.pad2(Math.floor(m / 60)) + ":" + util.pad2(m % 60);
  };

  function dayList(sel) {
    var out = [];
    var parts = sel.split(/\s*,\s*/);
    for (var i = 0; i < parts.length; i++) {
      var ends = parts[i].split(/\s*-\s*/);
      var a = DAYMAP[ends[0]], b = DAYMAP[ends[ends.length - 1]];
      if (a === undefined || b === undefined || ends.length > 2) return null;
      for (var d = a; ; d = (d + 1) % 7) { if (out.indexOf(d) < 0) out.push(d); if (d === b) break; }
    }
    return out;
  }

  function timeList(str) {
    var out = [], parts = str.split(/\s*,\s*/);
    for (var i = 0; i < parts.length; i++) {
      var m = /^(\d{1,2}):(\d{2})\s*(?:-\s*(\d{1,2}):(\d{2})|(\+))$/.exec(parts[i]);
      if (!m) return null;
      var o = Number(m[1]) * 60 + Number(m[2]);
      var c = m[5] ? o + 240 : Number(m[3]) * 60 + Number(m[4]);
      if (o >= 1440 || c > 48 * 60) return null;
      if (c <= o) c += 1440;
      out.push({ o: o, c: c });
    }
    return out;
  }

  // OpenStreetMap opening_hours -> schedule (common syntax; rules with month,
  // week, holiday or sun-based selectors are skipped; nothing usable -> null).
  P.parseOSM = function (str) {
    var s = util.normalizeText(str || "").replace(/"[^"]*"/g, " ").trim()
      .replace(/(\d)\s*,\s*(?=[a-z])/g, "$1;");  // "09:00-18:00, Sa ..." starts a new rule
    if (!s) return null;
    if (/^24\/7$/.test(s)) return { always: true, days: [0, 1, 2, 3, 4, 5, 6].map(function () { return [{ o: 0, c: 1440 }]; }) };
    var days = [[], [], [], [], [], [], []], used = false;
    s.split(/\s*(?:;|\|\|)\s*/).forEach(function (rule) {
      rule = rule.trim();
      if (!rule) return;
      if (/^(ph|sh)\b/.test(rule) || /\b(jan|feb|fev|mar|apr|abr|may|mai|jun|jul|aug|ago|sep|set|oct|out|nov|dec|dez|week|sunrise|sunset|dawn|dusk|easter)\b/.test(rule)) return;
      if (rule === "24/7") { days = days.map(function () { return [{ o: 0, c: 1440 }]; }); used = true; return; }
      var m = /^([a-z]{2,3}(?:\s*-\s*[a-z]{2,3})?(?:\s*,\s*[a-z]{2,3}(?:\s*-\s*[a-z]{2,3})?)*)\s*:?\s*(.*)$/.exec(rule);
      var sel = m ? dayList(m[1]) : null;
      var rest = sel ? m[2].trim() : rule;
      if (!sel) sel = [0, 1, 2, 3, 4, 5, 6];
      if (/^(off|closed|fechado)$/.test(rest)) { sel.forEach(function (d) { days[d] = []; }); used = true; return; }
      var times = rest ? timeList(rest) : null;
      if (!times) return;
      sel.forEach(function (d) { days[d] = times.slice(); });
      used = true;
    });
    return used ? { always: false, days: days } : null;
  };

  P.schedule = function (place) {
    if (place._sch !== undefined) return place._sch;
    var sch = null;
    if (place.opening_hours) {
      sch = P.parseOSM(place.opening_hours);
    } else {
      var o = P.minutes(place.opens_at), c = P.minutes(place.closes_at);
      if (isFinite(o) && isFinite(c)) {
        var open = P.parseDays(place.open_days);
        var iv = { o: o, c: c <= o ? c + 1440 : c };
        sch = { always: false, days: open.map(function (on) { return on ? [iv] : []; }) };
      }
    }
    try { Object.defineProperty(place, "_sch", { value: sch, enumerable: false, writable: true }); } catch (e) { /* frozen */ }
    return sch;
  };

  // Status at `date` (local time):
  //   {open, unknown, always, toClose, toOpen, daysAhead, opensAt, closesAt}
  P.status = function (place, date) {
    var st = { open: false, unknown: false, always: false, toClose: null, toOpen: null, daysAhead: null, opensAt: null, closesAt: null };
    var sch = P.schedule(place);
    if (!sch) { st.unknown = true; return st; }
    if (sch.always) { st.open = true; st.always = true; st.toClose = Infinity; return st; }
    var wd = date.getDay(), m = date.getHours() * 60 + date.getMinutes(), i, iv;
    var today = sch.days[wd], yest = sch.days[(wd + 6) % 7];
    for (i = 0; i < today.length; i++) {
      iv = today[i];
      if (iv.o <= m && m < iv.c) { st.open = true; st.toClose = iv.c - m; st.closesAt = P.hhmm(iv.c); return st; }
    }
    for (i = 0; i < yest.length; i++) {
      iv = yest[i];
      if (iv.c > 1440 && m < iv.c - 1440) { st.open = true; st.toClose = iv.c - 1440 - m; st.closesAt = P.hhmm(iv.c); return st; }
    }
    var next = null;
    today.forEach(function (x) { if (x.o > m && (next === null || x.o < next)) next = x.o; });
    if (next !== null) { st.daysAhead = 0; st.toOpen = next - m; st.opensAt = P.hhmm(next); return st; }
    for (var k = 1; k <= 7; k++) {
      var day = sch.days[(wd + k) % 7];
      if (day.length) {
        var first = Math.min.apply(null, day.map(function (x) { return x.o; }));
        st.daysAhead = k; st.toOpen = k * 1440 + first - m; st.opensAt = P.hhmm(first);
        return st;
      }
    }
    return st;
  };

  P.statusText = function (st, date) {
    var t = AC.i18n.t, tf = AC.i18n.tf;
    if (st.unknown) return t("place_hours_unknown");
    if (st.always) return t("place_open_24h");
    if (st.open) return st.toClose <= 60 ? tf("place_closes_soon", st.closesAt) : tf("place_open_until", st.closesAt);
    if (st.daysAhead === 0) return tf("place_opens_at", st.opensAt);
    if (st.daysAhead === 1) return tf("place_opens_tomorrow", st.opensAt);
    if (st.daysAhead) {
      var wd = ((date || new Date()).getDay() + st.daysAhead) % 7;
      return tf("place_opens_day", t("wd_min")[wd], st.opensAt);
    }
    return t("place_closed");
  };

  // Latest closing time tonight, in minutes after the evening's midnight
  // (01:30 -> 1530). Before 06:00 "tonight" is the night that started the
  // day before. Infinity for 24/7, null when closed tonight or unknown.
  P.closesTonight = function (place, date) {
    var sch = P.schedule(place);
    if (!sch) return null;
    if (sch.always) return Infinity;
    var wd = date.getDay();
    if (date.getHours() < 6) wd = (wd + 6) % 7;
    var late = null;
    sch.days[wd].forEach(function (iv) { if (late === null || iv.c > late) late = iv.c; });
    return late;
  };
  // "Open late": still open at 02:00 tonight.
  P.LATE = 26 * 60;
  P.isOpenLate = function (place, date) {
    var c = P.closesTonight(place, date);
    return c !== null && c >= P.LATE;
  };

  /* -------------------------------------------------------------- quality */
  // Rating weighted by how many reviews back it (a Bayesian average), so a
  // 4.9 from 12 reviews does not beat a 4.6 from 3,000.
  P.quality = function (rating, reviews) {
    if (rating === null || rating === undefined || rating === "") return null;
    var r = Number(rating), n = Math.max(0, Number(reviews) || 0), m = 150, C = 4.2;
    if (!isFinite(r)) return null;
    var b = (n * r + m * C) / (n + m);
    return Math.max(0, Math.min(1, (b - 3.8) / 1.1));
  };

  /* -------------------------------------------------------------- ranking */
  P.WHAT = {
    eat: { places: ["restaurant", "gastrobar", "cafe_bistro"], events: ["food"] },
    drink: { places: ["bar", "pub", "gastrobar", "rooftop_lounge"], events: [] },
    dance: { places: ["nightclub", "club"], events: ["music"] },
    show: { places: ["concert_house", "club"], events: ["music", "arts"] },
    culture: { places: ["cultural_spot", "cafe_bistro"], events: ["arts", "tech", "community"] }
  };
  P.WHO = {
    solo: ["chill", "culture"], date: ["romantic", "upscale"],
    friends: ["friends", "party", "casual"], family: ["family", "chill"]
  };

  function at(date, hh, mm, addDays) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + (addDays || 0), hh, mm || 0);
  }

  // When -> the moment places must be open, and the window events must start in.
  P.window = function (when, now) {
    now = now || new Date();
    var ref, from, to;
    if (when === "tonight") {
      ref = now.getHours() >= 21 ? now : at(now, 21);
      from = now.getHours() >= 18 ? now : at(now, 18);
      to = at(now, 3, 0, 1);
    } else if (when === "tomorrow") {
      ref = at(now, 20, 30, 1); from = at(now, 0, 0, 1); to = at(now, 23, 59, 1);
    } else if (when === "weekend") {
      var wd = now.getDay(), toSat = wd === 0 ? -1 : 6 - wd;
      var sat = at(now, 0, 0, toSat);
      ref = wd === 0 || wd === 6 ? (now.getHours() >= 21 ? now : at(now, 21)) : at(sat, 21);
      from = wd === 0 || wd === 6 ? now : sat;
      to = at(sat, 23, 59, 1);
    } else {
      ref = now; from = new Date(now.getTime() - 60 * 60000); to = new Date(now.getTime() + 3 * 3600000);
    }
    return { when: when || "now", ref: ref, from: from, to: to };
  };

  function eventDate(ev) {
    var m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(ev.starts_at || "");
    return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5])) : null;
  }

  function priceFit(budget, item) {
    if (!budget || budget === "any") return 1;
    if (item.kind === "place") {
      var lvl = Number(item.price_level) || 2;
      return (budget === "low" ? [1, 1, 0.65, 0.25, 0] : [1, 1, 1, 0.7, 0.3])[Math.min(4, Math.max(0, lvl))];
    }
    if (item.price_type === "free" || item.price_type === "donation") return 1;
    var p = Number(item.price);
    if (!isFinite(p) || item.price === null || item.price === "") return 0.6;
    if (budget === "low") return p <= 30 ? 0.8 : p <= 60 ? 0.45 : 0.15;
    return p <= 60 ? 1 : p <= 100 ? 0.7 : 0.4;
  }

  // items: [{kind: "place"|"event", id, category, vibes: [..], ...}]
  // answers: {what: [..], vibes: [..], who, when, budget}
  // -> [{item, score, match, reasons: [{type, text}], status|start}]
  P.rank = function (items, answers, now, opts) {
    answers = answers || {};
    opts = opts || {};
    var win = P.window(answers.when, now);
    var what = util.asArray(answers.what);
    var want = {};
    util.asArray(answers.vibes).forEach(function (v) { want[v] = 1; });
    util.asArray(P.WHO[answers.who]).forEach(function (v) { if (!want[v]) want[v] = 0.5; });
    var wantKeys = Object.keys(want), wantTotal = wantKeys.reduce(function (s, k) { return s + want[k]; }, 0);
    var okCats = { places: {}, events: {} };
    what.forEach(function (w) {
      var d = P.WHAT[w];
      if (!d) return;
      d.places.forEach(function (c) { okCats.places[c] = true; });
      d.events.forEach(function (c) { okCats.events[c] = true; });
    });

    var out = [];
    items.forEach(function (it) {
      var isPlace = it.kind === "place";
      if (what.length && !(isPlace ? okCats.places[it.category] : okCats.events[it.category])) return;
      var vibes = util.asArray(it.vibes);
      if (what.length === 1 && what[0] === "dance" && !isPlace && vibes.indexOf("dance") === -1) return;

      var timing, st = null, start = null;
      if (isPlace) {
        st = P.status(it, win.ref);
        if (st.open) timing = st.toClose >= 120 ? 1 : st.toClose >= 60 ? 0.7 : 0.35;
        else if (st.unknown) timing = 0.3;  // hours not listed: keep, rank lower
        else if (win.when === "now" && st.daysAhead === 0 && st.toOpen <= 60) timing = 0.5;
        else return;
      } else {
        start = eventDate(it);
        if (!start || start < win.from || start > win.to) return;
        timing = win.when === "now" ? 1 - 0.4 * Math.min(1, Math.abs(start - win.ref) / (3 * 3600000)) : 1;
      }

      var matched = vibes.filter(function (v) { return want[v]; });
      var vibe = wantTotal ? matched.reduce(function (s, v) { return s + want[v]; }, 0) / wantTotal : 0.5;
      var q = isPlace ? P.quality(it.rating, it.reviews_count) : null;
      var quality = q === null ? 0.55 : q;
      var price = priceFit(answers.budget, it);
      var score = 0.40 * vibe + 0.30 * quality + 0.15 * price + 0.15 * timing;
      out.push({ item: it, score: score, match: Math.round(score * 100), matchedVibes: matched, status: st, start: start });
    });

    out.sort(function (a, b) { return b.score - a.score || String(a.item.id).localeCompare(String(b.item.id)); });
    // Variety: at most `perCategory` of one kind in the top list.
    var perCat = opts.perCategory || 3, limit = opts.limit || 8, seen = {}, top = [];
    for (var i = 0; i < out.length && top.length < limit; i++) {
      var key = out[i].item.kind + ":" + out[i].item.category;
      seen[key] = (seen[key] || 0) + 1;
      if (seen[key] <= perCat) top.push(out[i]);
    }
    return top;
  };

  /* --------------------------------------------------------------- walking
   * Straight-line distance times 1.3 for streets; walking at 4.5 km/h, a
   * ride at 20 km/h plus 5 minutes to get one. More than 25 minutes on foot
   * counts as a ride.                                                       */
  P.WALK_LIMIT = 25;
  P.km = function (a, b) { return AC.geo.haversineKm(Number(a.lat), Number(a.lon), Number(b.lat), Number(b.lon)); };
  P.travel = function (km) {
    var walk = Math.max(1, Math.round(km * 1.3 / 4.5 * 60));
    return walk <= P.WALK_LIMIT ? { walk: true, minutes: walk } : { walk: false, minutes: Math.round(km * 1.3 / 20 * 60) + 5 };
  };
  P.distanceText = function (km) {
    return km < 1 ? AC.i18n.tf("distance_m", Math.max(10, Math.round(km * 100) * 10))
                  : AC.i18n.tf("distance_km", AC.fmt.number(km, km < 10 ? 1 : 0));
  };
  P.eventDate = eventDate;

  function wantOf(answers) {
    var want = {};
    util.asArray(answers.vibes).forEach(function (v) { want[v] = 1; });
    util.asArray(P.WHO[answers.who]).forEach(function (v) { if (!want[v]) want[v] = 0.5; });
    var total = Object.keys(want).reduce(function (s, k) { return s + want[k]; }, 0);
    return function (vibes) {
      var matched = util.asArray(vibes).filter(function (v) { return want[v]; });
      return { matched: matched, score: total ? matched.reduce(function (s, v) { return s + want[v]; }, 0) / total : 0.5 };
    };
  }
  function addMin(d, m) { return new Date(d.getTime() + m * 60000); }
  function round5(d) { return new Date(Math.ceil(d.getTime() / 300000) * 300000); }

  /* ------------------------------------------------------ plan my night
   * Dinner -> drinks or a show -> dancing. Each stop must be open when you
   * get there and for most of the stay (a place opening within the hour
   * moves the arrival to its opening time), close to the previous stop
   * (at most 6 km), and fit the quiz answers (vibes, company, budget).
   * A short beam search keeps the best whole route, not just the best first
   * stop. Places without listed hours can appear, flagged and ranked lower. */
  P.STAGES = {
    dinner: { places: ["restaurant", "gastrobar"], events: ["food"], stay: 90 },
    drinks: { places: ["bar", "pub", "rooftop_lounge", "gastrobar"], events: [], stay: 90 },
    show: { places: ["concert_house"], events: ["music", "arts"], stay: 120 },
    dance: { places: ["nightclub", "club"], events: ["music"], eventVibe: "dance", stay: 150 }
  };

  // When the night starts: 19:30 (today, tomorrow or Saturday), or now if
  // that is later; in the small hours, now.
  P.planStart = function (when, now) {
    now = now || new Date();
    if (when === "tomorrow") return at(now, 19, 30, 1);
    if (when === "weekend") {
      var wd = now.getDay();
      if (wd !== 6 && wd !== 0) return at(now, 19, 30, 6 - wd);
    }
    if (now.getHours() < 6) return round5(now);
    var base = at(now, 19, 30);
    return now > base ? round5(now) : base;
  };

  // Which stages fit the start time: a late start skips dinner.
  P.planStages = function (start) {
    var m = start.getHours() * 60 + start.getMinutes();
    if (m < 6 * 60) m += 1440;
    if (m <= 21 * 60 + 30) return ["dinner", ["drinks", "show"], "dance"];
    if (m <= 24 * 60 + 30) return [["drinks", "show"], "dance"];
    return ["dance"];
  };

  // A candidate for one stage at `arrive`: null when it does not fit.
  function stageFit(it, stageKeys, arrive, prev, fit, budget) {
    var isPlace = it.kind === "place", stage = null, i, def;
    for (i = 0; i < stageKeys.length; i++) {
      def = P.STAGES[stageKeys[i]];
      var ok = isPlace ? def.places.indexOf(it.category) !== -1 : def.events.indexOf(it.category) !== -1 &&
        (!def.eventVibe || util.asArray(it.vibes).indexOf(def.eventVibe) !== -1);
      if (ok) { stage = stageKeys[i]; break; }
    }
    if (!stage) return null;
    def = P.STAGES[stage];
    var km = prev ? P.km(prev, it) : 0;
    if (!isFinite(km) || km > 6) return null;
    var when = arrive, timing, st = null;
    if (isPlace) {
      st = P.status(it, arrive);
      if (st.open) {
        if (st.toClose < 60) return null;
        timing = Math.min(1, st.toClose / def.stay);
      } else if (st.unknown) {
        timing = 0.35;
      } else if (st.daysAhead === 0 && st.toOpen <= 60) {
        when = addMin(arrive, st.toOpen);
        st = P.status(it, when);
        timing = 0.8;
      } else return null;
    } else {
      var start = eventDate(it);
      if (!start || start < addMin(arrive, -30) || start > addMin(arrive, 90)) return null;
      when = start;
      timing = 1;
    }
    var v = fit(it.vibes);
    var q = isPlace ? P.quality(it.rating, it.reviews_count) : null;
    var score = 0.45 * v.score + 0.25 * (q === null ? 0.55 : q) + 0.15 * priceFit(budget, it) + 0.15 * timing - 0.05 * km;
    var tr = prev ? P.travel(km) : null;
    return { stage: stage, item: it, arrive: when, start: isPlace ? null : when, status: st, km: prev ? km : null, travel: tr,
             unknown: !!(st && st.unknown), matchedVibes: v.matched, score: score, leave: addMin(when, def.stay) };
  }

  function bestFor(items, stageKeys, arrive, prev, used, fit, budget, limit) {
    var out = [];
    items.forEach(function (it) {
      if (used[it.kind + ":" + it.id]) return;
      var c = stageFit(it, stageKeys, arrive, prev, fit, budget);
      if (c) out.push(c);
    });
    out.sort(function (a, b) { return b.score - a.score || String(a.item.id).localeCompare(String(b.item.id)); });
    return out.slice(0, limit || 1);
  }

  // -> {start, stops: [{stage, item, arrive, status, km, travel, unknown,
  //     matchedVibes}], unknownHours} or null when no stop fits.
  P.plan = function (items, answers, now, opts) {
    answers = answers || {};
    opts = opts || {};
    items = util.asArray(items).filter(function (it) { return isFinite(Number(it.lat)) && isFinite(Number(it.lon)); });
    var start = opts.start || P.planStart(answers.when, now);
    var stages = P.planStages(start).map(function (s) { return util.asArray(s); });
    var fit = wantOf(answers), beam = opts.beam || 6, best = null;
    // A stage nothing fits is skipped (no restaurant open: start with drinks).
    var firstStage = 0, firsts = [];
    while (firstStage < stages.length &&
           !(firsts = bestFor(items, stages[firstStage], start, null, {}, fit, answers.budget, beam)).length) firstStage++;
    firsts.forEach(function (first) {
      var route = [first], used = {}, total = first.score;
      used[first.item.kind + ":" + first.item.id] = true;
      for (var k = firstStage + 1; k < stages.length; k++) {
        var prev = route[route.length - 1], next = null;
        // Ranked at the time you leave, then re-checked at the time you
        // arrive (travel included).
        var options = bestFor(items, stages[k], prev.leave, prev.item, used, fit, answers.budget, 5);
        for (var o = 0; o < options.length && !next; o++) {
          var arrive = round5(addMin(prev.leave, options[o].travel ? options[o].travel.minutes : 0));
          next = stageFit(options[o].item, stages[k], arrive, prev.item, fit, answers.budget);
        }
        if (!next) continue;
        used[next.item.kind + ":" + next.item.id] = true;
        route.push(next);
        total += next.score;
      }
      // Longer routes win over a single great stop.
      total += 0.35 * route.length;
      if (!best || total > best.total) best = { total: total, route: route };
    });
    if (!best) return null;
    return {
      start: start, stops: best.route,
      unknownHours: best.route.some(function (s) { return s.unknown; })
    };
  };

  /* ------------------------------------------------------ before & after
   * Places near an event: before (dinner or a drink, open 90 minutes before
   * it starts) and after (bars and clubs open when it ends, about 2.5 hours
   * after the start). Nearest and best first; the radius grows when little
   * is close.                                                               */
  P.AROUND = {
    before: { places: ["restaurant", "gastrobar", "bar", "pub", "cafe_bistro", "rooftop_lounge"], offset: -90, need: 45, km: [1.2, 2.5] },
    after: { places: ["bar", "pub", "nightclub", "club", "rooftop_lounge", "gastrobar", "concert_house"], offset: 150, need: 60, km: [1.5, 3] }
  };

  P.around = function (ev, items, opts) {
    opts = opts || {};
    var start = eventDate(ev) || opts.start || null;
    var out = { start: start, before: [], after: [] };
    if (!start || !isFinite(Number(ev.lat)) || !isFinite(Number(ev.lon))) return out;
    var places = util.asArray(items).filter(function (it) {
      return it.kind === "place" && String(it.id) !== String(ev.id) && isFinite(Number(it.lat));
    });
    ["before", "after"].forEach(function (side) {
      var def = P.AROUND[side], moment = addMin(start, def.offset), picks = [];
      for (var r = 0; r < def.km.length && picks.length < 3; r++) {
        picks = [];
        places.forEach(function (it) {
          if (def.places.indexOf(it.category) === -1) return;
          var km = P.km(ev, it);
          if (km > def.km[r]) return;
          var st = P.status(it, moment);
          var timing;
          if (st.open) { if (st.toClose < def.need) return; timing = 1; }
          else if (st.unknown) timing = 0.4;
          else if (st.daysAhead === 0 && st.toOpen <= 30) timing = 0.7;
          else return;
          var q = P.quality(it.rating, it.reviews_count);
          var score = 0.45 * timing + 0.3 * (q === null ? 0.55 : q) + 0.25 * Math.max(0, 1 - km / def.km[def.km.length - 1]);
          picks.push({ item: it, km: km, status: st, at: moment, score: score, unknown: st.unknown });
        });
      }
      picks.sort(function (a, b) { return b.score - a.score || a.km - b.km; });
      out[side] = picks.slice(0, opts.limit || 4);
    });
    return out;
  };
})(window);
