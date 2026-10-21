pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import "../../code/dates.mjs" as Dates
import "." as Components

/**
 * The next two hours of rain, quarter by quarter, as small bars: shown on the Today tab only when
 * some is coming, with the time it starts and the time the two hours end.
 */
Item {
    id: bars

    /** The quarter hours of parseForecast() or of parseQuarters(), from the current one on. */
    required property var quarters
    required property var typography
    property color ink: "#ffffff"

    /** Less than this in a quarter of an hour is not rain worth a bar. */
    readonly property real wet: 0.1
    readonly property real peak: Math.max(0.5, ...quarters.map(quarter => quarter.precipitation || 0))
    readonly property var first: quarters.find(quarter => quarter.precipitation >= wet) || null

    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 6

        Components.Label {
            typography: bars.typography
            relativeSize: 0.85
            color: bars.ink
            opacity: 0.85
            text: bars.first !== null ? Dates.timeShown(bars.first.time) : ""
        }

        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: bars.typography.size * 2.2
            spacing: 3

            Repeater {
                model: bars.quarters

                delegate: Item {
                    id: quarter

                    required property var modelData

                    width: (parent.width - 3 * (bars.quarters.length - 1)) / Math.max(1, bars.quarters.length)
                    height: parent.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, Math.min(1, (quarter.modelData.precipitation || 0) / bars.peak) * parent.height)
                        radius: 2
                        color: (quarter.modelData.precipitation || 0) >= bars.wet ? "#8fd0ff" : Qt.alpha(bars.ink, 0.25)
                    }
                }
            }
        }

        Components.Label {
            typography: bars.typography
            relativeSize: 0.85
            color: bars.ink
            opacity: 0.85
            text: bars.quarters.length > 0 ? Dates.timeShown(Dates.addMinutes(bars.quarters[bars.quarters.length - 1].time, 15)) : ""
        }
    }
}
