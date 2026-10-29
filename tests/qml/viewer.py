#!/usr/bin/env python3
"""Loads the widget outside Plasma, with stand-ins for the Plasma modules, and saves a screenshot.

    viewer.py stage  out.png [--lang en] [--tab 1] [--mode failed] [--current '{"weatherCode": 95}']
    viewer.py applet out.png [--set language=en] [--wait 4000]      # real main.qml, real network
    viewer.py config out.png --page 1                               # a page of the settings dialog
    viewer.py stage  out.png --animations full --expect-motion       # fails unless the scene and an icon move
    viewer.py applet out.png --first-run --search Cluj               # no place set: search one and pick the first
    viewer.py applet out.png --forbid-host meteoromania.ro           # fails if the widget asks that site for anything

Exits with 1 when QML reported an error or a warning, so a broken binding does not go unnoticed.
"""

import argparse
import ctypes
import json
import os
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

# No core dump if Qt crashes: in a container that shares the kernel of the desktop, the dump goes to
# the crash handler of the desktop, which reports a crash of its own Python on the screen.
PR_SET_DUMPABLE = 4
ctypes.CDLL(None, use_errno=True).prctl(PR_SET_DUMPABLE, 0, 0, 0, 0)

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QElapsedTimer, QMetaObject, QTimer, QUrl, QtMsgType, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkRequest
from PySide6.QtQml import QQmlComponent, QQmlListReference, QQmlNetworkAccessManagerFactory, qmlRegisterSingletonType, qmlRegisterType
from PySide6.QtQuick import QQuickItem, QQuickView
from shiboken6 import getCppPointer

import shim_kirigami  # noqa: F401 - importing registers the QML types
import shim_plasmoid

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent.parent / "package"
WALLPAPER = HERE.parent.parent / "wallpaper" / "package"
FIXTURES = HERE.parent / "fixtures"

QML_SHIMS = {
    "org.kde.kirigami": ("kirigami", ["Icon", "FormLayout"], ["Units"]),
    "org.kde.plasma.components": ("components", ["Label", "TabBar", "TabButton", "ToolButton", "Button", "BusyIndicator", "ToolTip", "ScrollBar", "TextField", "Slider"], []),
    "org.kde.plasma.core": ("misc", ["Action", "Types"], []),
    "org.kde.kcmutils": ("misc", ["SimpleKCM"], []),
    "org.kde.plasma.configuration": ("misc", ["ConfigModel", "ConfigCategory"], []),
    "org.kde.notification": ("misc", ["Notification"], []),
    "org.kde.taskmanager": ("taskmanager", ["TasksModel", "VirtualDesktopInfo", "ActivityInfo"], []),
}

#: The place the widget is given, so that a run does not start at the first-run prompt unless asked to.
PLACE = {"locationName": "Constanța", "latitude": 44.18073, "longitude": 28.63432, "region": "Constanța", "countryCode": "RO"}

problems = []
#: The PlasmoidItem of an `applet` run, for reports made after it was built.
applet_root = []
# PySide destroys what a component created once the component itself is collected.
components = []
#: Every address the QML engine sent a request to, in order.
requested = []
#: Hosts whose requests fail at once, so that a recorded answer stays on screen.
offline = set()


class RecordingAccessManager(QNetworkAccessManager):
    def createRequest(self, operation, request, data=None):
        requested.append(request.url())

        if request.url().host() in offline:
            request = QNetworkRequest(QUrl("http://127.0.0.1:9/"))

        return super().createRequest(operation, request, data)


class RecordingFactory(QQmlNetworkAccessManagerFactory):
    def create(self, parent):
        return RecordingAccessManager(parent)


def asked(host):
    """The addresses requested from `host` or from a subdomain of it."""
    return [address.toString() for address in requested if address.host() == host or address.host().endswith(f".{host}")]


def on_message(kind, context, message):
    print(f"[qml] {message}", file=sys.stderr)

    if kind != QtMsgType.QtDebugMsg and kind != QtMsgType.QtInfoMsg:
        problems.append(message)


def url(path):
    return QUrl.fromLocalFile(str(path))


def register_qml_shims():
    for module, (folder, types, singletons) in QML_SHIMS.items():
        for name in types:
            qmlRegisterType(url(HERE / "shims" / folder / f"{name}.qml"), module, 1, 0, name)

        for name in singletons:
            qmlRegisterSingletonType(url(HERE / "shims" / folder / f"{name}.qml"), module, 1, 0, name)


