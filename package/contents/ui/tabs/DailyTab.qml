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
import "../../code/temperature.mjs" as Temperature
import "../../code/wmo.mjs" as Wmo
import "../components" as Components

/**
 * The forecast as a calendar: one row per week, each under a heading that says which week it is.
 * A day opens on its hours, along the curve of the Hours tab.
 */
Item {
    id: tab

    /** `daily` of the parsed forecast, past days included. */
    required property var days
    /** `allHours` of the parsed forecast: every hour of those days. */
    required property var allHours
    required property string windUnit
    /** mm | inch */
    required property string precipitationUnit
    /** full | reduced | off */
    required property string animations
    /** Current time at the forecast location. */
    required property string now
    /** Now, for the mark on today's bar. */
    required property real currentTemperature
    /** celsius | fahrenheit */
    required property string temperatureUnit
    /** The official warnings that have not expired. */
    required property var alerts
    required property string language
    /** 0 Sunday … 6 Saturday. */
    required property int firstDayOfWeek
    required property var typography
    required property var iconStyle

    readonly property var weeks: Dates.calendarWeeks(days, now, firstDayOfWeek)
    /** The bars of all days share one scale, so that a warm day stands out from a cold one. */
    readonly property var scale: Temperature.temperatureScale(days)
    readonly property real barThickness: Math.max(4, Math.round(metrics.height * 0.28))
    /** Below this chance the rain percentage is noise, not information. */
    readonly property int notablePrecipitationChance: 10
    /**
     * The warnings give way before the calendar does: first each loses a line of its text, then the
     * second warning goes, counted in the "+N" of the first. The title and one line always stay.
     */
    readonly property int alertsShown: calendarRoom(Math.min(2, alerts.length), 1) >= minimumWeekHeight ? 2 : 1
    readonly property int alertLines: calendarRoom(Math.min(alertsShown, alerts.length), 2) >= minimumWeekHeight ? 2 : 1
    /** Height of the four lines of text a day has, date, chance of rain, maximum, minimum, and of the bar between the last two. */
    readonly property real textHeight: metrics.height * 3.9 + barThickness + Kirigami.Units.smallSpacing
    readonly property real cellPadding: Kirigami.Units.smallSpacing * 3
    readonly property real headingHeight: metrics.height + Kirigami.Units.smallSpacing
    /** A week needs room for its heading, the text and an icon big enough to tell rain from snow. */
    readonly property real minimumWeekHeight: headingHeight + textHeight + Kirigami.Units.iconSizes.smallMedium * 1.25 + cellPadding
    readonly property var alertColours: ({ yellow: "#f7c948", orange: "#f08c2e", red: "#d93a3a" })
    /** The day opened on its hours, as "2026-10-21"; empty while the calendar shows. */
    property string openedDay: ""

    // The tab is kept once made: it opens on the calendar each time it comes on show.
    onVisibleChanged: {
        if (!visible) {
            openedDay = "";
        }
    }
    /** How many hours each date has, by date. */
    readonly property var hourCounts: {
        const counts = {};

        allHours.forEach(hour => {
            const date = hour.time.slice(0, 10);

            counts[date] = (counts[date] || 0) + 1;
        });

        return counts;
    }

    function openDay(date: string): void {
        if (hourCounts[date] > 0) {
            openedDay = date;
        }
    }

    Keys.onEscapePressed: event => {
        event.accepted = openedDay !== "";
        openedDay = "";
    }

    /** Height of a warning with its title and `lines` lines of text, as AlertBanner lays it out at most. */
    function colourOf(temperature: real): color {
        return Temperature.temperatureColour(Temperature.toCelsius(temperature, temperatureUnit));
    }

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
        visible: tab.openedDay === ""

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
                            readonly property bool opens: day !== null && tab.hourCounts[modelData.date] > 0
                            readonly property string worstAlert: Alerts.worstLevel(Alerts.alertsOn(tab.alerts, modelData.date)) || ""
                            readonly property real iconSize: Math.max(Kirigami.Units.iconSizes.small, Math.min(Kirigami.Units.iconSizes.large, width - Kirigami.Units.smallSpacing * 2, height - tab.textHeight - tab.cellPadding))

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            opacity: modelData.isPast ? (cellHover.hovered ? 0.7 : 0.45) : 1
                            activeFocusOnTab: opens
                            Accessible.role: opens ? Accessible.Button : Accessible.StaticText
                            Accessible.name: day === null ? "" : I18n.t(tab.language, "a11y.day", {
                                date: Dates.fullDate(modelData.date, tab.language),
                                condition: I18n.t(tab.language, Wmo.conditionKey(day.conditionCode)),
                                max: Format.temperature(day.temperatureMax),
                                min: Format.temperature(day.temperatureMin),
                            })
                            Accessible.description: opens ? I18n.t(tab.language, "days.showHours") : ""
                            Accessible.onPressAction: tab.openDay(modelData.date)
                            Keys.onReturnPressed: tab.openDay(modelData.date)
                            Keys.onEnterPressed: tab.openDay(modelData.date)
                            Keys.onSpacePressed: tab.openDay(modelData.date)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }

                            // Today stands out; any day lights up under the mouse, and shows when it has the focus.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Kirigami.Units.cornerRadius
                                color: cell.modelData.isToday
                                    ? Qt.alpha(Kirigami.Theme.highlightColor, cellHover.hovered ? 0.32 : 0.22)
                                    : Qt.alpha(Kirigami.Theme.textColor, cellHover.hovered && cell.day !== null ? 0.09 : 0)
                                border.width: cell.modelData.isToday || cell.activeFocus ? 1 : 0
                                border.color: cell.activeFocus ? Kirigami.Theme.focusColor : Qt.alpha(Kirigami.Theme.highlightColor, 0.6)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }

                            HoverHandler {
                                id: cellHover

                                cursorShape: cell.opens ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                enabled: cell.opens

                                onTapped: tab.openDay(cell.modelData.date)
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
                                        ? Dates.firstOfMonth(cell.modelData.date, tab.language)
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

                                // From the night to the day, on the scale of all days, in the colours of the two.
                                Item {
                                    id: bar

                                    readonly property real from: cell.day ? Temperature.scalePosition(cell.day.temperatureMin, tab.scale) : 0
                                    readonly property real to: cell.day ? Temperature.scalePosition(cell.day.temperatureMax, tab.scale) : 0

                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Math.min(cell.width - Kirigami.Units.smallSpacing * 3, Kirigami.Units.gridUnit * 3.5)
                                    Layout.preferredHeight: tab.barThickness
                                    opacity: cell.day ? 1 : 0

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                    }

                                    Rectangle {
                                        x: bar.from * (bar.width - bar.height)
                                        width: (bar.to - bar.from) * (bar.width - bar.height) + bar.height
                                        height: parent.height
                                        radius: height / 2

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal

                                            GradientStop {
                                                position: 0
                                                color: cell.day ? tab.colourOf(cell.day.temperatureMin) : "transparent"
                                            }
                                            GradientStop {
                                                position: 1
                                                color: cell.day ? tab.colourOf(cell.day.temperatureMax) : "transparent"
                                            }
                                        }
                                    }

                                    // Today: where the temperature is now.
                                    Rectangle {
                                        readonly property real side: bar.height + 4

                                        visible: cell.modelData.isToday && cell.day !== null
                                        x: Temperature.scalePosition(tab.currentTemperature, tab.scale) * (bar.width - bar.height) + (bar.height - side) / 2
                                        y: (bar.height - side) / 2
                                        width: side
                                        height: side
                                        radius: side / 2
                                        color: "#ffffff"
                                        border.width: 1.5
                                        border.color: Qt.alpha("#000000", 0.45)
                                    }
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

    // A day opened on its hours: its date and its range over the curve of its hours.
    Loader {
        id: dayView

        anchors.fill: parent
        active: tab.openedDay !== ""
        focus: active

        sourceComponent: ColumnLayout {
            id: dayPage

            readonly property var day: tab.days.find(candidate => candidate.date === tab.openedDay) || null

            spacing: Kirigami.Units.smallSpacing
            focus: true
            Keys.onEscapePressed: tab.openedDay = ""

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    icon.name: "go-previous"
                    display: QQC2.AbstractButton.IconOnly
                    text: I18n.t(tab.language, "days.back")

                    onClicked: tab.openedDay = ""

                    PlasmaComponents.ToolTip {
                        text: parent.text
                    }
                }

                Components.WeatherIcon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    visible: dayPage.day !== null
                    code: dayPage.day !== null ? dayPage.day.conditionCode : undefined
                    iconStyle: tab.iconStyle
                    animated: false
                }

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.1
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    text: Format.sentenceCase(Dates.fullDate(tab.openedDay, tab.language))
                }

                Components.Label {
                    typography: tab.typography
                    opacity: 0.85
                    visible: dayPage.day !== null
                    text: dayPage.day === null ? "" : [
                        `↑ ${Format.temperature(dayPage.day.temperatureMax)}  ↓ ${Format.temperature(dayPage.day.temperatureMin)}`,
                        dayPage.day.precipitationSum > 0 ? Format.precipitation(dayPage.day.precipitationSum, tab.precipitationUnit, tab.language) : "",
                    ].filter(part => part !== "").join("  ·  ")
                }
            }

            HourlyTab {
                Layout.fillWidth: true
                Layout.fillHeight: true
                hours: tab.allHours.filter(hour => hour.time.startsWith(tab.openedDay))
                days: tab.days
                language: tab.language
                windUnit: tab.windUnit
                temperatureUnit: tab.temperatureUnit
                animations: tab.animations
                precipitationUnit: tab.precipitationUnit
                typography: tab.typography
                iconStyle: tab.iconStyle
            }
        }

        // The day comes in a little from below, and fades in.
        onLoaded: {
            if (tab.animations !== "off") {
                daySlide.y = Kirigami.Units.gridUnit;
                opacity = 0;
                dayEntrance.restart();
            }
        }

        transform: Translate {
            id: daySlide
        }

        ParallelAnimation {
            id: dayEntrance

            NumberAnimation {
                target: daySlide
                property: "y"
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: dayView
                property: "opacity"
                to: 1
                duration: Kirigami.Units.longDuration
            }
        }
    }
}
