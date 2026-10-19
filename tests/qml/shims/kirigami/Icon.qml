import QtQuick

// Shows the requested icon name instead of the themed icon.
Item {
    id: icon

    property var source
    property bool isMask: false
    property color color: "#ffd75e"

    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: width / 5
        visible: !icon.isMask
        color: "#33ffffff"
        border.color: "#66ffffff"
    }

    Text {
        anchors.fill: parent
        anchors.margins: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WrapAnywhere
        color: icon.color
        font.pixelSize: icon.isMask ? icon.height * 0.9 : Math.max(7, icon.width / 6)
        text: icon.isMask ? "⚠" : String(icon.source).replace("weather-", "")
    }
}
