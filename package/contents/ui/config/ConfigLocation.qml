pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../../code/alerts.mjs" as Alerts
import "../../code/i18n.mjs" as I18n
import "../../code/places.mjs" as Places
import ".." as Ui

ConfigPage {
    id: page

    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    /** The times the summary of the day can come at: every half hour from 05:00 to 11:30. */
    readonly property var morningTimes: Array.from({ length: 14 }, (unused, index) => `${String(5 + Math.floor(index / 2)).padStart(2, "0")}:${index % 2 === 0 ? "00" : "30"}`)

    /** The parts of the summary left out, as an array. */
    function leftOut(): var {
        const names = [];

        for (let index = 0; index < cfg_morningParts.length; index++) {
            names.push(String(cfg_morningParts[index]));
        }

        return names;
    }

    readonly property Ui.PlaceSearch lookup: Ui.PlaceSearch {}
    readonly property var savedPlaces: Places.parsePlaces(cfg_savedPlaces)
    readonly property var currentPlace: ({ name: cfg_locationName, latitude: cfg_latitude, longitude: cfg_longitude, region: cfg_region, countryCode: cfg_countryCode })

    function show(place: var): void {
        cfg_locationName = place.name;
        cfg_latitude = place.latitude;
        cfg_longitude = place.longitude;
        cfg_region = place.region;
        cfg_countryCode = place.countryCode;
        // Shown, it is no longer among the places kept to switch to: found again, it was there twice.
        cfg_savedPlaces = Places.serializePlaces(Places.removePlace(savedPlaces, place));
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: I18n.t(page.language, "config.currentLocation")
            font.weight: Font.DemiBold
            text: page.cfg_locationName !== "" ? page.cfg_locationName : I18n.t(page.language, "config.noLocation")
        }

        QQC2.Label {
            // A county in Romania, the first division of the country elsewhere: a state, a province, a region.
            Kirigami.FormData.label: I18n.t(page.language, page.cfg_countryCode === "RO" ? "config.county" : "config.region")
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

                function searchOnReturn(event: var): void {
                    event.accepted = true;

                    if (searchButton.enabled) {
                        searchButton.clicked();
                    }
                }

                // Return is taken here: let through, it reached the settings dialog, which took it for OK
                // and closed before the places were found.
                Keys.onReturnPressed: event => searchField.searchOnReturn(event)
                Keys.onEnterPressed: event => searchField.searchOnReturn(event)
                // Emptied, the field lets go of the places it found.
                onTextChanged: {
                    if (text.trim() === "") {
                        page.lookup.clear();
                    }
                }
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

        // A place found: shown at once, or kept among the places to switch to from the header. In a
        // layout of its own, right under the search: a Repeater straight in a FormLayout has its
        // rows put at the very end of the page.
        ColumnLayout {
            visible: page.lookup.places.length > 0
            spacing: 0

            Repeater {
                model: page.lookup.places

                delegate: RowLayout {
                    id: found

                    required property var modelData

                    spacing: 0

                    QQC2.Button {
                        flat: true
                        icon.name: "mark-location"
                        text: found.modelData.label

                        onClicked: page.show(found.modelData)
                    }

                    QQC2.ToolButton {
                        icon.name: "list-add"
                        display: QQC2.AbstractButton.IconOnly
                        text: I18n.t(page.language, "config.keepPlace")
                        enabled: !Places.samePlace(found.modelData, page.currentPlace) && !page.savedPlaces.some(kept => Places.samePlace(kept, found.modelData))

                        onClicked: page.cfg_savedPlaces = Places.serializePlaces(Places.addPlace(page.savedPlaces, found.modelData, page.currentPlace))

                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
        }

        // GeoNames, which the places come from, asks to be named with them.
        QQC2.Label {
            visible: page.lookup.places.length > 0
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: I18n.t(page.language, "config.placesCredit")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: page.savedPlaces.length > 0
        }

        // The kept places: shown with a click, which keeps the one on show in their place, or removed.
        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.keptPlaces")
            visible: page.savedPlaces.length > 0
            spacing: 0

            Repeater {
                model: page.savedPlaces

                delegate: RowLayout {
                    id: kept

                    required property var modelData

                    spacing: 0

                    QQC2.Button {
                        flat: true
                        icon.name: "mark-location"
                        text: kept.modelData.region !== "" ? `${kept.modelData.name}, ${kept.modelData.region}` : kept.modelData.name

                        onClicked: {
                            page.cfg_savedPlaces = Places.serializePlaces(Places.switchPlaces(page.savedPlaces, kept.modelData, page.currentPlace));
                            page.show(kept.modelData);
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "edit-delete-remove"
                        display: QQC2.AbstractButton.IconOnly
                        text: I18n.t(page.language, "config.removePlace")

                        onClicked: page.cfg_savedPlaces = Places.serializePlaces(Places.removePlace(page.savedPlaces, kept.modelData))

                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.keptPlacesHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.notify")
            Kirigami.FormData.buddyFor: notifyAlerts
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                id: notifyAlerts

                checked: page.cfg_notifyAlerts
                text: I18n.t(page.language, "config.notifyAlerts")

                onToggled: page.cfg_notifyAlerts = checked
            }

            QQC2.CheckBox {
                checked: page.cfg_notifyRain
                text: I18n.t(page.language, "config.notifyRain")

                onToggled: page.cfg_notifyRain = checked
            }

            QQC2.CheckBox {
                checked: page.cfg_notifyFrost
                text: I18n.t(page.language, "config.notifyFrost")

                onToggled: page.cfg_notifyFrost = checked
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    checked: page.cfg_notifyMorning
                    text: I18n.t(page.language, "config.notifyMorning")

                    onToggled: page.cfg_notifyMorning = checked
                }

                // Every half hour of the morning; the list reads the same in every language, so that it keeps its choice.
                QQC2.ComboBox {
                    enabled: page.cfg_notifyMorning
                    model: page.morningTimes
                    currentIndex: Math.max(0, page.morningTimes.indexOf(page.cfg_morningTime))

                    onActivated: index => page.cfg_morningTime = page.morningTimes[index]
                }
            }

            // What the summary tells, each to leave out.
            ColumnLayout {
                Layout.leftMargin: Kirigami.Units.gridUnit
                visible: page.cfg_notifyMorning
                spacing: 0

                QQC2.Label {
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: I18n.t(page.language, "config.morningParts")
                }

                Repeater {
                    model: ["temperatures", "rain", "uv", "alerts", "pollen", "yesterday"]

                    delegate: QQC2.CheckBox {
                        id: part

                        required property string modelData

                        checked: page.leftOut().indexOf(modelData) === -1
                        text: I18n.t(page.language, `config.morning${modelData.charAt(0).toUpperCase()}${modelData.slice(1)}`)

                        onToggled: {
                            const others = page.leftOut().filter(name => name !== part.modelData);

                            page.cfg_morningParts = checked ? others : others.concat([part.modelData]);
                        }
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.airQuality")
            checked: page.cfg_showAirQuality
            text: I18n.t(page.language, "config.airQualityEnabled")

            onToggled: page.cfg_showAirQuality = checked
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.airQualityHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: alertsChoice

            Kirigami.FormData.label: I18n.t(page.language, "config.alerts")
            checked: page.cfg_showAlerts
            text: I18n.t(page.language, "config.alertsEnabled")

            onToggled: page.cfg_showAlerts = checked
        }

        // Where the warnings come from: MeteoAlarm in its countries, the public alert server elsewhere.
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, Alerts.hasMeteoalarm(page.cfg_countryCode) ? "config.alertsHint" : "config.alertsHintPublic")
        }

        // Required by the MeteoAlarm terms, word for word.
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: Alerts.hasMeteoalarm(page.cfg_countryCode)
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
