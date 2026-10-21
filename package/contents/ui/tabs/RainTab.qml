pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/rain.mjs" as Rain
import "../components" as Components

/**
 * When it rains and how much: a sentence, a chart of the amounts and the totals of the coming days;
 * or the radar, with the rain of the last two hours around the place.
 */
Item {
    id: tab

    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs. */
    required property var forecast
    /** The quarter hours of precipitation, fresher than those of the forecast while the notification of rain is on. */
    required property var minutely
    required property string language
    /** mm | inch */
    required property string precipitationUnit
    required property var typography
    /** The place, for the radar. */
    required property real latitude
    required property real longitude

    /** hours: the next 48 hours, hour by hour; quarters: the next 2 hours, in quarters of an hour; radar. */
    property string view: "hours"

    readonly property bool quarters: view === "quarters"

    /**
     * What the chart shows: `{ time, amount, chance }`, each bar at the time it starts; a quarter of an
     * hour has no chance, -1. An hour of Open-Meteo holds what falls in the hour before it, and the
     * first, the current hour, the hour gone by: the chart starts with the hour under way.
     */
    readonly property var points: quarters
        ? minutely.map(quarter => ({ time: quarter.time, amount: quarter.precipitation, chance: -1 }))
        : forecast.hourly.slice(1).map(hour => ({ time: Dates.addMinutes(hour.time, -60), amount: hour.precipitation, chance: hour.precipitationProbability }))
    readonly property real peak: Math.max(0, ...points.map(point => point.amount))
    /** The top of the scale, in mm. It has a floor, so that a drizzle does not fill the chart. */
    readonly property real scaleTop: Math.max(peak, quarters ? 0.5 : 2)
    readonly property int daysTotalled: 3
    readonly property var comingDays: forecast.daily.filter(day => day.date >= forecast.today.date).slice(0, daysTotalled)

    /** Whether the time of a point is written under the chart: every six hours, or every half hour. */
    function isLabelled(time: string): bool {
        return quarters ? Number(time.slice(14, 16)) % 30 === 0 : Number(time.slice(11, 13)) % 6 === 0;
    }

    FontMetrics {
        id: metrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.15
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                text: Rain.rainSentence(Rain.rainSummary(tab.forecast.hourly), tab.forecast.current.time, tab.language)
            }

            PlasmaComponents.ToolButton {
                autoExclusive: true
                checkable: true
                checked: tab.view === "hours"
                font.family: tab.typography.family
                font.pointSize: tab.typography.size
                text: I18n.t(tab.language, "rain.next48")

                onClicked: tab.view = "hours"
            }

            PlasmaComponents.ToolButton {
                autoExclusive: true
                checkable: true
                checked: tab.quarters
                visible: tab.minutely.length > 0
                font.family: tab.typography.family
                font.pointSize: tab.typography.size
                text: I18n.t(tab.language, "rain.next2")

                onClicked: tab.view = "quarters"
            }

            PlasmaComponents.ToolButton {
                autoExclusive: true
                checkable: true
                checked: tab.view === "radar"
                font.family: tab.typography.family
                font.pointSize: tab.typography.size
                text: I18n.t(tab.language, "rain.radar")

                onClicked: tab.view = "radar"
            }
        }

        Components.RadarMap {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tab.view === "radar"
            // Nothing is asked of the radar until it is opened, and nothing while it is not on screen.
            active: visible && tab.Window.window !== null && tab.Window.window.visible
            latitude: tab.latitude
            longitude: tab.longitude
            utcOffsetSeconds: tab.forecast.utcOffsetSeconds
            language: tab.language
            typography: tab.typography
        }

        Item {
            id: chart

            readonly property real plotTop: metrics.height * 1.4
            readonly property real plotBottom: height - metrics.height * 1.3
            readonly property real plotHeight: Math.max(0, plotBottom - plotTop)
            readonly property real step: tab.points.length > 0 ? width / tab.points.length : 0

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tab.view !== "radar"

            /** The point under the mouse, -1 for none. */
            readonly property int hovered: chartHover.hovered && step > 0 ? Math.min(tab.points.length - 1, Math.floor(chartHover.point.position.x / step)) : -1

            HoverHandler {
                id: chartHover
            }

            Components.Label {
                typography: tab.typography
                relativeSize: 0.9
                opacity: chart.hovered >= 0 ? 0 : 0.75
                visible: tab.peak > 0
                text: I18n.t(tab.language, tab.quarters ? "rain.peakQuarter" : "rain.peak", { amount: Format.precipitation(tab.peak, tab.precipitationUnit, tab.language) })
            }

            Row {
                anchors.right: parent.right
                spacing: Kirigami.Units.smallSpacing
                visible: !tab.quarters

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.gridUnit
                    height: 2
                    color: chanceLine.stroke
                }

                Components.Label {
                    typography: tab.typography
                    relativeSize: 0.9
                    opacity: 0.75
                    text: I18n.t(tab.language, "rain.probability")
                }
            }

            Repeater {
                model: tab.points

                delegate: Item {
                    id: point

                    /** `{ time, amount, chance }` */
                    required property var modelData
                    required property int index

                    readonly property bool startsDay: index > 0 && Dates.timeLabel(modelData.time) === "00:00"

                    x: index * chart.step
                    width: chart.step
                    height: chart.height

                    // The hour or the quarter under the mouse lights up.
                    Rectangle {
                        y: chart.plotTop
                        width: parent.width
                        height: chart.plotHeight
                        radius: Math.min(2, width / 2)
                        color: Qt.alpha(Kirigami.Theme.textColor, point.index === chart.hovered ? 0.1 : 0)

                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }

                    // Midnight: the next day begins.
                    Rectangle {
                        y: chart.plotTop
                        width: 1
                        height: chart.plotHeight
                        visible: point.startsDay
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
                    }

                    Components.Label {
                        x: Kirigami.Units.smallSpacing
                        y: chart.plotTop
                        typography: tab.typography
                        relativeSize: 0.85
                        visible: point.startsDay
                        opacity: 0.75
                        text: I18n.dayShort(tab.language, Dates.weekday(point.modelData.time))
                    }

                    Rectangle {
                        readonly property real gap: Math.min(2, parent.width * 0.2)

                        x: gap / 2
                        width: parent.width - gap
                        // Even the lightest rain gets a bar that can be seen.
                        height: point.modelData.amount > 0 ? Math.max(2, point.modelData.amount / tab.scaleTop * chart.plotHeight) : 0
                        y: chart.plotBottom - height
                        radius: Math.min(2, width / 2)
                        color: point.index === chart.hovered ? Qt.lighter(Kirigami.Theme.linkColor, 1.35) : Kirigami.Theme.linkColor
                    }

                    Components.Label {
                        anchors.horizontalCenter: parent.left
                        y: chart.plotBottom + Kirigami.Units.smallSpacing / 2
                        typography: tab.typography
                        relativeSize: 0.85
                        visible: tab.isLabelled(point.modelData.time) && point.index > 0
                        opacity: 0.75
                        text: tab.quarters ? Dates.timeLabel(point.modelData.time) : Dates.timeLabel(point.modelData.time).slice(0, 2)
                    }
                }
            }

            Rectangle {
                y: chart.plotBottom
                width: parent.width
                height: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
            }

            // What the point under the mouse holds, in place of the peak: its time, its amount and its chance.
            Components.Label {
                readonly property var point: chart.hovered >= 0 ? tab.points[chart.hovered] : null

                typography: tab.typography
                relativeSize: 0.9
                visible: point !== null
                font.weight: Font.DemiBold
                text: point === null ? "" : [
                    `${I18n.dayShort(tab.language, Dates.weekday(point.time))} ${Dates.timeLabel(point.time)}`,
                    Format.precipitation(point.amount, tab.precipitationUnit, tab.language),
                    point.chance >= 0 ? `${Format.percent(point.chance)} ${I18n.t(tab.language, "rain.probability")}` : "",
                ].filter(part => part !== "").join(" · ")
            }

            // The chance of precipitation, from 0 % on the baseline to 100 % at the top of the chart.
            Canvas {
                id: chanceLine

                readonly property color stroke: Qt.alpha(Kirigami.Theme.textColor, 0.55)

                anchors.fill: parent
                visible: !tab.quarters

                onPaint: {
                    const context = getContext("2d");

                    context.clearRect(0, 0, width, height);
                    context.strokeStyle = stroke;
                    context.lineWidth = 1.5;
                    context.lineJoin = "round";
                    context.beginPath();

                    tab.points.forEach((point, index) => {
                        const x = (index + 0.5) * chart.step;
                        const y = chart.plotBottom - Math.max(0, point.chance) / 100 * chart.plotHeight;

                        if (index === 0) {
                            context.moveTo(x, y);
                        } else {
                            context.lineTo(x, y);
                        }
                    });

                    context.stroke();
                }
                onStrokeChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: requestPaint()

                Connections {
                    target: tab

                    function onPointsChanged(): void {
                        chanceLine.requestPaint();
                    }
                }
            }
        }

        Components.Label {
            Layout.fillWidth: true
            typography: tab.typography
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: 0.85
            visible: tab.view !== "radar"
            text: tab.comingDays
                .map(day => `${I18n.dayShort(tab.language, Dates.weekday(day.date))} ${Format.precipitation(day.precipitationSum, tab.precipitationUnit, tab.language)}`)
                .join("   ·   ")
        }
    }
}
