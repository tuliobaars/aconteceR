/*! AC.PointMap (MIT licence). A generic Leaflet point map: place picker,
 * colour-by switch, clustering (donut clusters), locate / fit / re-centre, a
 * live legend with counts, click-to-pick and fly-to-focus. Controls sit in a
 * floating glass bar; key-free tiles, tinted by the time of day in CSS.
 *
 * It knows nothing about events. Give it places and points:
 *   places: [{id, label, lat, lon}]
 *   points: [{id, lat, lon, label (plain text), popup (HTML, already escaped),
 *             ...any columns the colour modes read}]
 *   colour modes: see AC.color in ac-core.js (factor levels or numeric bins)
 *
 *   var map = new AC.PointMap(element, {places, place, colorModes, colorMode,
 *     cluster, pickable, autoLocate, tiles ("auto" | "osm" | "esri" | {...}),
 *     placeTarget, modesTarget, groupBy, t,
 *     onPlace, onColorMode, onCluster, onGroup, onPick, onMarkerClick, onLocate});
 *   map.setPoints(points); map.setColorModes(modes, activeId); map.focus(id);
 *   map.setRoute([{lat, lon, label, n}]); map.clearRoute();
 *
 * groupBy: a point column (e.g. "neighborhood"). A switch in the bar then
 * swaps the pins for one bubble per group: size by count, colour by the
 * active colour mode (most common level, or the bin of the median value),
 * with the largest groups listed in the legend. Clicking a bubble zooms in
 * and shows its pins again. The switch hides when there are fewer than two
 * groups.
 *
 * Markup: .ac-pm-body / .ac-pm-canvas / .ac-pm-bar (with .ac-pm-bar-end for
 * host controls) and .ac-pm-overlay views are reused when the host rendered
 * them, created otherwise. placeTarget / modesTarget (element or selector)
 * move the place picker and the colour-by switch out of the map.          */
