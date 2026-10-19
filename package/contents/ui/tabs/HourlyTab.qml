pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../components" as Components

/** The next two days, hour by hour, along a temperature curve; scrolls sideways. */
Item {
    id: tab

    /** `hourly` of the parsed forecast. */
    required property var hours
    required property string language
    required property var typography
    required property var iconStyle

    readonly property int notablePrecipitationChance: 10
    readonly property real lineHeight: metrics.height
    readonly property real columnWidth: Math.max(Kirigami.Units.gridUnit * 2.6, metrics.averageCharacterWidth * 6.5)
    readonly property real iconSize: Math.min(columnWidth, Kirigami.Units.iconSizes.large)
    readonly property real lowest: Math.min(...hours.map(hour => hour.temperature))
    readonly property real highest: Math.max(...hours.map(hour => hour.temperature))

    /** The curve runs between the icons above it and the two lines about rain below it. */
    readonly property real curveTop: lineHeight * 3.2 + iconSize + Kirigami.Units.smallSpacing * 2
    readonly property real curveBottom: height - lineHeight * 2 - Kirigami.Units.largeSpacing * 2

    function curveY(temperature: real): real {
        const share = highest > lowest ? (temperature - lowest) / (highest - lowest) : 0.5;

        return curveBottom - share * Math.max(0, curveBottom - curveTop);
    }

    FontMetrics {
        id: metrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size
    }

    Flickable {
        id: strip

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        contentWidth: tab.hours.length * tab.columnWidth
        contentHeight: height

        QQC2.ScrollBar.horizontal: PlasmaComponents.ScrollBar {}

        Canvas {
            id: curve

            readonly property color stroke: Kirigami.Theme.highlightColor

            width: strip.contentWidth
            height: strip.height

            onPaint: {
                const context = getContext("2d");

                context.clearRect(0, 0, width, height);
                context.strokeStyle = stroke;
                context.lineWidth = 2;
                context.lineJoin = "round";
                context.beginPath();

                tab.hours.forEach((hour, index) => {
                    const x = (index + 0.5) * tab.columnWidth;
                    const y = tab.curveY(hour.temperature);

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

            Connections {
                target: tab

                function onHoursChanged(): void {
                    curve.requestPaint();
                }
            }
        }

        Row {
            height: strip.height

            Repeater {
                model: tab.hours

                delegate: Rectangle {
                    id: column

                    /** An entry of `hourly`. */
                    required property var modelData
                    required property int index

                    readonly property bool startsDay: index === 0 || Dates.timeLabel(modelData.time) === "00:00"
                    readonly property real pointY: tab.curveY(modelData.temperature)

                    width: tab.columnWidth
                    height: strip.height
                    // Night hours are shaded.
                    color: modelData.isDay ? "transparent" : Qt.alpha(Kirigami.Theme.textColor, 0.06)

                    Components.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        typography: tab.typography
                        relativeSize: 0.9
                        visible: column.startsDay
                        font.weight: Font.DemiBold
                        text: I18n.dayShort(tab.language, Dates.weekday(column.modelData.time))
                    }

                    Components.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tab.lineHeight
                        typography: tab.typography
                        opacity: 0.8
                        text: Dates.timeLabel(column.modelData.time)
                    }

                    Components.WeatherIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tab.lineHeight * 2.1
                        width: tab.iconSize
                        height: tab.iconSize
                        code: column.modelData.conditionCode
                        isDay: column.modelData.isDay
                        iconStyle: tab.iconStyle
                    }

                    Components.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: column.pointY - tab.lineHeight - Kirigami.Units.smallSpacing
                        typography: tab.typography
                        font.weight: Font.DemiBold
                        text: Format.temperature(column.modelData.temperature)
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: column.pointY - height / 2
                        width: 6
                        height: 6
                        radius: 3
                        color: Kirigami.Theme.highlightColor
                    }

                    Components.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: column.height - tab.lineHeight * 2 - Kirigami.Units.largeSpacing
                        typography: tab.typography
                        relativeSize: 0.85
                        visible: column.modelData.precipitationProbability >= tab.notablePrecipitationChance
                        color: Kirigami.Theme.linkColor
                        text: Format.percent(column.modelData.precipitationProbability)
                    }

                    Components.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: column.height - tab.lineHeight - Kirigami.Units.largeSpacing
                        typography: tab.typography
                        relativeSize: 0.85
                        visible: column.modelData.precipitation > 0
                        color: Kirigami.Theme.linkColor
                        text: Format.number(column.modelData.precipitation, 1, tab.language)
                    }
                }
            }
        }
    }

    // A mouse wheel turns up and down; here it moves the strip sideways.
    WheelHandler {
        onWheel: event => {
            const turn = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;

            strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - turn));
        }
    }
}
