#!/usr/bin/env python3
"""Browser test for inst/www/ac-shiny.js, the Shiny side of the shared components.

Builds a page with the markup app_page() / mod_map_ui() / mod_calendar_ui()
render, loads the real assets from inst/www, and stands in for Shiny's client
with a small mock of the API ac-shiny.js uses (input bindings, setInputValue,
custom messages, shiny:connected, sendInputMessage). Payloads have the shape
the R modules send. This checks the browser half of the Shiny contract;
tests/testthat checks the R half.

    pip install playwright && python -m playwright install chromium
    python tools/smoke_shiny_bindings.py [--jquery path/to/jquery.min.js]

jQuery comes from the installed shiny R package when Rscript is available.
"""
import csv
import datetime as dt
import html
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unicodedata

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
WWW = ROOT / "inst" / "www"
failures = []


def check(name, cond, detail=""):
    print(("  ok   " if cond else "  FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        failures.append(name)


def find_jquery():
    if "--jquery" in sys.argv:
        return pathlib.Path(sys.argv[sys.argv.index("--jquery") + 1])
    if shutil.which("Rscript"):
        out = subprocess.run(
            ["Rscript", "-e", "cat(system.file('www/shared/jquery.min.js', package = 'shiny'))"],
            capture_output=True, text=True).stdout.strip()
        if out:
            return pathlib.Path(out)
    fallback = pathlib.Path("/usr/share/javascript/jquery/jquery.min.js")
    if fallback.exists():
        return fallback
    sys.exit("jQuery not found; pass --jquery path/to/jquery.min.js")


def norm(s):
    return "".join(ch for ch in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(ch) != "Mn")


def cities():
    rows = list(csv.DictReader(open(ROOT / "inst/extdata/cities.csv", encoding="utf-8")))
    for i, c in enumerate(rows):  # same ids and order as load_cities()
        c["id"], c["label"] = str(i + 1), c["city"] + " - " + c["state"]
    return sorted(rows, key=lambda c: norm(c["city"]))


def band(pt, p):  # price_band() in R/categories.R
    if pt in ("free", "donation"):
        return pt
    if pt == "paid":
        if p in ("", "NA"):
            return "paid_na"
        p = float(p)
        return "p1" if p <= 30 else "p2" if p <= 60 else "p3" if p <= 100 else "p4"
    return "unknown"


def build_page(jquery):
    cs = cities()
    start = next(c for c in cs if c["city"] == "S\u00e3o Paulo")
    cfg = {"places": [{"id": c["id"], "label": c["label"], "name": c["city"], "lat": float(c["lat"]),
                       "lon": float(c["lon"])} for c in cs],
           "place": start["id"], "colorMode": None, "cluster": False, "autoLocate": True,
           "locate": True, "pickable": True, "zoom": 12, "tiles": None,
           "placeTarget": "#ac-place-slot", "modesTarget": "#ac-modes-slot", "groupBy": "neighborhood"}
    inc = lambda f: (WWW / f).read_text(encoding="utf-8")
    scripts = "".join(f"<script>{inc(f)}</script>" for f in
                      ["vendor/leaflet/leaflet.js", "ac-core.js", "ac-map.js", "ac-calendar.js",
                       "ac-places.js", "ac-decide.js", "ac-shiny.js"])
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<style>{inc('vendor/leaflet/leaflet.css')}</style><style>{inc('taiga-tokens.css')}</style><style>{inc('aconteceR.css')}</style>
<script src="{jquery.as_uri()}"></script>
<script>
window.__log = []; window.__handlers = {{}}; window.__bindings = [];
window.Shiny = {{
  InputBinding: function () {{}},
  inputBindings: {{ register: function (b) {{ __bindings.push(b); }} }},
  addCustomMessageHandler: function (type, fn) {{ __handlers[type] = fn; }},
  setInputValue: function (name, value, opts) {{
    __log.push([name, JSON.parse(JSON.stringify(value === undefined ? null : value)), opts || null]);
  }}
}};
// Like Shiny: bind inputs on jQuery ready, then connect.
$(function () {{
  __bindings.forEach(function (b) {{
    b.find(document).each(function (_, el) {{
      __log.push([el.id, b.getValue(el), "init"]);
      b.subscribe(el, function () {{ __log.push([el.id, b.getValue(el), "bound"]); }});
      el.__binding = b;
    }});
  }});
  setTimeout(function () {{ $(document).trigger("shiny:connected"); }}, 50);
}});
window.sendInputMessage = function (id, msg) {{ var el = document.getElementById(id); el.__binding.receiveMessage(el, msg); }};
window.serverMsg = function (type, msg) {{ __handlers[type](msg); }};
</script>{scripts}</head><body>
<script type="application/json" id="ac-i18n-dict">{(ROOT / 'inst/i18n/strings.json').read_text(encoding='utf-8')}</script>
<div class="ac-app" data-server-lang="pt" data-i18n-doc-title="doc_title" data-mode="events">
 <header class="ac-top">
  <label class="ac-search"><input id="events-q" type="search" data-i18n-ph="search_ph_top"></label>
  <div class="ac-top-actions"><div id="ac-place-slot"></div>
   <button type="button" class="ac-btn ac-btn-primary" data-open-pane="add"><span data-ac-icon="plus"></span></button>
   <div class="ac-lang" role="group">
    <button type="button" class="ac-lang-btn is-active" data-lang="pt">PT</button>
    <button type="button" class="ac-lang-btn" data-lang="en">EN</button>
    <input type="hidden" id="lang" class="ac-lang-input" value="pt" data-server-lang="pt"></div></div></header>
 <section class="ac-hero"><h1 class="ac-hello"><span data-ac-greeting></span>, <span class="ac-grad" data-ac-city-name></span></h1></section>
 <div id="mode" class="ac-chipset ac-mode" data-mode="single" data-default="events" data-app-mode>
  <button type="button" class="ac-chip is-on" data-value="events">Eventos</button>
  <button type="button" class="ac-chip" data-value="places">Lugares</button></div>
 <nav class="ac-filters">
  <div id="events-when" class="ac-chipset" role="group" data-mode="single" data-default="all">
   <button type="button" class="ac-chip" data-value="today"><span data-i18n="when_today">Hoje</span></button>
   <button type="button" class="ac-chip is-on" data-value="all"><span data-i18n="when_all">Qualquer data</span></button></div>
  <div id="events-cat" class="ac-chipset" role="group" data-mode="multi">
   <button type="button" class="ac-chip ac-chip-cat ac-chip-music" data-value="music"><span class="ac-chip-dot ac-cat-music"><span data-ac-icon="cat_music"></span></span>Música</button>
   <button type="button" class="ac-chip ac-chip-cat ac-chip-food" data-value="food">Gastronomia</button></div>
 </nav>
 <main class="ac-content">
  <section class="ac-panel ac-listpanel" data-panes="list">
   <div class="ac-pane" data-pane="list">
    <div class="ac-pane-head"><h2 class="ac-pane-title">Acontecendo</h2></div>
    <div id="events-list" class="shiny-html-output ac-pane-body"></div></div>
   <div class="ac-pane" data-pane="decide" hidden><div id="decide-dec" class="ac-decide-host" data-ac-decide="1"></div></div>
   <div class="ac-pane" data-pane="add" hidden>
    <div class="ac-pane-form"><div id="add-price_type" class="ac-chipset" data-mode="single" data-default="free">
     <button type="button" class="ac-chip is-on" data-value="free">Grátis</button>
     <button type="button" class="ac-chip" data-value="paid">Pago</button></div>
     <input id="add-date" type="date" value="2026-11-17" class="ac-native-input"></div></div>
  </section>
  <section class="ac-panel ac-stage">
   <div class="ac-stage-head">
    <div class="ac-seg ac-view-switch" role="group" data-target="map-pm" data-input-id="view">
     <button type="button" class="ac-seg-btn is-active" data-value="map"><span data-i18n="view_map">Mapa</span></button>
     <button type="button" class="ac-seg-btn" data-value="calendar"><span data-i18n="view_calendar">Calend&aacute;rio</span></button></div>
    <div id="ac-modes-slot"></div></div>
   <div id="map-pm" class="ac-pm" data-view="map" data-ac-pointmap="{html.escape(json.dumps(cfg, ensure_ascii=False))}">
    <div class="ac-pm-body"><div class="ac-pm-canvas"></div>
     <div class="ac-pm-overlay" data-view-name="calendar">
      <div id="calendar-cal" class="ac-cal-host" data-ac-calendar="1" data-color-from="map-pm"></div></div>
     <div class="ac-pm-bar"><div class="ac-pm-bar-end"></div></div></div>
   </div></section></main></div>
</body></html>"""


def payloads():
    rows = [r for r in csv.DictReader(open(ROOT / "inst/extdata/sample_events.csv", encoding="utf-8"))
            if r["city"] == "S\u00e3o Paulo - SP"]
    today = dt.date.today()
    ev = [dict(id=str(i + 1), lat=float(r["lat"]), lon=float(r["lon"]), label=r["title"],
               popup="<span class=\"ac-pop-title\">" + html.escape(r["title"]) + "</span>",
               price_band=band(r["price_type"], r["price"]), category=r["category"],
               starts_at=f"{today + dt.timedelta(days=int(r['days_from_now']))} {r['time']}",
               title=r["title"], meta="meta") for i, r in enumerate(rows)]
    level = lambda keys: [{"key": k, "color": "#%02x%02x%02x" % (40 + 25 * i, 200 - 20 * i, 90 + 15 * i), "label": k}
                          for i, k in enumerate(keys)]
    modes = [
        {"type": "factor", "column": "price_band", "label": "Pre\u00e7o", "title": "Pre\u00e7o", "na_color": "#8c8c8c",
         "na_label": "NA", "id": "price",
         "levels": level(["free", "donation", "p1", "p2", "p3", "p4", "paid_na", "unknown"])},
        {"type": "factor", "column": "category", "label": "Categoria", "title": "Categoria", "na_color": "#8c8c8c",
         "na_label": "NA", "id": "category",
         "levels": level(["music", "food", "arts", "sports", "tech", "community", "other"])},
    ]
    points = json.dumps([{k: e[k] for k in ("id", "lat", "lon", "label", "popup", "price_band", "category")} for e in ev])
    items = json.dumps([{k: e[k] for k in ("id", "starts_at", "title", "meta", "price_band", "category")} for e in ev])
    return ev, json.dumps(modes), points, items


def main():
    page_file = pathlib.Path(tempfile.mkdtemp()) / "shiny_mock.html"
    page_file.write_text(build_page(find_jquery()), encoding="utf-8")
    ev, modes, points, items = payloads()
    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={"width": 1300, "height": 800}, locale="en-US", timezone_id="America/Sao_Paulo")
        pg = ctx.new_page()
        errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        pg.goto(page_file.as_uri())
        pg.wait_for_timeout(400)
        log = lambda: [list(x) for x in pg.evaluate("__log")]
        msg = lambda t, m: pg.evaluate(f"serverMsg({json.dumps(t)}, {json.dumps(m)})")

        L = log()
        names = [x[0] for x in L]
        check("lang input reports the server's language at bind time", ["lang", "pt", "init"] in L, L[:3])
        check("native date input is bound with its value", ["add-date", "2026-11-17", "init"] in L)
        check("map reports place and cluster once connected", "map-pm_place" in names and "map-pm_cluster" in names)
        check("view switch reports its initial value", ["view", "map", None] in L)
        check("calendar reports its month", "calendar-cal_month" in names)
        check("the night flag is sent (dark from dusk)", "night" in names)
        clk = [x for x in L if x[0] == "clock"]
        check("the visitor's clock is sent", clk and set(clk[-1][1]) == {"wday", "minutes", "date"})
        check("the mode chip set reports events", ["mode", "events", "init"] in L)
        pg.evaluate("AC.theme.animateTo('night', {stepMs: 30})")
        try:
            pg.wait_for_function("__log.some(x => x[0] === 'night' && x[1] === true)", timeout=5000)
            followed = True
        except Exception:
            followed = False
        check("... and follows the theme", followed, [x for x in log() if x[0] == "night"])
        check("page is in pt-BR (server guess) in an English browser",
              pg.text_content("[data-i18n=view_map]") == "Mapa" and pg.evaluate("document.documentElement.lang") == "pt-BR")

        msg("ac-map", {"id": "map-pm", "action": "modes", "modes": modes, "active": None})
        msg("ac-map", {"id": "map-pm", "action": "points", "points": points})
        msg("ac-cal", {"id": "calendar-cal", "action": "items", "items": items})
        pg.wait_for_timeout(200)
        check("modes message sets and reports the colour mode", ["map-pm_color_mode", "price", None] in log())
        check("points message draws pins and the count",
              pg.locator("path.ac-pm-pin").count() == len(ev) and pg.text_content(".ac-pm-count").startswith(str(len(ev))))

        check("place picker renders in the header slot and the greeting names the city",
              pg.locator("#ac-place-slot .ac-pm-place-select").count() == 1
              and pg.text_content("[data-ac-city-name]") == "S\u00e3o Paulo")
        check("colour-by renders in the stage header", pg.locator("#ac-modes-slot .ac-pm-modes .ac-seg-btn").count() == 2)
        check("chip sets report their initial values",
              ["events-when", "all", "init"] in L and ["events-cat", None, "init"] in L and ["add-price_type", "free", "init"] in L)
        pg.click("#events-cat .ac-chip[data-value=music]")
        pg.click("#events-cat .ac-chip[data-value=food]")
        check("multi chips send arrays", ["events-cat", ["music", "food"], "bound"] in log())
        pg.click("#events-cat .ac-chip[data-value=music]"); pg.click("#events-cat .ac-chip[data-value=food]")
        check("... and null when empty", log()[-1] == ["events-cat", None, "bound"])
        pg.evaluate("sendInputMessage('events-when', {custom: '10 de dez'})")
        check("the server can add the custom date chip",
              ["events-when", "custom", "bound"] in log() and pg.locator("#events-when .ac-chip-custom.is-on").count() == 1)
        pg.click("#events-when .ac-chip[data-value=today]")
        check("picking another date chip drops the custom one",
              log()[-1] == ["events-when", "today", "bound"] and pg.locator("#events-when .ac-chip-custom").count() == 0)

        pg.evaluate("""document.getElementById('events-list').innerHTML =
          '<h4 class="ac-day">Hoje</h4><article class="ac-ev" data-id="1" data-input="events-focus">' +
          '<div class="ac-ev-tile ac-cat-music"><span data-ac-icon="cat_music"></span></div>' +
          '<div class="ac-ev-main"><h3 class="ac-ev-title"><button type="button" class="ac-ev-show" data-focus-id="1">Roda</button></h3></div></article>';
          $(document).trigger('shiny:value');""")
        pg.wait_for_timeout(50)
        check("rendered rows get their icons", pg.locator("#events-list .ac-ev-tile svg").count() == 1)
        pg.click(".ac-pm-modes [data-value=category]")
        pg.wait_for_timeout(50)
        check("colour-mode click reports the input", ["map-pm_color_mode", "category", None] in log())
        check("the calendar follows the map's colour mode in the browser",
              pg.evaluate("document.getElementById('calendar-cal')._acCal.spec.id") == "category")
        pg.click(".ac-ev-show")
        check("clicking a row title sends its id as an event", ["events-focus", "1", {"priority": "event"}] in log())
        pg.hover(".ac-ev")
        check("hovering a row rings its pin", pg.locator("path.ac-pm-halo").count() == 1)
        pg.evaluate("""window.__shown = 0; $('[data-pane=add]').on('shown', function () { window.__shown++; });""")
        pg.click(".ac-top [data-open-pane=add]")
        check("the add pane opens over the list and Shiny is told it is visible",
              pg.is_visible("#add-price_type") and not pg.is_visible("#events-list") and pg.evaluate("__shown") == 1)
        pg.click("#add-price_type .ac-chip[data-value=paid]")
        check("single chips send a string", log()[-1] == ["add-price_type", "paid", "bound"])
        msg("ac-pane", {"value": "list"})
        check("the server can go back to the list", pg.is_visible("#events-list"))
        pg.click(".ac-pm-canvas", position={"x": 200, "y": 200})
        clicks = [x for x in log() if x[0] == "map-pm_click"]
        check("a map click sends lat/lon with a nonce",
              clicks and set(clicks[-1][1]) == {"lat", "lon", "nonce"} and clicks[-1][2] == {"priority": "event"})

        msg("ac-view", {"target": "map-pm", "value": "calendar"})
        check("the server can switch to the calendar view",
              pg.get_attribute("#map-pm", "data-view") == "calendar" and ["view", "calendar", None] in log())
        day = pg.locator(".ac-cal-cell.has-items:not(.is-outside)").first.get_attribute("data-date")
        pg.click(f".ac-cal-daynum[data-date='{day}']")
        pg.click(".ac-cal [data-act=day-map]")
        sd = [x for x in log() if x[0] == "calendar-cal_show_day"]
        check("'show this day on the map' sends the date", sd and sd[-1][1]["date"] == day)
        pg.locator(".ac-cal-agenda-item").first.click()
        check("an agenda item sends its id", any(x[0] == "calendar-cal_item" for x in log()))

        pg.evaluate("sendInputMessage('add-date', {value: '2026-12-10'})")
        check("sendInputMessage updates a native date input",
              ["add-date", "2026-12-10", "bound"] in log() and pg.input_value("#add-date") == "2026-12-10")

        msg("ac-view", {"target": "map-pm", "value": "map"})
        msg("ac-map", {"id": "map-pm", "action": "focus",
                       "target": {"id": "999", "lat": -23.55, "lon": -46.63, "label": "Elsewhere", "popup": "<b>Elsewhere</b>"}})
        pg.wait_for_timeout(1300)
        check("focusing a point that is not drawn opens its popup",
              pg.is_visible(".leaflet-popup") and "Elsewhere" in pg.text_content(".leaflet-popup"))
        msg("ac-map", {"id": "map-pm", "action": "place", "place": "1"})
        check("the server can set the place (echoed as input)", ["map-pm_place", "1", None] in log())

        pg.click(".ac-lang-btn[data-lang=en]")
        check("the language button translates and reports lang=en",
              pg.text_content("[data-i18n=view_map]") == "Map" and ["lang", "en", "bound"] in log())
        check("the map controls relabel", pg.text_content(".ac-pm-colorby .ac-pm-label") == "Colour by")
        check("the document title follows the language", pg.title() == "aconteceR \u2014 event map and calendar")

        items = json.dumps([
            {"kind": "place", "id": "p1", "name": "Bar Aberto", "category": "bar", "vibes": "romantic,casual",
             "lat": -23.55, "lon": -46.64, "label": "Bar Aberto", "popup": "<b>Bar Aberto</b>",
             "opens_at": "00:00", "closes_at": "23:59", "open_days": "Todos", "rating": 4.7,
             "reviews_count": 900, "price_level": 2, "maps_url": "https://www.google.com/maps/search/x"},
            {"kind": "place", "id": "p2", "name": "Fechado", "category": "bar", "vibes": "romantic",
             "lat": -23.56, "lon": -46.65, "label": "Fechado", "popup": "x",
             "opens_at": "10:00", "closes_at": "10:01", "open_days": "Todos", "rating": 4.9,
             "reviews_count": 900, "price_level": 2}])
        msg("ac-decide", {"id": "decide-dec", "action": "items", "items": items})
        pg.click("[data-open-pane=decide]") if pg.locator("[data-open-pane=decide]").count() else pg.evaluate("AC.ui.openPane('decide')")
        pg.evaluate("(() => { const d = document.getElementById('decide-dec')._acDecide; d.answers.vibes = ['romantic']; d._go(5); })()")
        check("the quiz ranks the server's items (closed places left out)",
              pg.locator(".ac-dq-card").count() == 1 and "Bar Aberto" in pg.text_content(".ac-dq-card"))
        pg.click(".ac-dq-pick"); pg.wait_for_timeout(1300)
        check("a pick switches the mode input to places and flies the map",
              log()[-1][0] in ("mode", "map-pm_color_mode", "view") and ["mode", "places", "bound"] in log()
              and pg.get_attribute(".ac-app", "data-mode") == "places" and "Bar Aberto" in pg.text_content(".leaflet-popup"))

        night = json.dumps([
            {"kind": "place", "id": "b24", "name": "Bar 24 Horas", "category": "bar", "vibes": "casual",
             "lat": -23.55, "lon": -46.64, "opening_hours": "24/7", "popup": "<b>Bar 24 Horas</b>"},
            {"kind": "place", "id": "c24", "name": "Clube 24", "category": "nightclub", "vibes": "party",
             "lat": -23.552, "lon": -46.641, "opening_hours": "24/7", "popup": "<b>Clube 24</b>"}])
        msg("ac-decide", {"id": "decide-dec", "action": "items", "items": night})
        pg.evaluate("(() => { const d = document.getElementById('decide-dec')._acDecide; d.tab = 'plan'; d.view = 'results'; d.render(); })()")
        check("the plan tab builds a night from the server's items (no restaurant: starts with drinks)",
              pg.locator("#decide-dec .ac-plan-stop").count() == 2 and "Bar 24 Horas" in pg.text_content("#decide-dec .ac-plan")
              and pg.locator("#decide-dec .ac-plan-leg").count() == 1)
        pg.evaluate("AC.chips.set(document.getElementById('mode'), 'events')")
        pg.click("#decide-dec [data-act=route]"); pg.wait_for_timeout(800)
        check("'show the route' switches to places and draws it", pg.locator(".ac-pm-route-n").count() == 2
              and pg.get_attribute(".ac-app", "data-mode") == "places" and ["mode", "places", "bound"] in log())
        msg("ac-map", {"id": "map-pm", "action": "clear_route"})

        msg("ac-map", {"id": "map-pm", "action": "fit", "deferred": True})
        # Group view, route and "before & after" (the R side: mod_map_ui(group_by =),
        # map$show_route(), event_popup_html()).
        hood_pts = json.loads(points)
        for i, p_ in enumerate(hood_pts):
            p_["neighborhood"] = ["Pinheiros", "Centro", "Pinheiros", "Moema"][i % 4]
        msg("ac-map", {"id": "map-pm", "action": "points", "points": json.dumps(hood_pts)})
        check("the group switch appears when points carry the group column", pg.is_visible(".ac-pm-group"))
        pg.click(".ac-pm-group .ac-switch-track"); pg.wait_for_timeout(300)
        check("the group switch reports map-pm_group and draws one bubble per group",
              ["map-pm_group", True, None] in log() and pg.locator(".ac-pm-group-bubble").count() == 3)
        msg("ac-map", {"id": "map-pm", "action": "group", "on": False}); pg.wait_for_timeout(200)
        check("the server can turn the group view off", pg.locator(".ac-pm-group-bubble").count() == 0)
        stops = json.dumps([{"lat": -23.56, "lon": -46.69, "n": 1, "label": "1. <b>Jantar</b>", "popup": None},
                            {"lat": -23.561, "lon": -46.692, "n": 2, "label": "2. Bar", "popup": "<b>Bar</b>"}])
        msg("ac-map", {"id": "map-pm", "action": "route", "stops": stops}); pg.wait_for_timeout(400)
        check("a route message draws numbered stops", pg.locator(".ac-pm-route-n").count() == 2
              and pg.is_visible(".ac-pm-route-clear"))
        msg("ac-map", {"id": "map-pm", "action": "clear_route"})
        check("clear_route removes it", pg.locator(".ac-pm-route-n").count() == 0)
        ev0 = ev[0]
        popup = ('<span class="ac-pop-title">x</span><div class="ac-pop-actions"><button type="button" '
                 'class="ac-linkbtn ac-around-btn" data-ac-around="%s" data-title="%s" data-lat="%s" data-lon="%s" '
                 'data-start="%s"><span data-ac-icon="route"></span><span>Antes e depois</span></button></div>'
                 % (ev0["id"], html.escape(ev0["title"]), ev0["lat"], ev0["lon"], ev0["starts_at"]))
        msg("ac-map", {"id": "map-pm", "action": "focus", "target": {"id": "zz", "lat": ev0["lat"], "lon": ev0["lon"], "popup": popup}})
        pg.wait_for_timeout(1200)
        check("server popups get their icons and the 'before & after' button", pg.is_visible(".leaflet-popup .ac-around-btn svg"))
        pg.click(".leaflet-popup .ac-around-btn"); pg.wait_for_timeout(300)
        check("'before & after' opens the decide pane", pg.is_visible("#decide-dec .ac-around-h")
              and html.unescape(ev0["title"]) in pg.text_content("#decide-dec .ac-around-for"))
        pg.evaluate("AC.ui.openPane('list')")

        msg("ac-map", {"id": "map-pm", "action": "points", "points": points})
        check("a deferred fit runs on the next points", pg.evaluate("document.getElementById('map-pm')._acMap._fitNext") is False)
        msg("ac-map", {"id": "later-pm", "action": "points", "points": "[]"})
        check("messages for maps that do not exist yet are queued, without errors", not errs, errs)
        browser.close()
    print("\n" + ("FAILED: " + ", ".join(failures) if failures else "All Shiny-binding checks passed."))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
