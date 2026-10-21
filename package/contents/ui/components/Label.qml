import QtQuick
import org.kde.plasma.components as PlasmaComponents

/**
 * A label in the font and the size chosen in the settings of the widget. Plain text unless it says
 * otherwise: much of what it shows comes from the feeds, and a label that read markup in it loaded
 * the pictures a feed named, as it was shown.
 */
PlasmaComponents.Label {
    /** `{ family, size }`, see `typography` in FullRepresentation. */
    required property var typography
    /** Size of the text relative to the base size of the widget. */
    property real relativeSize: 1

    font.family: typography.family
    font.pointSize: typography.size * relativeSize
    textFormat: Text.PlainText
}
