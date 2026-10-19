import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "components" as Components

MouseArea {
    id: compact

    /** Condition code of the current weather; undefined while there is no forecast. */
    required property var conditionCode
    required property bool isDay
    /** meteocons | breeze */
    required property string iconSet
    required property string temperatureText

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Layout.minimumWidth: vertical ? 0 : content.implicitWidth
    Layout.minimumHeight: vertical ? content.implicitHeight : 0

    GridLayout {
        id: content

        anchors.centerIn: parent
        columns: compact.vertical ? 1 : 2
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: 0

        Components.WeatherIcon {
            readonly property real side: compact.vertical ? compact.width : compact.height

            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: side
            Layout.preferredHeight: side
            code: compact.conditionCode
            isDay: compact.isDay
            // A panel is no place for motion.
            iconStyle: ({ set: compact.iconSet, animated: false })
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignCenter
            visible: text !== ""
            text: compact.temperatureText
        }
    }
}