def config_defaults(package=PACKAGE):
    """The defaults of contents/config/main.xml, as Plasma would hand them to the widget, or to the wallpaper."""
    namespace = {"kcfg": "http://www.kde.org/standards/kcfg/1.0"}
    casts = {
        "String": lambda text: text or "",
        "Double": float,
        "Int": int,
        "Bool": lambda text: text == "true",
        "StringList": lambda text: [item for item in (text or "").split(",") if item],
    }
    entries = ElementTree.parse(package / "contents/config/main.xml").getroot().iterfind(".//kcfg:entry", namespace)

    return {entry.get("name"): casts[entry.get("type")](entry.findtext("kcfg:default", namespaces=namespace)) for entry in entries}


def create(component, properties=None, context=None):
    components.append(component)
    item = component.createWithInitialProperties(properties, context) if properties else component.create(context)

    # Initial properties a component does not have are errors, yet the object is still created.
    for error in component.errors():
        problems.append(error.toString())
        print(f"[qml] {error.toString()}", file=sys.stderr)

    if item is None:
        sys.exit(1)

    return item


def visual_tree(item):
    yield item

    for child in item.childItems():
        yield from visual_tree(child)


def has_property(item, name):
    return item.metaObject().indexOfProperty(name) >= 0


def motion(root):
    """Where the things that move are right now: the clocks of the scene, and the frame of every loaded icon film."""
    scenes = [item for item in visual_tree(root) if has_property(item, "fallClock")]
    films = [item for item in visual_tree(root) if has_property(item, "current") and has_property(item, "loaded") and item.property("loaded")]

    # The aurora sways by a clock of its own, on a clear night that has nothing that drifts or falls.
    auroras = [item for item in visual_tree(root) if has_property(item, "sight") and has_property(item, "phase") and item.property("opacity") > 0]

    return {
        "scene": [(scene.property("fallClock"), scene.property("driftClock")) for scene in scenes] + [aurora.property("phase") for aurora in auroras],
        "icons": [film.property("current") for film in films],
    }


def build_stage(engine, arguments, configuration):
    def fixture(name):
        return (FIXTURES / name).read_text(encoding="utf-8")

    properties = {
        "fixtureJson": Path(arguments.forecast).read_text(encoding="utf-8") if arguments.forecast else fixture("forecast-constanta.json"),
        "currentOverridesJson": arguments.current,
        "language": arguments.lang,
        "windUnit": arguments.wind,
        "precipitationUnit": arguments.precipitation,
        "tab": arguments.tab,
        "mode": arguments.mode,
        "firstDayOfWeek": arguments.first_day,
        "animations": arguments.animations,
        "hiddenTabs": arguments.hide,
        "fontScale": arguments.font_scale,
        "fontFamily": arguments.font,
        "iconSet": arguments.icons,
        "background": arguments.background,
        "places": [{"name": name, "latitude": 45.0 + index, "longitude": 25.0, "region": "", "countryCode": "RO"} for index, name in enumerate(filter(None, arguments.places.split(",")))],
        "picker": arguments.picker,
        "airQualityJson": fixture("airquality-spring.json") if arguments.pollen else fixture("airquality-constanta.json") if arguments.air else "",
        "auroraSight": arguments.aurora,
        "detailsOrder": list(filter(None, arguments.details_order.split(","))),
        "hiddenTiles": arguments.hide_tile,
        "landscape": arguments.landscape,
        "landscapeHeight": arguments.landscape_height,
        "todayParts": arguments.today.split(","),
        "todayGlass": arguments.glass,
        "todayBackground": arguments.backdrop,
        "detailsBoxes": arguments.details_boxes,
        "detailsGlass": arguments.details_glass,
        "backgroundTransparency": arguments.transparency,
        "region": arguments.region,
        "locality": arguments.locality,
    }

    if arguments.alerts:
        properties["alertsFeed"] = fixture("alerts-meteoalarm-romania.xml")
        properties["alertsCap"] = fixture("alerts-cap-wind.xml")
        properties["alertsNowcast"] = fixture("alerts-anm-nowcasting.xml")

    return create(QQmlComponent(engine, url(HERE / "Stage.qml")), properties)


