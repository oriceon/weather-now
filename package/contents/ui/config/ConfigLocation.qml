pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../../code/alerts.mjs" as Alerts
import "../../code/i18n.mjs" as I18n
import ".." as Ui

ConfigPage {
    id: page

    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)

    readonly property Ui.PlaceSearch lookup: Ui.PlaceSearch {}

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: I18n.t(page.language, "config.currentLocation")
            font.weight: Font.DemiBold
            text: page.cfg_locationName !== "" ? page.cfg_locationName : I18n.t(page.language, "config.noLocation")
        }

        QQC2.Label {
            Kirigami.FormData.label: I18n.t(page.language, "config.county")
            visible: page.cfg_region !== ""
            text: page.cfg_region
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.searchLabel")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: searchField

                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                placeholderText: I18n.t(page.language, "config.searchPlaceholder")

                onAccepted: searchButton.clicked()
            }

            QQC2.Button {
                id: searchButton

                enabled: searchField.text.trim().length > 1
                icon.name: "search"
                text: I18n.t(page.language, "config.search")

                onClicked: page.lookup.search(searchField.text, page.language)
            }
        }

        QQC2.Label {
            visible: page.lookup.message !== ""
            text: page.lookup.message !== "" ? I18n.t(page.language, page.lookup.message) : ""
        }

        Repeater {
            model: page.lookup.places

            delegate: QQC2.Button {
                id: place

                required property var modelData

                flat: true
                icon.name: "mark-location"
                text: modelData.label

                onClicked: {
                    page.cfg_locationName = place.modelData.name;
                    page.cfg_latitude = place.modelData.latitude;
                    page.cfg_longitude = place.modelData.longitude;
                    page.cfg_region = place.modelData.region;
                    page.cfg_countryCode = place.modelData.countryCode;
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: alertsChoice

            Kirigami.FormData.label: I18n.t(page.language, "config.alerts")
            // Warnings are known for the countries listed in code/alerts.mjs.
            enabled: Alerts.feedUrl(page.cfg_countryCode) !== ""
            checked: page.cfg_showAlerts
            text: I18n.t(page.language, "config.alertsEnabled")

            onToggled: page.cfg_showAlerts = checked
        }

        // A checkbox that cannot be ticked has to say why.
        QQC2.Label {
            visible: !alertsChoice.enabled
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.alertsUnavailable")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: alertsChoice.enabled
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.alertsHint")
        }

        // Required by the MeteoAlarm terms, word for word.
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: alertsChoice.enabled
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Alerts.meteoalarmDisclaimer(page.language)
        }

        // Off until asked for: the terms of meteoromania.ro want the written consent of ANM. Until it
        // comes, the box cannot be ticked at all. Independent of the county warnings, which come from MeteoAlarm.
        QQC2.CheckBox {
            id: nowcastingChoice

            visible: Alerts.nowcastUrl(page.cfg_countryCode) !== ""
            enabled: Alerts.NOWCASTING_ALLOWED
            checked: Alerts.NOWCASTING_ALLOWED && page.cfg_showNowcasting
            text: I18n.t(page.language, "config.nowcastingEnabled")

            onToggled: page.cfg_showNowcasting = checked
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: nowcastingChoice.visible
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, Alerts.NOWCASTING_ALLOWED ? "config.nowcastingHint" : "config.nowcastingPending")
        }
    }
}
