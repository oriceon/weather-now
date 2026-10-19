pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/dates.mjs" as Dates
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/meteocons.mjs" as Meteocons
import "../../code/moon.mjs" as MoonPhase
import "../components" as Components

/** The measurements behind the forecast: wind, humidity, pressure, UV, clouds, sun and moon. */
Item {
    id: tab

    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs. */
    required property var forecast
    required property string language
    required property string windUnit
    required property var typography
    required property var iconStyle

    readonly property var current: forecast.current
    readonly property var today: forecast.today
    readonly property var moon: MoonPhase.moonPhase(today.date)

    component Tile: Rectangle {
        id: tile

        required property string label
        required property string value
        property string note: ""
        /** A Meteocons icon, see DETAIL_ICONS and moonIcon() in code/meteocons.mjs. */
        required property string symbol

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, 0.07)

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: 0

            Components.SymbolIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                // Shown with the Meteocons icons, and only where the tile is tall enough.
                visible: tab.iconStyle.set === "meteocons" && tile.height >= Kirigami.Units.gridUnit * 7.5
                name: tile.symbol
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                opacity: 0.75
                text: tile.label
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.3
                horizontalAlignment: Text.AlignHCenter
                // A long value shrinks to fit rather than being cut.
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: tab.typography.size * 0.75
                font.weight: Font.DemiBold
                text: tile.value
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: tile.note !== ""
                opacity: 0.85
                text: tile.note
            }
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: 4
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Tile {
            symbol: "wind"
            label: I18n.t(tab.language, "details.wind")
            value: Format.wind(tab.current.windSpeed, tab.windUnit, tab.language)
            note: I18n.compass(tab.current.windDirection, tab.language)
        }

        Tile {
            symbol: "windsock"
            label: I18n.t(tab.language, "details.gusts")
            value: Format.wind(tab.current.windGusts, tab.windUnit, tab.language)
        }

        Tile {
            symbol: "humidity"
            label: I18n.t(tab.language, "details.humidity")
            value: Format.percent(tab.current.humidity)
        }

        Tile {
            symbol: "barometer"
            label: I18n.t(tab.language, "details.pressure")
            value: Format.pressure(tab.current.pressure)
        }

        Tile {
            symbol: "clear-day"
            label: I18n.t(tab.language, "details.uv")
            value: Format.number(tab.today.uvIndexMax, 1, tab.language)
            note: I18n.t(tab.language, Format.uvKey(tab.today.uvIndexMax))
        }

        Tile {
            symbol: "cloudy"
            label: I18n.t(tab.language, "details.clouds")
            value: Format.percent(tab.current.cloudCover)
        }

        Tile {
            symbol: "clear-day"
            label: I18n.t(tab.language, "details.sun")
            value: `↑ ${Dates.timeLabel(tab.today.sunrise)}`
            note: `↓ ${Dates.timeLabel(tab.today.sunset)}`
        }

        Tile {
            symbol: Meteocons.moonIcon(tab.moon.key)
            label: I18n.t(tab.language, "details.moon")
            value: Format.percent(tab.moon.illumination * 100)
            note: I18n.t(tab.language, tab.moon.key)
        }
    }
}
