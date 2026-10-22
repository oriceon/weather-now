pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../code/dates.mjs" as Dates
import "../code/format.mjs" as Format
import "../code/i18n.mjs" as I18n
import "../code/links.mjs" as Links
import "../code/rain.mjs" as Rain
import "../code/wmo.mjs" as Wmo
import "components" as Components
import "scene" as Scenery

/**
 * The widget made small on the desktop, without its tabs, over the animated sky: in a small one
 * the temperature and one line; in a wide, low band, the next hours beside it; in a middling one,
 * today and the three days after it. The source of the forecast stays named, with its link.
 */
Item {
    id: view

    /** small | band | medium */
    required property string mode
    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs. */
    required property var forecast
    required property string language
    required property string locationName
    required property string windUnit
    required property string temperatureUnit
    required property string animations
    /** A window fills the screen over the widget: the sky stands still. */
    property bool covered: false
    required property var typography
    required property var iconStyle
    required property string landscape
    /** How much of the height the land takes, in percent. */
    required property int landscapeHeight
    /** For the season of the leaves on the hills. */
    required property real latitude
    /** auroraOutlook() of code/aurora.mjs; null without one. */
    required property var aurora
    /** What is behind the text, as on the Today tab: sky, glass or text. */
    required property string backdrop
    /** How transparent the dark glass is, in percent, as on the Today tab. */
    required property int glassTransparency

    readonly property var current: forecast.current
    readonly property bool skyShown: backdrop === "sky"
    readonly property bool glassShown: backdrop !== "text"
    /** White on the sky; over the desktop, the colour of the Plasma theme, as on the tabs. */
    readonly property color ink: skyShown ? "#ffffff" : Kirigami.Theme.textColor
    /** On the dark glass, white, wherever there is glass. */
    readonly property color glassInk: glassShown ? "#ffffff" : ink
    readonly property color inkShadow: "#73000000"
    readonly property real gridUnit: Kirigami.Units.gridUnit * typography.size / Kirigami.Theme.defaultFont.pointSize
    /** The days after today, for the middling view. */
    readonly property var nextDays: {
        const today = forecast.daily.findIndex(day => day.date === forecast.today.date);

        return forecast.daily.slice(today + 1, today + 4);
    }
    readonly property string conditionText: I18n.t(language, Wmo.conditionKey(current.conditionCode))

    Scenery.WeatherScene {
        anchors.fill: parent
        visible: view.skyShown
        radius: Kirigami.Units.cornerRadius
        current: view.current
        today: view.forecast.today
        windUnit: view.windUnit
        temperatureUnit: view.temperatureUnit
        quality: view.animations
        landscape: view.landscape
        landscapeHeight: view.landscapeHeight
        latitude: view.latitude
        aurora: view.aurora !== null ? view.aurora.sight : "none"
        running: visible && !view.covered && view.Window.window !== null && view.Window.window.visible
    }

    component Ink: Components.Label {
        typography: view.typography
        color: view.ink
        style: view.skyShown ? Text.Raised : Text.Normal
        styleColor: view.inkShadow
    }

    // The place, small, in the corner.
    Ink {
        x: Kirigami.Units.largeSpacing
        y: Kirigami.Units.smallSpacing
        width: parent.width - 2 * x
        relativeSize: 0.9
        elide: Text.ElideRight
        opacity: 0.9
        text: view.locationName
    }

    // Small: the temperature as large as fits, and the weather in a line.
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
        visible: view.mode === "small"
        spacing: 0

        Ink {
            Layout.alignment: Qt.AlignHCenter
            relativeSize: Math.max(2, Math.min(5, view.height / view.gridUnit * 0.45))
            font.family: view.typography.display
            font.weight: Font.DemiBold
            text: Format.temperature(view.current.temperature)
        }

        Ink {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.conditionText
        }

        Ink {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            relativeSize: 0.85
            elide: Text.ElideRight
            opacity: 0.85
            visible: view.height > view.gridUnit * 6
            text: Rain.rainSentence(Rain.rainSummary(view.forecast.hourly), view.current.time, view.language)
        }
    }

    // A band, or a middling square: the weather now on the left, or on top.
    GridLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.largeSpacing * 1.6
        // Room for the source under the glass: in the corner, it stood on the edge of the glass.
        anchors.bottomMargin: source.implicitHeight + Kirigami.Units.smallSpacing * 2
        visible: view.mode !== "small"
        columns: view.mode === "band" ? 2 : 1
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: view.mode !== "band"
            spacing: 0

            Ink {
                Layout.alignment: view.mode === "band" ? Qt.AlignLeft : Qt.AlignHCenter
                relativeSize: view.mode === "band" ? 3 : 3.6
                font.family: view.typography.display
                font.weight: Font.DemiBold
                text: Format.temperature(view.current.temperature)
            }

            Ink {
                Layout.fillWidth: true
                Layout.maximumWidth: view.mode === "band" ? view.width * 0.32 : -1
                horizontalAlignment: view.mode === "band" ? Text.AlignLeft : Text.AlignHCenter
                elide: Text.ElideRight
                text: view.conditionText
            }

            Ink {
                Layout.fillWidth: true
                Layout.maximumWidth: view.mode === "band" ? view.width * 0.32 : -1
                horizontalAlignment: view.mode === "band" ? Text.AlignLeft : Text.AlignHCenter
                relativeSize: 0.85
                elide: Text.ElideRight
                opacity: 0.85
                text: `↑ ${Format.temperature(view.forecast.today.temperatureMax)}  ↓ ${Format.temperature(view.forecast.today.temperatureMin)}`
            }
        }

        // The next hours in a band, the next days in a square, on frosted glass.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: strip.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.cornerRadius * 2
            // Dark glass, so that white text reads over white clouds.
            color: Qt.rgba(0.04, 0.08, 0.16, view.glassShown ? (100 - view.glassTransparency) / 100 * 0.9 : 0)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, view.glassShown ? 0.22 : 0)

            RowLayout {
                id: strip

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: 0

                Repeater {
                    model: view.mode === "band" ? view.forecast.hourly.slice(1, 1 + Math.max(3, Math.min(8, Math.floor(view.width * 0.6 / (view.gridUnit * 2.6))))) : view.nextDays

                    delegate: ColumnLayout {
                        id: entry

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0

                        Ink {
                            Layout.alignment: Qt.AlignHCenter
                            relativeSize: 0.85
                            color: view.glassInk
                            opacity: 0.85
                            text: view.mode === "band" ? Dates.timeShown(entry.modelData.time) : I18n.dayShort(view.language, Dates.weekday(entry.modelData.date))
                        }

                        Components.WeatherIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            code: entry.modelData.conditionCode
                            isDay: view.mode === "band" ? entry.modelData.isDay : true
                            iconStyle: view.iconStyle
                            animated: false
                        }

                        Ink {
                            Layout.alignment: Qt.AlignHCenter
                            color: view.glassInk
                            font.weight: Font.DemiBold
                            text: view.mode === "band"
                                ? Format.temperature(entry.modelData.temperature)
                                : `${Format.temperature(entry.modelData.temperatureMax)} ${Format.temperature(entry.modelData.temperatureMin)}`
                        }
                    }
                }
            }
        }
    }

    // The source, as its licence asks, next to its data.
    Components.Label {
        id: source

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.smallSpacing
        typography: view.typography
        relativeSize: 0.7
        color: view.ink
        opacity: 0.75
        textFormat: Text.StyledText
        linkColor: view.ink
        text: '<a href="https://open-meteo.com/">Open-Meteo</a>'

        onLinkActivated: link => {
            if (Links.webAddress(link) !== "") {
                Qt.openUrlExternally(Links.webAddress(link));
            }
        }

        HoverHandler {
            cursorShape: source.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
