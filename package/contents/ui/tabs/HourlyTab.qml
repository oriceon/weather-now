pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/sun.mjs" as Sun
import "../../code/temperature.mjs" as Temperature
import "../../code/wmo.mjs" as Wmo
import "../components" as Components

/**
 * Hours along a temperature curve, which scrolls sideways: the next two days, or the hours of one
 * day opened from the calendar. An hour under the mouse lights up and tells the rest of its weather.
 */
Item {
    id: tab

    /** `hourly` of the parsed forecast, or the hours of one day of `allHours`. */
    required property var hours
    /** `daily` of the parsed forecast, for the sunrises and sunsets among the hours. */
    required property var days
    required property string language
    required property string windUnit
    /** celsius | fahrenheit: the colours of the curve go by °C. */
    required property string temperatureUnit
    /** full | reduced | off: the curve draws itself in, unless motion is off. */
    required property string animations
    /** mm | inch */
    required property string precipitationUnit
    required property var typography
    required property var iconStyle

    readonly property int notablePrecipitationChance: 10
    readonly property real lineHeight: metrics.height
    readonly property real columnWidth: Math.max(Kirigami.Units.gridUnit * 2.6, metrics.averageCharacterWidth * 6.5)
    readonly property real iconSize: Math.min(columnWidth, Kirigami.Units.iconSizes.large)
    readonly property real lowest: Math.min(...hours.map(hour => hour.temperature))
    readonly property real highest: Math.max(...hours.map(hour => hour.temperature))
    readonly property var sunMarks: Sun.sunEvents(days, hours)
    readonly property color sunColour: "#f6b73c"
    /** How much of the curve is drawn: it draws itself in, from left to right, as the tab opens. */
    property real reveal: animations === "off" ? 1 : 0

    /** The curve runs between the icons above it and, below it, the line of the sunrises and sunsets and the two lines about rain. */
    readonly property real curveTop: lineHeight * 3.2 + iconSize + Kirigami.Units.smallSpacing * 2
    readonly property real curveBottom: height - lineHeight * 3.2 - Kirigami.Units.largeSpacing * 2

    function colourOf(temperature: real): color {
        return Temperature.temperatureColour(Temperature.toCelsius(temperature, temperatureUnit));
    }

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

        // The temperature as a line in its own colours, hour by hour, over a glow that fades downwards.
        // It is drawn once and draws itself in as the window over it widens: drawn again at every step,
        // the whole two days of it, it held up the opening of the tab.
        Item {
            width: curve.width * tab.reveal
            height: curve.height
            clip: true

            Canvas {
                id: curve

                width: strip.contentWidth
                height: strip.height

                onPaint: {
                    const context = getContext("2d");
                    const points = tab.hours.map((hour, index) => ({ x: (index + 0.5) * tab.columnWidth, y: tab.curveY(hour.temperature), colour: tab.colourOf(hour.temperature) }));

                    context.clearRect(0, 0, width, height);

                    if (points.length < 2) {
                        return;
                    }

                    context.save();

                    const along = context.createLinearGradient(0, 0, width, 0);

                    points.forEach(point => along.addColorStop(point.x / width, point.colour));

                    context.beginPath();
                    context.moveTo(points[0].x, tab.curveBottom);
                    points.forEach(point => context.lineTo(point.x, point.y));
                    context.lineTo(points[points.length - 1].x, tab.curveBottom);
                    context.closePath();
                    context.globalAlpha = 0.22;
                    context.fillStyle = along;
                    context.fill();

                    // The glow fades out towards the bottom.
                    const fade = context.createLinearGradient(0, tab.curveTop, 0, tab.curveBottom);

                    fade.addColorStop(0, "rgba(0, 0, 0, 0)");
                    fade.addColorStop(1, "rgba(0, 0, 0, 1)");
                    context.globalCompositeOperation = "destination-out";
                    context.globalAlpha = 0.85;
                    context.fillStyle = fade;
                    context.fill();

                    context.globalCompositeOperation = "source-over";
                    context.globalAlpha = 1;
                    context.strokeStyle = along;
                    context.lineWidth = 2.5;
                    context.lineJoin = "round";
                    context.lineCap = "round";
                    context.beginPath();
                    points.forEach((point, index) => index === 0 ? context.moveTo(point.x, point.y) : context.lineTo(point.x, point.y));
                    context.stroke();
                    context.restore();
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: tab

                    function onTemperatureUnitChanged(): void {
                        curve.requestPaint();
                    }
                }

                Connections {
                    target: tab

                    function onHoursChanged(): void {
                        curve.requestPaint();
                    }
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
                    /** The curve has reached this hour. */
                    readonly property bool drawn: tab.reveal * tab.hours.length >= index + 0.5

                    width: tab.columnWidth
                    height: strip.height
                    // Night hours are shaded; the hour under the mouse is a shade lighter.
                    color: Qt.alpha(Kirigami.Theme.textColor, (modelData.isDay ? 0 : 0.06) + (columnHover.hovered ? 0.1 : 0))
                    Accessible.role: Accessible.StaticText
                    Accessible.name: [
                        I18n.t(tab.language, "a11y.hour", { time: Dates.timeShown(modelData.time), condition: I18n.t(tab.language, Wmo.conditionKey(modelData.conditionCode)), temperature: Format.temperature(modelData.temperature) }),
                        modelData.precipitationProbability >= tab.notablePrecipitationChance ? I18n.t(tab.language, "a11y.chance", { value: Format.percent(modelData.precipitationProbability) }) : "",
                    ].filter(part => part !== "").join(", ")

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }

                    HoverHandler {
                        id: columnHover
                    }

                    PlasmaComponents.ToolTip {
                        visible: columnHover.hovered
                        text: I18n.t(tab.language, "hours.tooltip", {
                            feelsLike: Format.temperature(column.modelData.apparentTemperature),
                            wind: `${Format.wind(column.modelData.windSpeed, tab.windUnit, tab.language)} ${I18n.compass(column.modelData.windDirection, tab.language)}`,
                            humidity: Format.percent(column.modelData.humidity),
                        })
                    }

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
                        text: Dates.timeShown(column.modelData.time)
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
                        opacity: column.drawn ? 1 : 0
                        text: Format.temperature(column.modelData.temperature)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                            }
                        }
                    }

                    // The point of the hour on the curve; bigger under the mouse.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: column.pointY - height / 2
                        width: 7
                        height: 7
                        radius: 3.5
                        scale: columnHover.hovered ? 1.7 : 1
                        opacity: column.drawn ? 1 : 0
                        color: tab.colourOf(column.modelData.temperature)
                        border.width: 1.5
                        border.color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.8)

                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutBack
                            }
                        }
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
                        text: Format.precipitationNumber(column.modelData.precipitation, tab.precipitationUnit, tab.language)
                    }
                }
            }
        }

        // Sunrise and sunset, to the minute: a thin line through the curve, and the time under it.
        Repeater {
            model: tab.sunMarks

            delegate: Item {
                id: sunMark

                required property var modelData

                x: Math.round(modelData.column * tab.columnWidth)
                y: tab.curveTop - tab.lineHeight * 0.5
                width: 1
                height: tab.curveBottom - y + tab.lineHeight * 1.4
                opacity: tab.reveal * tab.hours.length >= modelData.column ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }

                Rectangle {
                    width: 1
                    height: tab.curveBottom - sunMark.y
                    color: Qt.alpha(tab.sunColour, 0.55)
                }

                Row {
                    x: -width / 2
                    y: tab.curveBottom - sunMark.y + Kirigami.Units.smallSpacing
                    spacing: 3

                    Components.SunMark {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: sunMark.modelData.kind
                        colour: tab.sunColour
                    }

                    Components.Label {
                        typography: tab.typography
                        relativeSize: 0.8
                        color: tab.sunColour
                        text: Dates.timeShown(sunMark.modelData.time)
                    }
                }
            }
        }
    }

    // The tab is kept once made: the curve draws itself in again each time it comes on show.
    onVisibleChanged: {
        if (visible && animations !== "off") {
            drawIn.restart();
        }
    }

    NumberAnimation on reveal {
        id: drawIn

        running: tab.animations !== "off"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.OutCubic
    }

    // A mouse wheel turns up and down; here it moves the strip sideways.
    WheelHandler {
        onWheel: event => {
            const turn = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;

            strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - turn));
        }
    }
}
