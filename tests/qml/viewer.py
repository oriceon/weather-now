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
import os
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QElapsedTimer, QMetaObject, QTimer, QUrl, QtMsgType, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtNetwork import QNetworkAccessManager
from PySide6.QtQml import QQmlComponent, QQmlListReference, QQmlNetworkAccessManagerFactory, qmlRegisterSingletonType, qmlRegisterType
from PySide6.QtQuick import QQuickItem, QQuickView

import shim_kirigami  # noqa: F401 - importing registers the QML types
import shim_plasmoid

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent.parent / "package"
FIXTURES = HERE.parent / "fixtures"

QML_SHIMS = {
    "org.kde.kirigami": ("kirigami", ["Icon", "FormLayout"], ["Units", "Theme"]),
    "org.kde.plasma.components": ("components", ["Label", "TabBar", "TabButton", "ToolButton", "Button", "BusyIndicator", "ToolTip", "ScrollBar", "TextField"], []),
    "org.kde.plasma.core": ("misc", ["Action", "Types"], []),
    "org.kde.kcmutils": ("misc", ["SimpleKCM"], []),
    "org.kde.plasma.configuration": ("misc", ["ConfigModel", "ConfigCategory"], []),
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


class RecordingAccessManager(QNetworkAccessManager):
    def createRequest(self, operation, request, data=None):
        requested.append(request.url())

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


def config_defaults():
    """The defaults of contents/config/main.xml, as Plasma would hand them to the widget."""
    namespace = {"kcfg": "http://www.kde.org/standards/kcfg/1.0"}
    casts = {
        "String": lambda text: text or "",
        "Double": float,
        "Int": int,
        "Bool": lambda text: text == "true",
        "StringList": lambda text: [item for item in (text or "").split(",") if item],
    }
    entries = ElementTree.parse(PACKAGE / "contents/config/main.xml").getroot().iterfind(".//kcfg:entry", namespace)

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

    return {
        "scene": [(scene.property("fallClock"), scene.property("driftClock")) for scene in scenes],
        "icons": [film.property("current") for film in films],
    }


def build_stage(engine, arguments, configuration):
    def fixture(name):
        return (FIXTURES / name).read_text(encoding="utf-8")

    properties = {
        "fixtureJson": fixture("forecast-constanta.json"),
        "currentOverridesJson": arguments.current,
        "language": arguments.lang,
        "windUnit": arguments.wind,
        "tab": arguments.tab,
        "mode": arguments.mode,
        "firstDayOfWeek": arguments.first_day,
        "animations": arguments.animations,
        "hiddenTabs": arguments.hide,
        "fontScale": arguments.font_scale,
        "fontFamily": arguments.font,
        "iconSet": arguments.icons,
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
    representation = root.property("compactRepresentation" if arguments.compact else "fullRepresentation")
    item = create(representation, context=representation.creationContext())

    # Keeps the PlasmoidItem, and the store inside it, alive for as long as the view.
    root.setParent(item)

    def report():
        applet = shim_plasmoid.applet()
        print(f"applet: icon={applet.property('icon')!r} tooltip={root.property('toolTipMainText')!r} / {root.property('toolTipSubText')!r} actions={len(applet.actions)}")

    if arguments.tab and not arguments.compact:
        item.setProperty("currentTab", arguments.tab)

    QTimer.singleShot(max(0, arguments.wait - 100), report)

    return item


def build_config(engine, arguments, configuration):
    model = create(QQmlComponent(engine, url(PACKAGE / "contents/config/config.qml")))
    categories = QQmlListReference(model, "categories")
    names = [categories.at(index).property("name") for index in range(categories.count())]
    category = categories.at(arguments.page)
    page = create(QQmlComponent(engine, url(PACKAGE / "contents/ui" / category.property("source"))))
    defaults = config_defaults()

    print(f"config: pages={names} showing={category.property('name')!r} icon={category.property('icon')!r}")

    # Plasma 6.7 hands every setting and its default to every page. Whatever a page lacks ends up in
    # the journal as "Setting initial properties failed", which the Qt of the viewer does not report.
    for key, value in configuration.items():
        for name, given in ((f"cfg_{key}", value), (f"cfg_{key}Default", defaults[key])):
            if page.metaObject().indexOfProperty(name) < 0:
                problems.append(f"{category.property('source')} does not have a property called {name}")
                print(f"[qml] {problems[-1]}", file=sys.stderr)
                continue

            page.setProperty(name, given)

            # Apply writes every setting back from the page, so one the page does not touch must survive the trip.
            if page.property(name) != given:
                problems.append(f"{category.property('source')} gives {name} back as {page.property(name)!r}, not {given!r}")
                print(f"[qml] {problems[-1]}", file=sys.stderr)

    model.setParent(page)

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
    parser.add_argument("what", choices=["stage", "applet", "config"])
    parser.add_argument("out")
    parser.add_argument("--size", default="508x346")
    parser.add_argument("--wait", type=int, default=None, help="milliseconds before the screenshot")
    parser.add_argument("--light", action="store_true", help="light colour scheme")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", help="override a setting of the widget")
    parser.add_argument("--lang", default="ro")
    parser.add_argument("--wind", default="kmh")
    parser.add_argument("--tab", type=int, default=0)
    parser.add_argument("--mode", default="ready", choices=["ready", "loading", "failed", "stale", "welcome"])
    parser.add_argument("--first-run", action="store_true", help="applet, config: start without a place, as a new user does")
    parser.add_argument("--search", default="", metavar="TEXT", help="at the first-run prompt: search for TEXT and pick the first place found")
    parser.add_argument("--current", default="{}", help="JSON merged into the current conditions of the fixture")
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
    parser.add_argument("--page", type=int, default=0)
    parser.add_argument("--frames", type=int, default=0, metavar="COUNT", help="save COUNT screenshots instead of one, as OUT-0000.png…, with their times in OUT-times.txt")
    parser.add_argument("--frame-interval", type=int, default=66, metavar="MS", help="milliseconds between those screenshots")
    parser.add_argument("--expect-motion", action="store_true", help="fail unless the animated scene and an icon are moving")
    parser.add_argument("--forbid-host", action="append", default=[], metavar="HOST", help="fail if HOST, or a subdomain of it, is asked for anything")
    parser.add_argument("--expect-host", action="append", default=[], metavar="HOST", help="fail unless HOST, or a subdomain of it, is asked for something")
    arguments = parser.parse_args()

    if arguments.wait is None:
        arguments.wait = 4000 if arguments.what == "applet" else 500

    qInstallMessageHandler(on_message)
    application = QGuiApplication(sys.argv[:1])
    register_qml_shims()

    configuration = config_defaults()

    if not arguments.first_run:
        configuration.update(PLACE)

    for assignment in arguments.set:
        key, value = assignment.split("=", 1)
        given = configuration[key]

        # bool("false") is True.
        if isinstance(given, bool):
            configuration[key] = value == "true"
        else:
            configuration[key] = value.split(",") if isinstance(given, list) else type(given)(value)

    for key, value in configuration.items():
        shim_plasmoid.applet().property("configuration").insert(key, value)

    width, height = (int(side) for side in arguments.size.split("x"))
    view = QQuickView()
    # The engine does not own its factory; the variable keeps it alive for the whole run.
    factory = RecordingFactory()
    view.engine().setNetworkAccessManagerFactory(factory)
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    view.setSource(url(HERE / "Host.qml"))
    view.resize(width, height)

    theme = view.engine().singletonInstance("org.kde.kirigami", "Theme")
    theme.setProperty("dark", not arguments.light)

    content = view.rootObject().findChild(QQuickItem, "content")
    item = {"stage": build_stage, "applet": build_applet, "config": build_config}[arguments.what](view.engine(), arguments, configuration)
    item.setParentItem(content)

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

    for host in arguments.expect_host:
        if not asked(host):
            problems.append(f"{host} was never asked for anything")
            print(f"[network] {problems[-1]}", file=sys.stderr)

    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
