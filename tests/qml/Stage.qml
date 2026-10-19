import QtQuick

import "../../package/contents/code/alerts.mjs" as Alerts
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

    Ui.FullRepresentation {
        anchors.fill: parent
        forecast: stage.forecast
        alerts: stage.alerts
        located: stage.mode !== "welcome"
        ready: stage.mode === "ready" || stage.mode === "stale"
        loading: stage.mode === "loading"
        failed: stage.mode === "failed" || stage.mode === "stale"
        // The time of the forecast, which is when it was fetched.
        updatedAt: new Date(stage.forecast.current.time)
        language: stage.language
        locationName: stage.locality
        windUnit: stage.windUnit
        firstDayOfWeek: stage.firstDayOfWeek
        animations: stage.animations
        hiddenTabs: stage.hiddenTabs
        fontScale: stage.fontScale
        fontFamily: stage.fontFamily
        iconSet: stage.iconSet
        currentTab: stage.tab

        onPlaceChosen: place => stage.chosenPlace = place
    }
}
