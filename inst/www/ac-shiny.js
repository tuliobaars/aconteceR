/*! aconteceR Shiny bindings (MIT licence). Connects the shared components
 * (AC.PointMap, AC.MonthCalendar, AC.i18n) to Shiny:
 *
 *   .ac-pm[data-ac-pointmap]        -> AC.PointMap. Inputs: <id>_place,
 *       <id>_color_mode, <id>_cluster, <id>_group, <id>_click,
 *       <id>_marker_click, <id>_located. Messages: "ac-map" {id, action, ...}
 *       with action points | modes | place | focus | fit | clear_pick |
 *       highlight | cluster | group | route | clear_route.
 *   .ac-cal-host[data-ac-calendar]  -> AC.MonthCalendar. Inputs: <id>_month,
 *       <id>_day, <id>_item, <id>_show_day, <id>_show_month.
 *       Messages: "ac-cal" {id, action, ...}.
 *   input.ac-lang-input             -> input binding for the UI language.
 *   input.ac-native-input           -> input binding for native date/time.
 *   .ac-view-switch[data-input-id]  -> input with the active view; message
 *       "ac-view" {target, value} switches it from the server.
 *   .ac-chipset[id]                 -> input binding for the filter pills.
 *   .ac-ev[data-input]              -> a click on a title sends the event id.
 *   "ac-pane" {value}               -> opens a pane over the event list.
 *   input `night`                   -> TRUE while the page is dark (AC.theme).
 *   input `clock` {wday, minutes}   -> the visitor's clock, every minute.
 *   .ac-decide-host[data-ac-decide] -> AC.Decide; message "ac-decide" {id,
 *       action: "items", items}. A pick switches mode and flies the map;
 *       "show the route" draws the planned night on the map.              */
