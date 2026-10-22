import QtQuick

import "../../package/contents/code/activities.mjs" as Activities
import "../../package/contents/code/airquality.mjs" as AirQuality
import "../../package/contents/code/alerts.mjs" as Alerts
import "../../package/contents/code/details.mjs" as Details
import "../../package/contents/code/openmeteo.mjs" as OpenMeteo
import "../../package/contents/ui" as Ui

// Renders the full representation from recorded API responses, without the network.
Item {
    id: stage

    property string fixtureJson
    /** Fields that replace those of `current`, to stage a weather the fixture does not have. */
    property string currentOverridesJson: "{}"
    property string language: "ro"
    property string windUnit: "kmh"
    property string precipitationUnit: "mm"
    property string temperatureUnit: "celsius"
    property int tab: 0
    /** ready | loading | failed | stale (failed refresh, old forecast still shown) | welcome (no place chosen yet) */
    property string mode: "ready"
    /** What the first-run prompt handed over, null until a place is picked. */
    property var chosenPlace: null
    property int firstDayOfWeek: 1
    property string animations: "off"
    property var hiddenTabs: []
    property real fontScale: 1.1
    property string fontFamily: ""
    property string iconSet: "meteocons"
    /** The other places kept, and whether their list hangs open. */
    property var places: []
    property bool picker: false
    /** An answer of the air quality API, empty for none. */
    property string airQualityJson: ""
    /** How the aurora can be seen tonight, none for no outlook at all. */
    property string auroraSight: "none"
    /** The tiles of the Details tab, empty for the order of a new widget, and those turned off. */
    property var detailsOrder: []
    property var hiddenTiles: []
    property string background: "theme"
    property string landscape: "none"
    property int landscapeHeight: 55
    /** What the Today tab shows besides the weather now. */
    property var todayParts: ["hours", "insights", "rain", "yesterday"]
    property int todayGlass: 62
    property string todayBackground: "sky"
    property int backgroundTransparency: 100

    /** Recorded warning feeds; empty ones stage a place without warnings. */
    property string alertsFeed: ""
    property string alertsCap: ""
    property string alertsNowcast: ""
    property string region: "Constanța"
    property string locality: "Constanța"

    readonly property var forecast: {
        const parsed = OpenMeteo.parseForecast(JSON.parse(fixtureJson));

        Object.assign(parsed.current, JSON.parse(currentOverridesJson));

        return parsed;
    }
    readonly property var alerts: Alerts.parseFeed(alertsFeed, region, forecast.utcOffsetSeconds)
        .map(warning => Object.assign({}, warning, Alerts.parseCap(alertsCap, language)))
        .concat(Alerts.parseNowcast(alertsNowcast, region, locality))

    // As the widget does: Inter, which comes with it, unless a font is given.
    Ui.WidgetFonts {
        id: widgetFonts
    }

    Ui.FullRepresentation {
        anchors.fill: parent
        forecast: stage.forecast
        alerts: stage.alerts
        airQuality: stage.airQualityJson !== "" ? AirQuality.parseAirQuality(JSON.parse(stage.airQualityJson)) : null
        aurora: stage.auroraSight !== "none" ? { kp: 6.33, storm: "G2", sight: stage.auroraSight, needed: 5, direction: "north" } : null
        minutely: stage.forecast.minutely
        detailsOrder: Details.shownTiles(Details.tileOrder(stage.detailsOrder), stage.hiddenTiles)
        located: stage.mode !== "welcome"
        ready: stage.mode === "ready" || stage.mode === "stale"
        loading: stage.mode === "loading"
        failed: stage.mode === "failed" || stage.mode === "stale"
        // The time of the forecast, which is when it was fetched.
        updatedAt: new Date(stage.forecast.current.time)
        language: stage.language
        locationName: stage.locality
        windUnit: stage.windUnit
        precipitationUnit: stage.precipitationUnit
        temperatureUnit: stage.temperatureUnit
        firstDayOfWeek: stage.firstDayOfWeek
        animations: stage.animations
        hiddenTabs: stage.hiddenTabs
        fontScale: stage.fontScale
        fontFamily: stage.fontFamily !== "" ? stage.fontFamily : widgetFonts.text
        displayFontFamily: stage.fontFamily === "" ? widgetFonts.display : ""
        iconSet: stage.iconSet
        places: stage.places
        // Opened once laid out, as a click would.
        pickerOpen: false
        background: stage.background
        landscape: stage.landscape
        landscapeHeight: stage.landscapeHeight
        todayParts: stage.todayParts
        todayGlass: stage.todayGlass
        todayBackground: stage.todayBackground
        // Constanța, as the recorded answers are.
        latitude: 44.18073
        longitude: 28.63432
        activities: Activities.DEFAULT_ACTIVITIES
        backgroundTransparency: stage.backgroundTransparency
        currentTab: stage.tab

        onPlaceChosen: place => stage.chosenPlace = place
        onTilesReordered: shown => stage.detailsOrder = Details.withShownOrder(Details.tileOrder(stage.detailsOrder), shown)
        onTileHidden: tile => stage.hiddenTiles = stage.hiddenTiles.concat([tile])
        Component.onCompleted: Qt.callLater(() => pickerOpen = stage.picker)
    }
}
