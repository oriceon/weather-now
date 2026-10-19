import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid

import "../code/i18n.mjs" as I18n

ConfigModel {
    id: pages

    readonly property string language: I18n.resolveLanguage(configuredLanguage(), Qt.locale().uiLanguages)

    function configuredLanguage(): string {
        try {
            return Plasmoid.configuration.language;
        } catch (error) {
            return "auto";
        }
    }

    ConfigCategory {
        name: I18n.t(pages.language, "config.location")
        icon: "mark-location"
        source: "config/ConfigLocation.qml"
    }

    ConfigCategory {
        name: I18n.t(pages.language, "config.appearance")
        icon: "preferences-desktop-theme-global"
        source: "config/ConfigAppearance.qml"
    }

    ConfigCategory {
        name: I18n.t(pages.language, "config.units")
        icon: "preferences-desktop-locale"
        source: "config/ConfigUnits.qml"
    }
}
