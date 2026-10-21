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
    /** Empty for the font of the Plasma theme. */
    required property string fontFamily
    /** When the next rain starts, as "18:00"; empty when none is coming soon. */
    required property string rainStart

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Layout.minimumWidth: vertical ? 0 : content.implicitWidth
    Layout.minimumHeight: vertical ? content.implicitHeight : 0

    GridLayout {
        id: content

        anchors.centerIn: parent
        columns: compact.vertical ? 1 : 3
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
            font.family: compact.fontFamily !== "" ? compact.fontFamily : Kirigami.Theme.defaultFont.family
            text: compact.temperatureText
        }

        // Rain on its way: an umbrella and the hour it starts.
        Row {
            Layout.alignment: Qt.AlignCenter
            visible: compact.rainStart !== ""
            spacing: 2

            Components.UmbrellaMark {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(rainTime.font.pixelSize * 0.95)
                height: width
                colour: Kirigami.Theme.linkColor
            }

            PlasmaComponents.Label {
                id: rainTime

                font.family: compact.fontFamily !== "" ? compact.fontFamily : Kirigami.Theme.defaultFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.linkColor
                text: compact.rainStart
            }
        }
    }
}