(function () {
  "use strict";
  var AC = window.AC, $ = window.jQuery, Shiny = window.Shiny;
  if (!AC || !$ || !Shiny) return;

  var maps = {}, cals = {}, decides = {}, pending = {};
  var connected = false, queue = [];

  function send(name, value, opts) {
    if (connected) Shiny.setInputValue(name, value, opts);
    else queue.push([name, value, opts]);
  }
  $(document).on("shiny:connected", function () {
    connected = true;
    queue.splice(0).forEach(function (a) { Shiny.setInputValue(a[0], a[1], a[2]); });
  });

  var parse = function (x) { return typeof x === "string" ? JSON.parse(x) : x; };
  var nonce = function () { return Date.now() + Math.random(); };
  var EVENT = { priority: "event" };

  function firstMap() {
    for (var k in maps) if (Object.prototype.hasOwnProperty.call(maps, k)) return maps[k];
    return null;
  }

  /* ------------------------------------------------------- input bindings */
  var langBinding = new Shiny.InputBinding();
  $.extend(langBinding, {
    find: function (scope) { return $(scope).find("input.ac-lang-input"); },
    getValue: function (el) {
      // Called during Shiny's start-up, possibly before our own init runs.
      return AC.i18n._ready ? AC.i18n.lang : AC.i18n.detect(el.getAttribute("data-server-lang")).lang;
    },
    subscribe: function (el, callback) { $(el).on("ac:lang.aconteceR", function () { callback(false); }); },
    unsubscribe: function (el) { $(el).off(".aconteceR"); }
  });
  Shiny.inputBindings.register(langBinding, "aconteceR.lang");

  var nativeBinding = new Shiny.InputBinding();
  $.extend(nativeBinding, {
    find: function (scope) { return $(scope).find("input.ac-native-input"); },
    getValue: function (el) { return el.value || null; },
    setValue: function (el, value) { el.value = value || ""; },
    subscribe: function (el, callback) { $(el).on("change.aconteceR", function () { callback(false); }); },
    unsubscribe: function (el) { $(el).off(".aconteceR"); },
    receiveMessage: function (el, data) {
      if (data.value !== undefined) this.setValue(el, data.value);
      $(el).trigger("change");
    }
  });
  Shiny.inputBindings.register(nativeBinding, "aconteceR.native");

  // Filter pills: .ac-chipset[id]. Value: a string (single) or an array
  // (multi; null when empty). Messages: {value}, {custom: label}, {remove_custom}.
  var chipBinding = new Shiny.InputBinding();
  $.extend(chipBinding, {
    find: function (scope) { return $(scope).find(".ac-chipset[id]"); },
    getValue: function (el) {
      var v = AC.chips.value(el);
      return Array.isArray(v) && !v.length ? null : v;
    },
    subscribe: function (el, callback) { $(el).on("ac:chips.aconteceR", function () { callback(false); }); },
    unsubscribe: function (el) { $(el).off(".aconteceR"); },
    receiveMessage: function (el, data) {
      var o = { silent: !!data.silent, source: "server" };
      if (data.remove_custom) AC.chips.removeCustom(el, o);
      else if (data.custom !== undefined) AC.chips.custom(el, data.custom, o);
      else if (data.value !== undefined) AC.chips.set(el, data.value, o);
    }
  });
  Shiny.inputBindings.register(chipBinding, "aconteceR.chips");

  /* ---------------------------------------------------------- components */
  function queueOrRun(id, msg, registry, apply) {
    var inst = registry[id];
    if (inst) { apply(inst, msg); return; }
    (pending[id] = pending[id] || []).push(msg);
  }
  function flushPending(id, inst, apply) {
    (pending[id] || []).splice(0).forEach(function (m) { apply(inst, m); });
  }

  function syncColors(m) {
    for (var k in cals) {
      if (Object.prototype.hasOwnProperty.call(cals, k) && cals[k]._colorFrom === m.root.id) cals[k].setColorSpec(m.colorSpec());
    }
  }

  function showCityName(m) {
    var p = m.place();
    var els = document.querySelectorAll("[data-ac-city-name]");
    for (var i = 0; i < els.length; i++) els[i].textContent = p ? p.name : "";
  }

  function applyMap(m, msg) {
    switch (msg.action) {
      case "points": m.setPoints(parse(msg.points)); break;
      case "modes":
        m.setColorModes(parse(msg.modes), msg.active);
        send(m.root.id + "_color_mode", m.modeId);
        syncColors(m);
        break;
      case "place": m.setPlace(String(msg.place), { source: "server" }); break;
      case "focus": m.focus(msg.target); break;
      case "fit": if (msg.deferred) m.fitNext(); else m.fit(); break;
      case "clear_pick": m.clearPick(); break;
      case "highlight": m.highlight(msg.target); break;
      case "cluster": m.setCluster(!!msg.on); break;
      case "group": m.setGroup(!!msg.on); break;
      case "route": m.setRoute(parse(msg.stops)); break;
      case "clear_route": m.clearRoute(); break;
    }
  }

  function applyCal(c, msg) {
    switch (msg.action) {
      case "items": c.setItems(parse(msg.items)); break;
      case "month": c.setMonth(msg.month); break;
      case "select": c.select(msg.date || null); break;
    }
  }

  Shiny.addCustomMessageHandler("ac-map", function (msg) { queueOrRun(msg.id, msg, maps, applyMap); });
  Shiny.addCustomMessageHandler("ac-cal", function (msg) { queueOrRun(msg.id, msg, cals, applyCal); });
  Shiny.addCustomMessageHandler("ac-pane", function (msg) { AC.ui.openPane(msg.value); });
  Shiny.addCustomMessageHandler("ac-decide", function (msg) {
    queueOrRun(msg.id, msg, decides, function (d, m) { if (m.action === "items") d.setItems(parse(m.items)); });
  });
  Shiny.addCustomMessageHandler("ac-view", function (msg) {
    var sw = document.querySelector('.ac-view-switch[data-target="' + msg.target + '"]');
    if (sw) AC.ui.setView(sw, msg.value, "server");
  });

  function initMap(el) {
    if (el._acMap) return;
    var cfg = {};
    try { cfg = JSON.parse(el.getAttribute("data-ac-pointmap") || "{}"); } catch (e) { cfg = {}; }
    var id = el.id;
    var m = new AC.PointMap(el, {
      places: cfg.places, place: cfg.place, colorMode: cfg.colorMode, cluster: cfg.cluster,
      autoLocate: cfg.autoLocate, locate: cfg.locate, pickable: cfg.pickable, zoom: cfg.zoom,
      tiles: cfg.tiles || undefined, placeTarget: cfg.placeTarget || null, modesTarget: cfg.modesTarget || null,
      groupBy: cfg.groupBy || null,
      onGroup: function (on) { send(id + "_group", on); },
      onPlace: function (placeId) { send(id + "_place", placeId); showCityName(m); },
      onColorMode: function (mode) { send(id + "_color_mode", mode); syncColors(m); },
      onCluster: function (on) { send(id + "_cluster", on); },
      onPick: function (p) { send(id + "_click", { lat: p.lat, lon: p.lon, nonce: nonce() }, EVENT); },
      onMarkerClick: function (pid) { send(id + "_marker_click", { id: pid, nonce: nonce() }, EVENT); },
      onLocate: function (info) { send(id + "_located", info, EVENT); }
    });
    el._acMap = m;
    maps[id] = m;
    showCityName(m);
    send(id + "_place", m.placeId);
    send(id + "_cluster", m.clusterOn);
    flushPending(id, m, applyMap);
  }

  function initCal(el) {
    if (el._acCal) return;
    var id = el.id;
    var c = new AC.MonthCalendar(el, {
      onMonth: function (ym) { send(id + "_month", ym); },
      onSelect: function (d) { send(id + "_day", d); },
      onItem: function (itemId) { send(id + "_item", { id: itemId, nonce: nonce() }, EVENT); },
      onShowDay: function (d) { send(id + "_show_day", { date: d, nonce: nonce() }, EVENT); },
      onShowMonth: function (ym) { send(id + "_show_month", { month: ym, nonce: nonce() }, EVENT); }
    });
    c._colorFrom = el.getAttribute("data-color-from");
    el._acCal = c;
    cals[id] = c;
    send(id + "_month", c.month);
    var m = c._colorFrom && maps[c._colorFrom];
    if (m) c.setColorSpec(m.colorSpec());
    flushPending(id, c, applyCal);
  }

  // "Can't decide?": a pick switches to the matching mode and flies there.
  function initDecide(el) {
    if (el._acDecide) return;
    var id = el.id;
    var toMap = function (mode) {
      var modeSet = document.getElementById("mode");
      if (modeSet) AC.chips.set(modeSet, mode);
      var sw = document.querySelector(".ac-view-switch");
      if (sw) AC.ui.setView(sw, "map", "app");
      return firstMap();
    };
    var d = new AC.Decide(el, {
      onPick: function (item) {
        var m = toMap(item.kind === "place" ? "places" : "events");
        if (m) m.focus(item);
      },
      onRoute: function (stops) {
        var m = toMap("places");
        if (m) m.setRoute(stops);
      }
    });
    el._acDecide = d;
    decides[id] = d;
    (pending[id] || []).splice(0).forEach(function (msg) { if (msg.action === "items") d.setItems(parse(msg.items)); });
  }

  // The visitor's clock, for opening hours (the server may be elsewhere).
  function sendClock() {
    var now = new Date();
    send("clock", { wday: now.getDay(), minutes: now.getHours() * 60 + now.getMinutes(), date: AC.util.isoDate(now) });
  }

  /* ------------------------------------------------------------------ init */
  function init() {
    var app = document.querySelector(".ac-app");
    var serverLang = app ? app.getAttribute("data-server-lang") : null;
    AC.i18n.load(AC.util.readJsonScript("ac-i18n-dict"));
    AC.i18n._ready = true;
    AC.i18n.setLang(AC.i18n.detect(serverLang).lang);
    AC.ui.icons(document);

    Array.prototype.forEach.call(document.querySelectorAll(".ac-pm[data-ac-pointmap]"), initMap);
    Array.prototype.forEach.call(document.querySelectorAll(".ac-cal-host[data-ac-calendar]"), initCal);
    Array.prototype.forEach.call(document.querySelectorAll(".ac-decide-host[data-ac-decide]"), initDecide);
    sendClock();
    setInterval(sendClock, 60 * 1000);
    Array.prototype.forEach.call(document.querySelectorAll(".ac-view-switch[data-input-id]"), function (sw) {
      var active = sw.querySelector(".ac-seg-btn.is-active");
      send(sw.getAttribute("data-input-id"), active ? active.getAttribute("data-value") : null);
    });

    // Night plans first while the page is dark.
    send("night", AC.theme.isDark());
    document.addEventListener("ac:theme", function (e) {
      if (e.detail.darkChanged) send("night", e.detail.dark);
    });

    AC.i18n.onChange(function () {
      for (var k in maps) if (Object.prototype.hasOwnProperty.call(maps, k)) maps[k].relabel();
      for (var c in cals) if (Object.prototype.hasOwnProperty.call(cals, c)) cals[c].relabel();
      for (var dd in decides) if (Object.prototype.hasOwnProperty.call(decides, dd)) decides[dd].relabel();
      $("input.ac-lang-input").trigger("ac:lang");
    });
  }

  /* ------------------------------------------------------------ delegated */
  document.addEventListener("click", function (e) {
    var langBtn = e.target.closest(".ac-lang-btn");
    if (langBtn) { AC.i18n.setLang(langBtn.getAttribute("data-lang"), { persist: true }); return; }
    var show = e.target.closest(".ac-ev-show");
    if (show) {
      var row = show.closest(".ac-ev");
      var input = row && row.getAttribute("data-input");
      if (input) send(input, row.getAttribute("data-id"), EVENT);
    }
  });

  document.addEventListener("ac:view", function (e) {
    var sw = e.target;
    var input = sw && sw.getAttribute && sw.getAttribute("data-input-id");
    if (input) send(input, e.detail.value);
  });

  // Outputs in a pane that was hidden are suspended by Shiny; tell it.
  document.addEventListener("ac:pane", function (e) {
    var pane = e.target.querySelector('[data-pane="' + e.detail.value + '"]');
    if (pane) $(pane).trigger("shown");
  });

  // Hovering an event row rings its pin on the map.
  var hovered = null;
  document.addEventListener("mouseover", function (e) {
    var row = e.target.closest && e.target.closest(".ac-ev[data-id]");
    var id = row ? row.getAttribute("data-id") : null;
    if (id === hovered) return;
    hovered = id;
    var m = firstMap();
    if (m) m.highlight(id);
  });

  // Newly rendered rows need their icons.
  $(document).on("shiny:value", function () { setTimeout(function () { AC.ui.icons(document); }, 0); });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
