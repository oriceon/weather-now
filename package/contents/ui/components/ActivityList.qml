pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/activities.mjs" as Activities
import "../../code/i18n.mjs" as I18n
import "." as Components

/**
 * How the rest of the day suits the activities chosen: a row each, a dot in the colour of how good
 * it gets, its name, and the best stretch of time, or "not today".
 */
Item {
    id: list

    /** The ids of the activities, see ACTIVITIES in code/activities.mjs. */
    required property var activities
    /** The `hourly` of parseForecast(). */
    required property var hourly
    /** `{ windUnit, temperatureUnit }` */
    required property var units
    required property real moonIllumination
    required property string language
    required property var typography

    readonly property var colours: ({ good: "#45d08f", fair: "#f2cf3d", poor: Qt.alpha(Kirigami.Theme.textColor, 0.3) })
    /** The row under the mouse lifts a little: what the tile does under the mouse, row after row. */
    property real wave: -1

    function replay(): void {
        if (!sweep.running) {
            sweep.restart();
        }
    }

    NumberAnimation {
        id: sweep

        target: list
        property: "wave"
        from: 0
        to: list.activities.length + 1
        duration: 800
        onFinished: list.wave = -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing / 2

        Repeater {
            model: list.activities

            delegate: RowLayout {
                id: row

                required property string modelData
                required property int index

                readonly property var outlook: Activities.activityOutlook(row.modelData, list.hourly, list.units, list.moonIllumination)
                readonly property real bump: Math.max(0, 1 - Math.abs(list.wave - row.index))

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                transform: Translate {
                    x: row.bump * Kirigami.Units.smallSpacing
                }

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.smallSpacing * 2
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: list.colours[row.outlook.rating]
                }

                Components.Label {
                    Layout.fillWidth: true
                    typography: list.typography
                    relativeSize: 0.9
                    elide: Text.ElideRight
                    text: I18n.t(list.language, `activity.${row.modelData}`)
                }

                Components.Label {
                    typography: list.typography
                    relativeSize: 0.85
                    opacity: 0.8
                    text: row.outlook.rating === "poor"
                        ? I18n.t(list.language, "activity.notToday")
                        : `${row.outlook.start}–${row.outlook.end}`
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
