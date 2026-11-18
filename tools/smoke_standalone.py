#!/usr/bin/env python3
"""Browser smoke test for the standalone index.html (and the shared JS).

    pip install playwright && python -m playwright install chromium
    python tools/smoke_standalone.py [path/to/index.html]

Exits non-zero on the first failed check. Map tiles are not needed.
"""
import csv
import datetime as dt
import json
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "index.html"
URL = PAGE.as_uri()
failures = []


def check(name, cond, detail=""):
    print(("  ok   " if cond else "  FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))
    if not cond:
        failures.append(name)


def AC_ON(page, set_sel, value):
    return page.evaluate(f"AC.chips.value(document.querySelector('{set_sel}'))") == value


def new_page(browser, locale="pt-BR", tz="America/Recife", query="", **kw):
    ctx = browser.new_context(viewport={"width": 1400, "height": 860}, locale=locale, timezone_id=tz, **kw)
    page = ctx.new_page()
    page.errors = []
    page.on("pageerror", lambda e: page.errors.append(str(e)))
    page.on("console", lambda m: page.errors.append(m.text) if m.type == "error" and "tile" not in m.text
            and "Failed to load resource" not in m.text else None)
    page.goto(URL + query)
    page.wait_for_timeout(600)
    return ctx, page


with sync_playwright() as pw:
    browser = pw.chromium.launch()

    print("Shared helpers")
    ctx, page = new_page(browser)
    r = page.evaluate("""() => {
      const u = AC.util, S = window.AconteceStandalone;
      const Q = String.fromCharCode(34);
      const csv = u.parseCsv('a,b,c\\n' + Q + 'x, ' + Q + Q + 'q' + Q + Q + Q + ',NA,3\\n');
      const bins = AC.color.normalize({type: 'bins', column: 'v', breaks: [0, 10, 20], colors: ['#a', '#b'],
                                       labels: ['low', 'high'], na_label: 'n/a'});
      AC.i18n.setLang('pt');
      const moneyPt = AC.fmt.money(1250.5, 'BRL');
      const whenPt = AC.fmt.when('2026-12-05 20:00');
      AC.i18n.setLang('en');
      const moneyEn = AC.fmt.money(1250.5, 'BRL');
      const whenEn = AC.fmt.when('2026-12-05 20:00');
      AC.i18n.setLang('pt');
      return {
        csv0: csv[0].a, csvNA: csv[0].b, csvC: csv[0].c,
        sprintf: u.sprintf('%d de %s (%.2f) 100%%', 3.2, 'x', 1.005),
        bins: [0, 10, 10.5, 20, 25, null].map(v => AC.color.resolve(bins, {v: v}).label),
        bands: [{price_type: 'free'}, {price_type: 'paid', price: 30}, {price_type: 'paid', price: 30.01},
                {price_type: 'paid', price: 150}, {price_type: 'paid', price: null}, {price_type: 'x'}].map(S.priceBand),
        moneyPt, moneyEn, whenPt, whenEn,
        near: AC.geo.nearest(S.cities, -8.06, -34.9).place.label,
        tz: AC.geo.fromTimezone('America/Manaus').lat, tzNone: AC.geo.fromTimezone('Europe/Lisbon'),
        ids: S.filtered().length
      };
    }""")
    check("CSV parser handles quotes, escaped quotes and NA", r["csv0"] == 'x, "q"' and r["csvNA"] is None and r["csvC"] == "3", r)
    check("sprintf supports %d %s %.2f %%", r["sprintf"] == "3 de x (1.00) 100%" or r["sprintf"] == "3 de x (1.01) 100%", r["sprintf"])
    check("numeric bins are right-closed and include the lowest break", r["bins"] == ["low", "low", "high", "high", "n/a", "n/a"], r["bins"])
    check("price bands match R's price_band()", r["bands"] == ["free", "p1", "p2", "p4", "paid_na", "unknown"], r["bands"])
    check("money is locale-formatted", r["moneyPt"] == "R$ 1.250,50" and r["moneyEn"] == "R$ 1,250.50", (r["moneyPt"], r["moneyEn"]))
    check("dates are locale-formatted", r["whenPt"] == "Sáb, 05 dez · 20:00" and r["whenEn"] == "Sat, 05 Dec · 20:00", (r["whenPt"], r["whenEn"]))
    check("nearest city by haversine", r["near"] == "Recife - PE", r["near"])
    check("time-zone guess (and none outside Brazil)", abs(r["tz"] + 3.119) < 1e-6 and r["tzNone"] is None)

    print("Locale and closest city")
    title = lambda pg: pg.text_content("[data-pane=list] .ac-pane-title")
    check("pt-BR browser gets the Portuguese UI", page.evaluate("document.documentElement.lang") == "pt-BR"
          and title(page) == "Acontecendo")
    check("time zone America/Recife opens Recife", page.input_value(".ac-pm-place-select") ==
          page.evaluate("AconteceStandalone.cities.find(c => c.label === 'Recife - PE').id"))
    check("the greeting names the city", page.text_content("[data-ac-city-name]") == "Recife")
    check("a toast explains the automatic city", "Recife" in (page.text_content("#ac-toast") or ""))
    ctx.close()

    ctx, page = new_page(browser, locale="en-US", tz="America/Sao_Paulo")
    check("English browser in a Brazilian time zone opens in PT-BR", title(page) == "Acontecendo")
    ctx.close()
    ctx, page = new_page(browser, locale="en-GB", tz="Europe/London")
    check("English browser outside Brazil gets English", page.evaluate("document.documentElement.lang") == "en"
          and title(page) == "What's on")
    check("no Brazilian time zone keeps the default city", page.evaluate(
        "document.querySelector('.ac-pm-place-select').selectedOptions[0].text") == "São Paulo - SP")
    page.click(".ac-lang-btn[data-lang=pt]")
    page.reload(); page.wait_for_timeout(500)
    check("the toggle is remembered on reload (same session)", title(page) == "Acontecendo")
    ctx.close()
    ctx, page = new_page(browser, locale="en-GB", tz="Europe/London")
    check("a new session detects the language again", title(page) == "What's on")
    ctx.close()

    ctx, page = new_page(browser, locale="pt-BR", tz="America/Recife", query="?city=curitiba&lang=en")
    check("?city= and ?lang= override detection", page.evaluate(
        "document.querySelector('.ac-pm-place-select').selectedOptions[0].text") == "Curitiba - PR"
          and title(page) == "What's on")
    ctx.close()

    ctx, page = new_page(browser, locale="pt-BR", tz="America/Sao_Paulo",
                         geolocation={"latitude": -25.43, "longitude": -49.27}, permissions=["geolocation"])
    page.wait_for_timeout(800)
    check("granted geolocation picks the closest city", page.evaluate(
        "document.querySelector('.ac-pm-place-select').selectedOptions[0].text") == "Curitiba - PR")
    check("the toast names the city and distance", "Curitiba" in page.text_content("#ac-toast") and "km" in page.text_content("#ac-toast"))
    ctx.close()

    print("Time of day")
    BRT = dt.timezone(dt.timedelta(hours=-3))
    REC = "window.__phases = []; document.addEventListener('ac:theme', e => window.__phases.push(e.detail.phase));"

    def at(hh, mm, query=""):
        ctx = browser.new_context(viewport={"width": 1280, "height": 800}, locale="pt-BR", timezone_id="America/Sao_Paulo")
        pg = ctx.new_page()
        pg.clock.install(time=dt.datetime(2026, 11, 17, hh, mm, tzinfo=BRT))
        pg.add_init_script(REC)
        pg.goto(URL + query)
        pg.clock.run_for(6000)
        pg.wait_for_timeout(150)
        return ctx, pg

    phases = lambda pg: [p for i, p in enumerate(pg.evaluate("__phases")) if i == 0 or p != pg.evaluate("__phases")[i - 1]]
    ctx, pg = at(10, 0)
    check("opens in light mode during the day", phases(pg) == ["day"] and pg.get_attribute("html", "data-theme") == "light")
    check("daytime lists are in time order, without moons", pg.locator("#ev-list .ac-ev-moon").count() == 0)
    pg.click(".ac-theme-toggle"); pg.clock.run_for(3000); pg.wait_for_timeout(100)
    check("the toggle goes to dark through golden hour, sunset and dusk",
          phases(pg) == ["day", "golden", "sunset", "dusk", "night"] and pg.get_attribute("html", "data-theme") == "dark")
    pg.reload(); pg.clock.run_for(1000); pg.wait_for_timeout(100)
    check("the toggle is remembered for the session", pg.get_attribute("html", "data-phase") == "night")
    ctx.close()

    ctx, pg = at(20, 30)
    check("after 19:00 it opens light, then passes golden hour, sunset and dusk into dark",
          phases(pg) == ["day", "golden", "sunset", "dusk", "night"] and pg.get_attribute("html", "data-theme") == "dark")
    order_ok = pg.evaluate("""(() => {
      let ok = true, groups = 0, seenDay = false;
      for (const el of document.querySelectorAll('#ev-list > *')) {
        if (el.classList.contains('ac-day')) { seenDay = false; groups++; continue; }
        const night = !!el.querySelector('.ac-ev-moon');
        if (night && seenDay) ok = false;
        if (!night) seenDay = true;
      }
      return ok && groups > 1 && document.querySelectorAll('#ev-list .ac-ev-moon').length > 0;
    })()""")
    check("when dark, night activities lead each day (with a moon)", order_ok)
    check("the night-first hint shows", pg.is_visible(".ac-night-hint"))
    ctx.close()

    ctx, pg = at(18, 20)
    check("at 18:20 it stops at sunset (still light)", phases(pg)[-1] == "sunset" and pg.get_attribute("html", "data-theme") == "light")
    ctx.close()
    ctx, pg = at(20, 30, "?theme=light")
    check("?theme=light keeps it light at night", phases(pg)[-1] == "day")
    ctx.close()

    print("Filters and map")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    rows = lambda: page.locator("#ev-list .ac-ev").count()
    n_list = rows()
    count_badge = page.text_content(".ac-pm-count")
    legend_total = page.evaluate("[...document.querySelectorAll('.ac-pm-legend-n')].reduce((s, e) => s + Number(e.textContent), 0)")
    check("key-free tiles (Esri when opened from disk)", page.evaluate(
        "AconteceStandalone.map().tileLayer._url").startswith("https://server.arcgisonline.com/"))
    check("pins = list = legend total", count_badge.startswith(str(n_list)) and legend_total == n_list, (n_list, count_badge, legend_total))
    check("rows are grouped under day headers", page.locator("#ev-list .ac-day").count() >= 2)
    pins = page.locator("path.ac-pm-pin").count()
    page.click(".ac-pm-cluster .ac-switch-track"); page.wait_for_timeout(300)
    clusters = page.locator(".ac-pm-cluster-marker").count()
    check("clustering groups pins", clusters > 0 and page.locator("path.ac-pm-pin").count() < pins, (pins, clusters))
    page.click(".ac-pm-cluster .ac-switch-track")
    page.click(".ac-pm-modes [data-value=category]"); page.wait_for_timeout(200)
    check("colour by category switches the legend", page.text_content(".ac-pm-legend-head") == "Categoria")
    page.click("#f-cat .ac-chip[data-value=music]"); page.wait_for_timeout(150)
    check("category chip filters to music", rows() > 0 and page.locator("#ev-list .ac-ev-tile:not(.ac-cat-music)").count() == 0)
    page.click("#f-cat .ac-chip[data-value=arts]"); page.wait_for_timeout(150)
    check("category chips combine", page.locator("#ev-list .ac-cat-arts").count() > 0)
    page.click("#f-cat .ac-chip[data-value=music]"); page.click("#f-cat .ac-chip[data-value=arts]")
    page.click("#f-price .ac-chip[data-value=free]"); page.wait_for_timeout(150)
    check("price chip filters to free", rows() > 0 and page.locator("#ev-list .ac-price:not(.ac-band-free)").count() == 0)
    page.click("#f-price .ac-chip[data-value=free]")
    page.click("#f-when .ac-chip[data-value=today]"); page.wait_for_timeout(200)
    check("date chip filters list and map together",
          rows() == int(page.text_content(".ac-pm-count").split()[0]) and rows() < n_list)
    page.fill("#ev-q", "samba"); page.wait_for_timeout(400)
    page.click("#f-when .ac-chip[data-value=all]"); page.wait_for_timeout(200)
    check("the header search filters", 1 <= rows() < n_list and page.evaluate(
        "AconteceStandalone.filtered().every(e => AC.util.normalizeText([e.title, e.description, e.venue, e.city].join(' ')).includes('samba'))"))
    ctx.close()

    print("Calendar")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    page.click(".ac-view-switch [data-value=calendar]")
    check("view switch shows the calendar", page.is_visible(".ac-cal-grid") and page.get_attribute("#ac-map", "data-view") == "calendar")
    check("the calendar takes the full width (list hidden)", not page.is_visible(".ac-listpanel"))
    check("weeks start on Sunday in pt-BR", page.text_content(".ac-cal-dow") == "dom")
    title0 = page.text_content(".ac-cal-title")
    page.click(".ac-cal [data-act=next]")
    check("next month", page.text_content(".ac-cal-title") != title0)
    first_in = page.locator(".ac-cal-cell:not(.is-outside) .ac-cal-daynum").first
    start = first_in.get_attribute("data-date")
    first_in.focus()
    page.keyboard.press("ArrowRight"); page.keyboard.press("ArrowDown")
    check("arrow keys move the focus (+1 day, +1 week)", page.evaluate(
        "document.activeElement.dataset.date") == page.evaluate(f"AC.util.addDays('{start}', 8)"))
    page.keyboard.press("ArrowUp"); page.keyboard.press("ArrowLeft"); page.keyboard.press("ArrowLeft")
    check("arrowing past the first day moves to the previous month", page.text_content(".ac-cal-title") == title0)
    page.click(".ac-cal [data-act=next]")
    day = page.locator(".ac-cal-cell.has-items:not(.is-outside)").first.get_attribute("data-date")
    page.click(f".ac-cal-daynum[data-date='{day}']")
    check("picking a day opens its agenda", page.locator(".ac-cal-agenda-item").count() >= 1)
    page.click(".ac-cal [data-act=day-map]"); page.wait_for_timeout(300)
    check("'show day on map' adds a removable date chip and returns to the map",
          page.locator("#f-when .ac-chip-custom.is-on").count() == 1
          and page.get_attribute("#ac-map", "data-view") == "map"
          and page.locator("#ev-list .ac-ev").count() >= 1
          and page.evaluate("AconteceStandalone.filtered().every(e => e.starts_at.slice(0, 10) === '" + day + "')"))
    page.click("#f-when .ac-chip-custom .ac-chip-x"); page.wait_for_timeout(150)
    check("removing the date chip goes back to any date",
          page.locator("#f-when .ac-chip-custom").count() == 0 and AC_ON(page, "#f-when", "all"))
    ctx.close()

    print("Add event")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    page.click(".ac-top [data-open-pane=add]")
    check("'Novo evento' opens the form over the list", page.is_visible("#add-form") and not page.is_visible("#ev-list"))
    page.click("#add-form button[type=submit]")
    check("validation errors are in Portuguese", "Informe um título" in page.text_content("#ac-toast"))
    page.fill("#add-title", "Roda de samba <b>teste</b>")
    page.fill("#add-venue", "Praça")
    page.click("#add-cat .ac-chip[data-value=community]")
    page.click(".ac-pm-canvas", position={"x": 300, "y": 300})
    check("clicking the map picks a location", "escolhido no mapa" in page.text_content("#add-where"))
    page.click("#add-form button[type=submit]"); page.wait_for_timeout(900)
    check("saved event appears in the list, escaped, with its category",
          page.locator("#ev-list .ac-ev", has_text="Roda de samba <b>teste</b>").locator(".ac-cat-community").count() == 1)
    page.reload(); page.wait_for_timeout(500)
    check("user events persist after reload",
          page.locator("#ev-list .ac-ev-title", has_text="Roda de samba").count() == 1)
    page.click(".ac-top [data-open-pane=add]")
    page.fill("#add-title", "Roda de samba <b>teste</b>")
    page.click("#add-form button[type=submit]")
    check("duplicates are refused", "já está cadastrado" in page.text_content("#ac-toast"))
    ctx.close()

    print("Search & import")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    page.click(".ac-top [data-open-pane=search]")
    page.fill("#sr-q", "festival sympla")
    page.click("#sr-go")
    n = page.locator("#sr-list .ac-src", has_text="sympla").count()
    check("search finds demo-source events", n == 1, n)
    page.fill("#sr-q", "")
    page.click("#sr-import")
    check("import adds one event per template for the city", "13 novo(s) evento(s)" in page.text_content("#ac-toast"),
          page.text_content("#ac-toast"))
    page.click("#sr-import")
    check("import is idempotent", "já estão salvos" in page.text_content("#ac-toast"))
    page.click("#sr-scope .ac-chip[data-value=all]")
    page.fill("#sr-q", "Manaus")
    page.click("#sr-go")
    page.locator("#sr-list .ac-ev-show").first.click(); page.wait_for_timeout(1200)
    check("'show on map' for another city switches city and opens the popup",
          page.evaluate("document.querySelector('.ac-pm-place-select').selectedOptions[0].text") == "Manaus - AM"
          and page.is_visible(".leaflet-popup") and page.text_content("[data-ac-city-name]") == "Manaus")
    page.click(".ac-lang-btn[data-lang=en]")
    check("switching language re-renders results", "result" in page.text_content("#sr-summary"))
    check("no JavaScript errors", not page.errors, page.errors)
    ctx.close()

    print("Places")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    cases = list(csv.DictReader(open(ROOT / "tests/testthat/fixtures/hours_cases.csv", encoding="utf-8")))
    got = page.evaluate("""cases => cases.map(k => {
      const d = new Date(2026, 10, 15 + Number(k.wday), 0, Number(k.minutes));  // 2026-11-15 is a Sunday
      const place = {opening_hours: k.opening_hours, opens_at: k.opens_at, closes_at: k.closes_at, open_days: k.open_days};
      const st = AC.places.status(place, d);
      const tc = st.toClose === Infinity || st.toClose === undefined ? null : st.toClose;  // 24/7 -> R's NA
      return [st.open, tc, st.daysAhead === undefined ? null : st.daysAhead, AC.places.statusText(st, d)];
    })""", cases)
    bad = []
    for k, g in zip(cases, got):
        want = [k["open"] == "TRUE", None if k["to_close"] == "NA" else int(k["to_close"]),
                None if k["days_ahead"] == "NA" else int(k["days_ahead"]), k["text_pt"]]
        if g != want: bad.append((k["note"], g, want))
    check("opening hours match the shared R fixture (hours_cases.csv)", not bad, bad)
    vib = page.evaluate("""(() => {
      const sub = AC.places.compileRules([{vibe: 'culture', pattern: 'cultur'}, {vibe: 'culture', pattern: 'arte$'},
        {vibe: 'party', pattern: '@nightclub'}, {vibe: 'outdoor', pattern: 'ar-livre'}]);
      return ['Espaço Cultural', 'chope artesanal', 'Arte urbana', 'x @nightclub', 'Jardim ao ar livre', 'Quarteto']
        .map(x => AC.places.classify(x, sub).join(','));
    })()""")
    check("vibe matching agrees with R's classify_vibes()", vib == ["culture", "", "culture", "party", "outdoor", ""], vib)

    rk = page.evaluate("""(() => {
      const base = {kind: 'place', category: 'bar', opens_at: '17:00', closes_at: '02:00', open_days: 'Todos',
                    rating: 4.5, reviews_count: 500, price_level: 2};
      const mk = (id, o) => Object.assign({}, base, {id: id, vibes: []}, o);
      const now = new Date(2026, 10, 17, 21, 0);  // Tuesday 21:00
      const items = [mk('plain'), mk('romantic', {vibes: ['romantic']}), mk('closed', {opens_at: '10:00', closes_at: '18:00'}),
                     mk('cheap', {price_level: 1}), mk('pricey', {price_level: 4}),
                     {kind: 'event', id: 'soon', category: 'music', vibes: ['live_music'], starts_at: '2026-11-17 22:00', price_type: 'free'},
                     {kind: 'event', id: 'next-week', category: 'music', vibes: [], starts_at: '2026-11-25 22:00', price_type: 'free'}];
      const ids = a => AC.places.rank(items, a, now, {perCategory: 10}).map(r => r.item.id);
      return {vibe: ids({vibes: ['romantic'], when: 'now'}), budget: ids({budget: 'low', when: 'now'}),
              show: ids({what: ['show'], when: 'now'}), tomorrow: ids({when: 'tomorrow'})};
    })()""")
    check("ranking: a vibe match comes first", rk["vibe"][0] == "romantic", rk)
    check("ranking: closed places and far-off events are left out",
          "closed" not in rk["vibe"] and "next-week" not in rk["vibe"] and "soon" in rk["vibe"], rk)
    check("ranking: a low budget puts cheap places above pricey ones",
          rk["budget"].index("cheap") < rk["budget"].index("pricey"), rk)
    check("ranking: 'catch a show' keeps music events and concert venues only", rk["show"] == ["soon"], rk)

    page.click("#f-mode .ac-chip[data-value=places]"); page.wait_for_timeout(300)
    rows = lambda: page.locator("#pl-list .ac-place").count()
    check("places mode lists this city's places, one pin each",
          rows() > 50 and int(page.text_content(".ac-pm-count").split()[0]) == rows())
    check("places mode switches the map's colour modes (category, vibe, hours, rating)",
          page.locator(".ac-pm-modes .ac-seg-btn").count() == 4
          and page.is_visible("#pl-demo"))
    check("the calendar switch is hidden for places", not page.is_visible(".ac-view-switch"))
    page.click(".ac-pm-modes .ac-seg-btn[data-value=hours]"); page.wait_for_timeout(200)
    hours = page.evaluate("""(() => {
      const now = new Date(), pts = AconteceStandalone.map().points;
      const want = x => { const st = AC.places.status(x, now); return st.open ? 'open' : st.unknown ? 'unknown' : st.daysAhead === 0 ? 'later' : 'closed'; };
      const byId = {}; AconteceStandalone.places.forEach(p => byId[p.id] = p);
      return {ok: pts.every(p => p.status_key === want(byId[p.id])), legend: document.querySelectorAll('.ac-pm-legend-rows li').length};
    })()""")
    check("'hours' colours pins by opening status, with a legend", hours["ok"] and hours["legend"] >= 1, hours)
    page.click(".ac-pm-modes .ac-seg-btn[data-value=category]")
    page.click("#p-open .ac-chip"); page.wait_for_timeout(200)
    check("'open now' keeps only open places", page.locator("#pl-list .ac-place-closed").count() == 0 and rows() > 0)
    page.click("#p-open .ac-chip")
    page.click("#p-cat .ac-chip[data-value=nightclub]"); page.wait_for_timeout(150)
    check("category chips filter places", rows() > 0 and page.locator("#pl-list .ac-ev-tile:not(.ac-pcat-nightclub)").count() == 0)
    page.click("#p-cat .ac-chip[data-value=nightclub]")
    page.click("#p-vibe .ac-chip[data-value=romantic]"); page.wait_for_timeout(150)
    check("vibe chips filter places", rows() > 0 and page.evaluate(
        "AconteceStandalone.placesFiltered().every(x => x.p.vibe_groups.includes('romantic'))"))
    check("places link to Google Maps", page.locator("#pl-list a.ac-ev-link[href^='https://www.google.com/maps/']").count() == rows())
    page.locator("#pl-list .ac-ev-show").first.click(); page.wait_for_timeout(1200)
    check("a place title flies the map to it", page.is_visible(".leaflet-popup .ac-pop-title"))
    page.click("#f-mode .ac-chip[data-value=events]"); page.wait_for_timeout(200)
    check("back to events restores event pins and colours", page.locator(".ac-pm-modes .ac-seg-btn").count() == 2
          and page.locator("#ev-list .ac-ev").count() > 0)
    ctx.close()

    print("Can't decide?")
    ctx, page = new_page(browser, tz="America/Sao_Paulo")
    page.click(".ac-decide-btn")
    check("the button opens the quiz over the list", page.is_visible(".ac-dq-opt") and not page.is_visible("#ev-list"))
    page.click(".ac-dq-opt[data-v=drink]"); page.click(".ac-decide [data-act=next]")
    page.click(".ac-dq-opt[data-v=romantic]"); page.click(".ac-dq-opt[data-v=upscale]")
    page.click(".ac-dq-opt[data-v=chill]"); page.click(".ac-dq-opt[data-v=party]")
    check("at most three vibes", page.locator(".ac-dq-opt.is-on").count() == 3)
    page.click(".ac-decide [data-act=next]")
    page.click(".ac-dq-opt[data-v=date]"); page.wait_for_timeout(300)
    page.click(".ac-dq-opt[data-v=tonight]"); page.wait_for_timeout(300)
    page.click(".ac-dq-opt[data-v=low]"); page.wait_for_timeout(400)
    cards = page.locator(".ac-dq-card").count()
    verdict = page.evaluate("""(() => {
      const d = AconteceStandalone.decide(), win = AC.places.window('tonight', new Date());
      const res = d.results(new Date());
      const drink = AC.places.WHAT.drink.places;
      return {n: res.length,
              allDrink: res.every(r => r.item.kind === 'place' && drink.includes(r.item.category)),
              allOpen: res.every(r => AC.places.status(r.item, win.ref).open),
              sorted: res.every((r, i) => i === 0 || res[i - 1].score >= r.score)};
    })()""")
    check("results: drink places open tonight, best match first",
          cards == verdict["n"] and cards > 0 and verdict["allDrink"] and verdict["allOpen"] and verdict["sorted"], verdict)
    check("each result explains itself (time, rating, vibes)", page.locator(".ac-dq-card").first.locator(".ac-dq-reason").count() >= 3)
    page.locator(".ac-dq-pick").first.click(); page.wait_for_timeout(1200)
    check("picking a result switches to places and flies there",
          page.evaluate("AconteceStandalone.state.mode") == "places" and page.is_visible(".leaflet-popup"))
    page.click(".ac-lang-btn[data-lang=en]")
    check("the quiz follows the language", page.text_content(".ac-decide .ac-dq-q") in ("Picked for you", "What are you in the mood for?"))
    check("no JavaScript errors", not page.errors, page.errors)
    ctx.close()

    print("Night out: plan, before & after, open late, neighbourhoods")
    ctx, page = new_page(browser, tz="America/Recife")
    logic = page.evaluate("""(() => {
      const P = AC.places;
      const mk = (id, cat, lat, lon, hours, rating) => ({kind: 'place', id: id, category: cat, lat: lat, lon: lon,
        opening_hours: hours, rating: rating, reviews_count: 400, vibes: [], name: id});
      const items = [
        mk('R1', 'restaurant', -8.0630, -34.8713, 'Mo-Su 18:00-23:30', 4.4),
        mk('R2', 'restaurant', -8.1500, -34.9200, 'Mo-Su 18:00-23:30', 4.9),
        mk('B1', 'bar', -8.0640, -34.8720, 'Mo-Su 17:00-02:00', 4.3),
        mk('B2', 'bar', -8.0625, -34.8700, 'Mo-Su 17:00-21:30', 4.8),
        mk('C1', 'nightclub', -8.0680, -34.8750, 'Fr-Sa 23:00-05:00', 4.2),
        mk('X', 'cafe_bistro', -8.0631, -34.8714, null, null)];
      const fri = new Date(2026, 10, 20, 18, 0);          // Friday 18:00
      const plan = P.plan(items, {when: 'tonight'}, fri);
      const hm = d => String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
      const late = P.plan(items, {when: 'now'}, new Date(2026, 10, 20, 23, 10));
      const ev = {kind: 'event', id: 'e1', title: 'Show', lat: -8.0632, lon: -34.8710, starts_at: '2026-11-20 20:00'};
      const ar = P.around(ev, items);
      return {
        ids: plan.stops.map(s => s.item.id), stages: plan.stops.map(s => s.stage), times: plan.stops.map(s => hm(s.arrive)),
        walk: plan.stops.slice(1).every(s => s.travel && s.travel.walk), unknown: plan.unknownHours,
        lateStages: late ? late.stops.map(s => s.stage) : null,
        before: ar.before.map(r => r.item.id), after: ar.after.map(r => r.item.id),
        start: P.planStart('tonight', new Date(2026, 10, 20, 21, 7)).getHours() + ':' + P.planStart('tonight', new Date(2026, 10, 20, 21, 7)).getMinutes(),
        lateAt: [P.isOpenLate(items[2], fri), P.isOpenLate(items[3], fri), P.isOpenLate(items[4], fri),
                 P.isOpenLate(items[4], new Date(2026, 10, 19, 22, 0)), P.isOpenLate(items[5], fri)]
      };
    })()""")
    check("plan: dinner -> drinks -> dance, close together, open on arrival",
          logic["ids"] == ["R1", "B1", "C1"] and logic["stages"] == ["dinner", "drinks", "dance"] and logic["walk"], logic)
    check("plan: the club stop waits for its 23:00 opening", logic["times"][0] == "19:30" and logic["times"][2] == "23:00", logic)
    check("plan: a late start skips dinner", logic["lateStages"] is not None and "dinner" not in logic["lateStages"], logic)
    check("plan: starts now when it is past 19:30", logic["start"] == "21:10", logic)
    check("before & after: open then, nearby, far places left out",
          set(logic["before"]) >= {"R1", "B2"} and "R2" not in logic["before"], logic)
    check("before & after: after the show, bars and the club about to open",
          set(logic["after"]) >= {"B1", "C1"} and "B2" not in logic["after"] and "R2" not in logic["after"], logic)
    check("open late: still open at 02:00 tonight", logic["lateAt"] == [True, False, True, False, False], logic)

    page.click("#f-mode .ac-chip[data-value=places]"); page.wait_for_timeout(300)
    page.click("#p-open .ac-chip[data-value=late]"); page.wait_for_timeout(200)
    late_ok = page.evaluate("""(() => {
      const list = AconteceStandalone.placesFiltered(new Date());
      return {n: list.length, all: list.every(x => AC.places.isOpenLate(x.p, new Date()))};
    })()""")
    check("'open late' chip keeps places open at 02:00", late_ok["all"] and page.locator("#pl-list .ac-place").count() == min(late_ok["n"], 100), late_ok)
    page.click("#p-open .ac-chip[data-value=late]"); page.wait_for_timeout(200)
    check("the group switch shows for places (they have neighbourhoods)", page.is_visible(".ac-pm-group"))
    page.click(".ac-pm-group .ac-switch-track"); page.wait_for_timeout(500)
    hoods = page.evaluate("""new Set(AconteceStandalone.placesFiltered().map(x => x.p.neighborhood).filter(Boolean)).size""")
    check("by neighbourhood: one bubble per neighbourhood, top list in the legend",
          page.locator(".ac-pm-group-bubble").count() == hoods and hoods > 1
          and page.locator(".ac-pm-group-rows [data-group]").count() == min(5, hoods), hoods)
    check("bubbles are sized by count", page.evaluate("""(() => {
      const b = [...document.querySelectorAll('.ac-pm-group-bubble')].map(e => [Number(e.querySelector('b').textContent), e.offsetWidth]);
      b.sort((x, y) => x[0] - y[0]);
      return b[b.length - 1][1] >= b[0][1];
    })()"""))
    page.locator(".ac-pm-group-rows [data-group]").first.click(); page.wait_for_timeout(900)
    check("clicking a neighbourhood zooms in and shows its pins",
          page.locator(".ac-pm-group-bubble").count() == 0 and not page.is_checked(".ac-pm-group input"))
    page.click("#f-mode .ac-chip[data-value=events]"); page.wait_for_timeout(300)
    check("events have no neighbourhoods, so no group switch", not page.is_visible(".ac-pm-group"))

    ev_id = page.evaluate("AconteceStandalone.filtered().find(e => isFinite(e.lat)).id")
    page.evaluate(f"AconteceStandalone.map().focus({json.dumps(ev_id)})"); page.wait_for_timeout(1200)
    check("event popups offer 'before & after'", page.is_visible(".leaflet-popup .ac-around-btn"))
    page.click(".leaflet-popup .ac-around-btn"); page.wait_for_timeout(300)
    check("'before & after' opens in the decide pane with two sections",
          page.is_visible(".ac-decide .ac-around-h") and page.locator(".ac-decide .ac-around-h").count() == 2
          and page.evaluate("document.querySelector('[data-panes]').getAttribute('data-panes')") == "decide")
    page.click(".ac-decide [data-act=around-back]"); page.wait_for_timeout(200)
    check("'back' returns to the quiz", page.is_visible(".ac-dq-opt"))
    page.click("#f-mode .ac-chip[data-value=places]"); page.wait_for_timeout(300)
    check("an event's popup closes when its pin leaves the map", not page.is_visible(".leaflet-popup"))

    for _ in range(5):
        page.click(".ac-decide [data-act=skip]"); page.wait_for_timeout(120)
    page.click(".ac-dq-tabs [data-tab=plan]"); page.wait_for_timeout(200)
    stops = page.locator(".ac-plan-stop").count()
    check("the plan tab shows a route or explains why not", stops > 0 or page.is_visible(".ac-decide .ac-empty"))
    if stops:
        check("stops are numbered, with the way between them", page.locator(".ac-plan-n").count() == stops
              and page.locator(".ac-plan-leg").count() == stops - 1)
        page.click(".ac-decide [data-act=route]"); page.wait_for_timeout(900)
        check("'show the route' draws numbered stops on the map",
              page.locator(".ac-pm-route-n").count() == stops and page.is_visible(".ac-pm-route-clear")
              and page.evaluate("AconteceStandalone.state.mode") == "places")
        page.click(".ac-pm-route-clear"); page.wait_for_timeout(200)
        check("the route can be cleared", page.locator(".ac-pm-route-n").count() == 0 and not page.is_visible(".ac-pm-route-clear"))
    page.click(".ac-lang-btn[data-lang=en]"); page.wait_for_timeout(100)
    check("the plan tab follows the language", page.text_content(".ac-dq-tabs [data-tab=plan]") == "Plan my night")
    check("no JavaScript errors", not page.errors, page.errors)
    ctx.close()

    print("Small screen")
    ctx = browser.new_context(viewport={"width": 390, "height": 800}, locale="pt-BR", timezone_id="America/Sao_Paulo")
    page = ctx.new_page(); errs = []
    page.on("pageerror", lambda e: errs.append(str(e)))
    page.goto(URL); page.wait_for_timeout(500)
    check("map comes first on phones", page.locator(".ac-stage").bounding_box()["y"] < page.locator(".ac-listpanel").bounding_box()["y"])
    check("no horizontal overflow", page.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 1"))
    check("no JavaScript errors", not errs, errs)
    ctx.close()

    browser.close()

print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'All standalone checks passed.'}")
sys.exit(1 if failures else 0)
