pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/airquality.mjs" as AirQuality
import "../../code/dates.mjs" as Dates
import "../../code/i18n.mjs" as I18n
import "." as Components

/**
 * The pollen of the next days: a column a day, its name over a dot for each pollen in the air,
 * the most felt on top, in the colour of its level. Under the mouse, the dots grow one by one.
 */
Item {
    id: pollenDays

    /** `pollenDays` of parseAirQuality() in code/airquality.mjs. */
    required property var days
    required property string language
    required property var typography
    property bool animated: true

    /** The dots stand out one after the other: what the tile does under the mouse. */
    property real wave: -1

    function replay(): void {
        if (animated && !swell.running) {
            swell.restart();
        }
    }

    NumberAnimation {
        id: swell

        target: pollenDays
        property: "wave"
        from: 0
        to: 5
        duration: 900
        onFinished: pollenDays.wave = -1
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: pollenDays.days.slice(0, 4)

            delegate: ColumnLayout {
                id: day

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 2

                Components.Label {
                    Layout.alignment: Qt.AlignHCenter
                    typography: pollenDays.typography
                    relativeSize: 0.8
                    opacity: 0.75
                    text: I18n.dayShort(pollenDays.language, Dates.weekday(day.modelData.date))
                }

                Repeater {
                    model: day.modelData.pollens.slice(0, 3)

                    delegate: Rectangle {
                        id: dot

                        required property var modelData

                        readonly property real bump: Math.max(0, 1 - Math.abs(pollenDays.wave - day.index))

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.smallSpacing * 2.2
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: AirQuality.POLLEN_COLOURS[dot.modelData.level]
                        scale: 1 + 0.5 * bump
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
