pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/alerts.mjs" as Alerts
import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/insights.mjs" as Insights
import "../../code/rain.mjs" as Rain
import "../../code/temperature.mjs" as Temperature
import "../../code/wmo.mjs" as Wmo
import "../components" as Components
import "../scene" as Scenery

/**
 * The weather now, over the animated sky: the temperature large, what stands out in the hours
 * ahead, the rain of the next two hours when some is coming, and the next six hours on a strip of
 * frosted glass. The sky shifts a little under the mouse, its far layers least.
 */
Item {
    id: tab

    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs. */
    required property var forecast
    /** The official warnings that have not expired. */
    required property var alerts
    required property string language
    required property string windUnit
    /** mm | inch */
    required property string precipitationUnit
    /** celsius | fahrenheit */
    required property string temperatureUnit
    /** full | reduced | off */
    required property string animations
    required property var typography
    required property var iconStyle
    /** auroraOutlook() of code/aurora.mjs, for the sky; null without one. */
    required property var aurora
    /** The quarter hours of precipitation, the freshest on hand. */
    required property var minutely
    /** One of KINDS in code/land.mjs. */
    required property string landscape
    /** How much of the height of the tab the land takes, in percent. */
    required property int landscapeHeight
    /** For the season of the leaves on the hills. */
    required property real latitude
    /** What the tab shows besides the weather now: hours, conditions, insights, rain, yesterday. */
    required property var parts
    /** How transparent the dark glass is, in percent: 0 opaque, 100 none at all. */
    required property int glassTransparency
    /** Whether the tab is the one on show; behind another, it stays drawn but stands still. */
    property bool shown: true

    readonly property var current: forecast.current
    readonly property var today: forecast.today
    /** The sky is painted by the widget, so the text on it does not follow the Plasma theme. */
    readonly property color ink: "#ffffff"
    /** A soft shadow keeps the text readable on a bright sky. */
    readonly property color inkShadow: "#73000000"
    /** How much bigger than the theme font the text is; the layout needs that much more room. */
    readonly property real fontFactor: typography.size / Kirigami.Theme.defaultFont.pointSize
    readonly property real gridUnit: Kirigami.Units.gridUnit * fontFactor
    readonly property bool narrow: width < gridUnit * 22
    readonly property bool roomy: height >= gridUnit * 14
    /** Below the height the tab is laid out for, the temperature shrinks with it, down to 70 %. */
    readonly property real fit: Math.max(0.7, Math.min(1, height / (gridUnit * 16)))
    readonly property real textFit: 0.6 + 0.4 * fit
    readonly property real margin: narrow ? Kirigami.Units.largeSpacing : Kirigami.Units.largeSpacing * 2
    readonly property int textAlignment: narrow ? Text.AlignHCenter : Text.AlignLeft
    readonly property string feelsLikeText: I18n.t(language, "today.feelsLike", { temp: Format.temperature(current.apparentTemperature) })
    readonly property string rangeText: `↑ ${Format.temperature(today.temperatureMax)}   ↓ ${Format.temperature(today.temperatureMin)}`
    readonly property var leadAlert: Alerts.leadAlert(alerts, current.time)
    /** Warmer or colder than yesterday, by the highest temperatures; empty when yesterday is not known. */
    readonly property string yesterdayText: {
        const compared = Temperature.comparedWithYesterday(forecast.daily, today.date);

        return compared === null ? "" : I18n.t(language, `today.${compared.kind}`, { difference: `${compared.difference}°` });
    }
    /** What stands out in the hours ahead: a storm, gusts, frost… see code/insights.mjs. */
    readonly property var insightTexts: Insights.insights(forecast, { windUnit: windUnit, temperatureUnit: temperatureUnit }, language, 2)
    /** The rain of the next two hours shows when some is coming. */
    readonly property bool rainComing: minutely.some(quarter => quarter.precipitation >= 0.1)
    /** The next six hours, for the strip at the bottom. */
    readonly property var nextHours: forecast.hourly.slice(1, 7)
    readonly property bool moving: animations !== "off"
    /** The dark glass under the hours and the conditions, as transparent as chosen. */
    readonly property real glassAlpha: (100 - glassTransparency) / 100 * 0.9

    function shows(part: string): bool {
        return parts.indexOf(part) !== -1;
    }

    /** A measurement on a pill of glass: wind, humidity, precipitation. */
    component Chip: Rectangle {
        id: chip

        required property string label
        required property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: chipText.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius * 2
        // Over snow that has settled, white would not carry the white text. Under the mouse, a shade brighter.
        // Dark glass: white text reads on it over the whitest cloud passing behind. Under the mouse, a shade lighter.
        color: Qt.rgba(0.04, 0.08, 0.16, chipHover.hovered ? tab.glassAlpha * 0.75 : tab.glassAlpha)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Accessible.role: Accessible.StaticText
        Accessible.name: `${label}: ${value}`

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        HoverHandler {
            id: chipHover
        }

        ColumnLayout {
            id: chipText

            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: 0

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: tab.ink
                opacity: 0.85
                text: chip.label
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.1
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: tab.ink
                font.weight: Font.DemiBold
                text: chip.value
            }
        }
    }

    Scenery.WeatherScene {
        id: sky

        anchors.fill: parent
        temperatureUnit: tab.temperatureUnit
        radius: Kirigami.Units.cornerRadius
        current: tab.current
        today: tab.today
        windUnit: tab.windUnit
        aurora: tab.aurora !== null ? tab.aurora.sight : "none"
        landscape: tab.landscape
        landscapeHeight: tab.landscapeHeight
        latitude: tab.latitude
        quality: tab.animations
        // Nothing moves while the widget is not on screen. `Window.window` is the window the tab is in, null before
        // it is placed in one; the attached `Window` itself has no `visible`.
        // Kept while another tab is shown, it stands still meanwhile.
        running: tab.shown && tab.visible && tab.Window.window !== null && tab.Window.window.visible
        // The mouse tilts the sky: each layer shifts by its depth.
        tiltX: pointer.hovered && tab.moving ? (pointer.point.position.x / Math.max(1, tab.width) - 0.5) * 2 : 0
        tiltY: pointer.hovered && tab.moving ? (pointer.point.position.y / Math.max(1, tab.height) - 0.5) * 2 : 0
    }

    HoverHandler {
        id: pointer
    }

    // A soft shade behind the temperature and its texts, so that they read on the brightest sky.
    Canvas {
        id: scrim

        property rect area: Qt.rect(0, 0, 0, 0)
        /** Deeper under a covered sky by day, white with cloud, fog or snow, where the small lines did not read. */
        readonly property real depth: tab.current.isDay && (tab.current.cloudCover || 0) >= 70 ? 1.6 : 1

        /** Put where the block of the temperature is now; a binding would not see the layout change. */
        function follow(): void {
            const corner = hero.mapToItem(tab, 0, 0);

            area = Qt.rect(corner.x, corner.y, hero.width, hero.height);
        }

        x: area.x - area.width * 0.18
        y: area.y - area.height * 0.25
        width: area.width * 1.36
        height: area.height * 1.5

        onPaint: {
            const context = getContext("2d");
            // An ellipse: a circle as wide as the canvas, squeezed to its height.
            const shade = context.createRadialGradient(width / 2, width / 2, 0, width / 2, width / 2, width / 2);

            context.clearRect(0, 0, width, height);
            context.save();
            context.scale(1, height / Math.max(1, width));
            shade.addColorStop(0, `rgba(10, 18, 34, ${0.26 * depth})`);
            shade.addColorStop(0.6, `rgba(10, 18, 34, ${0.12 * depth})`);
            shade.addColorStop(1, "rgba(10, 18, 34, 0)");
            context.fillStyle = shade;
            context.fillRect(0, 0, width, width);
            context.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onDepthChanged: requestPaint()
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: chips.visible ? chips.top : glassStrip.visible ? glassStrip.top : parent.bottom
        anchors.margins: tab.margin
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.1
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    // With the clock, the day turns with it at midnight, not with the next forecast.
                    text: Format.sentenceCase(Dates.fullDate(clock.visible && clock.placeNow !== "" ? clock.placeNow : tab.current.time, tab.language))
                }

                // The clock of the place, under its day: the time there, to the second.
                RowLayout {
                    id: clock

                    /** The time at the place, as localNow() of code/dates.mjs has it; set each second. */
                    property string placeNow: ""
                    property string time: ""
                    /** Whether the place keeps another time than the computer: then the clock says whose it is. */
                    property bool elsewhere: false

                    function tick(): void {
                        const offset = tab.forecast.utcOffsetSeconds;

                        time = Dates.clockText(offset, /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat)), [Qt.locale().amText, Qt.locale().pmText]);
                        placeNow = Dates.localNow(offset);
                        elsewhere = offset !== -new Date().getTimezoneOffset() * 60;
                    }

                    visible: tab.shows("clock")
                    spacing: Kirigami.Units.smallSpacing

                    Components.Label {
                        typography: tab.typography
                        relativeSize: 1.6
                        font.weight: Font.DemiBold
                        // Figures of one width: the seconds do not shake the line as they change.
                        font.features: { "tnum": 1 }
                        color: tab.ink
                        style: Text.Raised
                        styleColor: tab.inkShadow
                        text: clock.time
                    }

                    Components.Label {
                        Layout.alignment: Qt.AlignBaseline
                        visible: clock.elsewhere
                        typography: tab.typography
                        relativeSize: 0.85
                        color: tab.ink
                        style: Text.Raised
                        styleColor: tab.inkShadow
                        opacity: 0.8
                        text: I18n.t(tab.language, "today.placeTime")
                    }

                    // On the turn of each second, so that the seconds keep pace with those of the panel;
                    // still while the tab is out of sight.
                    Timer {
                        interval: 1000
                        repeat: true
                        triggeredOnStart: true
                        running: clock.visible && tab.shown && tab.Window.window !== null && tab.Window.window.visible

                        onTriggered: {
                            clock.tick();
                            interval = 1000 - Date.now() % 1000 + 5;
                        }
                    }
                }
            }

            Components.Label {
                // Measured against the tab: the width of the row itself depends on this label.
                Layout.maximumWidth: tab.width * 0.58
                // Level with the day, the clock shown under it or not.
                Layout.alignment: Qt.AlignTop
                typography: tab.typography
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                color: tab.ink
                style: Text.Raised
                styleColor: tab.inkShadow
                opacity: 0.9
                text: Rain.rainSentence(Rain.rainSummary(tab.forecast.hourly), tab.current.time, tab.language)
            }
        }

        Loader {
            Layout.fillWidth: true
            active: tab.leadAlert !== null
            visible: active

            sourceComponent: Components.AlertBanner {
                alert: tab.leadAlert
                now: tab.current.time
                language: tab.language
                typography: tab.typography
                textLines: tab.roomy ? 2 : 1
                moreCount: tab.alerts.length - 1
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // The temperature, large, and beside it, or under it in a narrow widget, what the weather is like.
        GridLayout {
            id: hero

            Layout.alignment: Qt.AlignHCenter
            // A layout fills its cell by default, which would pin the block to the left edge.
            Layout.fillWidth: false
            Layout.maximumWidth: parent.width
            columns: tab.narrow ? 1 : 2
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: 0

            onXChanged: Qt.callLater(scrim.follow)
            onYChanged: Qt.callLater(scrim.follow)
            onWidthChanged: Qt.callLater(scrim.follow)
            onHeightChanged: Qt.callLater(scrim.follow)

            Components.Label {
                Layout.alignment: Qt.AlignHCenter
                typography: tab.typography
                relativeSize: (tab.narrow ? 4.4 : 5.6) * tab.fit
                font.family: tab.typography.display
                font.weight: Font.DemiBold
                color: tab.ink
                style: Text.Raised
                styleColor: tab.inkShadow
                text: Format.temperature(tab.current.temperature)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.75 * tab.textFit
                    horizontalAlignment: tab.textAlignment
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    font.weight: Font.DemiBold
                    text: I18n.t(tab.language, Wmo.conditionKey(tab.current.conditionCode))
                }

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.2 * tab.textFit
                    horizontalAlignment: tab.textAlignment
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    opacity: 0.92
                    text: `${tab.feelsLikeText}  ·  ${tab.rangeText}`
                }

                // In a narrow widget, only if it is tall too.
                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.05 * tab.textFit
                    horizontalAlignment: tab.textAlignment
                    visible: tab.shows("yesterday") && tab.yesterdayText !== "" && (!tab.narrow || tab.roomy)
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    opacity: 0.8
                    text: tab.yesterdayText
                }
            }
        }

        // The clock takes its room from above the temperature; this takes as much from below, so
        // that the temperature stays where it was, the clock shown or not.
        Item {
            Layout.preferredHeight: Math.max(0, clock.implicitHeight - parent.spacing)
            visible: clock.visible
        }

        Item {
            Layout.fillHeight: true
        }

        // What stands out in the hours ahead, each on a pill of its own.
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: tab.shows("insights") && tab.insightTexts.length > 0 && tab.height >= tab.gridUnit * 12

            Repeater {
                model: tab.insightTexts

                delegate: Rectangle {
                    id: pill

                    required property string modelData

                    width: Math.min(pillText.implicitWidth + Kirigami.Units.largeSpacing * 2, tab.width - tab.margin * 2)
                    height: pillText.implicitHeight + Kirigami.Units.smallSpacing
                    radius: height / 2
                    color: Qt.rgba(0.05, 0.1, 0.2, pillHover.hovered ? 0.42 : 0.3)

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }

                    HoverHandler {
                        id: pillHover
                    }

                    Components.Label {
                        id: pillText

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - Kirigami.Units.largeSpacing * 2)
                        typography: tab.typography
                        relativeSize: 0.95
                        elide: Text.ElideRight
                        color: tab.ink
                        text: pill.modelData
                    }
                }
            }
        }

        Components.RainBars {
            Layout.fillWidth: true
            visible: tab.shows("rain") && tab.rainComing && tab.height >= tab.gridUnit * 11
            quarters: tab.minutely
            typography: tab.typography
            ink: tab.ink
        }
    }

    // Wind, humidity and precipitation, when they are asked for, over the hours.
    RowLayout {
        id: chips

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: glassStrip.visible ? glassStrip.top : parent.bottom
        anchors.leftMargin: tab.margin
        anchors.rightMargin: tab.margin
        anchors.bottomMargin: glassStrip.visible ? Kirigami.Units.smallSpacing : tab.margin
        spacing: Kirigami.Units.smallSpacing
        visible: tab.shows("conditions")

        Chip {
            label: I18n.t(tab.language, "today.wind")
            value: `${Format.wind(tab.current.windSpeed, tab.windUnit, tab.language)} ${I18n.compass(tab.current.windDirection, tab.language)}`
        }

        Chip {
            label: I18n.t(tab.language, "today.humidity")
            value: Format.percent(tab.current.humidity)
        }

        Chip {
            label: I18n.t(tab.language, "today.precipitation")
            value: Format.precipitation(tab.today.precipitationSum, tab.precipitationUnit, tab.language)
        }
    }

    // The next six hours, on a strip of frosted glass: the sky behind it shows through, blurred.
    Item {
        id: glassStrip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: tab.margin
        height: hourRow.implicitHeight + Kirigami.Units.smallSpacing * 2
        visible: tab.shows("hours")

        // The blur needs the graphics card; drawn in software, the strip is only tinted.
        Loader {
            anchors.fill: parent
            active: glassStrip.visible && GraphicsInfo.api !== GraphicsInfo.Software

            sourceComponent: Item {
                ShaderEffectSource {
                    id: behind

                    anchors.fill: parent
                    sourceItem: sky
                    sourceRect: Qt.rect(glassStrip.x, glassStrip.y, glassStrip.width, glassStrip.height)
                    visible: false
                }

                Rectangle {
                    id: rounding

                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius * 2
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: behind
                    blurEnabled: true
                    blur: 1
                    blurMax: 32
                    saturation: 0.15
                    maskEnabled: true
                    maskSource: rounding
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            // Dark glass, for the same reason as the chips: white text over white clouds.
            color: Qt.rgba(0.04, 0.08, 0.16, tab.glassAlpha)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)
        }

        RowLayout {
            id: hourRow

            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 0

            Repeater {
                model: tab.nextHours

                delegate: Rectangle {
                    id: hour

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: hourColumn.implicitHeight + Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(1, 1, 1, hourHover.hovered ? 0.14 : 0)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: I18n.t(tab.language, "a11y.hour", { time: Dates.timeLabel(modelData.time), condition: I18n.t(tab.language, Wmo.conditionKey(modelData.conditionCode)), temperature: Format.temperature(modelData.temperature) })

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }

                    HoverHandler {
                        id: hourHover
                    }

                    ColumnLayout {
                        id: hourColumn

                        anchors.centerIn: parent
                        spacing: 0

                        Components.Label {
                            Layout.alignment: Qt.AlignHCenter
                            typography: tab.typography
                            relativeSize: 0.9
                            color: tab.ink
                            opacity: 0.85
                            text: Dates.timeLabel(hour.modelData.time)
                        }

                        Components.WeatherIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium * Math.min(1.25, tab.fontFactor) * tab.fit
                            Layout.preferredHeight: Layout.preferredWidth
                            code: hour.modelData.conditionCode
                            isDay: hour.modelData.isDay
                            iconStyle: tab.iconStyle
                            animated: false
                        }

                        Components.Label {
                            Layout.alignment: Qt.AlignHCenter
                            typography: tab.typography
                            relativeSize: 1.05
                            color: tab.ink
                            font.weight: Font.DemiBold
                            text: Format.temperature(hour.modelData.temperature)
                        }
                    }
                }
            }
        }
    }
}