def build_applet(engine, arguments, configuration):
    root = create(QQmlComponent(engine, url(PACKAGE / "contents/ui/main.qml")))
    applet_root.append(root)

    # The tooltip of the panel, on its own.
    if arguments.tooltip:
        QTimer.singleShot(max(0, arguments.wait - 100), lambda: print(f"tooltip: {root.property('toolTipItem').property('implicitWidth')}x{root.property('toolTipItem').property('implicitHeight')}"))

        return root.property("toolTipItem")
    representation = root.property("compactRepresentation" if arguments.compact else "fullRepresentation")
    item = create(representation, context=representation.creationContext())

    # Keeps the PlasmoidItem, and the store inside it, alive for as long as the view.
    root.setParent(item)

    def report():
        applet = shim_plasmoid.applet()
        # What Plasma shows where switch sizes are not set: the representation the widget prefers.
        preferred = root.property("preferredRepresentation")
        shown = "none" if preferred is None else "full" if getCppPointer(preferred) == getCppPointer(root.property("fullRepresentation")) else "compact"
        print(f"applet: icon={applet.property('icon')!r} tooltip={root.property('toolTipMainText')!r} / {root.property('toolTipSubText')!r} actions={len(applet.actions)} backgroundHints={applet.property('backgroundHints')} shown={shown}")

    if arguments.tab and not arguments.compact:
        item.setProperty("currentTab", arguments.tab)

    QTimer.singleShot(max(0, arguments.wait - 100), report)

    return item


def setting_value(given, value):
    """`value`, as written on the command line, of the type of the setting, whose value is now `given`."""
    # bool("false") is True.
    if isinstance(given, bool):
        return value == "true"

    # A list is given as words separated by commas, or as JSON when its items hold commas themselves.
    if isinstance(given, list):
        return json.loads(value) if value.startswith("[") else value.split(",")

    return type(given)(value)


def hand_settings(page, source, configuration, defaults):
    """
    Plasma 6.7 hands every setting and its default to every page. Whatever a page lacks ends up in
    the journal as "Setting initial properties failed", which the Qt of the viewer does not report.
    """
    for key, value in configuration.items():
        for name, given in ((f"cfg_{key}", value), (f"cfg_{key}Default", defaults[key])):
            if page.metaObject().indexOfProperty(name) < 0:
                problems.append(f"{source} does not have a property called {name}")
                print(f"[qml] {problems[-1]}", file=sys.stderr)
                continue

            page.setProperty(name, given)

            # Apply writes every setting back from the page, so one the page does not touch must survive the trip.
            if page.property(name) != given:
                problems.append(f"{source} gives {name} back as {page.property(name)!r}, not {given!r}")
                print(f"[qml] {problems[-1]}", file=sys.stderr)


def build_config(engine, arguments, configuration):
    model = create(QQmlComponent(engine, url(PACKAGE / "contents/config/config.qml")))
    categories = QQmlListReference(model, "categories")
    names = [categories.at(index).property("name") for index in range(categories.count())]
    category = categories.at(arguments.page)
    page = create(QQmlComponent(engine, url(PACKAGE / "contents/ui" / category.property("source"))))

    print(f"config: pages={names} showing={category.property('name')!r} icon={category.property('icon')!r}")
    hand_settings(page, category.property("source"), configuration, config_defaults())
    model.setParent(page)

    return page


def build_wallpaper(engine, arguments, configuration):
    """
    The wallpaper, with the weather of Open-Meteo; with --forecast or --current, with a recorded
    answer instead, at the time of its conditions.
    """
    recorded = bool(arguments.forecast) or arguments.current != "{}"

    # Before the wallpaper asks, so that its own request fails and leaves the recorded answer alone.
    if recorded:
        offline.add("api.open-meteo.com")

    width, height = (int(side) for side in arguments.size.split("x"))
    # As Plasma makes it: at the size of the screen from the start.
    item = create(QQmlComponent(engine, url(WALLPAPER / "contents/ui/main.qml")), {"width": width, "height": height})

    if recorded:
        reader = QQmlComponent(engine)
        reader.setData(
            b"""import QtQuick
import "contents/code/openmeteo.mjs" as OpenMeteo

QtObject {
    property var target
    property string answer
    property string overrides

    Component.onCompleted: {
        const forecast = OpenMeteo.parseForecast(JSON.parse(answer));

        Object.assign(forecast.current, JSON.parse(overrides));
        target.forecast = forecast;
        target.now = forecast.current.time;
    }
}
""",
            url(WALLPAPER / "reader.qml"),
        )
        answer = Path(arguments.forecast).read_text(encoding="utf-8") if arguments.forecast else (FIXTURES / "forecast-constanta.json").read_text(encoding="utf-8")
        create(reader, {"target": item, "answer": answer, "overrides": arguments.current}).setParent(item)

    return item


