pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/alerts.mjs" as Alerts
import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../components" as Components

/** The forecast as a calendar: one row per week, each under a heading that says which week it is. */
Item {
    id: tab

    /** `daily` of the parsed forecast, past days included. */
    required property var days
    /** Current time at the forecast location. */
    required property string now
    /** The official warnings that have not expired. */
    required property var alerts
    required property string language
    /** 0 Sunday … 6 Saturday. */
    required property int firstDayOfWeek
    required property var typography
    required property var iconStyle

    readonly property var weeks: Dates.calendarWeeks(days, now, firstDayOfWeek)
    /** Below this chance the rain percentage is noise, not information. */
    readonly property int notablePrecipitationChance: 10
    /**
     * The warnings give way before the calendar does: first each loses a line of its text, then the
     * second warning goes, counted in the "+N" of the first. The title and one line always stay.
     */
    readonly property int alertsShown: calendarRoom(Math.min(2, alerts.length), 1) >= minimumWeekHeight ? 2 : 1
    readonly property int alertLines: calendarRoom(Math.min(alertsShown, alerts.length), 2) >= minimumWeekHeight ? 2 : 1
    /** Height of the four lines of text a day has: date, chance of rain, maximum, minimum. */
    readonly property real textHeight: metrics.height * 3.9
    readonly property real cellPadding: Kirigami.Units.smallSpacing * 3
    readonly property real headingHeight: metrics.height + Kirigami.Units.smallSpacing
    /** A week needs room for its heading, the text and an icon big enough to tell rain from snow. */
    readonly property real minimumWeekHeight: headingHeight + textHeight + Kirigami.Units.iconSizes.smallMedium * 1.25 + cellPadding
    readonly property var alertColours: ({ yellow: "#f7c948", orange: "#f08c2e", red: "#d93a3a" })

    /** Height of a warning with its title and `lines` lines of text, as AlertBanner lays it out at most. */
    function bannerHeight(lines: int): real {
        return metrics.height * (1 + lines) + Kirigami.Units.smallSpacing * 2;
    }

    /** What is left for the calendar under the weekday names and `banners` warnings of `lines` lines. */
    function calendarRoom(banners: int, lines: int): real {
        return height - metrics.height - Kirigami.Units.smallSpacing * (banners + 1) - banners * bannerHeight(lines);
    }

    FontMetrics {
        id: metrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: tab.alerts.slice(0, tab.alertsShown)

            delegate: Components.AlertBanner {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                alert: modelData
                now: tab.now
                language: tab.language
                typography: tab.typography
                textLines: tab.alertLines
                moreCount: index === tab.alertsShown - 1 ? tab.alerts.length - tab.alertsShown : 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Dates.weekdayOrder(tab.firstDayOfWeek)

                delegate: Components.Label {
                    required property int modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    typography: tab.typography
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.75
                    text: I18n.dayShort(tab.language, modelData)
                }
            }
        }

        ListView {
            id: list

            /** As many whole weeks as fit; the rest are a scroll away. */
            readonly property int weeksShown: Math.max(1, Math.min(count, Math.floor(height / tab.minimumWeekHeight)))
            /** Never below the height a week needs: a list too short for one scrolls instead of squeezing it. */
            readonly property real weekHeight: Math.max(tab.minimumWeekHeight, height / weeksShown)

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            model: tab.weeks

            QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {}

            delegate: Item {
                id: week

                /** The seven cells of a week, see calendarWeeks() in code/dates.mjs. */
                required property var modelData
                required property int index

                width: list.width
                height: list.weekHeight

                // Which week this is: without it the rows read as more forecasts for the same day.
                RowLayout {
                    id: heading

                    width: parent.width
                    height: tab.headingHeight
                    spacing: Kirigami.Units.largeSpacing

                    Components.Label {
                        typography: tab.typography
                        relativeSize: 0.9
                        font.weight: Font.DemiBold
                        opacity: 0.8
                        text: Dates.weekTitle(week.modelData, week.index, tab.language)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
                    }
                }

                RowLayout {
                    anchors.top: heading.bottom
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: week.modelData

                        delegate: Item {
                            id: cell

                            /** `{ date, day, isToday, isPast }`, see calendarWeeks() in code/dates.mjs. */
                            required property var modelData

                            readonly property var day: modelData.day
                            readonly property string worstAlert: Alerts.worstLevel(Alerts.alertsOn(tab.alerts, modelData.date)) || ""
                            readonly property real iconSize: Math.max(Kirigami.Units.iconSizes.small, Math.min(Kirigami.Units.iconSizes.large, width - Kirigami.Units.smallSpacing * 2, height - tab.textHeight - tab.cellPadding))

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            opacity: modelData.isPast ? 0.45 : 1

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Kirigami.Units.cornerRadius
                                visible: cell.modelData.isToday
                                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                                border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)
                            }

                            // A warning in force on that day, in the colour of its code.
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 2
                                width: parent.width - Kirigami.Units.smallSpacing * 3
                                height: 3
                                radius: 1.5
                                visible: cell.worstAlert !== ""
                                color: cell.worstAlert !== "" ? tab.alertColours[cell.worstAlert] : "transparent"
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width
                                spacing: Kirigami.Units.smallSpacing / 2

                                Components.Label {
                                    Layout.fillWidth: true
                                    typography: tab.typography
                                    relativeSize: 0.95
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    font.weight: cell.modelData.isToday ? Font.Bold : Font.Normal
                                    opacity: cell.day ? 1 : 0.4
                                    // The first of a month says which month begins.
                                    text: Dates.dayOfMonth(cell.modelData.date) === 1
                                        ? `1 ${I18n.monthShort(tab.language, Dates.monthOf(cell.modelData.date))}`
                                        : Dates.dayOfMonth(cell.modelData.date)
                                }

                                Components.WeatherIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: cell.iconSize
                                    Layout.preferredHeight: cell.iconSize
                                    opacity: cell.day ? 1 : 0
                                    code: cell.day ? cell.day.conditionCode : undefined
                                    iconStyle: tab.iconStyle
                                    // The days gone by stand still.
                                    animated: tab.iconStyle.animated && cell.day !== null && !cell.modelData.isPast
                                }

                                Components.Label {
                                    Layout.fillWidth: true
                                    typography: tab.typography
                                    relativeSize: 0.8
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Kirigami.Theme.linkColor
                                    // Kept in the layout when hidden, so that the temperatures of all days line up.
                                    opacity: cell.day && cell.day.precipitationProbability >= tab.notablePrecipitationChance ? 1 : 0
                                    text: cell.day ? Format.percent(cell.day.precipitationProbability) : ""
                                }

                                Components.Label {
                                    Layout.fillWidth: true
                                    typography: tab.typography
                                    relativeSize: 1.05
                                    horizontalAlignment: Text.AlignHCenter
                                    font.weight: Font.DemiBold
                                    text: cell.day ? Format.temperature(cell.day.temperatureMax) : ""
                                }

                                Components.Label {
                                    Layout.fillWidth: true
                                    typography: tab.typography
                                    horizontalAlignment: Text.AlignHCenter
                                    opacity: 0.7
                                    text: cell.day ? Format.temperature(cell.day.temperatureMin) : ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
