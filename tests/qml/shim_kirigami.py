"""
Stand-in for the part of org.kde.kirigami that has to be native: the `FormData` attached properties,
and `Theme`, whose colours an item hands down to the items inside it. An item that sets
`Kirigami.Theme.inherit: false` and a `colorSet` gives itself and everything inside it that set's
colours, as Kirigami does; the widget uses it for the colours of its black background.
"""

from enum import IntEnum

from PySide6.QtCore import Property, QEnum, QObject, Signal
from PySide6.QtGui import QColor, QFont
from PySide6.QtQml import QmlAnonymous, QmlAttached, QmlElement
from PySide6.QtQuick import QQuickItem
from shiboken6 import getCppPointer, isValid

from shim_plasmoid import accessors

QML_IMPORT_NAME = "org.kde.kirigami"
QML_IMPORT_MAJOR_VERSION = 1


@QmlAnonymous
class FormDataAttached(QObject):
    labelChanged = Signal()
    isSectionChanged = Signal()
    buddyForChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._label = ""
        self._isSection = False
        self._buddyFor = None

    label = Property(str, *accessors("label", "labelChanged"), notify=labelChanged)
    isSection = Property(bool, *accessors("isSection", "isSectionChanged"), notify=isSectionChanged)
    buddyFor = Property(QObject, *accessors("buddyFor", "buddyForChanged"), notify=buddyForChanged)


@QmlElement
@QmlAttached(FormDataAttached)
class FormData(QObject):
    @staticmethod
    def qmlAttachedProperties(self, attachee):
        return FormDataAttached(attachee)


#: The colours of Breeze and Breeze Dark, and of the complementary set, which is dark under both.
PALETTES = {
    "dark": {
        "textColor": "#fcfcfc", "disabledTextColor": "#a1a9b1", "backgroundColor": "#2a2738", "alternateBackgroundColor": "#322f43",
        "highlightColor": "#c217c9", "highlightedTextColor": "#ffffff", "linkColor": "#5cb7f0",
        "positiveTextColor": "#27ae60", "neutralTextColor": "#f67400", "negativeTextColor": "#da4453", "focusColor": "#3daee9",
    },
    "light": {
        "textColor": "#232629", "disabledTextColor": "#707d8a", "backgroundColor": "#eff0f1", "alternateBackgroundColor": "#e3e5e7",
        "highlightColor": "#3daee9", "highlightedTextColor": "#ffffff", "linkColor": "#2980b9",
        "positiveTextColor": "#27ae60", "neutralTextColor": "#f67400", "negativeTextColor": "#da4453", "focusColor": "#3daee9",
    },
    "complementary": {
        "textColor": "#fcfcfc", "disabledTextColor": "#a1a9b1", "backgroundColor": "#2a2e32", "alternateBackgroundColor": "#1b1e20",
        "highlightColor": "#3daee9", "highlightedTextColor": "#fcfcfc", "linkColor": "#1d99f3",
        "positiveTextColor": "#27ae60", "neutralTextColor": "#f67400", "negativeTextColor": "#da4453", "focusColor": "#3daee9",
    },
}


#: Values of `Theme.ColorSet`, below.
VIEW = 0
COMPLEMENTARY = 5


#: The colour scheme of the viewer, which every theme shares.
STATE = {"dark": True}
#: The theme attached to each item, by the address of the item.
ATTACHED = {}


def notify_all():
    """Any change may change the colours of any theme, so all of them say so; the viewer has few."""
    for theme in list(ATTACHED.values()):
        if isValid(theme):
            theme.changed.emit()


def set_dark(dark):
    STATE["dark"] = dark
    notify_all()


def address(thing):
    return getCppPointer(thing)[0]


def colour_property(name, notify):
    return Property(QColor, lambda self: QColor(self.palette()[name]), notify=notify)


@QmlAnonymous
class ThemeAttached(QObject):
    changed = Signal()

    def __init__(self, attachee):
        super().__init__(attachee)
        self._attachee = attachee
        self._inherit = True
        self._colorSet = VIEW
        key = address(attachee)
        ATTACHED[key] = self
        attachee.destroyed.connect(lambda: ATTACHED.pop(key, None))

        if isinstance(attachee, QQuickItem):
            attachee.parentChanged.connect(notify_all)

    def outer(self):
        """The theme of the nearest item around this one that has one, or None; items being destroyed have none."""
        thing = self._attachee

        while isValid(thing):
            thing = thing.parentItem() or thing.parent() if isinstance(thing, QQuickItem) else thing.parent()

            if thing is None or not isValid(thing):
                return None

            found = ATTACHED.get(address(thing))

            if found is not None and isValid(found):
                return found

        return None

    def effectiveColorSet(self):
        if not self._inherit:
            return self._colorSet

        around = self.outer()

        return around.effectiveColorSet() if around is not None else VIEW

    def palette(self):
        if self.effectiveColorSet() == COMPLEMENTARY:
            return PALETTES["complementary"]

        return PALETTES["dark" if STATE["dark"] else "light"]

    def get_inherit(self):
        return self._inherit

    def set_inherit(self, inherit):
        if self._inherit != inherit:
            self._inherit = inherit
            notify_all()

    def get_color_set(self):
        return self._colorSet

    def set_color_set(self, color_set):
        if self._colorSet != color_set:
            self._colorSet = int(color_set)
            notify_all()

    inherit = Property(bool, get_inherit, set_inherit, notify=changed)
    colorSet = Property(int, get_color_set, set_color_set, notify=changed)
    #: Only the viewer reads it, for the colour of the desktop stand-in.
    dark = Property(bool, lambda self: STATE["dark"], notify=changed)

    textColor = colour_property("textColor", changed)
    disabledTextColor = colour_property("disabledTextColor", changed)
    backgroundColor = colour_property("backgroundColor", changed)
    alternateBackgroundColor = colour_property("alternateBackgroundColor", changed)
    highlightColor = colour_property("highlightColor", changed)
    highlightedTextColor = colour_property("highlightedTextColor", changed)
    linkColor = colour_property("linkColor", changed)
    positiveTextColor = colour_property("positiveTextColor", changed)
    neutralTextColor = colour_property("neutralTextColor", changed)
    negativeTextColor = colour_property("negativeTextColor", changed)
    focusColor = colour_property("focusColor", changed)

    defaultFont = Property(QFont, lambda self: QFont(QFont().family(), 10), constant=True)
    smallFont = Property(QFont, lambda self: QFont(QFont().family(), 8), constant=True)


@QmlElement
@QmlAttached(ThemeAttached)
class Theme(QObject):
    @QEnum
    class ColorSet(IntEnum):
        View = VIEW
        Window = 1
        Button = 2
        Selection = 3
        Tooltip = 4
        Complementary = COMPLEMENTARY
        Header = 6

    @staticmethod
    def qmlAttachedProperties(self, attachee):
        return ThemeAttached(attachee)
