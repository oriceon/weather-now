import QtQuick
import org.kde.plasma.components as PlasmaComponents

/** A label in the font and the size chosen in the settings of the widget. */
PlasmaComponents.Label {
    /** `{ family, size }`, see `typography` in FullRepresentation. */
    required property var typography
    /** Size of the text relative to the base size of the widget. */
    property real relativeSize: 1

    font.family: typography.family
    font.pointSize: typography.size * relativeSize
}
