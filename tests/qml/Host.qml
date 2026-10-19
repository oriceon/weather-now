import QtQuick
import org.kde.kirigami as Kirigami

// A stand-in for the desktop and the frame Plasma draws around a widget.
Rectangle {
    /** False for a widget that asks for no background. */
    property bool framed: true

    color: Kirigami.Theme.dark ? "#3b1560" : "#9fb6cc"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 6
        color: parent.framed ? Kirigami.Theme.backgroundColor : "transparent"

        Item {
            objectName: "content"
            anchors.fill: parent
            anchors.margins: 10
        }
    }
}
