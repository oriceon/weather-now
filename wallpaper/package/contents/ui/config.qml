pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../code/i18n.mjs" as I18n
import "../code/land.mjs" as Land

/** The settings of the wallpaper: the place, the land under the sky, and how much it moves. */
Kirigami.FormLayout {
    id: page

    property string cfg_locationName
    property string cfg_locationNameDefault
    property real cfg_latitude
    property real cfg_latitudeDefault
    property real cfg_longitude
    property real cfg_longitudeDefault
    property string cfg_landscape
    property string cfg_landscapeDefault
    property int cfg_landscapeHeight
    property int cfg_landscapeHeightDefault
    property string cfg_animations
    property string cfg_animationsDefault
    property bool cfg_pauseWhenCovered
    property bool cfg_pauseWhenCoveredDefault
    // Plasma hands these to every page of a wallpaper; without them it logs an error at each opening.
    property var configDialog
    property var wallpaperConfiguration

    readonly property string language: I18n.resolveLanguage("auto", Qt.locale().uiLanguages)
    readonly property PlaceSearch lookup: PlaceSearch {}

    // Lines its labels up with those of the page that holds it, as the wallpapers of Plasma do.
    twinFormLayouts: typeof parentLayout !== "undefined" && parentLayout !== null ? [parentLayout] : []

    QQC2.Label {
        Kirigami.FormData.label: I18n.t(page.language, "config.currentLocation")
        font.weight: Font.DemiBold
        text: page.cfg_locationName !== "" ? page.cfg_locationName : I18n.t(page.language, "config.noLocation")
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

    // In a layout of its own, right under the search: a Repeater straight in a FormLayout has its
    // rows put at the very end of the page.
    ColumnLayout {
        visible: page.lookup.places.length > 0
        spacing: 0

        Repeater {
            model: page.lookup.places

            delegate: QQC2.Button {
                required property var modelData

                flat: true
                icon.name: "mark-location"
                text: modelData.label

                onClicked: {
                    page.cfg_locationName = modelData.name;
                    page.cfg_latitude = modelData.latitude;
                    page.cfg_longitude = modelData.longitude;
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
    }

    ColumnLayout {
        Kirigami.FormData.label: I18n.t(page.language, "wallpaper.landscape")
        Kirigami.FormData.buddyFor: landscapeNone
        spacing: Kirigami.Units.smallSpacing

        // Only so that the label of the group has something to point at: Kirigami puts the label
        // level with it, and at the end it stood by the last button.
        Item {
            id: landscapeNone
        }

        Repeater {
            model: Land.KINDS

            delegate: QQC2.RadioButton {
                required property string modelData

                checked: page.cfg_landscape === modelData
                text: I18n.t(page.language, `config.landscape${modelData.charAt(0).toUpperCase()}${modelData.slice(1)}`)

                onToggled: page.cfg_landscape = modelData
            }
        }

    }

    RowLayout {
        Kirigami.FormData.label: I18n.t(page.language, "config.landscapeHeight")
        enabled: page.cfg_landscape !== "none"
        spacing: Kirigami.Units.smallSpacing

        QQC2.Slider {
            id: landscapeHeight

            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            from: 25
            to: 85
            stepSize: 5
            snapMode: QQC2.Slider.SnapAlways
            value: page.cfg_landscapeHeight

            onMoved: page.cfg_landscapeHeight = Math.round(value)
        }

        QQC2.Label {
            // As wide as the widest value, so that the slider does not move under the mouse.
            Layout.minimumWidth: widest.advanceWidth
            text: `${Math.round(landscapeHeight.value)}%`

            TextMetrics {
                id: widest

                text: "100%"
            }
        }
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    ColumnLayout {
        Kirigami.FormData.label: I18n.t(page.language, "config.animations")
        Kirigami.FormData.buddyFor: animationsFull
        spacing: Kirigami.Units.smallSpacing

        QQC2.RadioButton {
            id: animationsFull

            checked: page.cfg_animations === "full"
            text: I18n.t(page.language, "config.animationsFull")

            onToggled: page.cfg_animations = "full"
        }

        QQC2.RadioButton {
            checked: page.cfg_animations === "reduced"
            text: I18n.t(page.language, "config.animationsReduced")

            onToggled: page.cfg_animations = "reduced"
        }

        QQC2.RadioButton {
            checked: page.cfg_animations === "off"
            text: I18n.t(page.language, "config.animationsOff")

            onToggled: page.cfg_animations = "off"
        }

        QQC2.CheckBox {
            enabled: page.cfg_animations !== "off"
            checked: page.cfg_pauseWhenCovered
            text: I18n.t(page.language, "wallpaper.pause")

            onToggled: page.cfg_pauseWhenCovered = checked
        }
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    // Open-Meteo asks to be named where its data shows; the wallpaper has no room for it.
    QQC2.Label {
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: I18n.t(page.language, "wallpaper.credit")
    }
}
