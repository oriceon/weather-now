import QtQuick
import QtQuick.Controls.Basic as Basic
import org.kde.kirigami as Kirigami

Basic.TabButton {
    id: button

    contentItem: Text {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Kirigami.Theme.textColor
        font: button.font
        text: button.text
    }

    background: Item {
        implicitHeight: 30

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 3
            color: button.checked ? Kirigami.Theme.highlightColor : "transparent"
        }
    }
}
