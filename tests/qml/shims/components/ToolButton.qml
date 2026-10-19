import QtQuick
import QtQuick.Controls.Basic as Basic
import org.kde.kirigami as Kirigami

Basic.ToolButton {
    id: button

    readonly property bool iconOnly: display === Basic.AbstractButton.IconOnly

    implicitWidth: iconOnly ? 28 : label.implicitWidth + 16
    implicitHeight: 28

    contentItem: Text {
        id: label

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Kirigami.Theme.textColor
        opacity: button.enabled ? 1 : 0.4
        font: button.font
        text: button.iconOnly ? "⟳" : button.text
    }

    background: Rectangle {
        radius: 4
        color: button.checked ? Kirigami.Theme.highlightColor : "#22ffffff"
    }
}
