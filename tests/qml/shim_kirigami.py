"""Stand-in for the part of org.kde.kirigami that has to be native: the `FormData` attached properties."""

from PySide6.QtCore import Property, QObject, Signal
from PySide6.QtQml import QmlAnonymous, QmlAttached, QmlElement

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
