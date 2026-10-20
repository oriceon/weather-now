pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/i18n.mjs" as I18n

ConfigPage {
    id: page

    /** Follows the choice on this page, so the labels switch language before the change is applied. */
    readonly property string language: I18n.resolveLanguage(cfg_language, Qt.locale().uiLanguages)

    /**
     * The options of the ComboBoxes read the same in every language on purpose: a model
     * that changed with the language would make a ComboBox drop its selection.
     */
    readonly property var languageValues: ["auto", "ro", "en"]
    readonly property var fontScaleValues: [90, 100, 110, 125, 140, 160]
    readonly property var tabIds: ["today", "hours", "rain", "days", "details"]

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
            model: ["Auto", "Română", "English"]
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
                // Empty is the font of the Plasma theme.
                text: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : I18n.t(page.language, "config.fontTheme")
            }

            QQC2.Button {
                icon.name: "settings-configure"
                text: I18n.t(page.language, "config.fontChoose")

                onClicked: {
                    fontDialog.selectedFont = Qt.font({ family: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : Kirigami.Theme.defaultFont.family });
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