(function (global) {
  "use strict";
  var AC = global.AC, L = global.L;
  var util = AC.util, color = AC.color, esc = AC.util.escapeHtml;

  // English fallbacks, so the component works without the app dictionary.
  var DEFAULT_TEXT = {
    pm_city: "Place", pm_color_by: "Colour by", pm_cluster: "Cluster",
    pm_cluster_title: "Group nearby pins", pm_locate: "Find the place closest to me",
    group_toggle: "By area", group_title: "Areas", group_count: "%d items", group_top: "Mostly %s",
    group_top_list: "Largest areas", plan_clear: "Clear the route", route_label: "Route",
    pm_fit: "Fit all pins", pm_reset: "Re-centre", pm_count: "%d on the map",
    pm_legend: "Legend", pm_cluster_items: "%d items at this spot", pm_zoom_in: "Zoom in",
    pm_zoom_out: "Zoom out", pm_picked: "Picked location", pm_toolbar_aria: "Map controls",
    geo_nearest: "Showing %s, the closest to you (%s).",
    geo_far: "Nothing covered near you. Showing the closest, %s (%s away).",
    geo_timezone: "Showing %s, based on your time zone.",
    geo_failed: "Could not get your location.", geo_km: "%s km"
  };

  var REDUCED_MOTION = global.matchMedia && global.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html !== undefined) e.innerHTML = html;
    return e;
  }

  function PointMap(root, opts) {
    if (!(this instanceof PointMap)) return new PointMap(root, opts);
    if (!L) throw new Error("AC.PointMap needs Leaflet (window.L).");
    opts = opts || {};
    this.root = root;
    this.opts = opts;
    this.places = util.asArray(opts.places).map(function (p) {
      return { id: String(p.id), label: String(p.label), name: String(p.name || p.city || p.label),
               lat: Number(p.lat), lon: Number(p.lon) };
    });
    this.placeId = opts.place !== undefined && opts.place !== null ? String(opts.place)
      : (this.places[0] ? this.places[0].id : null);
    this.points = [];
    this.modes = [];
    this.modeId = null;
    this.clusterOn = !!opts.cluster;
    this.groupOn = false;
    this.route = [];
    this.userChosePlace = false;
    this.markers = {};
    this.highlightId = null;
    this.legendOpen = opts.legendOpen !== undefined ? !!opts.legendOpen : !(global.innerWidth < 700);

    this._buildDom();
    this._initMap();
    this.setColorModes(opts.colorModes || [], opts.colorMode);
    // Deferred so the host has the map object before any onPlace callback.
    var self = this;
    if (opts.autoLocate) setTimeout(function () { self._autoLocate(opts.autoLocate); }, 0);
  }

  var P = PointMap.prototype;

  P.t = function (key) {
    var custom = this.opts.t;
    if (custom) {
      var v = custom(key);
      if (v !== undefined && v !== null && v !== key) return v;
    }
    if (AC.i18n && AC.i18n.has(key)) return AC.i18n.t(key);
    return DEFAULT_TEXT[key] !== undefined ? DEFAULT_TEXT[key] : key;
  };
  P.tf = function (key) {
    return util.sprintf.apply(null, [this.t(key)].concat(Array.prototype.slice.call(arguments, 1)));
  };

  P._emit = function (name) {
    var fn = this.opts[name];
    if (typeof fn === "function") fn.apply(this, Array.prototype.slice.call(arguments, 1));
  };

  /* ------------------------------------------------------------------ DOM */
  function resolve(target) {
    if (!target) return null;
    return typeof target === "string" ? document.querySelector(target) : target;
  }

  // Markup (created when missing, reused when the host rendered it):
  //   .ac-pm > .ac-pm-body > .ac-pm-canvas          the Leaflet map
  //                        > .ac-pm-overlay*         host views (calendar)
  //                        > .ac-pm-bar              floating glass bar
  //                            > .ac-pm-bar-end      host extras
  // The place picker and the colour-by switch go to opts.placeTarget /
  // opts.modesTarget when given (e.g. the page header), else into the map.
  P._buildDom = function () {
    var root = this.root, I = AC.icons, self = this;
    root.classList.add("ac-pm");
    var body = root.querySelector(".ac-pm-body");
    if (!body) { body = el("div", "ac-pm-body"); root.appendChild(body); }
    var canvas = body.querySelector(".ac-pm-canvas");
    if (!canvas) { canvas = el("div", "ac-pm-canvas"); body.insertBefore(canvas, body.firstChild); }
    var bar = body.querySelector(".ac-pm-bar");
    if (!bar) { bar = el("div", "ac-pm-bar"); body.appendChild(bar); }
    bar.setAttribute("role", "toolbar");
    var barEnd = bar.querySelector(".ac-pm-bar-end");

    var hasPlaces = this.places.length > 0;
    var placeHost = resolve(this.opts.placeTarget);
    if (hasPlaces) {
      if (!placeHost) { placeHost = el("div", "ac-pm-float ac-pm-float-place"); body.appendChild(placeHost); }
      placeHost.innerHTML = '<label class="ac-city-pill" data-kt="pm_city">' +
        '<span class="ac-city-pin" aria-hidden="true">' + I.pin + "</span>" +
        '<span class="ac-sr-only" data-k="pm_city"></span>' +
        '<select class="ac-pm-place-select">' + this.places.map(function (p) {
          return '<option value="' + esc(p.id) + '">' + esc(p.label) + "</option>";
        }).join("") + "</select></label>";
    }
    var modesHtml = '<div class="ac-pm-colorby"><span class="ac-pm-label" data-k="pm_color_by"></span>' +
      '<div class="ac-seg ac-seg-sm ac-pm-modes" role="group"></div></div>';
    var modesHost = resolve(this.opts.modesTarget);
    if (modesHost) modesHost.innerHTML = modesHtml;

    var controls = el("div", "ac-pm-controls",
      '<span class="ac-pm-count" aria-live="polite"><span class="ac-pm-dot" aria-hidden="true"></span><span class="ac-pm-count-text"></span></span>' +
      '<span class="ac-pm-sep ac-pm-mapctl" aria-hidden="true"></span>' +
      (modesHost ? "" : modesHtml + '<span class="ac-pm-sep" aria-hidden="true"></span>') +
      '<label class="ac-switch ac-pm-cluster ac-pm-mapctl" data-kt="pm_cluster_title">' +
      '<input type="checkbox" role="switch" data-ka="pm_cluster"' + (this.clusterOn ? " checked" : "") + ">" +
      '<span class="ac-switch-track" aria-hidden="true"></span>' +
      '<span class="ac-pm-ico" aria-hidden="true">' + I.layers + '</span><span data-k="pm_cluster"></span></label>' +
      (this.opts.groupBy ? '<label class="ac-switch ac-pm-group ac-pm-mapctl" data-kt="group_toggle" hidden>' +
        '<input type="checkbox" role="switch" data-ka="group_toggle"><span class="ac-switch-track" aria-hidden="true"></span>' +
        '<span class="ac-pm-ico" aria-hidden="true">' + I.hood + '</span><span data-k="group_toggle"></span></label>' : "") +
      '<span class="ac-pm-sep ac-pm-mapctl" aria-hidden="true"></span>' +
      '<div class="ac-pm-iconbtns ac-pm-mapctl">' +
      '<button type="button" class="ac-pm-route-clear" data-act="clear-route" data-kt="plan_clear" hidden>' +
      I.close + '<span data-k="route_label"></span></button>' +
      (this.opts.locate !== false && hasPlaces ?
        '<button type="button" class="ac-iconbtn ac-iconbtn-glass" data-act="locate" data-ka="pm_locate">' + I.locate + "</button>" : "") +
      '<button type="button" class="ac-iconbtn ac-iconbtn-glass" data-act="fit" data-ka="pm_fit">' + I.fit + "</button>" +
      (hasPlaces ? '<button type="button" class="ac-iconbtn ac-iconbtn-glass" data-act="reset" data-ka="pm_reset">' + I.reset + "</button>" : "") +
      "</div>");
    if (barEnd) bar.insertBefore(controls, barEnd); else bar.appendChild(controls);

    this.body = body;
    this.canvas = canvas;
    this.bar = bar;
    this.labelRoots = [root, placeHost, modesHost].filter(Boolean);
    this.placeSelect = placeHost ? placeHost.querySelector(".ac-pm-place-select") : null;
    this.modesBox = (modesHost || bar).querySelector(".ac-pm-modes");
    this.clusterInput = bar.querySelector(".ac-pm-cluster input");
    this.groupSwitch = bar.querySelector(".ac-pm-group");
    this.groupInput = this.groupSwitch ? this.groupSwitch.querySelector("input") : null;
    this.routeClear = bar.querySelector(".ac-pm-route-clear");
    this.countEl = bar.querySelector(".ac-pm-count-text");
    if (this.placeSelect && this.placeId) this.placeSelect.value = this.placeId;

    if (this.placeSelect) {
      this.placeSelect.addEventListener("change", function () {
        self.userChosePlace = true;
        self.setPlace(self.placeSelect.value, { source: "user" });
      });
    }
    this.modesBox.addEventListener("click", function (e) {
      var b = e.target.closest(".ac-seg-btn");
      if (b) self.setColorMode(b.getAttribute("data-value"), { source: "user" });
    });
    this.clusterInput.addEventListener("change", function () {
      self.setCluster(self.clusterInput.checked, { source: "user" });
    });
    if (this.groupInput) {
      this.groupInput.addEventListener("change", function () {
        self.setGroup(self.groupInput.checked, { source: "user" });
      });
    }
    bar.querySelector(".ac-pm-iconbtns").addEventListener("click", function (e) {
      var b = e.target.closest("[data-act]");
      if (!b) return;
      var act = b.getAttribute("data-act");
      if (act === "clear-route") self.clearRoute();
      else if (act === "locate") self.locate();
      else if (act === "fit") self.fit();
      else if (act === "reset") self.reset();
    });
    this.relabel();
  };

  P.relabel = function () {
    var self = this;
    this.labelRoots.forEach(function (scope) {
      var q = function (sel, fn) {
        var els = scope.querySelectorAll(sel);
        for (var i = 0; i < els.length; i++) fn(els[i]);
      };
      q("[data-k]", function (e) { e.textContent = self.t(e.getAttribute("data-k")); });
      q("[data-ka]", function (e) {
        var txt = self.t(e.getAttribute("data-ka"));
        e.setAttribute("aria-label", txt);
        e.setAttribute("title", txt);
      });
      q("[data-kt]", function (e) { e.setAttribute("title", self.t(e.getAttribute("data-kt"))); });
    });
    this.bar.setAttribute("aria-label", this.t("pm_toolbar_aria"));
    if (this.map) {
      if (this.zoomCtl) this.map.removeControl(this.zoomCtl);
      this.zoomCtl = L.control.zoom({
        position: "topleft", zoomInTitle: this.t("pm_zoom_in"), zoomOutTitle: this.t("pm_zoom_out")
      }).addTo(this.map);
      this._renderLegend();
      this._renderCount();
    }
  };

  /* ---------------------------------------------------------------- tiles
   * Key-free providers only. OpenStreetMap's tile policy wants a Referer,
   * which pages opened from disk (file://) do not send, so "auto" uses Esri's
   * public street map there and OpenStreetMap otherwise. The colours follow
   * the time of day through a CSS filter (see aconteceR.css), so one tile set
   * serves every phase.                                                     */
  var OSM_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a>';
  PointMap.TILES = {
    osm: { url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", subdomains: "abc", attribution: OSM_ATTR, maxZoom: 19 },
    esri: {
      url: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
      attribution: "Tiles &copy; Esri &mdash; Esri, HERE, Garmin, " + OSM_ATTR + " contributors", maxZoom: 19
    }
  };

  // opts.tiles: "auto" (default), "osm", "esri", a {url, attribution,
  // subdomains, maxZoom} object, or {light: {...}, dark: {...}}.
  P._tileSpec = function () {
    var t = this.opts.tiles || "auto";
    if (t === "auto") t = global.location && global.location.protocol === "file:" ? "esri" : "osm";
    if (typeof t === "string") t = PointMap.TILES[t] || PointMap.TILES.osm;
    if (t.light || t.dark) {
      var dark = document.documentElement.getAttribute("data-theme") === "dark";
      return (dark ? t.dark : t.light) || t.light || t.dark;
    }
    return t;
  };

  P._applyTiles = function () {
    var spec = this._tileSpec();
    if (this._tileUrl === spec.url) return;
    if (this.tileLayer) this.map.removeLayer(this.tileLayer);
    this._tileUrl = spec.url;
    this.tileLayer = L.tileLayer(spec.url, {
      attribution: spec.attribution || OSM_ATTR, maxZoom: spec.maxZoom || 19, subdomains: spec.subdomains || "abc"
    }).addTo(this.map);
    this.tileLayer.bringToBack();
  };

  /* ------------------------------------------------------------------ map */
  P._initMap = function () {
    var self = this, o = this.opts;
    var start = this.place() || { lat: 0, lon: 0 };
    var map = this.map = L.map(this.canvas, {
      zoomControl: false, minZoom: 3, worldCopyJump: true,
      zoomAnimation: !REDUCED_MOTION, fadeAnimation: !REDUCED_MOTION, markerZoomAnimation: !REDUCED_MOTION
    });
    this._applyTiles();
    if (global.MutationObserver) {
      new global.MutationObserver(function () { self._applyTiles(); })
        .observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    }
    L.control.scale({ position: "bottomleft", imperial: false }).addTo(map);

    this.layer = L.layerGroup().addTo(map);
    this.routeLayer = L.layerGroup().addTo(map);
    this.haloLayer = L.layerGroup().addTo(map);
    this.pickLayer = L.layerGroup().addTo(map);

    var Legend = L.Control.extend({
      options: { position: "topright" },
      onAdd: function () {
        var div = L.DomUtil.create("div", "ac-pm-legend");
        L.DomEvent.disableClickPropagation(div);
        L.DomEvent.disableScrollPropagation(div);
        return div;
      }
    });
    this.legendCtl = new Legend().addTo(map);
    this.legendCtl.getContainer().addEventListener("click", function (e) {
      if (e.target.closest(".ac-pm-legend-head")) {
        self.legendOpen = !self.legendOpen;
        self._renderLegend();
        return;
      }
      var g = e.target.closest("[data-group]");
      if (g) self.zoomToGroup(g.getAttribute("data-group"));
    });

    map.setView([start.lat, start.lon], o.zoom || 12);
    this.relabel();

    map.on("zoomend", function () { if (self.clusterOn) self._draw(); });
    // Popups built on the server may carry <span data-ac-icon> placeholders.
    map.on("popupopen", function (e) {
      var node = e.popup && e.popup.getElement && e.popup.getElement();
      if (node && AC.ui && AC.ui.icons) AC.ui.icons(node);
    });
    map.on("click", function (e) {
      if (o.pickable === false) return;
      self._setPick(e.latlng.lat, e.latlng.lng);
      self._emit("onPick", { lat: e.latlng.lat, lon: e.latlng.lng });
    });
    // Buttons inside popups, e.g. the list shown for a cluster at one spot.
    this.canvas.addEventListener("click", function (e) {
      var b = e.target.closest("[data-pm-id]");
      if (b) { e.preventDefault(); self.openPopup(b.getAttribute("data-pm-id")); }
    });

    if (global.ResizeObserver) {
      new global.ResizeObserver(function () { map.invalidateSize(false); }).observe(this.canvas);
    } else {
      global.addEventListener("resize", function () { map.invalidateSize(false); });
    }
  };

  /* --------------------------------------------------------------- places */
  P.place = function () {
    for (var i = 0; i < this.places.length; i++) if (this.places[i].id === this.placeId) return this.places[i];
    return this.places[0] || null;
  };

  P.setPlace = function (id, o) {
    o = o || {};
    var prev = this.placeId;
    this.placeId = String(id);
    if (this.placeSelect && this.placeSelect.value !== this.placeId) this.placeSelect.value = this.placeId;
    var p = this.place();
    if (p && o.move !== false) this._moveTo([p.lat, p.lon], this.opts.zoom || 12);
    this.clearPick();
    if (prev !== this.placeId) this.clearRoute();
    if (prev !== this.placeId || o.force) this._emit("onPlace", this.placeId, o.source || "api");
  };

  P._moveTo = function (latlng, zoom) {
    if (REDUCED_MOTION) this.map.setView(latlng, zoom);
    else this.map.flyTo(latlng, zoom, { duration: 0.8 });
  };

  P.reset = function () {
    var p = this.place();
    if (p) this._moveTo([p.lat, p.lon], this.opts.zoom || 12);
  };

  P.fit = function () {
    var pts = this._validPoints();
    if (!pts.length) { this.reset(); return; }
    if (pts.length === 1) { this._moveTo([pts[0].lat, pts[0].lon], 15); return; }
    var b = L.latLngBounds(pts.map(function (p) { return [p.lat, p.lon]; }));
    this.map.fitBounds(b, { padding: [48, 48], maxZoom: 16, animate: !REDUCED_MOTION });
  };

  /* -------------------------------------------------------------- locate */
  P._autoLocate = function (mode) {
    var self = this;
    if (!this.places.length) return;
    var tz = AC.geo.fromTimezone();
    if (tz) this._applyGeo(tz, { quietIfSame: true });
    if (mode === "timezone") return;
    AC.geo.locate(function (pos) { if (pos) self._applyGeo(pos, {}); }, { skipIfDenied: true });
  };

  P.locate = function () {
    var self = this;
    AC.geo.locate(function (pos) {
      if (pos) self._applyGeo(pos, { manual: true });
      else AC.ui.toast(self.t("geo_failed"), { kind: "warning" });
    });
  };

  P._applyGeo = function (pos, o) {
    if (this.userChosePlace && !o.manual) return;
    var near = AC.geo.nearest(this.places, pos.lat, pos.lon);
    if (!near) return;
    var same = near.place.id === this.placeId;
    if (!same || o.manual) this.setPlace(near.place.id, { source: pos.source });
    if (o.manual) this.userChosePlace = true;
    var info = { placeId: near.place.id, label: near.place.label, km: near.km, source: pos.source, lat: pos.lat, lon: pos.lon };
    this._emit("onLocate", info);
    if (o.quietIfSame && same) return;
    var km = AC.fmt ? AC.fmt.km(near.km) : Math.round(near.km) + " km";
    var msg;
    if (pos.source === "timezone") msg = this.tf("geo_timezone", near.place.label);
    else if (near.km > (this.opts.farKm || 150)) msg = this.tf("geo_far", near.place.label, km);
    else msg = this.tf("geo_nearest", near.place.label, km);
    AC.ui.toast(msg);
  };

  /* ------------------------------------------------------- colour modes */
  P.setColorModes = function (modes, activeId) {
    this.modes = util.asArray(modes).map(color.normalize).filter(Boolean);
    var want = activeId !== undefined && activeId !== null ? String(activeId) : this.modeId;
    var ids = this.modes.map(function (m) { return String(m.id); });
    this.modeId = ids.indexOf(want) >= 0 ? want : (ids[0] || null);
    var box = this.modesBox;
    box.innerHTML = this.modes.map(function (m) {
      return '<button type="button" class="ac-seg-btn" data-value="' + esc(m.id) + '">' + esc(m.label || m.id) + "</button>";
    }).join("");
    AC.ui.setSegmented(box, this.modeId);
    box.parentNode.hidden = this.modes.length < 2;
    this._draw();
  };

  P.setColorMode = function (id, o) {
    id = String(id);
    if (id === this.modeId) return;
    this.modeId = id;
    AC.ui.setSegmented(this.modesBox, id);
    this._draw();
    this._emit("onColorMode", id, (o && o.source) || "api");
  };

  P.colorSpec = function () {
    for (var i = 0; i < this.modes.length; i++) if (String(this.modes[i].id) === this.modeId) return this.modes[i];
    return null;
  };

  P.colorOf = function (item) { return color.resolve(this.colorSpec(), item).color; };

  P.setCluster = function (on, o) {
    on = !!on;
    if (this.clusterInput.checked !== on) this.clusterInput.checked = on;
    if (on === this.clusterOn) return;
    this.clusterOn = on;
    this._draw();
    this._emit("onCluster", on, (o && o.source) || "api");
  };

  /* --------------------------------------------------------------- points */
  P.setPoints = function (points) {
    this.points = util.asArray(points).map(function (p) {
      var q = {};
      for (var k in p) if (Object.prototype.hasOwnProperty.call(p, k)) q[k] = p[k];
      q.id = String(p.id);
      q.lat = Number(p.lat);
      q.lon = Number(p.lon);
      return q;
    });
    // A popup or halo for a point that is gone (filters, mode switch) goes too.
    if (this.highlightId && !this._popupExternal && !this._find(this.highlightId)) {
      if (this.map) this.map.closePopup();
      this.highlightId = null;
      this._haloPoint = null;
    }
    this._draw();
    if (this._fitNext) { this._fitNext = false; this.fit(); }
  };

  // Fit the map to the points of the next setPoints() call (used when the
  // host changes a filter and the new points arrive asynchronously).
  // Falls back to fitting the current points if nothing arrives in time
  // (e.g. the filter did not actually change).
  P.fitNext = function () {
    var self = this;
    this._fitNext = true;
    clearTimeout(this._fitTimer);
    this._fitTimer = setTimeout(function () {
      if (self._fitNext) { self._fitNext = false; self.fit(); }
    }, 1500);
  };

  P._validPoints = function () {
    return this.points.filter(function (p) { return isFinite(p.lat) && isFinite(p.lon); });
  };

  P._find = function (id) {
    id = String(id);
    for (var i = 0; i < this.points.length; i++) if (this.points[i].id === id) return this.points[i];
    return null;
  };

  P._draw = function () {
    if (!this.map) return;
    var self = this, spec = this.colorSpec();
    var pts = this._validPoints();
    this.layer.clearLayers();
    this.markers = {};
    var zoom = this.map.getZoom();
    var maxClusterZoom = this.opts.clusterMaxZoom || 18;
    this._groups = this._groupPoints(pts);
    if (this.groupSwitch) {
      var usable = this._groups.length >= 2;
      this.groupSwitch.hidden = !usable;
      if (!usable && this.groupOn) { this.groupOn = false; this.groupInput.checked = false; }
    }
    if (this.groupOn) {
      this._drawGroups(spec);
    } else if (this.clusterOn && pts.length > 1 && zoom < maxClusterZoom) {
      this._cluster(pts, zoom).forEach(function (c) {
        if (c.items.length === 1) self._addPin(c.items[0], spec);
        else self._addCluster(c.items, spec);
      });
    } else {
      pts.forEach(function (p) { self._addPin(p, spec); });
    }
    this._renderHalo();
    this._renderLegend();
    this._renderCount();
  };

  /* -------------------------------------------------------------- groups */
  // Points by the groupBy column, largest group first.
  P._groupPoints = function (pts) {
    var col = this.opts.groupBy;
    if (!col) return [];
    var by = {}, list = [];
    pts.forEach(function (p) {
      var k = p[col];
      if (k === null || k === undefined || String(k).trim() === "") return;
      k = String(k);
      if (!by[k]) { by[k] = { key: k, items: [] }; list.push(by[k]); }
      by[k].items.push(p);
    });
    // Centre: the median point, so one stray pin does not drag it.
    list.forEach(function (g) {
      g.lat = median(g.items.map(function (p) { return p.lat; }));
      g.lon = median(g.items.map(function (p) { return p.lon; }));
    });
    list.sort(function (a, b) { return b.items.length - a.items.length || a.key.localeCompare(b.key); });
    return list;
  };

  function median(xs) {
    var s = xs.slice().sort(function (a, b) { return a - b; }), n = s.length;
    return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2;
  }

  P.setGroup = function (on, o) {
    on = !!on && !!this.opts.groupBy;
    if (this.groupInput && this.groupInput.checked !== on) this.groupInput.checked = on;
    if (on === this.groupOn) return;
    this.groupOn = on;
    this.map.closePopup();
    this._draw();
    if (on && this._groups.length > 1) {
      // Fit the bubbles (group centres), close enough that they separate.
      var b = L.latLngBounds(this._groups.map(function (g) { return [g.lat, g.lon]; }));
      this._fitClear(b, 16);
    }
    this._emit("onGroup", on, (o && o.source) || "api");
  };

  // Leave the group view and zoom to one group's pins.
  P.zoomToGroup = function (key) {
    var g = null;
    for (var i = 0; i < this._groups.length; i++) if (this._groups[i].key === key) g = this._groups[i];
    if (!g) return;
    this.setGroup(false, { source: "user" });
    var b = L.latLngBounds(g.items.map(function (p) { return [p.lat, p.lon]; }));
    if (g.items.length === 1) this._moveTo([g.items[0].lat, g.items[0].lon], 16);
    else this.map.fitBounds(b, { padding: [60, 60], maxZoom: 17, animate: !REDUCED_MOTION });
  };

  P._drawGroups = function (spec) {
    var self = this, groups = this._groups;
    var max = groups.length ? groups[0].items.length : 1;
    groups.forEach(function (g) {
      var n = g.items.length;
      var lat = g.lat, lon = g.lon;
      var top = color.summary(spec, g.items);
      g.top = top;
      var d = Math.round(26 + 34 * Math.sqrt(n / max));
      var icon = L.divIcon({
        className: "ac-pm-group-icon", iconSize: [d, d], iconAnchor: [d / 2, d / 2],
        html: '<div class="ac-pm-group-bubble" style="--c:' + esc(top.color) + ";width:" + d + "px;height:" + d + 'px">' +
          "<b>" + n + "</b></div>" + '<span class="ac-pm-group-name">' + esc(g.key) + "</span>"
      });
      var m = L.marker([lat, lon], { icon: icon, keyboard: true, title: g.key, riseOnHover: true });
      m.bindTooltip("<strong>" + esc(g.key) + "</strong><br>" + esc(self.tf("group_count", n)) +
        (top.label ? "<br>" + esc(self.tf("group_top", top.label)) : ""), { direction: "top", offset: [0, -d / 2], className: "ac-pm-tip" });
      m.on("click", function () { self.zoomToGroup(g.key); });
      m.addTo(self.layer);
      g.items.forEach(function (p) { self.markers[p.id] = m; });
    });
  };

  /* --------------------------------------------------------------- route */
  // Numbered stops joined by a dashed line (e.g. a planned night out).
  P.setRoute = function (stops) {
    var self = this;
    this.route = util.asArray(stops).filter(function (s) { return isFinite(Number(s.lat)) && isFinite(Number(s.lon)); });
    this.routeLayer.clearLayers();
    if (this.routeClear) this.routeClear.hidden = !this.route.length;
    if (!this.route.length) return;
    var latlngs = this.route.map(function (s) { return [Number(s.lat), Number(s.lon)]; });
    L.polyline(latlngs, { className: "ac-pm-route-line", weight: 4, opacity: 0.9, dashArray: "1 9", lineCap: "round", interactive: false })
      .addTo(this.routeLayer);
    this.route.forEach(function (s, i) {
      var icon = L.divIcon({ className: "ac-pm-route-icon", iconSize: [30, 30], iconAnchor: [15, 15],
                             html: '<span class="ac-pm-route-n">' + esc(s.n || i + 1) + "</span>" });
      var m = L.marker([Number(s.lat), Number(s.lon)], { icon: icon, keyboard: true, title: s.label || "", zIndexOffset: 1000 });
      if (s.label) m.bindTooltip(esc(s.label), { direction: "top", offset: [0, -14], className: "ac-pm-tip" });
      m.on("click", function () {
        L.popup({ maxWidth: 300, offset: [0, -10], className: "ac-pm-popup" })
          .setLatLng([Number(s.lat), Number(s.lon)])
          .setContent(s.popup ? String(s.popup) : "<strong>" + esc(s.label || "") + "</strong>").openOn(self.map);
      });
      m.addTo(self.routeLayer);
    });
    if (latlngs.length === 1) this._moveTo(latlngs[0], 16);
    else this._fitClear(L.latLngBounds(latlngs), 16);
  };

  // Fit bounds clear of the legend (top right) and the floating bar (bottom).
  P._fitClear = function (bounds, maxZoom) {
    var legend = this.legendCtl && this.legendCtl.getContainer();
    var right = legend && legend.style.display !== "none" && legend.offsetWidth ? legend.offsetWidth + 40 : 60;
    var bottom = this.bar && this.bar.offsetHeight ? this.bar.offsetHeight + 50 : 60;
    this.map.fitBounds(bounds, { paddingTopLeft: [70, 60], paddingBottomRight: [right, bottom], maxZoom: maxZoom, animate: !REDUCED_MOTION });
  };

  P.clearRoute = function () {
    this.route = [];
    if (this.routeLayer) this.routeLayer.clearLayers();
    if (this.routeClear) this.routeClear.hidden = true;
  };

  P._addPin = function (p, spec) {
    var self = this;
    var m = L.circleMarker([p.lat, p.lon], {
      radius: 8, weight: 2, color: "#ffffff", opacity: 1,
      fillColor: color.resolve(spec, p).color, fillOpacity: 0.95, className: "ac-pm-pin"
    });
    m.bindPopup(this._popupHtml(p), { maxWidth: 300, className: "ac-pm-popup" });
    if (p.label) m.bindTooltip(esc(p.label), { direction: "top", offset: [0, -8], className: "ac-pm-tip" });
    m.on("click", function () { self._emit("onMarkerClick", p.id); });
    m.addTo(this.layer);
    this.markers[p.id] = m;
  };

  P._popupHtml = function (p) {
    return p.popup ? String(p.popup) : "<strong>" + esc(p.label || p.id) + "</strong>";
  };

  // Greedy pixel-radius clustering at the current zoom, using a grid index
  // so each point only checks its neighbouring cells.
  P._cluster = function (pts, zoom) {
    var map = this.map, R = this.opts.clusterRadius || 46;
    var proj = pts.map(function (p) {
      var q = map.project([p.lat, p.lon], zoom);
      return { p: p, x: q.x, y: q.y, gx: Math.floor(q.x / R), gy: Math.floor(q.y / R) };
    });
    var grid = {};
    proj.forEach(function (q, i) {
      var k = q.gx + ":" + q.gy;
      (grid[k] = grid[k] || []).push(i);
    });
    var used = [], out = [];
    for (var i = 0; i < proj.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      var q = proj[i], items = [q.p];
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          var cell = grid[(q.gx + dx) + ":" + (q.gy + dy)] || [];
          for (var c = 0; c < cell.length; c++) {
            var j = cell[c];
            if (used[j]) continue;
            var ddx = proj[j].x - q.x, ddy = proj[j].y - q.y;
            if (ddx * ddx + ddy * ddy <= R * R) { used[j] = true; items.push(proj[j].p); }
          }
        }
      }
      out.push({ items: items });
    }
    return out;
  };

  // Cluster icon: a donut split by the active colour mode, count in the middle.
  P._clusterIcon = function (items, spec) {
    var n = items.length;
    var size = Math.round(32 + Math.min(18, (Math.log(n) / Math.LN2) * 3.5));
    var sw = 5, r = size / 2 - sw / 2 - 1, C = 2 * Math.PI * r, off = 0;
    var rows = color.legend(spec, items);
    var arcs = rows.map(function (row) {
      var len = (row.count / n) * C;
      var s = '<circle cx="' + size / 2 + '" cy="' + size / 2 + '" r="' + r.toFixed(2) + '" fill="none" stroke="' +
        esc(row.color) + '" stroke-width="' + sw + '" stroke-dasharray="' + len.toFixed(2) + " " + (C - len).toFixed(2) +
        '" stroke-dashoffset="' + (-off).toFixed(2) + '"/>';
      off += len;
      return s;
    }).join("");
    var html = '<div class="ac-pm-cluster-marker" style="width:' + size + "px;height:" + size + 'px">' +
      '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + " " + size + '" aria-hidden="true">' +
      '<circle class="ac-pm-cluster-bg" cx="' + size / 2 + '" cy="' + size / 2 + '" r="' + (r + sw / 2).toFixed(2) + '"/>' +
      '<g transform="rotate(-90 ' + size / 2 + " " + size / 2 + ')">' + arcs + "</g></svg>" +
      "<span>" + n + "</span></div>";
    return L.divIcon({ html: html, className: "ac-pm-cluster-icon", iconSize: [size, size] });
  };

  P._addCluster = function (items, spec) {
    var self = this, lat = 0, lon = 0;
    items.forEach(function (p) { lat += p.lat; lon += p.lon; });
    lat /= items.length; lon /= items.length;
    var m = L.marker([lat, lon], {
      icon: this._clusterIcon(items, spec), keyboard: true,
      title: this.tf("pm_cluster_items", items.length), riseOnHover: true
    });
    m.on("click", function () {
      var b = L.latLngBounds(items.map(function (p) { return [p.lat, p.lon]; }));
      var samePlace = b.getNorthEast().distanceTo(b.getSouthWest()) < 15;
      if (samePlace || self.map.getZoom() >= (self.opts.clusterMaxZoom || 18) - 1) {
        self._listPopup([lat, lon], items);
      } else {
        self.map.fitBounds(b, { padding: [60, 60], maxZoom: self.map.getZoom() + 4, animate: !REDUCED_MOTION });
      }
    });
    m.addTo(this.layer);
    items.forEach(function (p) { self.markers[p.id] = m; });
  };

  P._listPopup = function (latlng, items) {
    var self = this;
    var html = '<div class="ac-pm-list"><div class="ac-pm-list-head">' + esc(this.tf("pm_cluster_items", items.length)) +
      "</div><ul>" + items.map(function (p) {
        var dot = '<span class="ac-swatch" style="background:' + esc(self.colorOf(p)) + '"></span>';
        return '<li><button type="button" data-pm-id="' + esc(p.id) + '">' + dot + "<span>" + esc(p.label || p.id) + "</span></button></li>";
      }).join("") + "</ul></div>";
    L.popup({ maxWidth: 320, className: "ac-pm-popup" }).setLatLng(latlng).setContent(html).openOn(this.map);
  };

  P.openPopup = function (id) {
    var p = this._find(id);
    this._popupExternal = false;
    return p ? this._openPopupFor(p) : false;
  };

  P._openPopupFor = function (p) {
    L.popup({ maxWidth: 300, offset: [0, -4], className: "ac-pm-popup" })
      .setLatLng([p.lat, p.lon]).setContent(this._popupHtml(p)).openOn(this.map);
    this._haloPoint = p;
    this.highlightId = p.id;
    this._renderHalo();
    return true;
  };

  // Fly to a point and open its popup, even when it sits inside a cluster.
  // Accepts an id, or a point object ({id, lat, lon, label, popup}) for items
  // that are not among the drawn points (e.g. a search result elsewhere).
  P.focus = function (target) {
    var self = this, p;
    var external = false;
    if (target && typeof target === "object") {
      p = this._find(target.id);
      if (!p) {
        external = true;
        p = { id: String(target.id), lat: Number(target.lat), lon: Number(target.lon), label: target.label, popup: target.popup };
      }
    } else {
      p = this._find(target);
    }
    if (!p || !isFinite(p.lat) || !isFinite(p.lon)) return false;
    if (this.groupOn) this.setGroup(false, { source: "api" });
    // An item from elsewhere (a search result) keeps its popup when the
    // points change; one of our points loses it when it leaves the map.
    this._popupExternal = external;
    var zoom = Math.max(this.map.getZoom(), 16);
    this.map.closePopup();
    if (REDUCED_MOTION) {
      this.map.setView([p.lat, p.lon], zoom);
      this._openPopupFor(p);
    } else {
      this.map.once("moveend", function () { self._openPopupFor(p); });
      this.map.flyTo([p.lat, p.lon], zoom, { duration: 0.7 });
    }
    return true;
  };

  // A pulsing ring around one point (null clears it). Used for list hover.
  P.highlight = function (id) {
    this.highlightId = id === null || id === undefined ? null : String(id);
    this._haloPoint = null;
    this._renderHalo();
  };

  P._renderHalo = function () {
    this.haloLayer.clearLayers();
    if (!this.highlightId) return;
    var p = this._find(this.highlightId) || (this._haloPoint && this._haloPoint.id === this.highlightId ? this._haloPoint : null);
    if (!p || !isFinite(p.lat)) return;
    L.circleMarker([p.lat, p.lon], {
      radius: 15, weight: 3, color: this.colorOf(p), fill: false, interactive: false, className: "ac-pm-halo"
    }).addTo(this.haloLayer);
  };

  /* ----------------------------------------------------------------- pick */
  P._setPick = function (lat, lon) {
    this.pickLayer.clearLayers();
    var icon = L.divIcon({
      className: "ac-pm-pick-icon", iconSize: [26, 34], iconAnchor: [13, 33],
      html: '<svg viewBox="0 0 26 34" width="26" height="34" aria-hidden="true"><path class="ac-pm-pick-shape" ' +
        'd="M13 33S2 20.5 2 12.5a11 11 0 0 1 22 0C24 20.5 13 33 13 33z"/><circle cx="13" cy="12.5" r="4" fill="#fff"/></svg>'
    });
    L.marker([lat, lon], { icon: icon, keyboard: false, title: this.t("pm_picked") }).addTo(this.pickLayer);
  };

  P.clearPick = function () { if (this.pickLayer) this.pickLayer.clearLayers(); };

  /* --------------------------------------------------------- legend/count */
  P._renderLegend = function () {
    if (!this.legendCtl) return;
    var box = this.legendCtl.getContainer();
    if (this.groupOn && this._groups && this._groups.length) {
      var self = this;
      box.style.display = "";
      box.innerHTML =
        '<button type="button" class="ac-pm-legend-head" aria-expanded="' + (this.legendOpen ? "true" : "false") + '">' +
        "<span>" + esc(this.t("group_top_list")) + "</span>" + '<span class="ac-pm-legend-caret" aria-hidden="true"></span></button>' +
        (this.legendOpen ? '<ul class="ac-pm-legend-rows ac-pm-group-rows">' + this._groups.slice(0, 5).map(function (g) {
          var top = g.top || color.summary(self.colorSpec(), g.items);
          return '<li><button type="button" data-group="' + esc(g.key) + '" title="' + esc(top.label ? self.tf("group_top", top.label) : g.key) + '">' +
            '<span class="ac-swatch" style="background:' + esc(top.color) + '"></span>' +
            '<span class="ac-pm-legend-label">' + esc(g.key) + '</span><span class="ac-pm-legend-n">' + g.items.length + "</span></button></li>";
        }).join("") + "</ul>" : "");
      return;
    }
    var spec = this.colorSpec();
    var rows = spec ? color.legend(spec, this._validPoints()) : [];
    if (!spec || !rows.length) { box.style.display = "none"; return; }
    box.style.display = "";
    box.innerHTML =
      '<button type="button" class="ac-pm-legend-head" aria-expanded="' + (this.legendOpen ? "true" : "false") + '">' +
      "<span>" + esc(spec.title || spec.label || this.t("pm_legend")) + "</span>" +
      '<span class="ac-pm-legend-caret" aria-hidden="true"></span></button>' +
      (this.legendOpen ? '<ul class="ac-pm-legend-rows">' + rows.map(function (r) {
        return '<li><span class="ac-swatch" style="background:' + esc(r.color) + '"></span>' +
          '<span class="ac-pm-legend-label">' + esc(r.label) + '</span><span class="ac-pm-legend-n">' + r.count + "</span></li>";
      }).join("") + "</ul>" : "");
  };

  P._renderCount = function () {
    if (this.countEl) this.countEl.textContent = this.tf("pm_count", this._validPoints().length);
  };

  AC.PointMap = PointMap;
})(window);
