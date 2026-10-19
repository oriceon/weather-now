import QtQuick

import "../code/alerts.mjs" as Alerts
import "../code/openmeteo.mjs" as OpenMeteo
import "../code/wmo.mjs" as Wmo

/**
 * Loads the forecast from Open-Meteo and the official warnings for the place, and keeps them fresh.
 */
QtObject {
    id: store

    /** False while no place is chosen: there is nothing to ask for then. */
    property bool active: true
    /** Starts the warnings the store logs, so that they can be found in the journal: the id of the widget. */
    property string logName: ""
    property real latitude
    property real longitude
    property string temperatureUnit: "celsius"
    property string windUnit: "kmh"
    property int refreshMinutes: 30

    /** What the warnings are looked up by: the country, the county and the locality. */
    property string countryCode
    property string region
    property string locality
    /** The county warnings, through MeteoAlarm. */
    property bool alertsEnabled: true
    /** The immediate warnings, from the website of ANM, which is asked for nothing while this is off. Independent of `alertsEnabled`. */
    property bool nowcastingEnabled: false
    /** Language the text of the warnings is wanted in. */
    property string language: "en"

    /** Last forecast that was loaded. It stays available while a refresh is running or failing. */
    property var forecast: null
    /** The request the forecast on hand answers. */
    property string loadedUrl: ""
    property date updatedAt
    property bool loading: false
    property bool failed: false
    property string errorText: ""

    readonly property string requestUrl: OpenMeteo.forecastUrl({
        latitude: latitude,
        longitude: longitude,
        temperatureUnit: temperatureUnit,
        windUnit: windUnit,
    })
    /** False while the forecast on hand is for another place or unit than the configured one. */
    readonly property bool ready: forecast !== null && loadedUrl === requestUrl
    readonly property string iconName: ready ? Wmo.iconName(forecast.current.conditionCode, forecast.current.isDay) : "weather-none-available"

    /** Warnings per county, as the feed lists them: without their text, which comes from `warningTexts`. */
    property var countyWarnings: []
    /** Immediate warnings, which name localities. */
    property var immediateWarnings: []
    /** `{ headline, description }` of the warnings whose text was fetched, by address and language. */
    property var warningTexts: ({})
    /** Every warning for the place, expired ones included; see code/alerts.mjs. */
    readonly property var alerts: countyWarnings
        .map(warning => Object.assign({}, warning, warningTexts[store.textKey(warning.capUrl)] || {}))
        .concat(immediateWarnings)
    readonly property string feedUrl: alertsEnabled ? Alerts.feedUrl(countryCode) : ""
    readonly property string nowcastUrl: nowcastingEnabled && Alerts.NOWCASTING_ALLOWED ? Alerts.nowcastUrl(countryCode) : ""
    /** What the warnings on hand were looked up for. */
    readonly property string alertsKey: [alertsEnabled, nowcastingEnabled, countryCode, region, locality, language].join("|")

    readonly property int retryMinutes: 1
    /** The MeteoAlarm terms want warnings passed on within five minutes of being published, whatever the forecast does. */
    readonly property int alertMinutes: 5
    /** A request that has not answered by then is given up, and tried again like any other failure. */
    readonly property int patienceSeconds: 25
    property int requestSerial: 0
    property int alertSerial: 0

    readonly property Timer refreshTimer: Timer {
        interval: (store.failed ? store.retryMinutes : store.refreshMinutes) * 60 * 1000
        repeat: true
        running: store.active

        onTriggered: store.refresh()
    }

    readonly property Timer patienceTimer: Timer {
        interval: store.patienceSeconds * 1000
        running: store.loading

        onTriggered: {
            // Whatever the request still answers is ignored from here on.
            store.requestSerial++;
            store.loading = false;
            store.failed = true;
            store.errorText = "The forecast request timed out";
            console.warn(`${store.logName}: the forecast request timed out`);
        }
    }

    readonly property Timer alertsTimer: Timer {
        interval: store.alertMinutes * 60 * 1000
        repeat: true
        running: store.active && (store.feedUrl !== "" || store.nowcastUrl !== "")

        onTriggered: store.refreshAlerts()
    }

    function textKey(capUrl: string): string {
        return `${language}|${capUrl}`;
    }

    /** Hands the body of a successful response to `receive`; a failed request is left alone, the next refresh retries. */
    function fetchText(url: string, receive: var): void {
        const request = new XMLHttpRequest();

        request.onreadystatechange = () => {
            if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {
                receive(request.responseText);
            }
        };

        request.open("GET", url);
        request.send();
    }

    function refresh(): void {
        if (!active) {
            return;
        }

        const serial = ++requestSerial;
        const url = requestUrl;
        const request = new XMLHttpRequest();

        loading = true;

        request.onreadystatechange = () => {
            // A newer request makes this answer obsolete.
            if (request.readyState !== XMLHttpRequest.DONE || serial !== store.requestSerial) {
                return;
            }

            store.loading = false;

            try {
                store.forecast = OpenMeteo.parseForecast(JSON.parse(request.responseText));
                store.loadedUrl = url;
                store.updatedAt = new Date();
                store.failed = false;
                store.errorText = "";
            } catch (error) {
                store.failed = true;
                store.errorText = String(error.message || error);
                console.warn(`${store.logName}: the forecast could not be loaded:`, store.errorText);

                return;
            }

            store.refreshAlerts();
        };

        request.open("GET", url);
        request.send();
    }

    /** Needs a forecast: the feed gives times in UTC, and the forecast knows the offset of the place. */
    function refreshAlerts(): void {
        const serial = ++alertSerial;

        if (forecast === null) {
            countyWarnings = [];
            immediateWarnings = [];

            return;
        }

        if (feedUrl === "") {
            countyWarnings = [];
        } else {
            fetchText(feedUrl, text => {
                if (serial !== store.alertSerial) {
                    return;
                }

                store.countyWarnings = Alerts.parseFeed(text, store.region, store.forecast.utcOffsetSeconds);
                store.countyWarnings.forEach(warning => store.fetchWarningText(warning.capUrl));
            });
        }

        if (nowcastUrl === "") {
            immediateWarnings = [];
        } else {
            fetchText(nowcastUrl, text => {
                if (serial === store.alertSerial) {
                    store.immediateWarnings = Alerts.parseNowcast(text, store.region, store.locality);
                }
            });
        }
    }

    function fetchWarningText(capUrl: string): void {
        const key = textKey(capUrl);
        const wanted = language;

        if (capUrl === "" || warningTexts[key] !== undefined) {
            return;
        }

        fetchText(capUrl, text => {
            const texts = Object.assign({}, store.warningTexts);

            texts[key] = Alerts.parseCap(text, wanted);
            // A new object, so that everything bound to the texts notices.
            store.warningTexts = texts;
        });
    }

    onActiveChanged: Qt.callLater(store.refresh)
    onRequestUrlChanged: Qt.callLater(store.refresh)
    onAlertsKeyChanged: Qt.callLater(store.refreshAlerts)
    Component.onCompleted: Qt.callLater(store.refresh)
}
