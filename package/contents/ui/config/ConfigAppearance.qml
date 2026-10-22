pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/activities.mjs" as Activities
import "../../code/details.mjs" as Details
import "../../code/i18n.mjs" as I18n
import "../../code/land.mjs" as Land

ConfigPage {
    id: page

    /** Follows the choice on this page, so the labels switch language before the change is applied. */
    readonly property string language: I18n.resolveLanguage(cfg_language, Qt.locale().uiLanguages)

    /**
     * The options of the ComboBoxes read the same in every language on purpose: a model
     * that changed with the language would make a ComboBox drop its selection.
     */
    readonly property var languageValues: ["auto", "ro", "en", "de", "es", "fr", "it", "pl"]
    readonly property var fontScaleValues: [90, 100, 110, 125, 140, 160]
    readonly property var tabIds: ["today", "hours", "rain", "days", "details"]

    /** What the Today tab shows besides the weather now, as an array. */
    function todayParts(): var {
        const parts = [];

        for (let index = 0; index < cfg_todayParts.length; index++) {
            parts.push(String(cfg_todayParts[index]));
        }

        return parts;
    }

    /** The activities chosen, as an array; none chosen is those of a new widget. */
    function chosenActivities(): var {
        const chosen = Activities.ACTIVITIES.filter(activity => cfg_activities.indexOf(activity) !== -1);

        return chosen.length > 0 ? chosen : Activities.DEFAULT_ACTIVITIES;
    }

    /** The tiles turned off, as an array of ids. */
    function hiddenTiles(): var {
        return Details.TILES.filter(tile => cfg_hiddenTiles.indexOf(tile) !== -1);
    }

    function hiddenTabs(): var {
        const hidden = [];

        for (let index = 0; index < cfg_hiddenTabs.length; index++) {
            hidden.push(String(cfg_hiddenTabs[index]));
        }

        return hidden;
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.language")
            // Each language by its own name.
            model: ["Auto", "Română", "English", "Deutsch", "Español", "Français", "Italiano", "Polski"]
            currentIndex: page.languageValues.indexOf(page.cfg_language)

            onActivated: index => page.cfg_language = page.languageValues[index]
        }

        QQC2.Label {
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.languageHint")
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.firstDay")
            Kirigami.FormData.buddyFor: firstDayAuto
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: firstDayAuto

                checked: page.cfg_firstDayOfWeek === -1
                text: I18n.t(page.language, "config.firstDayAuto")

                onToggled: page.cfg_firstDayOfWeek = -1
            }

            QQC2.RadioButton {
                checked: page.cfg_firstDayOfWeek === 1
                text: I18n.t(page.language, "config.monday")

                onToggled: page.cfg_firstDayOfWeek = 1
            }

            QQC2.RadioButton {
                checked: page.cfg_firstDayOfWeek === 0
                text: I18n.t(page.language, "config.sunday")

                onToggled: page.cfg_firstDayOfWeek = 0
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.fontSize")
            model: page.fontScaleValues.map(percent => `${percent}%`)
            currentIndex: page.fontScaleValues.indexOf(page.cfg_fontScale)

            onActivated: index => page.cfg_fontScale = page.fontScaleValues[index]
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.fontFamily")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                // Empty is Inter, which comes with the widget.
                text: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : I18n.t(page.language, "config.fontWidget")
            }

            QQC2.Button {
                icon.name: "settings-configure"
                text: I18n.t(page.language, "config.fontChoose")

                onClicked: {
                    fontDialog.selectedFont = Qt.font({ family: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : "Weather Now Inter" });
                    fontDialog.open();
                }
            }

            QQC2.Button {
                visible: page.cfg_fontFamily !== ""
                icon.name: "edit-undo"
                text: I18n.t(page.language, "config.fontReset")

                onClicked: page.cfg_fontFamily = ""
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.background")
            Kirigami.FormData.buddyFor: backgroundBlack
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: backgroundBlack

                checked: page.cfg_background === "black"
                text: I18n.t(page.language, "config.backgroundBlack")

                onToggled: page.cfg_background = "black"
            }

            QQC2.RadioButton {
                checked: page.cfg_background === "theme"
                text: I18n.t(page.language, "config.backgroundTheme")

                onToggled: page.cfg_background = "theme"
            }

            QQC2.RadioButton {
                checked: page.cfg_background === "none"
                text: I18n.t(page.language, "config.backgroundNone")

                onToggled: page.cfg_background = "none"
            }
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.backgroundTransparency")
            visible: page.cfg_background === "none"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: transparency

                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: page.cfg_backgroundTransparency

                onMoved: page.cfg_backgroundTransparency = Math.round(value)
            }

            QQC2.Label {
                // As wide as the widest value, so that the slider does not move under the mouse.
                Layout.minimumWidth: widest.advanceWidth
                text: `${Math.round(transparency.value)}%`

                TextMetrics {
                    id: widest

                    text: "100%"
                }
            }
        }

        // Room between the slider above and the choices below, which otherwise nearly touch.
        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.today")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: ["clock", "hours", "conditions", "insights", "rain", "yesterday"]

                delegate: QQC2.CheckBox {
                    id: todayChoice

                    required property string modelData

                    checked: page.todayParts().indexOf(modelData) !== -1
                    text: I18n.t(page.language, `config.today${modelData.charAt(0).toUpperCase()}${modelData.slice(1)}`)

                    onToggled: {
                        const others = page.todayParts().filter(part => part !== todayChoice.modelData);

                        page.cfg_todayParts = checked ? others.concat([todayChoice.modelData]) : others;
                    }
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.todayGlass")
            // With only the text, there is no glass to make transparent.
            enabled: page.cfg_todayBackground !== "text"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: glass

                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: page.cfg_todayGlass

                onMoved: page.cfg_todayGlass = Math.round(value)
            }

            QQC2.Label {
                // As wide as the widest value, so that the slider does not move under the mouse.
                Layout.minimumWidth: widestGlass.advanceWidth
                text: `${Math.round(glass.value)}%`

                TextMetrics {
                    id: widestGlass

                    text: "100%"
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.todayBackground")
            Kirigami.FormData.buddyFor: todayBackgroundSky
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: todayBackgroundSky

                checked: page.cfg_todayBackground === "sky"
                text: I18n.t(page.language, "config.todayBackgroundSky")

                onToggled: page.cfg_todayBackground = "sky"
            }

            QQC2.RadioButton {
                checked: page.cfg_todayBackground === "glass"
                text: I18n.t(page.language, "config.todayBackgroundGlass")

                onToggled: page.cfg_todayBackground = "glass"
            }

            QQC2.RadioButton {
                checked: page.cfg_todayBackground === "text"
                text: I18n.t(page.language, "config.todayBackgroundText")

                onToggled: page.cfg_todayBackground = "text"
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                // Only while the rest of the widget still has a background of its own.
                visible: page.cfg_todayBackground !== "sky" && (page.cfg_background !== "none" || page.cfg_backgroundTransparency < 100)
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: I18n.t(page.language, "config.todayBackgroundHint")
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.landscape")
            Kirigami.FormData.buddyFor: landscapeNone
            // The land is drawn under the sky only.
            enabled: page.cfg_todayBackground === "sky"
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
                    required property int index

                    checked: page.cfg_landscape === modelData
                    text: I18n.t(page.language, `config.landscape${modelData.charAt(0).toUpperCase()}${modelData.slice(1)}`)

                    onToggled: page.cfg_landscape = modelData
                }
            }

        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.landscapeHeight")
            enabled: page.cfg_todayBackground === "sky" && page.cfg_landscape !== "none"
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
                Layout.minimumWidth: widestGlass.advanceWidth
                text: `${Math.round(landscapeHeight.value)}%`
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.icons")
            Kirigami.FormData.buddyFor: iconsMeteocons
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: iconsMeteocons

                checked: page.cfg_iconSet === "meteocons"
                text: I18n.t(page.language, "config.iconsMeteocons")

                onToggled: page.cfg_iconSet = "meteocons"
            }

            QQC2.RadioButton {
                checked: page.cfg_iconSet === "breeze"
                text: I18n.t(page.language, "config.iconsTheme")

                onToggled: page.cfg_iconSet = "breeze"
            }
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

            // Plasma's own speed of animations, at "Instant", stops the widget whatever is chosen here.
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: Kirigami.Units.longDuration === 0
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: I18n.t(page.language, "config.animationsSystem")
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.panel")
            checked: page.cfg_showRainInPanel
            text: I18n.t(page.language, "config.panelRain")

            onToggled: page.cfg_showRainInPanel = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.detailsOrder")
            spacing: Kirigami.Units.smallSpacing

            // A box for each tile, in the order the tiles are in; the last one left cannot be turned off.
            Repeater {
                model: Details.tileOrder(page.cfg_detailsOrder)

                delegate: QQC2.CheckBox {
                    id: tileChoice

                    required property string modelData

                    enabled: !checked || page.hiddenTiles().length < Details.TILES.length - 1
                    checked: page.hiddenTiles().indexOf(modelData) === -1
                    text: I18n.t(page.language, Details.TILE_NAMES[modelData])

                    onToggled: {
                        const others = page.hiddenTiles().filter(tile => tile !== tileChoice.modelData);

                        page.cfg_hiddenTiles = checked ? others : others.concat([tileChoice.modelData]);
                    }
                }
            }

            QQC2.Button {
                enabled: page.cfg_detailsOrder.length > 0
                icon.name: "edit-undo"
                text: I18n.t(page.language, "config.detailsOrderReset")

                onClicked: page.cfg_detailsOrder = []
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: I18n.t(page.language, "config.detailsOrderHint")
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.activities")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: Activities.ACTIVITIES

                delegate: QQC2.CheckBox {
                    id: activityChoice

                    required property string modelData

                    // The last one left cannot be turned off.
                    enabled: !checked || page.chosenActivities().length > 1
                    checked: page.chosenActivities().indexOf(modelData) !== -1
                    text: I18n.t(page.language, `activity.${modelData}`)

                    onToggled: {
                        const others = page.chosenActivities().filter(activity => activity !== activityChoice.modelData);

                        page.cfg_activities = checked ? others.concat([activityChoice.modelData]) : others;
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: I18n.t(page.language, "config.activitiesHint")
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.tabs")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.tabIds

                delegate: QQC2.CheckBox {
                    id: tabChoice

                    required property string modelData

                    // The last tab left cannot be turned off.
                    enabled: !checked || page.hiddenTabs().length < page.tabIds.length - 1
                    checked: page.hiddenTabs().indexOf(modelData) === -1
                    text: I18n.t(page.language, `tab.${modelData}`)

                    onToggled: {
                        const others = page.hiddenTabs().filter(id => id !== tabChoice.modelData);

                        page.cfg_hiddenTabs = checked ? others : others.concat([tabChoice.modelData]);
                    }
                }
            }
        }
    }

    // The fonts are listed in a dialog of their own. A ComboBox of the desktop style made a row for
    // every installed font as the page opened and laid them all out again as the list opened, and
    // with a few hundred fonts Plasma froze for seconds, both times.
    QtDialogs.FontDialog {
        id: fontDialog

        title: I18n.t(page.language, "config.fontDialogTitle")
        modality: Qt.WindowModal
        parentWindow: page.Window.window

        onAccepted: page.cfg_fontFamily = selectedFont.family
    }
}
