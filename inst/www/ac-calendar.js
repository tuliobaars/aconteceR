/*! AC.MonthCalendar (MIT licence). A month grid with coloured event chips,
 * a day agenda panel and keyboard navigation (arrows, Home/End, PageUp/Down).
 *
 *   var cal = new AC.MonthCalendar(element, {items, colorSpec, month, t,
 *     onMonth, onSelect, onItem, onShowDay, onShowMonth});
 *   cal.setItems([{id, starts_at: "YYYY-MM-DD HH:MM", title, meta, ...}]);
 *   cal.setColorSpec(spec);       // same colour spec the map uses
 *
 * Colours come from the colour spec (see AC.color), so the calendar always
 * matches the map's "colour by" choice.                                     */
(function (global) {
  "use strict";
  var AC = global.AC, util = AC.util, esc = AC.util.escapeHtml;

  var DEFAULT_TEXT = {
    cal_prev: "Previous month", cal_next: "Next month", cal_today: "Today",
    cal_month_count_one: "%d event this month", cal_month_count_many: "%d events this month",
    cal_more: "+%d more", cal_day_empty: "Nothing on this day.", cal_pick_day: "Pick a day.",
    cal_show_day_on_map: "Show this day on the map", cal_show_month_on_map: "Show this month on the map",
    cal_close: "Close", cal_filters_note: "", count_events_one: "%d event", count_events_many: "%d events"
  };

  function ym(d) { return d.getFullYear() + "-" + util.pad2(d.getMonth() + 1); }

  function MonthCalendar(root, opts) {
    if (!(this instanceof MonthCalendar)) return new MonthCalendar(root, opts);
    opts = opts || {};
    this.root = root;
    this.opts = opts;
    this.items = [];
    this.byDate = {};
    this.spec = opts.colorSpec ? AC.color.normalize(opts.colorSpec) : null;
    this.month = opts.month || ym(new Date());
    this.selected = opts.selected || null;
    this.focusDate = this.selected || null;
    root.classList.add("ac-cal");
    this._bind();
    if (opts.items) this.setItems(opts.items); else this.render();
  }

  var P = MonthCalendar.prototype;

  P.t = function (key) {
    if (this.opts.t) {
      var v = this.opts.t(key);
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

  P.weekStart = function () {
    if (this.opts.weekStart !== undefined) return Number(this.opts.weekStart) || 0;
    var w = AC.i18n && AC.i18n.has("week_start") ? Number(AC.i18n.t("week_start")) : 0;
    return isFinite(w) ? w : 0;
  };

  P.setItems = function (items) {
    var byDate = {};
    this.items = util.asArray(items).map(function (it) {
      var s = String(it.starts_at || it.date || "");
      var q = {};
      for (var k in it) if (Object.prototype.hasOwnProperty.call(it, k)) q[k] = it[k];
      q.id = String(it.id);
      q._date = s.slice(0, 10);
      q._time = it.time || (s.length >= 16 ? s.slice(11, 16) : "");
      return q;
    }).filter(function (it) { return /^\d{4}-\d{2}-\d{2}$/.test(it._date); });
    this.items.sort(function (a, b) {
      return (a._date + a._time).localeCompare(b._date + b._time);
    });
    this.items.forEach(function (it) { (byDate[it._date] = byDate[it._date] || []).push(it); });
    this.byDate = byDate;
    this.render();
  };

  P.setColorSpec = function (spec) {
    this.spec = spec ? AC.color.normalize(spec) : null;
    this.render();
  };

  P.colorOf = function (it) { return AC.color.resolve(this.spec, it).color; };

  P.setMonth = function (month, o) {
    if (!/^\d{4}-\d{2}$/.test(month || "")) return;
    var changed = month !== this.month;
    this.month = month;
    if (this.selected && this.selected.slice(0, 7) !== month) this.selected = null;
    this.render();
    if (changed) this._emit("onMonth", month, (o && o.source) || "api");
  };

  P.shiftMonth = function (delta) {
    var p = this.month.split("-");
    this.setMonth(ym(new Date(Number(p[0]), Number(p[1]) - 1 + delta, 1)), { source: "user" });
  };

  P.select = function (iso, o) {
    if (iso && iso.slice(0, 7) !== this.month) this.month = iso.slice(0, 7);
    this.selected = iso || null;
    if (iso) this.focusDate = iso;
    this.render();
    this._emit("onSelect", this.selected, (o && o.source) || "api");
  };

  P.relabel = function () { this.render(); };

  /* --------------------------------------------------------------- render */
  P._days = function () {
    var p = this.month.split("-");
    var y = Number(p[0]), m = Number(p[1]) - 1;
    var first = new Date(y, m, 1);
    var lead = (first.getDay() - this.weekStart() + 7) % 7;
    var daysInMonth = new Date(y, m + 1, 0).getDate();
    var weeks = Math.ceil((lead + daysInMonth) / 7);
    var out = [];
    for (var i = 0; i < weeks * 7; i++) out.push(new Date(y, m, 1 - lead + i));
    return { year: y, month: m, days: out };
  };

  P.render = function () {
    var self = this, g = this._days();
    var today = util.today();
    var ws = this.weekStart();
    var wdMin = this.t("wd_min");
    var maxChips = this.opts.maxChips || 3;
    if (!Array.isArray(wdMin)) wdMin = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    var inMonth = this.items.filter(function (it) { return it._date.slice(0, 7) === self.month; });
    var focus = this.focusDate && this.focusDate.slice(0, 7) === this.month ? this.focusDate
      : (this.selected || (today.slice(0, 7) === this.month ? today : this.month + "-01"));
    this.focusDate = focus;

    var dows = "";
    for (var c = 0; c < 7; c++) {
      var wd = (ws + c) % 7;
      dows += '<div class="ac-cal-dow' + (wd === 0 || wd === 6 ? " is-weekend" : "") + '" role="columnheader">' +
        esc(wdMin[wd]) + "</div>";
    }

    var rows = "";
    for (var r = 0; r < g.days.length / 7; r++) {
      rows += '<div class="ac-cal-row" role="row">';
      for (var k = 0; k < 7; k++) {
        var d = g.days[r * 7 + k];
        var iso = util.isoDate(d);
        var list = this.byDate[iso] || [];
        var cls = ["ac-cal-cell"];
        if (d.getMonth() !== g.month) cls.push("is-outside");
        if (iso === today) cls.push("is-today");
        if (iso === this.selected) cls.push("is-selected");
        if (d.getDay() === 0 || d.getDay() === 6) cls.push("is-weekend");
        if (list.length) cls.push("has-items");
        var label = AC.fmt.dayLong(iso) + (list.length ? ", " + this.tf(list.length === 1 ? "count_events_one" : "count_events_many", list.length) : "");
        var chips = list.slice(0, maxChips).map(function (it) {
          return '<li><button type="button" class="ac-cal-chip" data-id="' + esc(it.id) + '" title="' +
            esc((it._time ? it._time + " \u00b7 " : "") + (it.title || "")) + '" tabindex="-1">' +
            '<span class="ac-swatch" style="background:' + esc(self.colorOf(it)) + '"></span>' +
            (it._time ? '<span class="ac-cal-chip-time">' + esc(it._time) + "</span>" : "") +
            '<span class="ac-cal-chip-title">' + esc(it.title || "") + "</span></button></li>";
        }).join("");
        var dots = list.slice(0, 6).map(function (it) {
          return '<span class="ac-swatch" style="background:' + esc(self.colorOf(it)) + '"></span>';
        }).join("");
        rows += '<div class="' + cls.join(" ") + '" role="gridcell" data-date="' + iso + '"' +
          (iso === this.selected ? ' aria-selected="true"' : "") + ">" +
          '<button type="button" class="ac-cal-daynum" data-date="' + iso + '" tabindex="' + (iso === focus ? "0" : "-1") +
          '" aria-label="' + esc(label) + '">' + d.getDate() + "</button>" +
          (list.length ? '<span class="ac-cal-n" aria-hidden="true">' + list.length + "</span>" : "") +
          (chips ? '<ul class="ac-cal-chips">' + chips + "</ul>" : "") +
          (list.length > maxChips ? '<button type="button" class="ac-cal-more" data-date="' + iso + '" tabindex="-1">' +
            esc(this.tf("cal_more", list.length - maxChips)) + "</button>" : "") +
          (dots ? '<div class="ac-cal-dots" aria-hidden="true">' + dots + "</div>" : "") +
          "</div>";
      }
      rows += "</div>";
    }

    var I = AC.icons;
    var countKey = inMonth.length === 1 ? "cal_month_count_one" : "cal_month_count_many";
    var note = this.t("cal_filters_note");
    this.root.innerHTML =
      '<div class="ac-cal-head">' +
      '<div class="ac-cal-nav">' +
      '<button type="button" class="ac-iconbtn" data-act="prev" aria-label="' + esc(this.t("cal_prev")) + '" title="' + esc(this.t("cal_prev")) + '">' + I.chevronLeft + "</button>" +
      '<h2 class="ac-cal-title" id="' + this._titleId() + '" aria-live="polite">' + esc(AC.fmt.monthTitle(g.year, g.month)) + "</h2>" +
      '<button type="button" class="ac-iconbtn" data-act="next" aria-label="' + esc(this.t("cal_next")) + '" title="' + esc(this.t("cal_next")) + '">' + I.chevronRight + "</button>" +
      '<button type="button" class="ac-btn ac-btn-ghost ac-btn-sm" data-act="today">' + esc(this.t("cal_today")) + "</button>" +
      "</div>" +
      '<div class="ac-cal-summary"><span class="ac-cal-count">' + esc(this.tf(countKey, inMonth.length)) + "</span>" +
      (inMonth.length ? '<button type="button" class="ac-linkbtn" data-act="month-map">' + I.map +
        "<span>" + esc(this.t("cal_show_month_on_map")) + "</span></button>" : "") +
      "</div></div>" +
      (note && note !== "cal_filters_note" ? '<p class="ac-cal-note">' + esc(note) + "</p>" : "") +
      '<div class="ac-cal-main">' +
      '<div class="ac-cal-grid" role="grid" aria-labelledby="' + this._titleId() + '">' +
      '<div class="ac-cal-row ac-cal-dows" role="row">' + dows + "</div>" + rows + "</div>" +
      this._panelHtml() + "</div>";
  };

  P._titleId = function () {
    if (!this._tid) this._tid = "ac-cal-title-" + Math.random().toString(36).slice(2, 8);
    return this._tid;
  };

  P._panelHtml = function () {
    var self = this, I = AC.icons;
    if (!this.selected) {
      return '<aside class="ac-cal-panel is-empty"><p class="ac-cal-hint">' + I.calendar +
        "<span>" + esc(this.t("cal_pick_day")) + "</span></p></aside>";
    }
    var list = this.byDate[this.selected] || [];
    var items = list.map(function (it) {
      return '<li><button type="button" class="ac-cal-agenda-item" data-id="' + esc(it.id) + '">' +
        '<span class="ac-swatch" style="background:' + esc(self.colorOf(it)) + '"></span>' +
        '<span class="ac-cal-agenda-time">' + esc(it._time || "") + "</span>" +
        '<span class="ac-cal-agenda-text"><span class="ac-cal-agenda-title">' + esc(it.title || "") + "</span>" +
        (it.meta ? '<span class="ac-cal-agenda-meta">' + esc(it.meta) + "</span>" : "") +
        "</span></button></li>";
    }).join("");
    return '<aside class="ac-cal-panel" aria-label="' + esc(AC.fmt.dayLong(this.selected)) + '">' +
      '<div class="ac-cal-panel-head"><h3>' + esc(AC.fmt.dayLong(this.selected)) + "</h3>" +
      '<button type="button" class="ac-iconbtn ac-iconbtn-sm" data-act="close" aria-label="' + esc(this.t("cal_close")) +
      '" title="' + esc(this.t("cal_close")) + '">' + I.close + "</button></div>" +
      (list.length ? '<ul class="ac-cal-agenda">' + items + "</ul>" : '<p class="ac-cal-hint">' + esc(this.t("cal_day_empty")) + "</p>") +
      (list.length ? '<button type="button" class="ac-btn ac-btn-primary ac-btn-block" data-act="day-map">' + I.map +
        "<span>" + esc(this.t("cal_show_day_on_map")) + "</span></button>" : "") +
      "</aside>";
  };

  /* --------------------------------------------------------------- events */
  P._bind = function () {
    var self = this, root = this.root;
    root.addEventListener("click", function (e) {
      var act = e.target.closest("[data-act]");
      if (act && root.contains(act)) {
        var a = act.getAttribute("data-act");
        if (a === "prev") self.shiftMonth(-1);
        else if (a === "next") self.shiftMonth(1);
        else if (a === "today") { self.setMonth(util.today().slice(0, 7), { source: "user" }); self.select(util.today(), { source: "user" }); }
        else if (a === "close") self.select(null, { source: "user" });
        else if (a === "day-map" && self.selected) self._emit("onShowDay", self.selected);
        else if (a === "month-map") self._emit("onShowMonth", self.month);
        return;
      }
      var item = e.target.closest("[data-id]");
      if (item && root.contains(item)) { self._emit("onItem", item.getAttribute("data-id")); return; }
      var cell = e.target.closest("[data-date]");
      if (cell && root.contains(cell)) {
        var iso = cell.getAttribute("data-date");
        self.select(iso, { source: "user" });
        self._focusDay(iso);
      }
    });
    root.addEventListener("keydown", function (e) {
      var btn = e.target.closest && e.target.closest(".ac-cal-daynum");
      if (!btn) return;
      var iso = btn.getAttribute("data-date");
      var d = util.parseIsoDate(iso);
      var next = null;
      var dow = (d.getDay() - self.weekStart() + 7) % 7;
      switch (e.key) {
        case "ArrowLeft": next = util.addDays(iso, -1); break;
        case "ArrowRight": next = util.addDays(iso, 1); break;
        case "ArrowUp": next = util.addDays(iso, -7); break;
        case "ArrowDown": next = util.addDays(iso, 7); break;
        case "Home": next = util.addDays(iso, -dow); break;
        case "End": next = util.addDays(iso, 6 - dow); break;
        case "PageUp": next = util.isoDate(new Date(d.getFullYear(), d.getMonth() - 1, Math.min(d.getDate(), 28))); break;
        case "PageDown": next = util.isoDate(new Date(d.getFullYear(), d.getMonth() + 1, Math.min(d.getDate(), 28))); break;
        default: return;
      }
      e.preventDefault();
      self.focusDate = next;
      if (next.slice(0, 7) !== self.month) self.setMonth(next.slice(0, 7), { source: "user" });
      else self.render();
      self._focusDay(next);
    });
  };

  P._focusDay = function (iso) {
    this.focusDate = iso;
    var btns = this.root.querySelectorAll(".ac-cal-daynum");
    for (var i = 0; i < btns.length; i++) {
      var on = btns[i].getAttribute("data-date") === iso;
      btns[i].setAttribute("tabindex", on ? "0" : "-1");
      if (on) btns[i].focus();
    }
  };

  AC.MonthCalendar = MonthCalendar;
})(window);
