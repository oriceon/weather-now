pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/alerts.mjs" as Alerts
import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/rain.mjs" as Rain
import "../../code/wmo.mjs" as Wmo
import "../components" as Components
import "../scene" as Scenery

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
    /** full | reduced | off */
    required property string animations
    required property var typography
    required property var iconStyle

    readonly property var current: forecast.current
    readonly property var today: forecast.today
    /** The sky is painted by the widget, so the text on it does not follow the Plasma theme. */
    readonly property color ink: "#ffffff"
    /** A soft shadow keeps the text readable on a bright sky. */
    readonly property color inkShadow: "#73000000"
    /** How much bigger than the theme font the text is; the layout needs that much more room. */
    readonly property real fontFactor: typography.size / Kirigami.Theme.defaultFont.pointSize
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 25 * fontFactor
    readonly property bool roomy: height >= Kirigami.Units.gridUnit * 14 * fontFactor
    readonly property int textAlignment: narrow ? Text.AlignHCenter : Text.AlignLeft
    readonly property string feelsLikeText: I18n.t(language, "today.feelsLike", { temp: Format.temperature(current.apparentTemperature) })
    readonly property string rangeText: `↑ ${Format.temperature(today.temperatureMax)}   ↓ ${Format.temperature(today.temperatureMin)}`
    readonly property var leadAlert: Alerts.leadAlert(alerts, current.time)

    component Chip: Rectangle {
        id: chip

        required property string label
        required property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: chipText.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(1, 1, 1, 0.18)

        ColumnLayout {
            id: chipText

            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: 0

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: tab.ink
                opacity: 0.85
                text: chip.label
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.2
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: tab.ink
                font.weight: Font.DemiBold
                text: chip.value
            }
        }
    }

    Scenery.WeatherScene {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        current: tab.current
        today: tab.today
        windUnit: tab.windUnit
        quality: tab.animations
        // Nothing moves while the widget is not on screen. `Window.window` is the window the tab is in, null before
        // it is placed in one; the attached `Window` itself has no `visible`.
        running: tab.Window.window !== null && tab.Window.window.visible
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: tab.narrow ? Kirigami.Units.largeSpacing : Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.1
                elide: Text.ElideRight
                color: tab.ink
                style: Text.Raised
                styleColor: tab.inkShadow
                text: Format.sentenceCase(Dates.fullDate(tab.current.time, tab.language))
            }

            Components.Label {
                // Measured against the tab: the width of the row itself depends on this label.
                Layout.maximumWidth: tab.width * 0.58
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

        // Centred while it fits. A narrow widget has no room for the texts beside the temperature, so they go below it.
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            // A layout fills its cell by default, which would pin the block to the left edge.
            Layout.fillWidth: false
            Layout.maximumWidth: parent.width
            columns: tab.narrow ? 1 : 2
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: 0

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                Components.WeatherIcon {
                    readonly property real side: Kirigami.Units.iconSizes.huge * (tab.narrow ? 1 : 1.5) * tab.fontFactor

                    Layout.preferredWidth: side
                    Layout.preferredHeight: side
                    code: tab.current.conditionCode
                    isDay: tab.current.isDay
                    iconStyle: tab.iconStyle
                    // The one big icon keeps moving in the reduced mode too.
                    animated: tab.iconStyle.set === "meteocons" && tab.animations !== "off"
                }

                Components.Label {
                    typography: tab.typography
                    relativeSize: tab.narrow ? 3 : 4
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    font.weight: Font.DemiBold
                    text: Format.temperature(tab.current.temperature)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.45
                    horizontalAlignment: tab.textAlignment
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    text: I18n.t(tab.language, Wmo.conditionKey(tab.current.conditionCode))
                }

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.1
                    horizontalAlignment: tab.textAlignment
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    opacity: 0.9
                    text: tab.narrow ? `${tab.feelsLikeText}  ·  ${tab.rangeText}` : tab.feelsLikeText
                }

                Components.Label {
                    Layout.fillWidth: true
                    typography: tab.typography
                    relativeSize: 1.1
                    visible: !tab.narrow
                    elide: Text.ElideRight
                    color: tab.ink
                    style: Text.Raised
                    styleColor: tab.inkShadow
                    opacity: 0.9
                    text: tab.rangeText
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

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
    }
}
