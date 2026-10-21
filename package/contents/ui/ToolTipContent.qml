pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/alerts.mjs" as Alerts
import "../code/dates.mjs" as Dates
import "../code/format.mjs" as Format
import "../code/i18n.mjs" as I18n
import "../code/wmo.mjs" as Wmo
import "components" as Components

/**
 * The tooltip of the widget in a panel: the weather now, the next hours and the next days, and the
 * warnings in force, so that a glance tells without opening it.
 */
Item {
    id: tip

    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs; null while there is none. */
    required property var forecast
    /** The official warnings, expired ones included. */
    required property var alerts
    required property string language
    required property string locationName
    /** What to say while there is no forecast to show. */
    required property string statusText
    required property string iconSet
    required property string fontFamily

    /** One hour in two, from the next one on. */
    readonly property var hours: forecast ? forecast.hourly.filter((hour, index) => index > 0 && index % 2 === 1).slice(0, 6) : []
    /** Today and the three days after it. */
    readonly property var days: {
        if (!forecast) {
            return [];
        }

        const first = forecast.daily.findIndex(day => day.date === forecast.today.date);

        return forecast.daily.slice(first, first + 4);
    }
    readonly property var warnings: forecast ? Alerts.inLeadOrder(Alerts.activeAlerts(alerts, forecast.current.time), forecast.current.time) : []
    readonly property var iconStyle: ({ set: iconSet, animated: false })
    readonly property var alertColours: ({ yellow: "#f7c948", orange: "#f08c2e", red: "#d93a3a" })

    implicitWidth: content.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    // Plain text: the place and the warnings come from the feeds.
    component Small: PlasmaComponents.Label {
        font.family: tip.fontFamily !== "" ? tip.fontFamily : Kirigami.Theme.defaultFont.family
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
    }

    ColumnLayout {
        id: content

        x: Kirigami.Units.largeSpacing
        y: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Components.WeatherIcon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                visible: tip.forecast !== null
                code: tip.forecast ? tip.forecast.current.conditionCode : undefined
                isDay: tip.forecast ? tip.forecast.current.isDay : true
                iconStyle: tip.iconStyle
            }

            ColumnLayout {
                spacing: 0

                Small {
                    horizontalAlignment: Text.AlignLeft
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    text: tip.locationName
                }

                Small {
                    horizontalAlignment: Text.AlignLeft
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    text: tip.forecast
                        ? `${Format.temperature(tip.forecast.current.temperature)} · ${I18n.t(tip.language, Wmo.conditionKey(tip.forecast.current.conditionCode))}`
                        : tip.statusText
                }

                Small {
                    horizontalAlignment: Text.AlignLeft
                    visible: tip.forecast !== null
                    opacity: 0.75
                    text: tip.forecast
                        ? `${I18n.t(tip.language, "today.feelsLike", { temp: Format.temperature(tip.forecast.current.apparentTemperature) })} · ↑ ${Format.temperature(tip.forecast.today.temperatureMax)} ↓ ${Format.temperature(tip.forecast.today.temperatureMin)}`
                        : ""
                }
            }
        }

        // The warnings in force, each with the colour of its code.
        Repeater {
            model: tip.warnings.slice(0, 3)

            delegate: RowLayout {
                id: warning

                required property var modelData

                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.smallSpacing * 1.5
                    Layout.fillHeight: true
                    radius: width / 2
                    color: tip.alertColours[warning.modelData.level] || tip.alertColours.yellow
                }

                Small {
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: `${Alerts.alertTitle(warning.modelData, tip.language)} · ${Alerts.alertInterval(warning.modelData, tip.forecast.current.time, tip.language)}`
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            visible: tip.forecast !== null
            color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }

        // The next hours, then the next days, side by side.
        RowLayout {
            visible: tip.forecast !== null
            spacing: Kirigami.Units.largeSpacing * 2

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: tip.hours

                    delegate: ColumnLayout {
                        id: hour

                        required property var modelData

                        spacing: 0

                        Small {
                            Layout.alignment: Qt.AlignHCenter
                            opacity: 0.75
                            text: Dates.timeLabel(hour.modelData.time)
                        }

                        Components.WeatherIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            code: hour.modelData.conditionCode
                            isDay: hour.modelData.isDay
                            iconStyle: tip.iconStyle
                        }

                        Small {
                            Layout.alignment: Qt.AlignHCenter
                            font.weight: Font.DemiBold
                            text: Format.temperature(hour.modelData.temperature)
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: tip.days

                    delegate: ColumnLayout {
                        id: day

                        required property var modelData

                        spacing: 0

                        Small {
                            Layout.alignment: Qt.AlignHCenter
                            opacity: 0.75
                            text: I18n.dayShort(tip.language, Dates.weekday(day.modelData.date))
                        }

                        Components.WeatherIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            code: day.modelData.conditionCode
                            iconStyle: tip.iconStyle
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Kirigami.Units.smallSpacing / 2

                            Small {
                                font.weight: Font.DemiBold
                                text: Format.temperature(day.modelData.temperatureMax)
                            }

                            Small {
                                opacity: 0.65
                                text: Format.temperature(day.modelData.temperatureMin)
                            }
                        }
                    }
                }
            }
        }
    }
}
