import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../../code/i18n.mjs" as I18n

ConfigPage {
    id: page

    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)

    readonly property var temperatureValues: ["celsius", "fahrenheit"]
    readonly property var windValues: ["kmh", "ms", "mph"]
    readonly property var refreshValues: [15, 30, 60]

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.temperature")
            model: ["°C", "°F"]
            currentIndex: page.temperatureValues.indexOf(page.cfg_temperatureUnit)

            onActivated: index => page.cfg_temperatureUnit = page.temperatureValues[index]
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.wind")
            model: ["km/h", "m/s", "mph"]
            currentIndex: page.windValues.indexOf(page.cfg_windUnit)

            onActivated: index => page.cfg_windUnit = page.windValues[index]
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.refresh")
            model: ["15 min", "30 min", "60 min"]
            currentIndex: page.refreshValues.indexOf(page.cfg_refreshMinutes)

            onActivated: index => page.cfg_refreshMinutes = page.refreshValues[index]
        }
    }
}
