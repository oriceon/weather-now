import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/alerts.mjs" as Alerts
import "../../code/i18n.mjs" as I18n
import "." as Components

/** An official weather warning: colour code, phenomenon, interval and the text of the warning. */
Rectangle {
    id: banner

    /** A warning from parseFeed() or parseNowcast() in code/alerts.mjs. */
    required property var alert
    /** Current time at the forecast location. */
    required property string now
    required property string language
    required property var typography
    /** How many lines of text to show under the title, at least one; the whole text is in the tooltip. */
    property int textLines: 2
    /** Other warnings in force that this banner stands for as well. */
    property int moreCount: 0

    /** Background and text colour of each colour code. */
    readonly property var palettes: ({
        yellow: ["#f7c948", "#2b2300"],
        orange: ["#f08c2e", "#2b1500"],
        red: ["#d93a3a", "#ffffff"],
    })
    readonly property color ink: palettes[alert.level][1]
    readonly property string title: `${Alerts.alertTitle(alert, language)}  ·  ${Alerts.alertInterval(alert, now, language)}`
    readonly property string body: alert.description
    /**
     * Who issued the warning and when. The MeteoAlarm terms require both to be shown with the
     * warning, so they open the line under the title, which is never hidden.
     */
    readonly property string credit: [alert.issuer, Alerts.alertIssued(alert, now, language)].filter(part => part !== "").join(" · ")
    /** Where the warning can be read at its source; the MeteoAlarm terms require the link. */
    readonly property string site: alert.source === "meteoalarm" ? "www.meteoalarm.org" : "www.meteoromania.ro"

    implicitHeight: content.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: palettes[alert.level][0]

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Kirigami.Units.smallSpacing * 2
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "dialog-warning-symbolic"
                isMask: true
                color: banner.ink
            }

            Components.Label {
                Layout.fillWidth: true
                typography: banner.typography
                elide: Text.ElideRight
                color: banner.ink
                font.weight: Font.DemiBold
                text: banner.title
            }

            Components.Label {
                typography: banner.typography
                visible: banner.moreCount > 0
                color: banner.ink
                font.weight: Font.DemiBold
                text: `+${banner.moreCount}`
            }
        }

        Components.Label {
            Layout.fillWidth: true
            typography: banner.typography
            relativeSize: 0.95
            wrapMode: Text.WordWrap
            maximumLineCount: Math.max(1, banner.textLines)
            elide: Text.ElideRight
            color: banner.ink
            text: [banner.credit, banner.body].filter(part => part !== "").join(" · ")
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Qt.openUrlExternally(`https://${banner.site}`)
    }

    PlasmaComponents.ToolTip {
        visible: hover.hovered
        text: [
            banner.title,
            banner.credit,
            banner.body,
            I18n.t(banner.language, `alert.source.${banner.alert.source}`),
            banner.alert.source === "meteoalarm" ? Alerts.meteoalarmDisclaimer(banner.language) : "",
            // The MeteoAlarm terms require the original wording, after the translation if there is one.
            banner.alert.source === "meteoalarm" ? Alerts.METEOALARM_DISCLAIMER : "",
            I18n.t(banner.language, "alert.openSite", { site: banner.site }),
        ].filter((part, index, parts) => part !== "" && parts.indexOf(part) === index).join("\n")
    }
}