def build_wallpaper_config(engine, arguments, configuration):
    page = create(QQmlComponent(engine, url(WALLPAPER / "contents/ui/config.qml")))

    hand_settings(page, "config.qml", configuration, config_defaults(WALLPAPER))

    return page


def record_frames(view, out, count, interval, done):
    """
    Saves `count` screenshots, one every `interval` milliseconds, as out-0000.png, out-0001.png…,
    and in out-times.txt the millisecond each was taken at, for an animation with the real timing.
    """
    stem = str(Path(out).with_suffix(""))
    clock = QElapsedTimer()
    times = []

    def grab():
        view.grabWindow().save(f"{stem}-{len(times):04d}.png")
        times.append(clock.elapsed())

        if len(times) < count:
            # Aimed at the next tick of the timeline, so that slow frames do not stretch it.
            QTimer.singleShot(max(0, interval * len(times) - clock.elapsed()), grab)
        else:
            Path(f"{stem}-times.txt").write_text("".join(f"{time}\n" for time in times))
            done()

    clock.start()
    grab()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["stage", "applet", "config", "wallpaper", "wallpaper-config"], help="wallpaper, wallpaper-config: run wallpaper/sync.sh first")
    parser.add_argument("out")
    parser.add_argument("--size", default="508x346")
    parser.add_argument("--wait", type=int, default=None, help="milliseconds before the screenshot")
    parser.add_argument("--light", action="store_true", help="light colour scheme")
    parser.add_argument("--background", default="theme", choices=["black", "theme", "none"], help="stage: the background of the widget")
    parser.add_argument("--transparency", type=int, default=100, help="stage: percent of transparency of the transparent background")
    parser.add_argument("--air", action="store_true", help="stage: show the recorded air quality")
    parser.add_argument("--pollen", action="store_true", help="stage: an air of spring, with the pollen of four days")
    parser.add_argument("--places", default="", help="stage: other places kept, by name, separated by commas")
    parser.add_argument("--picker", action="store_true", help="stage: the list of the other places hangs open")
    parser.add_argument("--aurora", default="none", choices=["none", "overhead", "horizon", "camera"], help="stage: how the aurora can be seen tonight, with a Kp of 6.33")
    parser.add_argument("--details-order", default="", metavar="TILES", help="stage: the tiles of the Details tab, by id, separated by commas")
    parser.add_argument("--glass", type=int, default=62, help="stage: percent of transparency of the glass of the Today tab")
    parser.add_argument("--backdrop", choices=["sky", "glass", "text"], default="sky", help="stage: what is behind the text of the Today tab")
    parser.add_argument("--details-boxes", choices=["theme", "glass"], default="theme", help="stage: the boxes of the Details tab")
    parser.add_argument("--details-glass", type=int, default=62, help="stage: percent of transparency of the dark glass of the Details tab")
    parser.add_argument("--today", default="hours,insights,rain,yesterday", metavar="PARTS", help="stage: what the Today tab shows, separated by commas")
    parser.add_argument("--landscape", default="none", choices=["none", "hills", "city", "sea", "poppies", "lake", "village"], help="stage: the land under the sky of the Today tab")
    parser.add_argument("--landscape-height", type=int, default=55, help="stage: percent of the height of the Today tab the land takes")
    parser.add_argument("--hide-tile", action="append", default=[], metavar="TILE", help="stage: a tile of the Details tab that is turned off")
    parser.add_argument("--tooltip", action="store_true", help="applet: show the tooltip of the panel")
    parser.add_argument("--drag", default="", metavar="X1,Y1:X2,Y2", help="press at the first point of the window and move to the second, 1.2 s before the screenshot")
    parser.add_argument("--hide-class", action="append", default=[], metavar="TYPE", help="with --resize-steps: hide every item of this QML type first, to find which one makes the resize slow")
    parser.add_argument("--resize-steps", type=int, default=0, metavar="COUNT", help="after --wait, shrink the window by a tenth in COUNT steps a frame apart, as Plasma does entering edit mode, and print how long each took")
    parser.add_argument("--trace-paint", action="store_true", help="print every time a Canvas paints, with the milliseconds since the start")
    parser.add_argument("--switch-frames", action="store_true", help="stage: go to the Hours tab and back to Today, then save --frames screenshots from the moment of the switch")
    parser.add_argument("--switch-to", type=int, default=-1, metavar="TAB", help="with --switch-frames: go from Today to this tab instead, and save the screenshots from then")
    parser.add_argument("--switch-via", type=int, default=1, metavar="TAB", help="with --switch-frames: the tab to go to before coming back to Today")
    parser.add_argument("--time-switch", action="store_true", help="stage: time switches from the Hours tab back to the Today tab")
    parser.add_argument("--drop", action="store_true", help="with --drag, let go at the end")
    parser.add_argument("--report-cut", action="store_true", help="before the screenshot, print every text on show that ends in … or is wider than its room")
    parser.add_argument("--wheel", default="", metavar="X,Y:NOTCHES", help="turn the mouse wheel over that point of the window, down for more than 0, 1.2 s before the screenshot, and print where each view scrolled to")
    parser.add_argument("--item-set", action="append", default=[], metavar="NAME=VALUE", help="set a property on every item that has it, halfway through --wait")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", help="override a setting of the widget")
    parser.add_argument("--apply", action="append", default=[], metavar="KEY=VALUE", help="config: choose this on the page and press Apply, as Plasma does it, the dialog left open; each in turn, and each must be saved")
    parser.add_argument("--lang", default="ro")
    parser.add_argument("--wind", default="kmh")
    parser.add_argument("--precipitation", default="mm", choices=["mm", "inch"], help="stage: the unit of rain and snow")
    parser.add_argument("--tab", type=int, default=0)
    parser.add_argument("--mode", default="ready", choices=["ready", "loading", "failed", "stale", "welcome"])
    parser.add_argument("--first-run", action="store_true", help="applet, config: start without a place, as a new user does")
    parser.add_argument("--search", default="", metavar="TEXT", help="at the first-run prompt: search for TEXT and pick the first place found")
    parser.add_argument("--current", default="{}", help="JSON merged into the current conditions of the fixture")
    parser.add_argument("--forecast", default="", metavar="FILE", help="stage: an Open-Meteo answer to show instead of the recorded one")
    parser.add_argument("--first-day", type=int, default=1, help="stage: first day of the week, 0 Sunday … 6 Saturday")
    parser.add_argument("--animations", default="off", choices=["full", "reduced", "off"], help="stage: off gives a still, repeatable picture")
    parser.add_argument("--hide", action="append", default=[], metavar="TAB", help="stage: a tab that is turned off")
    parser.add_argument("--font-scale", type=float, default=1.1)
    parser.add_argument("--font", default="")
    parser.add_argument("--icons", default="meteocons", choices=["meteocons", "breeze"])
    parser.add_argument("--alerts", action="store_true", help="stage: the recorded warnings")
    parser.add_argument("--region", default="Constanța")
    parser.add_argument("--locality", default="Constanța")
    parser.add_argument("--compact", action="store_true", help="applet: show the panel representation")
    parser.add_argument("--form-factor", default="horizontal", choices=list(shim_plasmoid.FORM_FACTORS), help="applet: where the widget is: planar is the desktop")
    parser.add_argument("--page", type=int, default=0)
    parser.add_argument("--frames", type=int, default=0, metavar="COUNT", help="save COUNT screenshots instead of one, as OUT-0000.png…, with their times in OUT-times.txt")
    parser.add_argument("--frame-interval", type=int, default=66, metavar="MS", help="milliseconds between those screenshots")
    parser.add_argument("--expect-motion", action="store_true", help="fail unless the animated scene and an icon are moving")
    parser.add_argument("--forbid-host", action="append", default=[], metavar="HOST", help="fail if HOST, or a subdomain of it, is asked for anything")
    parser.add_argument("--count-host", action="append", default=[], metavar="HOST", help="print how many requests went to HOST, or a subdomain of it")
    parser.add_argument("--expect-host", action="append", default=[], metavar="HOST", help="fail unless HOST, or a subdomain of it, is asked for something")
    arguments = parser.parse_args()

    if arguments.wait is None:
        arguments.wait = 4000 if arguments.what == "applet" else 500

    qInstallMessageHandler(on_message)
    application = QGuiApplication(sys.argv[:1])
    register_qml_shims()

    wallpaper = arguments.what.startswith("wallpaper")
    configuration = config_defaults(WALLPAPER if wallpaper else PACKAGE)

    if not arguments.first_run:
        configuration.update({key: value for key, value in PLACE.items() if key in configuration})

    for assignment in arguments.set:
        key, value = assignment.split("=", 1)
        configuration[key] = setting_value(configuration[key], value)

    settings = shim_plasmoid.wallpaper_configuration() if wallpaper else shim_plasmoid.applet().property("configuration")

    for key, value in configuration.items():
        settings.insert(key, value)

    width, height = (int(side) for side in arguments.size.split("x"))
    view = QQuickView()
    # The engine does not own its factory; the variable keeps it alive for the whole run.
    factory = RecordingFactory()
    view.engine().setNetworkAccessManagerFactory(factory)
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    view.setSource(url(HERE / "Host.qml"))
    view.resize(width, height)

    shim_kirigami.set_dark(not arguments.light)
    shim_plasmoid.form_factor[0] = shim_plasmoid.FORM_FACTORS[arguments.form_factor]

    content = view.rootObject().findChild(QQuickItem, "content")
    builders = {"stage": build_stage, "applet": build_applet, "config": build_config, "wallpaper": build_wallpaper, "wallpaper-config": build_wallpaper_config}
    item = builders[arguments.what](view.engine(), arguments, configuration)

    # A wallpaper has the whole screen, without the frame of a widget.
    if arguments.what == "wallpaper":
        content = view.rootObject()

    item.setParentItem(content)

    # Plasma draws no frame around a widget that asks for no background.
    def follow_background():
        framed = arguments.background == "theme" if arguments.what == "stage" else shim_plasmoid.applet().property("backgroundHints") != 0
        view.rootObject().setProperty("framed", framed)

    shim_plasmoid.applet().backgroundHintsChanged.connect(follow_background)
    follow_background()

    def fit():
        item.setWidth(content.width())
        item.setHeight(content.height())

    content.widthChanged.connect(fit)
    content.heightChanged.connect(fit)
    view.show()
    fit()

    def frames():
        record_frames(view, arguments.out, arguments.frames, arguments.frame_interval, shoot)

    def shoot():
        saved = view.grabWindow().save(arguments.out)
        print(f"screenshot: {arguments.out} saved={saved} problems={len(problems)}")
        application.quit()

    def watch_motion():
        before = motion(item)

        def compare():
            after = motion(item)

            if not before["scene"] and not before["icons"]:
                problems.append("there is nothing here that could move")

            # A tab without a scene, or without icons, is not held to them. Stage a weather
            # with clouds or precipitation: a clear sky has nothing that drifts or falls.
            for what in ("scene", "icons"):
                if not before[what]:
                    continue

                moved = before[what] != after[what]
                print(f"motion: {what} {'moves' if moved else 'STANDS STILL'}  {before[what][:3]} -> {after[what][:3]}")

                if not moved:
                    problems.append(f"the {what} do not move")

            shoot()

        QTimer.singleShot(800, compare)

    def search_place():
        """Types into the prompt, lets the search answer, picks the first place and reports what the widget did with it."""
        fields = [candidate for candidate in visual_tree(item) if has_property(candidate, "placeholderText")]

        if not fields:
            problems.append("there is no search field to type into")
            return shoot()

        fields[0].setProperty("text", arguments.search)
        QMetaObject.invokeMethod(fields[0], "accepted")

        def pick():
            found = [candidate for candidate in visual_tree(item) if has_property(candidate, "modelData") and has_property(candidate, "text")]
            print(f"search: {len(found)} places for {arguments.search!r}; first: {found[0].property('text') if found else None!r}")

            if not found:
                problems.append("the search found no place to pick")
                return shoot()

            QMetaObject.invokeMethod(found[0], "clicked")
            QTimer.singleShot(arguments.wait, report_place)

        def report_place():
            applet = shim_plasmoid.applet().property("configuration")
            chosen = item.property("chosenPlace")
            chosen = chosen.toVariant() if hasattr(chosen, "toVariant") else chosen
            print(f"picked: stage={chosen!r} settings={ {key: applet.value(key) for key in PLACE} }")

            for root in applet_root:
                print(f"after picking: tooltip={root.property('toolTipMainText')!r} / {root.property('toolTipSubText')!r}")
            shoot()

        QTimer.singleShot(4000, pick)

    # Sets a property on every item that has it, once the view is built: a day opened, a tile under the mouse.
    def poke():
        for assignment in arguments.item_set:
            name, value = assignment.split("=", 1)
            value = {"true": True, "false": False}.get(value, value)
            touched = [item for item in visual_tree(item_root[0]) if has_property(item, name)]

            for target in touched:
                target.setProperty(name, value)

            print(f"item-set: {name}={value!r} on {len(touched)} items")

    item_root = [item]

    # Each choice made on the page and applied, the dialog staying open: Plasma calls saveConfig(), then
    # writes every setting back from the page.
    def apply_choices():
        for assignment in arguments.apply:
            key, value = assignment.split("=", 1)
            chosen = setting_value(configuration[key], value)

            item.setProperty(f"cfg_{key}", chosen)
            QMetaObject.invokeMethod(item, "saveConfig")

            for name in configuration:
                written = item.property(f"cfg_{name}")
                settings.insert(name, written.toVariant() if hasattr(written, "toVariant") else written)

            saved = settings.value(key)
            print(f"apply: {key}={chosen!r} saved {saved!r}")

            if saved != chosen:
                problems.append(f"Apply saved {key} as {saved!r}, not {chosen!r}")
                print(f"[qml] {problems[-1]}", file=sys.stderr)

    if arguments.apply:
        QTimer.singleShot(max(0, arguments.wait // 2), apply_choices)

    if arguments.item_set:
        QTimer.singleShot(max(0, arguments.wait // 2), poke)

    # Presses at the first point and moves to the second, as a hand on the mouse would, in time for the screenshot.
    def drag():
        from PySide6.QtCore import QPoint, Qt
        from PySide6.QtTest import QTest

        (x1, y1), (x2, y2) = [tuple(int(value) for value in point.split(",")) for point in arguments.drag.split(":")]
        steps = 15

        QTest.mousePress(view, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, QPoint(x1, y1))

        def step(index):
            point = QPoint(x1 + (x2 - x1) * index // steps, y1 + (y2 - y1) * index // steps)
            QTest.mouseMove(view, point)

            if index < steps:
                QTimer.singleShot(30, lambda: step(index + 1))
            elif arguments.drop:
                QTest.mouseRelease(view, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)

        QTimer.singleShot(30, lambda: step(1))

    if arguments.drag:
        QTimer.singleShot(max(0, arguments.wait - 1200), drag)

    # Notch by notch, as a mouse wheel turns, over the point; then where every view stands.
    def wheel():
        from PySide6.QtCore import QPoint, QPointF, Qt
        from PySide6.QtGui import QWheelEvent
        from PySide6.QtTest import QTest

        place, notches = arguments.wheel.split(":")
        x, y = (int(value) for value in place.split(","))
        QTest.mouseMove(view, QPoint(x, y))

        for _ in range(abs(int(notches))):
            turn = QPoint(0, -120 if int(notches) > 0 else 120)
            event = QWheelEvent(QPointF(x, y), QPointF(view.mapToGlobal(QPoint(x, y))), QPoint(0, 0), turn, Qt.MouseButton.NoButton, Qt.KeyboardModifier.NoModifier, Qt.ScrollPhase.NoScrollPhase, False)
            QGuiApplication.sendEvent(view, event)

        views = [(round(candidate.property("contentY")), round(candidate.property("contentHeight") - candidate.property("height"))) for candidate in visual_tree(item_root[0]) if has_property(candidate, "contentY") and has_property(candidate, "flicking")]
        print(f"wheel: {notches} notches at {x},{y}; each view at contentY, of most: {views}")

    if arguments.wheel:
        QTimer.singleShot(max(0, arguments.wait - 1200), wheel)

    # Texts cut short: elided, past their last line, or wider than the item that holds them.
    def report_cut():
        def shown(candidate):
            while candidate is not None:
                if not candidate.isVisible() or candidate.opacity() == 0:
                    return False
                candidate = candidate.parentItem()
            return True

        for candidate in visual_tree(item_root[0]):
            if not has_property(candidate, "truncated") or not has_property(candidate, "contentWidth") or not shown(candidate):
                continue

            text = str(candidate.property("text") or "").replace("\n", " / ")
            wider = candidate.property("contentWidth") > candidate.property("width") + 1

            if text and (candidate.property("truncated") or wider):
                print(f"cut: {text!r} width={candidate.property('width'):.0f} needs={candidate.property('contentWidth'):.0f} elided={candidate.property('truncated')}")

    if arguments.report_cut:
        QTimer.singleShot(max(0, arguments.wait - 200), report_cut)

    # How long a switch from the Hours tab back to the Today tab takes, to the first frame shown.
    def time_switch():
        clock = QElapsedTimer()
        times = []
        full = next(candidate for candidate in visual_tree(item) if has_property(candidate, "currentTab"))

        away = []

        for attempt in range(4):
            clock.start()
            full.setProperty("currentTab", 1)
            view.grabWindow()
            away.append(clock.elapsed())
            clock.start()
            full.setProperty("currentTab", 0)

            # A canvas paints a frame or two after it is made: the switch is over once they have.
            for frame in range(4):
                view.grabWindow()

            times.append(clock.elapsed())

        print(f"switch to Today: {times} ms")
        print(f"switch away from Today: {away} ms")

    if arguments.time_switch:
        QTimer.singleShot(max(0, arguments.wait - 600), time_switch)

    if arguments.trace_paint:
        from PySide6.QtCore import QObject as Object, SIGNAL

        started = QElapsedTimer()
        started.start()
        traced = set()

        def trace():
            for candidate in visual_tree(item):
                if candidate.metaObject().indexOfSignal("painted()") >= 0 and id(candidate) not in traced:
                    traced.add(id(candidate))
                    chain = []
                    ancestor = candidate

                    while ancestor is not None and len(chain) < 4:
                        chain.append(ancestor.metaObject().className().split("_QML")[0])
                        ancestor = ancestor.parentItem()

                    label = f"{'<'.join(chain)} {int(candidate.width())}x{int(candidate.height())}"
                    Object.connect(candidate, SIGNAL("painted()"), lambda label=label: print(f"[paint] {started.elapsed():6d} ms {label}"))

                    for signal in ("widthChanged()", "heightChanged()"):
                        Object.connect(candidate, SIGNAL(signal), lambda label=label, signal=signal, candidate=candidate: print(f"[size] {started.elapsed():6d} ms {label} {signal} -> {candidate.width():.0f}x{candidate.height():.0f}"))

            QTimer.singleShot(200, trace)

        trace()

    # Resizes as an animation does, a frame at a time, and times each frame.
    def resize_steps():
        for candidate in visual_tree(item):
            if any(candidate.metaObject().className().startswith(name) for name in arguments.hide_class):
                candidate.setProperty("visible", False)

        QGuiApplication.processEvents()
        view.grabWindow()
        clock = QElapsedTimer()
        started = view.width(), view.height()
        times = []

        for step in range(1, arguments.resize_steps + 1):
            share = 1 - 0.1 * step / arguments.resize_steps
            clock.start()
            view.resize(int(started[0] * share), int(started[1] * share))
            resized = clock.elapsed()
            QGuiApplication.processEvents()
            processed = clock.elapsed()
            view.grabWindow()
            times.append(clock.elapsed())
            print(f"resize step {step}: resize {resized} ms, events {processed - resized} ms, frame {clock.elapsed() - processed} ms")

        print(f"resize: {times} ms, {sum(times)} in all")
        application.quit()

    if arguments.resize_steps:
        QTimer.singleShot(arguments.wait, resize_steps)
        application.exec()
        sys.exit(1 if problems else 0)

    # What the Today tab looks like, frame by frame, as it comes back.
    def switch_back():
        full = next(candidate for candidate in visual_tree(item) if has_property(candidate, "currentTab"))

        if arguments.switch_to >= 0:
            full.setProperty("currentTab", arguments.switch_to)
            record_frames(view, arguments.out, arguments.frames, arguments.frame_interval, application.quit)

            return

        full.setProperty("currentTab", arguments.switch_via)
        QTimer.singleShot(1000, lambda: (full.setProperty("currentTab", 0), record_frames(view, arguments.out, arguments.frames, arguments.frame_interval, application.quit)))

    if arguments.switch_frames:
        QTimer.singleShot(arguments.wait, switch_back)
        application.exec()
        sys.exit(1 if problems else 0)

    if arguments.search:
        QTimer.singleShot(500, search_place)
    else:
        QTimer.singleShot(arguments.wait, watch_motion if arguments.expect_motion else frames if arguments.frames else shoot)
    application.exec()

    if arguments.forbid_host or arguments.expect_host:
        print(f"requests: {sorted({address.host() for address in requested})}")

    for host in arguments.forbid_host:
        if asked(host):
            problems.append(f"{host} was asked for {asked(host)}")
            print(f"[network] {problems[-1]}", file=sys.stderr)

    for host in arguments.count_host:
        print(f"requests to {host}: {len(asked(host))}")

        for address in asked(host):
            print(f"  {address[:140]}")

    for host in arguments.expect_host:
        if not asked(host):
            problems.append(f"{host} was never asked for anything")
            print(f"[network] {problems[-1]}", file=sys.stderr)

    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
