import QtQuick
import QtQuick.Controls.Basic as Basic
import org.kde.kirigami as Kirigami

Basic.ToolButton {
    id: button

    readonly property bool iconOnly: display === Basic.AbstractButton.IconOnly
    /** A glyph in place of the icons of the theme, which the viewer does not have, for the icons the widget uses. */
    readonly property string glyph: ({
        "zoom-in": "+",
        "zoom-out": "−",
        "media-playback-pause": "‖",
        "media-playback-start": "▶",
        "list-add": "+",
        "edit-delete-remove": "✕",
    })[icon.name] || "⟳"

    implicitWidth: iconOnly ? 28 : label.implicitWidth + 16
    implicitHeight: 28

    contentItem: Text {
        id: label

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: button.icon.color.a > 0 ? button.icon.color : Kirigami.Theme.textColor
        opacity: button.enabled ? 1 : 0.4
        font: button.font
        text: button.iconOnly ? button.glyph : button.text
    }

    background: Rectangle {
        radius: 4
        color: button.checked ? Kirigami.Theme.highlightColor : "#22ffffff"
    }
}
