pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/i18n.mjs" as I18n
import "components" as Components

/** What a new widget shows instead of a forecast: it asks which place the forecast is wanted for. */
ColumnLayout {
    id: prompt

    required property string language
    required property var typography

    readonly property PlaceSearch lookup: PlaceSearch {}

    /** A place of parseGeocode() in code/openmeteo.mjs. */
    signal placeChosen(var place)

    function search(): void {
        if (field.text.trim().length > 1) {
            lookup.search(field.text, language);
        }
    }

    spacing: Kirigami.Units.largeSpacing

    Item {
        Layout.fillHeight: true
        Layout.maximumHeight: Kirigami.Units.gridUnit * 2
    }

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large
        source: "mark-location"
    }

    Components.Label {
        Layout.fillWidth: true
        typography: prompt.typography
        relativeSize: 1.4
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.t(prompt.language, "welcome.title")
    }

    Components.Label {
        Layout.fillWidth: true
        typography: prompt.typography
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: 0.75
        text: I18n.t(prompt.language, "welcome.hint")
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.TextField {
            id: field

            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            font.family: prompt.typography.family
            font.pointSize: prompt.typography.size
            placeholderText: I18n.t(prompt.language, "config.searchPlaceholder")

            onAccepted: prompt.search()
            // Emptied, the field lets go of the places it found.
            onTextChanged: {
                if (text.trim() === "") {
                    prompt.lookup.clear();
                }
            }
        }

        PlasmaComponents.Button {
            enabled: field.text.trim().length > 1
            font.family: prompt.typography.family
            font.pointSize: prompt.typography.size
            icon.name: "search"
            text: I18n.t(prompt.language, "config.search")

            onClicked: prompt.search()
        }
    }

    Components.Label {
        Layout.fillWidth: true
        typography: prompt.typography
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: prompt.lookup.message !== ""
        text: prompt.lookup.message !== "" ? I18n.t(prompt.language, prompt.lookup.message) : ""
    }

    // The places found; the list scrolls when there are more than fit.
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        Layout.alignment: Qt.AlignHCenter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Kirigami.Units.smallSpacing / 2
        model: prompt.lookup.places

        delegate: PlasmaComponents.Button {
            id: place

            required property var modelData

            width: ListView.view.width
            flat: true
            font.family: prompt.typography.family
            font.pointSize: prompt.typography.size
            icon.name: "mark-location"
            text: modelData.label

            onClicked: prompt.placeChosen(place.modelData)
        }
    }
}
