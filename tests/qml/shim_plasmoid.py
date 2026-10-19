"""Stand-in for the org.kde.plasma.plasmoid QML module: the `Plasmoid` attached object and `PlasmoidItem`."""

from PySide6.QtCore import Property, QObject, Signal
from PySide6.QtQml import ListProperty, QmlAnonymous, QmlAttached, QmlElement, QQmlComponent, QQmlPropertyMap
from PySide6.QtQuick import QQuickItem

QML_IMPORT_NAME = "org.kde.plasma.plasmoid"
QML_IMPORT_MAJOR_VERSION = 1

HORIZONTAL_FORM_FACTOR = 2


def accessors(name, signal_name):
    """Getter and setter of a notifying property stored in `_<name>`."""

    def getter(self):
        return getattr(self, f"_{name}")

    def setter(self, value):
        if getattr(self, f"_{name}") != value:
            setattr(self, f"_{name}", value)
            getattr(self, signal_name).emit()

    return getter, setter


@QmlAnonymous
class Applet(QObject):
    """What `Plasmoid.` resolves to anywhere inside the widget."""

    iconChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._configuration = QQmlPropertyMap(self)
        self._icon = ""
        self.actions = []

    @Property(QObject, constant=True)
    def configuration(self):
        return self._configuration

    @Property(int, constant=True)
    def formFactor(self):
        return HORIZONTAL_FORM_FACTOR

    @Property(str, constant=True)
    def title(self):
        return "Weather Now"

    @Property(str, constant=True)
    def pluginName(self):
        return "ro.oriceon.weather"

    icon = Property(str, *accessors("icon", "iconChanged"), notify=iconChanged)

    def append_action(self, action):
        self.actions.append(action)

    contextualActions = ListProperty(QObject, append_action)


_applet = None


def applet():
    """The single applet every `Plasmoid` attachment shares; created on first use, after the application exists."""
    global _applet

    if _applet is None:
        _applet = Applet()

    return _applet


@QmlElement
@QmlAttached(Applet)
class Plasmoid(QObject):
    @staticmethod
    def qmlAttachedProperties(self, attachee):
        return applet()


@QmlElement
class PlasmoidItem(QQuickItem):
    compactRepresentationChanged = Signal()
    fullRepresentationChanged = Signal()
    switchWidthChanged = Signal()
    switchHeightChanged = Signal()
    toolTipMainTextChanged = Signal()
    toolTipSubTextChanged = Signal()
    expandedChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._compactRepresentation = None
        self._fullRepresentation = None
        self._switchWidth = 0.0
        self._switchHeight = 0.0
        self._toolTipMainText = ""
        self._toolTipSubText = ""
        self._expanded = False

    compactRepresentation = Property(QQmlComponent, *accessors("compactRepresentation", "compactRepresentationChanged"), notify=compactRepresentationChanged)
    fullRepresentation = Property(QQmlComponent, *accessors("fullRepresentation", "fullRepresentationChanged"), notify=fullRepresentationChanged)
    switchWidth = Property(float, *accessors("switchWidth", "switchWidthChanged"), notify=switchWidthChanged)
    switchHeight = Property(float, *accessors("switchHeight", "switchHeightChanged"), notify=switchHeightChanged)
    toolTipMainText = Property(str, *accessors("toolTipMainText", "toolTipMainTextChanged"), notify=toolTipMainTextChanged)
    toolTipSubText = Property(str, *accessors("toolTipSubText", "toolTipSubTextChanged"), notify=toolTipSubTextChanged)
    expanded = Property(bool, *accessors("expanded", "expandedChanged"), notify=expandedChanged)
