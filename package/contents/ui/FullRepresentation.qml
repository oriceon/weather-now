pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/alerts.mjs" as Alerts
import "../code/i18n.mjs" as I18n
import "../code/links.mjs" as Links
import "../code/places.mjs" as Places
import "components" as Components
import "tabs" as Tabs

Item {
    id: full

    /** Parsed forecast, see parseForecast() in code/openmeteo.mjs. Only read while `ready`. */
    required property var forecast
    /** Official warnings for the place, see code/alerts.mjs. */
    required property var alerts
    /** parseAirQuality() of code/airquality.mjs; null when there is none. */
    required property var airQuality
    /** auroraOutlook() of code/aurora.mjs; null without a Kp for the night. */
    required property var aurora
    /** The quarter hours of precipitation, fresher than the forecast's while the notification of rain is on. */
    required property var minutely
    /** The tiles of the Details tab that are shown, in their order; see code/details.mjs. */
    required property var detailsOrder
    /** False until a place is chosen; the widget then asks for one instead of showing a forecast. */
    required property bool located
    required property bool ready
    required property bool loading
    required property bool failed
    /** Why the forecast could not be loaded, in a sentence; empty while it could. */
    property string failureText: ""
    required property date updatedAt
    required property string language
    required property string locationName
    /** The other places kept, see code/places.mjs; with any, the name in the header opens a list of them. */
    property var places: []
    /** True while the list of places hangs open under the name. */
    property bool pickerOpen: false
    /** Where the list of places hangs: under the name, measured as it opens. */
    property point pickerOrigin: Qt.point(0, 0)
    required property string windUnit
    /** mm | inch */
    required property string precipitationUnit
    /** celsius | fahrenheit: the colours of the temperatures go by °C. */
    required property string temperatureUnit
    /** 0 Sunday … 6 Saturday. */
    required property int firstDayOfWeek
    /** full | reduced | off */
    required property string animations
    /** A window fills the screen over the widget on the desktop: the sky and the icons stand still. */
    property bool covered: false
    /** Ids of the tabs the user turned off. */
    required property var hiddenTabs
    /** Size of the text relative to the font of the Plasma theme. */
    required property real fontScale
    /** Empty for the font of the Plasma theme. */
    required property string fontFamily
    /** A family for the big numbers, drawn for large sizes; empty for `fontFamily`. */
    required property string displayFontFamily
    /** meteocons | breeze */
    required property string iconSet
    /** black | theme | none */
    required property string background
    /** The land under the sky of the Today tab: one of KINDS in code/land.mjs. */
    required property string landscape
    /** How much of the height of the Today tab the land takes, in percent. */
    required property int landscapeHeight
    /** What the Today tab shows besides the weather now, see todayParts in config/main.xml. */
    required property var todayParts
    /** How transparent the dark glass of the Today tab is, in percent. */
    required property int todayGlass
    /** What is behind the text of the Today tab: sky, glass or text, see todayBackground in config/main.xml. */
    required property string todayBackground
    /** The boxes of the Details tab: theme or glass, see detailsBoxes in config/main.xml. */
    required property string detailsBoxes
    /** How transparent their dark glass is, in percent. */
    required property int detailsGlass
    /** The place, for the rising and setting of the moon, and the season of the land. */
    required property real latitude
    required property real longitude
    /** The activities of their tile in Details, see code/activities.mjs. */
    required property var activities
    /** Percent: how much of the desktop shows through the transparent background; 100 is none at all. */
    required property int backgroundTransparency

    /** Index into `tabIds`. */
    property int currentTab: 0
    /**
     * What the size of the widget leaves room for: full, with its tabs; a wide, low band of the
     * hours ahead; a middling square, today and three days; or small, the temperature and a line.
     */
    readonly property string sizeMode: {
        const across = width / (Kirigami.Units.gridUnit * roomFactor);
        const down = height / (Kirigami.Units.gridUnit * roomFactor);

        if (across >= 20 && down >= 16) {
            return "full";
        }

        if (down < 11 && across >= down * 2.1) {
            return "band";
        }

        return across >= 12 && down >= 10 ? "medium" : "small";
    }
    readonly property bool compactView: sizeMode !== "full" && located && ready
    /**
     * True once the Today tab has been shown: from then on it is kept, see tabArea. Set by hand, not
     * bound: a binding to the tab on show turned false on leaving Today the first time, and the tab
     * was thrown away and built again, its whole sky with it.
     */
    property bool todaySeen: false

    readonly property var typography: ({
        family: fontFamily !== "" ? fontFamily : Kirigami.Theme.defaultFont.family,
        display: displayFontFamily !== "" ? displayFontFamily : fontFamily !== "" ? fontFamily : Kirigami.Theme.defaultFont.family,
        size: Kirigami.Theme.defaultFont.pointSize * fontScale,
    })
    /** Which icons the tabs show, and whether they move; only the Meteocons have animations. */
    readonly property var iconStyle: ({
        set: iconSet,
        animated: iconSet === "meteocons" && animations === "full",
        paused: covered,
    })
    /** Bigger text needs a bigger widget. */
    readonly property real roomFactor: Math.max(1, fontScale)
    readonly property var tabOrder: ["today", "hours", "rain", "days", "details"]
    readonly property var tabIds: {
        const shown = tabOrder.filter(id => !isHidden(id));

        return shown.length > 0 ? shown : [tabOrder[0]];
    }
    readonly property string tabId: tabIds[Math.min(currentTab, tabIds.length - 1)]
    /** In the order they lead, so that where only the first few have room, a red one is not left out. */
    readonly property var activeAlerts: ready ? Alerts.inLeadOrder(Alerts.activeAlerts(alerts, forecast.current.time), forecast.current.time) : []
    /**
     * Who the warnings on screen come from, as links: the service that issued them, named as the
     * MeteoAlarm terms want, and MeteoAlarm when they came through it. Empty while there are none.
     */
    readonly property string alertsSource: {
        if (activeAlerts.length === 0) {
            return "";
        }

        // Named by the feed, which may put markup in the name: it reads as it is written.
        const issuer = Links.escapeMarkup(activeAlerts[0].issuer);
        const site = Alerts.issuerSite(activeAlerts[0].issuer);
        const service = site !== "" ? `<a href="${site}">${issuer}</a>` : issuer;

        // The terms of the public alert server: name the official source, and link to the server.
        if (activeAlerts[0].source === "public") {
            return I18n.t(language, "header.sourceAlerts", { issuer: service, site: `<a href="${Alerts.PUBLIC_ALERT_SERVER}">alerts.kde.org</a>` });
        }

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
    /** Another of the kept places was picked from the header. */
    signal placeSwitched(var place)
    /** The tiles of the Details tab were dragged into another order. */
    signal tilesReordered(var order)
    /** A tile of the Details tab was closed with its ×. */
    signal tileHidden(string tile)

    /** Hangs the list of places under the name, as it is laid out now; a binding would not see the layout change. */
    function placePicker(): void {
        const origin = placeName.mapToItem(full, 0, placeName.height + Kirigami.Units.smallSpacing);

        pickerOrigin = Qt.point(origin.x, origin.y);
    }

    /** The place on show, as the kept ones are written; see code/places.mjs. */
    readonly property var currentPlace: ({ name: locationName, latitude: latitude, longitude: longitude, region: "", countryCode: "" })
    /** All the places, the one on show among them, in the order the dots under the name show them. */
    readonly property var placeRing: places.length > 0 ? Places.placeRing(currentPlace, places) : []
    /** Turns of the wheel not yet a whole step. */
    property real wheelTurn: 0

    /** Puts on show the place `step` places away round the ring of places. */
    function stepPlace(step: int): void {
        const next = Places.neighbourPlace(currentPlace, places, step);

        if (next !== null) {
            pickerOpen = false;
            placeSwitched(next);
        }
    }

    /** The next tab, or the one before with a negative `step`, round the strip. */
    function switchTab(step: int): void {
        currentTab = (Math.min(currentTab, tabIds.length - 1) + step + tabIds.length) % tabIds.length;
    }

    function isHidden(id: string): bool {
        for (let index = 0; index < hiddenTabs.length; index++) {
            if (hiddenTabs[index] === id) {
                return true;
            }
        }

        return false;
    }

    // Takes the keys while open: Ctrl+Tab and the others below.
    focus: true

    // Small enough for a corner of the desktop: below the size of the tabs, the widget shows less, see sizeMode.
    Layout.minimumWidth: Kirigami.Units.gridUnit * 9 * roomFactor
    Layout.minimumHeight: Kirigami.Units.gridUnit * 6 * roomFactor
    Layout.preferredWidth: Kirigami.Units.gridUnit * 28 * roomFactor
    Layout.preferredHeight: Kirigami.Units.gridUnit * 21 * roomFactor

    onPickerOpenChanged: {
        if (pickerOpen) {
            placePicker();
        }
    }
    onWidthChanged: {
        if (pickerOpen) {
            placePicker();
        }
    }
    onBackgroundChanged: {
        if (pickerOpen) {
            Qt.callLater(placePicker);
        }
    }

    // Ctrl+Tab and Ctrl+Page Down go to the next tab, with Shift or Page Up to the one before; Escape closes the list of places.
    Keys.onPressed: event => {
        const control = (event.modifiers & Qt.ControlModifier) !== 0;

        if (control && (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)) {
            switchTab(1);
        } else if (control && (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)) {
            switchTab(-1);
        } else if (control && (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && places.length > 0) {
            stepPlace(event.key === Qt.Key_Right ? 1 : -1);
        } else if (event.key === Qt.Key_Escape && pickerOpen) {
            pickerOpen = false;
        } else {
            return;
        }

        event.accepted = true;
    }

    // On its own black background the widget takes the dark colours Plasma keeps for such places,
    // whatever the theme: those of a light one would not read on black.
    Kirigami.Theme.inherit: background !== "black"
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    // The black background, or the colour of the Plasma theme behind the transparent one, as much as asked.
    Rectangle {
        anchors.fill: parent
        visible: full.background === "black" || (full.background === "none" && full.backgroundTransparency < 100)
        radius: Kirigami.Units.cornerRadius * 2
        color: full.background === "black" ? "#000000" : Qt.alpha(Kirigami.Theme.backgroundColor, 1 - full.backgroundTransparency / 100)
    }

    // A widget too small for its tabs.
    Loader {
        anchors.fill: parent
        anchors.margins: full.background === "theme" ? 0 : Kirigami.Units.smallSpacing
        active: full.compactView

        sourceComponent: CompactView {
            covered: full.covered
            mode: full.sizeMode
            forecast: full.forecast
            language: full.language
            locationName: full.locationName
            windUnit: full.windUnit
            temperatureUnit: full.temperatureUnit
            animations: full.animations
            typography: full.typography
            iconStyle: full.iconStyle
            landscape: full.landscape
            landscapeHeight: full.landscapeHeight
            latitude: full.latitude
            aurora: full.aurora
            backdrop: full.todayBackground
            glassTransparency: full.todayGlass
        }
    }

    ColumnLayout {
        anchors.fill: parent
        // The frame of the Plasma theme brings its own margins.
        anchors.margins: full.background === "theme" ? 0 : Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: !full.compactView

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Components.Label {
                id: placeName

                Layout.fillWidth: true
                typography: full.typography
                relativeSize: 1.35
                elide: Text.ElideRight
                text: full.locationName + (full.places.length > 0 ? " ▾" : "")
                visible: full.located
                Accessible.role: full.places.length > 0 ? Accessible.ButtonDropDown : Accessible.StaticText

                // With other places kept, the name opens their list, and lights up under the mouse.
                Rectangle {
                    z: -1
                    x: -Kirigami.Units.smallSpacing
                    width: Math.min(parent.width, parent.implicitWidth) + Kirigami.Units.smallSpacing * 2
                    height: parent.height
                    radius: Kirigami.Units.cornerRadius
                    color: placeTouch.containsMouse || full.pickerOpen ? Qt.alpha(Kirigami.Theme.textColor, 0.1) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                MouseArea {
                    id: placeTouch

                    width: Math.min(parent.width, parent.implicitWidth)
                    height: parent.height
                    enabled: full.places.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: full.pickerOpen = !full.pickerOpen

                    PlasmaComponents.ToolTip {
                        visible: placeTouch.containsMouse && !full.pickerOpen
                        text: I18n.t(full.language, "header.switchPlace")
                    }
                }

                // The wheel, or a swipe sideways on a touchpad, goes round the places, a notch at a time.
                WheelHandler {
                    enabled: full.places.length > 0

                    onWheel: event => {
                        full.wheelTurn += event.angleDelta.y !== 0 ? -event.angleDelta.y : event.angleDelta.x;

                        if (Math.abs(full.wheelTurn) >= 120) {
                            full.stepPlace(full.wheelTurn > 0 ? 1 : -1);
                            full.wheelTurn = 0;
                        }
                    }
                }

                // A dot for each place, the one on show lit, after the name.
                Row {
                    x: Math.min(parent.width, parent.implicitWidth) + Kirigami.Units.smallSpacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: full.placeRing.length > 1

                    Repeater {
                        model: full.placeRing

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool here: Places.samePlace(modelData, full.currentPlace)

                            width: here ? 8 : 6
                            height: 6
                            radius: 3
                            color: Kirigami.Theme.textColor
                            opacity: here ? 0.9 : 0.35

                            Behavior on width {
                                NumberAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }
                        }
                    }
                }
            }

            Components.Label {
                id: updated

                typography: full.typography
                relativeSize: 0.9
                visible: full.ready
                color: full.failed ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                opacity: full.failed ? 1 : 0.7
                text: I18n.t(full.language, "header.updated", { time: Qt.formatTime(full.updatedAt, Qt.locale().timeFormat(Locale.ShortFormat)) })

                // In the colour of a warning, the forecast is an old one: why, under the mouse.
                HoverHandler {
                    id: updatedHover
                }

                PlasmaComponents.ToolTip {
                    visible: updatedHover.hovered && full.failureText !== ""
                    text: full.failureText
                }
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

            FontMetrics {
                id: tabFont

                font.family: full.typography.family
                font.pointSize: full.typography.size
            }

            PlasmaComponents.TabBar {
                id: tabStrip

                /**
                 * The names of the tabs, all at one size: as large as lets the longest fit its button. In a
                 * narrow widget, "Aujourd'hui" or "Szczegóły" ran past theirs.
                 */
                readonly property real labelScale: Math.max(0.75, Math.min(1, ...Array.from(contentChildren).map(button => button.fit || 1)))
                /**
                 * The share of the bar each button has when the names fit: not the width of a button, which,
                 * with a name too long for its share, follows the name, and so the size it is given.
                 */
                readonly property real share: (availableWidth - spacing * Math.max(0, full.tabIds.length - 1)) / Math.max(1, full.tabIds.length)

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
                        /** How much smaller its name must be to fit, at the size of the text; a little to spare. */
                        readonly property real fit: tabFont.font.pointSize > 0 ? (tabStrip.share - leftPadding - rightPadding) * 0.97 / Math.max(1, tabFont.advanceWidth(text)) : 1

                        font.family: full.typography.family
                        font.pointSize: full.typography.size * tabStrip.labelScale
                        text: I18n.t(full.language, `tab.${modelData}`)
                    }
                }
            }

            // Only the tab in view exists, so the others cost nothing; but Today, once seen, stays, standing
            // still while hidden: its sky took long to build again each time it was picked.
            Item {
                id: tabArea

                /** The tab shown before, to slide the new one in from its side. */
                property int previousTab: 0

                Layout.fillWidth: true
                Layout.fillHeight: true

                // A tab slides in a little from the side of the tab strip it was picked on, and fades in.
                transform: Translate {
                    id: tabSlide
                }

                Connections {
                    target: full

                    function onTabIdChanged(): void {
                        if (full.animations !== "off") {
                            tabSlide.x = (full.currentTab >= tabArea.previousTab ? 1 : -1) * Kirigami.Units.gridUnit * 1.5;
                            tabArea.opacity = 0;
                            tabEntrance.restart();
                        }

                        tabArea.previousTab = full.currentTab;
                    }
                }

                // Kept on screen behind the other tabs, faded out and deaf to the mouse: hidden, its sky
                // lost its pictures and drew them again, one after another, every time it came back.
                Loader {
                    anchors.fill: parent
                    active: (full.todaySeen || full.tabId === "today") && full.tabIds.indexOf("today") !== -1
                    opacity: full.tabId === "today" ? 1 : 0
                    enabled: full.tabId === "today"
                    sourceComponent: todayTab

                    // Made once, kept from then on.
                    onLoaded: full.todaySeen = true
                }

                // The other tabs, each made the first time it is picked and kept from then on, hidden while
                // another is on show: thrown away and made again, each held up the switch a moment.
                Repeater {
                    model: ["hours", "rain", "days", "details"]

                    delegate: Loader {
                        required property string modelData
                        /** Made once, kept from then on. */
                        property bool kept: false

                        anchors.fill: parent
                        active: kept || full.tabId === modelData
                        visible: full.tabId === modelData
                        sourceComponent: ({ hours: hoursTab, rain: rainTab, days: daysTab, details: detailsTab })[modelData]

                        // Not on loading: that happens while `active` itself is being worked out.
                        onVisibleChanged: kept = kept || visible
                    }
                }

                ParallelAnimation {
                    id: tabEntrance

                    NumberAnimation {
                        target: tabSlide
                        property: "x"
                        to: 0
                        duration: Kirigami.Units.longDuration + 60
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: tabArea
                        property: "opacity"
                        to: 1
                        duration: Kirigami.Units.longDuration
                    }
                }
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
                    // The air quality comes from CAMS, which asks to be named where its data shows.
                    full.tabId === "details" && full.airQuality !== null ? I18n.t(full.language, "header.sourceAir", { source: '<a href="https://atmosphere.copernicus.eu/">CAMS</a>' }) : "",
                    // The Kp comes from the space weather service of NOAA.
                    full.tabId === "details" && full.aurora !== null && full.detailsOrder.indexOf("aurora") !== -1 ? I18n.t(full.language, "header.sourceKp", { source: '<a href="https://www.swpc.noaa.gov/">NOAA SWPC</a>' }) : "",
                    full.alertsSource,
                ].filter(part => part !== "").join(" · ")

                onLinkActivated: link => {
                    if (Links.webAddress(link) !== "") {
                        Qt.openUrlExternally(Links.webAddress(link));
                    }
                }

                HoverHandler {
                    cursorShape: sources.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }

    Component {
        id: todayTab

        Tabs.TodayTab {
            covered: full.covered
            shown: full.tabId === "today"
            aurora: full.aurora
            minutely: full.minutely
            landscape: full.landscape
            landscapeHeight: full.landscapeHeight
            latitude: full.latitude
            parts: full.todayParts
            glassTransparency: full.todayGlass
            backdrop: full.todayBackground
            temperatureUnit: full.temperatureUnit
            forecast: full.forecast
            alerts: full.activeAlerts
            language: full.language
            precipitationUnit: full.precipitationUnit
            windUnit: full.windUnit
            animations: full.animations
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: hoursTab

        Tabs.HourlyTab {
            days: full.forecast.daily
            temperatureUnit: full.temperatureUnit
            animations: full.animations
            hours: full.forecast.hourly
            language: full.language
            windUnit: full.windUnit
            precipitationUnit: full.precipitationUnit
            typography: full.typography
            iconStyle: full.iconStyle
        }
    }

    Component {
        id: rainTab

        Tabs.RainTab {
            forecast: full.forecast
            minutely: full.minutely
            language: full.language
            precipitationUnit: full.precipitationUnit
            typography: full.typography
            latitude: full.latitude
            longitude: full.longitude
        }
    }

    Component {
        id: daysTab

        Tabs.DailyTab {
            days: full.forecast.daily
            allHours: full.forecast.allHours
            now: full.forecast.current.time
            windUnit: full.windUnit
            precipitationUnit: full.precipitationUnit
            animations: full.animations
            currentTemperature: full.forecast.current.temperature
            temperatureUnit: full.temperatureUnit
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
            animations: full.animations
            boxes: full.detailsBoxes
            glassTransparency: full.detailsGlass
            airQuality: full.airQuality
            aurora: full.aurora
            order: full.detailsOrder
            latitude: full.latitude
            longitude: full.longitude
            activities: full.activities
            precipitationUnit: full.precipitationUnit
            temperatureUnit: full.temperatureUnit
            forecast: full.forecast
            language: full.language
            windUnit: full.windUnit
            typography: full.typography
            iconStyle: full.iconStyle

            onReordered: order => full.tilesReordered(order)
            onHidden: tile => full.tileHidden(tile)
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

            Components.Label {
                Layout.fillWidth: true
                typography: full.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.75
                visible: full.failed && full.failureText !== ""
                text: full.failureText
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

    // A click anywhere else closes the list of places.
    MouseArea {
        anchors.fill: parent
        visible: full.pickerOpen

        onClicked: full.pickerOpen = false
    }

    Rectangle {
        visible: full.pickerOpen && full.places.length > 0
        x: full.pickerOrigin.x
        y: full.pickerOrigin.y
        width: Math.min(full.width - 2 * x, Kirigami.Units.gridUnit * 16)
        height: placeList.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        // Opaque whatever the background of the widget is: a list over the sky has to read.
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

        Column {
            id: placeList

            x: Kirigami.Units.smallSpacing
            y: Kirigami.Units.smallSpacing
            width: parent.width - 2 * x

            Repeater {
                model: full.places

                delegate: Rectangle {
                    id: choice

                    required property var modelData

                    width: placeList.width
                    height: choiceName.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: choiceTouch.containsMouse ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : "transparent"

                    Components.Label {
                        id: choiceName

                        anchors.verticalCenter: parent.verticalCenter
                        x: Kirigami.Units.smallSpacing * 2
                        width: parent.width - 2 * x
                        typography: full.typography
                        elide: Text.ElideRight
                        text: choice.modelData.region !== "" ? `${choice.modelData.name}, ${choice.modelData.region}` : choice.modelData.name
                    }

                    MouseArea {
                        id: choiceTouch

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            full.pickerOpen = false;
                            full.placeSwitched(choice.modelData);
                        }
                    }
                }
            }
        }
    }
}
