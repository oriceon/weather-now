pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
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
    readonly property var fontChoices: {
        const choices = ["Auto"];
        const families = Qt.fontFamilies();

        for (let index = 0; index < families.length; index++) {
            choices.push(families[index]);
        }

        return choices;
    }
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

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.fontFamily")
            model: page.fontChoices
            // "Auto", the first choice, is the font of the Plasma theme.
            currentIndex: Math.max(0, page.fontChoices.indexOf(page.cfg_fontFamily))

            onActivated: index => page.cfg_fontFamily = index === 0 ? "" : page.fontChoices[index]
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
}
