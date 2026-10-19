import QtQuick
import org.kde.kirigami as Kirigami

// A stand-in for the desktop and the frame Plasma draws around a widget.
Rectangle {
    color: Kirigami.Theme.dark ? "#3b1560" : "#9fb6cc"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 6
        color: Kirigami.Theme.backgroundColor

        Item {
            objectName: "content"
            anchors.fill: parent
            anchors.margins: 10
        }
    }
}
