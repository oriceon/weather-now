pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/alerts.mjs" as Alerts
import "../code/i18n.mjs" as I18n
import "components" as Components
import "tabs" as Tabs

Item {
    id: full

    /** Parsed forecast, see parseForecast() in code/openmeteo.mjs. Only read while `ready`. */
    required property var forecast
    /** Official warnings for the place, see code/alerts.mjs. */
    required property var alerts
    /** False until a place is chosen; the widget then asks for one instead of showing a forecast. */
    required property bool located
    required property bool ready
    required property bool loading
    required property bool failed
    required property date updatedAt
    required property string language
    required property string locationName
    required property string windUnit
    /** 0 Sunday … 6 Saturday. */
    required property int firstDayOfWeek
    /** full | reduced | off */
    required property string animations
    /** Ids of the tabs the user turned off. */
    required property var hiddenTabs
    /** Size of the text relative to the font of the Plasma theme. */
    required property real fontScale
    /** Empty for the font of the Plasma theme. */
    required property string fontFamily
    /** meteocons | breeze */
    required property string iconSet

    /** Index into `tabIds`. */
    property int currentTab: 0

    readonly property var typography: ({
        family: fontFamily !== "" ? fontFamily : Kirigami.Theme.defaultFont.family,
        size: Kirigami.Theme.defaultFont.pointSize * fontScale,
    })
    /** Which icons the tabs show, and whether they move; only the Meteocons have animations. */
    readonly property var iconStyle: ({
        set: iconSet,
        animated: iconSet === "meteocons" && animations === "full",
    })
    /** Bigger text needs a bigger widget. */
    readonly property real roomFactor: Math.max(1, fontScale)
    readonly property var tabOrder: ["today", "hours", "rain", "days", "details"]
    readonly property var tabIds: {
        const shown = tabOrder.filter(id => !isHidden(id));

        return shown.length > 0 ? shown : [tabOrder[0]];
    }
    readonly property string tabId: tabIds[Math.min(currentTab, tabIds.length - 1)]
    readonly property var activeAlerts: ready ? Alerts.activeAlerts(alerts, forecast.current.time) : []
    /**
     * Who the warnings on screen come from, as links: the service that issued them, named as the
     * MeteoAlarm terms want, and MeteoAlarm when they came through it. Empty while there are none.
     */
    readonly property string alertsSource: {
        if (activeAlerts.length === 0) {
            return "";
        }

        const issuer = activeAlerts[0].issuer;
        const site = Alerts.issuerSite(issuer);
        const service = site !== "" ? `<a href="${site}">${issuer}</a>` : issuer;

        // Nowcasting alone comes from the service itself, without MeteoAlarm.
        if (!activeAlerts.some(alert => alert.source === "meteoalarm")) {
            return service;
        }

        const meteoalarm = '<a href="https://www.meteoalarm.org">MeteoAlarm</a>';

        return service !== "" ? I18n.t(language, "header.sourceAlerts", { issuer: service, site: meteoalarm }) : meteoalarm;
    }

    signal refreshRequested()
    /** A place of parseGeocode() in code/openmeteo.mjs, picked at the first-run prompt. */
    signal placeChosen(var place)

    function isHidden(id: string): bool {
        for (let index = 0; index < hiddenTabs.length; index++) {
            if (hiddenTabs[index] === id) {
                return true;
            }
        }

        return false;
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20 * roomFactor
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18 * roomFactor
    Layout.preferredWidth: Kirigami.Units.gridUnit * 28 * roomFactor
    Layout.preferredHeight: Kirigami.Units.gridUnit * 21 * roomFactor

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Components.Label {
                Layout.fillWidth: true
                typography: full.typography
                relativeSize: 1.35
                elide: Text.ElideRight
                text: full.locationName
                visible: full.located
            }

            Components.Label {
                typography: full.typography
                relativeSize: 0.9
                visible: full.ready
                color: full.failed ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                opacity: full.failed ? 1 : 0.7
                text: I18n.t(full.language, "header.updated", { time: Qt.formatTime(full.updatedAt, "HH:mm") })
            }

            PlasmaComponents.ToolButton {
                display: QQC2.AbstractButton.IconOnly
                visible: full.located
                enabled: !full.loading
                icon.name: "view-refresh"
                text: I18n.t(full.language, "header.refresh")

                onClicked: full.refreshRequested()

                PlasmaComponents.ToolTip {
                    text: parent.text
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: !full.located ? promptView : full.ready ? forecastView : statusView
        }
    }

    Component {
        id: promptView

        LocationPrompt {
            language: full.language
            typography: full.typography

            onPlaceChosen: place => full.placeChosen(place)
        }
    }

    Component {
        id: forecastView

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.TabBar {
                Layout.fillWidth: true
                currentIndex: Math.min(full.currentTab, full.tabIds.length - 1)

                // -1 while the buttons are being rebuilt after a change of the tabs shown.
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        full.currentTab = currentIndex;
                    }
                }

                Repeater {
                    model: full.tabIds

                    delegate: PlasmaComponents.TabButton {
                        required property string modelData

                        font.family: full.typography.family
                        font.pointSize: full.typography.size
                        text: I18n.t(full.language, `tab.${modelData}`)
                    }
                }
            }

            // Only the tab in view exists, so the others cost nothing, and the animated one stops when left.
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: ({ today: todayTab, hours: hoursTab, rain: rainTab, days: daysTab, details: detailsTab })[full.tabId]
            }

            // The sources, as links. Open-Meteo and MeteoAlarm both require theirs; ANM issued the warnings.
            Components.Label {
                id: sources

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.Wrap
                typography: full.typography
                relativeSize: 0.85
                opacity: 0.75
                textFormat: Text.StyledText
                text: [
                    I18n.t(full.language, "header.source", { forecast: '<a href="https://open-meteo.com/">Open-Meteo</a>' }),
                    full.alertsSource,
                ].filter(part => part !== "").join(" · ")

                onLinkActivated: link => Qt.openUrlExternally(link)

                HoverHandler {
                    cursorShape: sources.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }

    Component {
        id: todayTab

        Tabs.TodayTab {
            forecast: full.forecast
            alerts: full.activeAlerts
            language: full.language
            windUnit: full.windUnit
            animations: full.animations
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: hoursTab

        Tabs.HourlyTab {
            hours: full.forecast.hourly
            language: full.language
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: rainTab

        Tabs.RainTab {
            forecast: full.forecast
            language: full.language
            typography: full.typography
        }
    }

    Component {
        id: daysTab

        Tabs.DailyTab {
            days: full.forecast.daily
            now: full.forecast.current.time
            alerts: full.activeAlerts
            language: full.language
            firstDayOfWeek: full.firstDayOfWeek
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: detailsTab

        Tabs.DetailsTab {
            forecast: full.forecast
            language: full.language
            windUnit: full.windUnit
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: statusView

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Item {
                Layout.fillHeight: true
            }

            PlasmaComponents.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: !full.failed
                running: visible
            }

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                visible: full.failed
                source: "network-disconnect"
            }

            Components.Label {
                Layout.fillWidth: true
                typography: full.typography
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: I18n.t(full.language, full.failed ? "state.error" : "state.loading")
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                visible: full.failed
                enabled: !full.loading
                icon.name: "view-refresh"
                text: I18n.t(full.language, "state.retry")

                onClicked: full.refreshRequested()
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
