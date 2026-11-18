/*! AC.Decide (MIT licence). "Can't decide?": a few quick questions, then
 * places and events ranked by what is open (or starting) when you want to go,
 * how well they match the vibe, their rating and the budget; a second tab
 * plans the whole night (dinner -> drinks or a show -> dancing, each stop
 * open when you get there and close to the previous one). It also shows
 * "before & after" suggestions around an event. The logic lives in
 * AC.places.rank / plan / around (ac-places.js).
 *
 *   var d = new AC.Decide(element, {
 *     onPick: function (item) {...},           // a suggestion was chosen
 *     onRoute: function (stops) {...}          // "show the route on the map"
 *   });
 *   d.setItems([{kind: "place"|"event", id, category, vibes: [...], lat, lon,
 *                label, popup, ...}]);
 *   d.showAround({id, title, lat, lon, starts_at});
 *
 * Any element with data-ac-around="<event id>" (plus data-title, data-lat,
 * data-lon, data-start) opens "before & after" in the first AC.Decide on the
 * page and switches to its pane ("decide"), e.g. the link in event popups. */
(function (global) {
  "use strict";
  var AC = global.AC, util = AC.util, esc = util.escapeHtml, I = AC.icons;
  var t = function (k) { return AC.i18n.t(k); };
  var tf = function () { return AC.i18n.tf.apply(null, arguments); };

  var VIBE_ICONS = {
    chill: "moon", romantic: "heart", party: "sparkles", live_music: "cat_music", dance: "pcat_nightclub",
    casual: "pcat_pub", upscale: "star", outdoor: "sun", alternative: "bolt", culture: "pcat_cultural_spot",
    friends: "cat_community", family: "home"
  };
  var STEPS = [
    { key: "what", q: "q_what", multi: true, options: [
      { v: "eat", icon: "pcat_restaurant", label: "act_eat", tile: "ac-pcat-restaurant" },
      { v: "drink", icon: "pcat_bar", label: "act_drink", tile: "ac-pcat-bar" },
      { v: "dance", icon: "pcat_nightclub", label: "act_dance", tile: "ac-pcat-nightclub" },
      { v: "show", icon: "pcat_concert_house", label: "act_show", tile: "ac-pcat-concert_house" },
      { v: "culture", icon: "pcat_cultural_spot", label: "act_culture", tile: "ac-pcat-cultural_spot" }] },
    { key: "vibes", q: "q_vibe", hint: "q_vibe_hint", multi: true, max: 3, options: AC.places.VIBES.map(function (v) {
      return { v: v, label: "vibe_" + v, tile: "ac-vibe-" + v, icon: VIBE_ICONS[v] || "sparkles" };
    }) },
    { key: "who", q: "q_who", options: [
      { v: "solo", icon: "person", label: "who_solo", tile: "ac-vibe-chill" },
      { v: "date", icon: "heart", label: "who_date", tile: "ac-vibe-romantic" },
      { v: "friends", icon: "cat_community", label: "who_friends", tile: "ac-vibe-friends" },
      { v: "family", icon: "home", label: "who_family", tile: "ac-vibe-family" }] },
    { key: "when", q: "q_when", options: [
      { v: "now", icon: "bolt", label: "dwhen_now", tile: "ac-vibe-party" },
      { v: "tonight", icon: "moon", label: "dwhen_tonight", tile: "ac-vibe-live_music" },
      { v: "tomorrow", icon: "sun", label: "dwhen_tomorrow", tile: "ac-vibe-casual" },
      { v: "weekend", icon: "calendar", label: "dwhen_weekend", tile: "ac-vibe-outdoor" }] },
    { key: "budget", q: "q_budget", options: [
      { v: "low", text: "$", label: "budget_low", tile: "ac-vibe-outdoor" },
      { v: "mid", text: "$$", label: "budget_mid", tile: "ac-vibe-casual" },
      { v: "any", text: "$$$", label: "budget_any", tile: "ac-vibe-upscale" }] }
  ];
  var DEFAULTS = { what: [], vibes: [], who: null, when: "now", budget: "any" };

  function Decide(root, opts) {
    if (!(this instanceof Decide)) return new Decide(root, opts);
    this.root = root;
    this.opts = opts || {};
    this.items = [];
    this.reset();
    root.classList.add("ac-decide");
    this._bind();
    Decide.instances.push(this);
  }
  Decide.instances = [];
  var D = Decide.prototype;

  D.reset = function () {
    this.answers = JSON.parse(JSON.stringify(DEFAULTS));
    this.step = 0;
    this.view = "quiz";
    this.tab = "picks";
    this.render();
  };

  D.setItems = function (items) {
    this.items = util.asArray(items).map(function (it) {
      var q = {};
      for (var k in it) if (Object.prototype.hasOwnProperty.call(it, k)) q[k] = it[k];
      q.vibes = Array.isArray(it.vibes) ? it.vibes : String(it.vibes || "").split(",").filter(Boolean);
      return q;
    });
    if (this.view !== "quiz") this.render();
  };

  D.results = function (now) {
    return AC.places.rank(this.items, this.answers, now || new Date());
  };

  D.relabel = function () { this.render(); };

  D.render = function () {
    this._pickable = [];
    if (this.view === "results") this._renderResults();
    else if (this.view === "around") this._renderAround();
    else this._renderStep();
  };

  // Remembers an item for the pick buttons; returns its index.
  D._keep = function (item) { this._pickable.push(item); return this._pickable.length - 1; };

  D.plan = function (now) {
    return AC.places.plan(this.items, this.answers, now || new Date());
  };

  // "Before & after" for an event (the item with that id when known).
  D.showAround = function (ev) {
    var known = null;
    for (var i = 0; i < this.items.length; i++) {
      if (this.items[i].kind === "event" && String(this.items[i].id) === String(ev.id)) { known = this.items[i]; break; }
    }
    this.aroundEvent = known || ev;
    this.returnView = this.view === "around" ? this.returnView : this.view;
    this.view = "around";
    this.render();
    var h = this.root.querySelector(".ac-dq-q");
    if (h && this.opts.focus !== false) h.focus({ preventScroll: true });
  };

  D._renderStep = function () {
    var s = STEPS[this.step], a = this.answers[s.key], self = this;
    var dots = STEPS.map(function (_, i) {
      return '<span class="ac-dq-dot' + (i < self.step ? " is-done" : i === self.step ? " is-now" : "") + '"></span>';
    }).join("");
    var opts = s.options.map(function (o) {
      var on = s.multi ? a.indexOf(o.v) !== -1 : a === o.v;
      return '<button type="button" class="ac-dq-opt' + (on ? " is-on" : "") + '" data-v="' + esc(o.v) + '" aria-pressed="' + on + '">' +
        '<span class="ac-dq-tile ' + esc(o.tile || "") + '" aria-hidden="true">' +
        (o.icon ? I[o.icon] : '<span class="ac-dq-tile-text">' + esc(o.text) + "</span>") + "</span>" +
        '<span class="ac-dq-label">' + esc(t(o.label)) + "</span></button>";
    }).join("");
    var last = this.step === STEPS.length - 1;
    this.root.innerHTML =
      '<div class="ac-dq-head"><span class="ac-dq-count">' + esc(tf("decide_step", this.step + 1, STEPS.length)) +
      '</span><span class="ac-dq-dots" aria-hidden="true">' + dots + "</span></div>" +
      '<h3 class="ac-dq-q" tabindex="-1">' + esc(t(s.q)) + "</h3>" +
      (s.hint ? '<p class="ac-dq-hint">' + esc(t(s.hint)) + "</p>" : "") +
      '<div class="ac-dq-options' + (s.options.length > 6 ? " is-many" : "") + '" role="group" aria-label="' + esc(t(s.q)) + '">' + opts + "</div>" +
      '<div class="ac-dq-nav">' +
      (this.step > 0 ? '<button type="button" class="ac-btn ac-btn-ghost ac-btn-sm" data-act="back">' + I.back + "<span>" + esc(t("back")) + "</span></button>" : "<span></span>") +
      '<span class="ac-dq-navr"><button type="button" class="ac-btn ac-btn-sm" data-act="skip">' + esc(t("decide_any")) + "</button>" +
      (s.multi || last ? '<button type="button" class="ac-btn ac-btn-primary ac-btn-sm" data-act="next">' +
        esc(t(last ? "decide_show" : "decide_next")) + "</button>" : "") + "</span></div>";
  };

  function dayWord(d) {
    var today = util.today(), iso = util.isoDate(d);
    if (iso === today) return t("day_today");
    if (iso === util.addDays(today, 1)) return t("day_tomorrow");
    return t("wd_short")[d.getDay()];
  }

  // Chips under a suggestion: opening status (or start time), rating,
  // matched vibes and price. `when` is the moment the status refers to.
  D._reasons = function (r, when) {
    var it = r.item, out = [];
    if (it.kind === "place" && r.status) {
      out.push({ cls: r.status.unknown ? "is-unknown" : "is-time", text: AC.places.statusText(r.status, when) });
      if (it.rating !== null && it.rating !== undefined && it.rating !== "") {
        out.push({ cls: "is-rating", html: I.star + esc(AC.fmt.number(it.rating, 1)) });
      }
    } else if (r.start) {
      out.push({ cls: "is-time", text: tf("event_at", dayWord(r.start), util.pad2(r.start.getHours()) + ":" + util.pad2(r.start.getMinutes())) });
    }
    util.asArray(r.matchedVibes).slice(0, 2).forEach(function (v) { out.push({ cls: "is-vibe", text: t("vibe_" + v) }); });
    if (it.kind === "place" && Number(it.price_level) > 0) out.push({ cls: "is-price", text: new Array(Number(it.price_level) + 1).join("$") });
    if (it.kind === "event") out.push({ cls: "is-price", text: AC.fmt.price(it.price_type, it.price, it.currency) });
    return out;
  };

  function tileOf(it) {
    var isPlace = it.kind === "place";
    var cat = isPlace ? it.category : (["music", "food", "arts", "sports", "tech", "community"].indexOf(it.category) >= 0 ? it.category : "other");
    return { cat: cat, cls: (isPlace ? "ac-pcat-" : "ac-cat-") + cat, icon: I[(isPlace ? "pcat_" : "cat_") + cat] || I.sparkles };
  }

  function kindText(it) {
    var tl = tileOf(it);
    return it.kind === "place" ? t("pcat_" + tl.cat) + (it.neighborhood ? " \u00b7 " + it.neighborhood : "")
                               : t("kind_event") + " \u00b7 " + t("cat_" + tl.cat);
  }

  function mapsLinkHtml(it) {
    return it.kind === "place" && /^https?:\/\/\S+$/i.test(it.maps_url || "")
      ? '<a class="ac-linkbtn" href="' + esc(it.maps_url) + '" target="_blank" rel="noopener noreferrer">' +
        I.external + "<span>" + esc(t("place_maps_link")) + "</span></a>" : "";
  }

  function reasonsHtml(list) {
    return list.map(function (x) {
      return '<span class="ac-dq-reason ' + x.cls + '">' + (x.html || esc(x.text)) + "</span>";
    }).join("");
  }

  // One suggestion card. o: {kind (text above the name), reasons, side (HTML
  // on the right), i (animation index)}.
  D._card = function (it, o) {
    var tl = tileOf(it), link = mapsLinkHtml(it);
    return '<li class="ac-dq-card" style="--i:' + (o.i || 0) + '">' +
      '<div class="ac-ev-tile ' + tl.cls + '" aria-hidden="true">' + tl.icon + "</div>" +
      '<div class="ac-dq-main"><div class="ac-dq-kind">' + esc(o.kind || kindText(it)) + "</div>" +
      '<h4 class="ac-dq-name"><button type="button" class="ac-dq-pick" data-i="' + this._keep(it) + '">' +
      esc(it.name || it.title || it.label) + "</button></h4>" +
      '<div class="ac-dq-reasons">' + reasonsHtml(o.reasons || []) + "</div>" +
      (link ? '<div class="ac-dq-links">' + link + "</div>" : "") + "</div>" + (o.side || "") + "</li>";
  };

  function emptyHtml(key) {
    return '<div class="ac-empty"><strong>' + esc(t("empty_title")) + "</strong><span>" + esc(t(key)) + "</span></div>";
  }

  function hhmm(d) { return util.pad2(d.getHours()) + ":" + util.pad2(d.getMinutes()); }

  D._renderResults = function () {
    var self = this, now = new Date();
    var tabs = '<div class="ac-seg ac-seg-sm ac-dq-tabs" role="group">' +
      ["picks", "plan"].map(function (k) {
        var on = self.tab === k;
        return '<button type="button" class="ac-seg-btn' + (on ? " is-active" : "") + '" data-tab="' + k + '" aria-pressed="' + on + '">' +
          (k === "plan" ? I.route : I.sparkles) + "<span>" + esc(t(k + "_tab")) + "</span></button>";
      }).join("") + "</div>";
    var body = this.tab === "plan" ? this._planHtml(now) : this._picksHtml(now);
    this.root.innerHTML =
      '<div class="ac-dq-head"><h3 class="ac-dq-q" tabindex="-1">' + esc(t("decide_results")) + "</h3>" +
      '<button type="button" class="ac-btn ac-btn-sm" data-act="restart">' + esc(t("decide_restart")) + "</button></div>" +
      tabs + body;
  };

  D._picksHtml = function (now) {
    var self = this, win = AC.places.window(this.answers.when, now);
    var res = this.results(now);
    this._last = res;
    if (!res.length) return emptyHtml("decide_none");
    return '<ol class="ac-dq-results">' + res.map(function (r, i) {
      return self._card(r.item, {
        i: i, reasons: self._reasons(r, win.ref),
        side: '<div class="ac-dq-match" title="' + esc(tf("decide_match", r.match)) + '"><strong>' + r.match + "%</strong></div>"
      });
    }).join("") + "</ol>";
  };

  function legHtml(stop) {
    if (!stop.travel) return "";
    var dist = AC.places.distanceText(stop.km);
    var txt = stop.travel.walk ? tf("plan_walk", dist, stop.travel.minutes) : tf("plan_ride", dist, stop.travel.minutes);
    return '<li class="ac-plan-leg" aria-hidden="false">' + (stop.travel.walk ? I.walk : I.car) + "<span>" + esc(txt) + "</span></li>";
  }

  D._planHtml = function (now) {
    var self = this, plan = this.plan(now);
    this._plan = plan;
    if (!plan || !plan.stops.length) return emptyHtml("plan_none");
    var html = '<p class="ac-dq-hint">' + esc(t("plan_title")) + "</p><ol class=\"ac-plan\">";
    plan.stops.forEach(function (s, i) {
      html += legHtml(s);
      var stageText = t("plan_" + s.stage) + " \u00b7 " + tf("plan_at", hhmm(s.arrive));
      var reasons = self._reasons(s, s.arrive);
      html += '<li class="ac-plan-stop" style="--i:' + i + '"><span class="ac-plan-n" aria-hidden="true">' + (i + 1) + "</span>" +
        '<ol class="ac-dq-results ac-plan-card">' + self._card(s.item, { i: i, kind: stageText, reasons: reasons }) + "</ol></li>";
    });
    html += "</ol>";
    if (plan.unknownHours) html += '<p class="ac-demo-note">' + I.clock + "<span>" + esc(t("plan_hours_note")) + "</span></p>";
    if (typeof this.opts.onRoute === "function") {
      html += '<div class="ac-dq-nav"><span></span><button type="button" class="ac-btn ac-btn-primary ac-btn-sm" data-act="route">' +
        I.route + "<span>" + esc(t("plan_show_map")) + "</span></button></div>";
    }
    return html;
  };

  D.routeStops = function () {
    if (!this._plan) return [];
    return this._plan.stops.map(function (s, i) {
      var it = s.item;
      return { id: it.id, kind: it.kind, lat: Number(it.lat), lon: Number(it.lon), n: i + 1,
               label: (i + 1) + ". " + (it.name || it.title || it.label) + " \u00b7 " + hhmm(s.arrive),
               popup: it.popup || null, stage: s.stage, item: it };
    });
  };

  D._renderAround = function () {
    var self = this, ev = this.aroundEvent || {};
    var res = AC.places.around(ev, this.items);
    this._around = res;
    var when = res.start ? AC.fmt.when(util.isoDate(res.start) + " " + hhmm(res.start)) : "";
    var section = function (side, key) {
      var list = res[side];
      return '<h4 class="ac-around-h">' + esc(t(key)) + "</h4>" + (list.length ? '<ol class="ac-dq-results">' + list.map(function (r, i) {
        var reasons = self._reasons(r, r.at);
        reasons.unshift({ cls: "is-dist", html: I.walk + esc(AC.places.distanceText(r.km)) });
        return self._card(r.item, { i: i, reasons: reasons });
      }).join("") + "</ol>" : '<p class="ac-dq-hint">' + esc(t("around_none")) + "</p>");
    };
    this.root.innerHTML =
      '<div class="ac-dq-head"><h3 class="ac-dq-q" tabindex="-1">' + esc(t("around_title")) + "</h3>" +
      '<button type="button" class="ac-btn ac-btn-sm" data-act="around-back">' + esc(t("around_back")) + "</button></div>" +
      '<p class="ac-around-for">' + esc(tf("around_for", ev.title || ev.label || "")) + (when ? " \u00b7 " + esc(when) : "") + "</p>" +
      section("before", "around_before") + section("after", "around_after");
  };

  D._go = function (step) {
    if (step >= STEPS.length) { this.view = "results"; this.render(); }
    else { this.step = Math.max(0, step); this.view = "quiz"; this.render(); }
    var h = this.root.querySelector(".ac-dq-q");
    if (h && this.opts.focus !== false) h.focus({ preventScroll: true });
  };

  D._bind = function () {
    var self = this;
    this.root.addEventListener("click", function (e) {
      var act = e.target.closest("[data-act]");
      if (act) {
        var a = act.getAttribute("data-act");
        var s = STEPS[self.step];
        if (a === "back") self._go(self.step - 1);
        else if (a === "next") self._go(self.step + 1);
        else if (a === "skip") { self.answers[s.key] = JSON.parse(JSON.stringify(DEFAULTS[s.key])); self._go(self.step + 1); }
        else if (a === "restart") { self.reset(); }
        else if (a === "route" && typeof self.opts.onRoute === "function") { self.opts.onRoute(self.routeStops()); }
        else if (a === "around-back") { self.view = self.returnView === "results" ? "results" : "quiz"; self.render(); }
        return;
      }
      var tab = e.target.closest("[data-tab]");
      if (tab) { self.tab = tab.getAttribute("data-tab"); self.render(); return; }
      var opt = e.target.closest(".ac-dq-opt");
      if (opt) {
        var st = STEPS[self.step], v = opt.getAttribute("data-v");
        if (st.multi) {
          var cur = self.answers[st.key], k = cur.indexOf(v);
          if (k !== -1) cur.splice(k, 1);
          else if (!st.max || cur.length < st.max) cur.push(v);
          self.render();
        } else {
          self.answers[st.key] = v;
          self.render();
          setTimeout(function () { self._go(self.step + 1); }, 160);
        }
        return;
      }
      var pick = e.target.closest(".ac-dq-pick");
      if (pick && self._pickable) {
        var item = self._pickable[Number(pick.getAttribute("data-i"))];
        if (item && typeof self.opts.onPick === "function") self.opts.onPick(item);
      }
    });
  };

  // "Before & after" links, e.g. in event popups (see the header comment).
  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("[data-ac-around]");
    if (!b || !Decide.instances.length) return;
    e.preventDefault();
    var num = function (k) { var v = b.getAttribute(k); return v === null || v === "" ? NaN : Number(v); };
    Decide.instances[0].showAround({
      id: b.getAttribute("data-ac-around"), title: b.getAttribute("data-title") || "",
      lat: num("data-lat"), lon: num("data-lon"), starts_at: b.getAttribute("data-start") || "", kind: "event"
    });
    if (AC.ui && AC.ui.openPane) AC.ui.openPane("decide");
  });

  Decide.STEPS = STEPS;
  AC.Decide = Decide;
})(window);
