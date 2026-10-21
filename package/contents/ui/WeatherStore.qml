import QtQuick

import "../code/airquality.mjs" as AirQuality
import "../code/alerts.mjs" as Alerts
import "../code/aurora.mjs" as Aurora
import "../code/cache.mjs" as Cache
import "../code/openmeteo.mjs" as OpenMeteo

/**
 * Loads the forecast from Open-Meteo and the official warnings for the place, and keeps them fresh,
 * without asking the servers more than it needs: a place switched to is asked for once it has been
 * settled on, what was fetched a moment ago is taken from code/cache.mjs, and a forecast that failed
 * is asked again later and later.
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
    /** The official warnings: per county through MeteoAlarm, elsewhere from the public alert server. */
    property bool alertsEnabled: true
    /** The immediate warnings, from the website of ANM, which is asked for nothing while this is off. Independent of `alertsEnabled`. */
    property bool nowcastingEnabled: false
    /** Air quality and pollen, asked for with every forecast while this is on. */
    property bool airQualityEnabled: true
    /** The quarter hours of rain, asked for again in between forecasts, for the notification of rain. */
    property bool quartersEnabled: false
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
    /** The HTTP status of the last failure: 0 for no answer at all, 200 for one that could not be read. */
    property int failureStatus: 0

    readonly property string requestUrl: OpenMeteo.forecastUrl({
        latitude: latitude,
        longitude: longitude,
        temperatureUnit: temperatureUnit,
        windUnit: windUnit,
    })
    /** False while the forecast on hand is for another place or unit than the configured one. */
    readonly property bool ready: forecast !== null && loadedUrl === requestUrl

    /** The quarter hours of precipitation: those of the forecast, or fresher ones asked for in between. */
    property var minutely: []
    /** The time at the place, as fresh as the last answer: the forecast's, or that of the quarter hours. */
    property string now: ""
    readonly property string quartersUrl: OpenMeteo.quartersUrl({ latitude: latitude, longitude: longitude })

    /** The 3-hour Kp of NOAA, see parseKpForecast() in code/aurora.mjs; the same for every place. */
    property var kpForecast: []

    /** parseAirQuality() of code/airquality.mjs for the place; null while off, unknown or failed. */
    property var airQuality: null
    // Nothing is asked before there is a place: at the first run, the air at 0°, 0° was.
    readonly property string airQualityUrl: airQualityEnabled && active ? AirQuality.airQualityUrl(latitude, longitude) : ""

    /** Warnings per county, as the feed lists them: without their text, which comes from `warningTexts`. */
    property var countyWarnings: []
    /** Immediate warnings, which name localities. */
    property var immediateWarnings: []
    /** `{ headline, description }` of the warnings whose text was fetched, by address and language. */
    property var warningTexts: ({})
    /** Warnings of the public alert server for the place, in the order it listed them. */
    property var publicWarnings: []
    /** Whether the warnings of each source came in at least once since the place or the language changed. */
    property bool feedChecked: false
    property bool publicChecked: false
    /** True once every source has answered: from then on, a warning that appears is news. */
    readonly property bool alertsChecked: (feedUrl === "" || feedChecked) && (publicAlertsUrl === "" || publicChecked)
        // A notification sent before the text of the warning came had only its hours.
        && countyWarnings.every(warning => warning.capUrl === "" || warningTexts[textKey(warning.capUrl)] !== undefined)
    /**
     * What the documents of the public alert server held, by id and language: a warning, null for one
     * that is not, or false for one that could not be fetched, which is asked again at the next refresh.
     */
    property var publicDocuments: ({})
    /** Every warning for the place, expired ones included; see code/alerts.mjs. */
    readonly property var alerts: countyWarnings
        .map(warning => Object.assign({}, warning, warningTexts[store.textKey(warning.capUrl)] || {}))
        .concat(immediateWarnings)
        .concat(publicWarnings)
    readonly property string feedUrl: alertsEnabled ? Alerts.feedUrl(countryCode) : ""
    readonly property string publicAlertsUrl: alertsEnabled && countryCode !== "" && !Alerts.hasMeteoalarm(countryCode) ? Alerts.publicAlertsUrl(latitude, longitude) : ""
    readonly property string nowcastUrl: nowcastingEnabled && Alerts.NOWCASTING_ALLOWED ? Alerts.nowcastUrl(countryCode) : ""
    /** What the warnings on hand were looked up for. */
    readonly property string alertsKey: [alertsEnabled, nowcastingEnabled, countryCode, region, locality, language, publicAlertsUrl].join("|")

    /** As often as the settings say, but no more than every quarter of an hour. */
    readonly property int everyMinutes: Math.max(15, refreshMinutes)
    /** Failures in a row: the forecast is asked again after 1, 2, 4… minutes, at most as late as it is refreshed. */
    property int failures: 0
    /** Open-Meteo answered that it is asked too often: it is asked again in an hour. */
    property bool refused: false
    readonly property int retryMinutes: refused ? 60 : Math.min(everyMinutes, Math.pow(2, Math.max(0, failures - 1)))
    /**
     * The refresh asked for by hand waits this long after the one before it: a forecast that has just
     * come is fresh, while one that failed may be tried again at once, but not over and over.
     */
    readonly property int refreshPauseSeconds: refused ? 60 : failed ? 3 : 30
    property double askedAt: 0
    /** The request of the forecast still running, which a newer one cancels. */
    property var forecastRequest: null
    readonly property int quarterMinutes: 15
    /** NOAA estimates the Kp of the current slot through it; once an hour keeps the night's outlook fresh. */
    readonly property int kpMinutes: 60
    /** The MeteoAlarm terms want warnings passed on within five minutes of being published, whatever the forecast does. */
    readonly property int alertMinutes: 5
    /** A request that has not answered by then is given up, and tried again like any other failure. */
    readonly property int patienceSeconds: 25
    /**
     * How long an answer is taken from the cache instead of the server, in minutes. The feed of the
     * warnings stays fresher than the five minutes the MeteoAlarm terms allow; a warning document
     * does not change under its address.
     */
    readonly property int forecastFresh: 10
    readonly property int airFresh: 30
    readonly property int feedFresh: 4
    readonly property int documentFresh: 60
    readonly property int kpFresh: 55
    /** Longer answers are refused unread: none of the feeds sends as much, and reading one held up the desktop. */
    readonly property int mostCharacters: 2 * 1000 * 1000
    property int requestSerial: 0
    property int alertSerial: 0
    /**
     * The requests of fetchText() under way, by address: `{ request, since, waiting }`. Asked again
     * meanwhile, as the warnings are by both the forecast and the change of place, an address is not
     * asked twice; a request that hangs past the patience of the store is given up the next time.
     */
    property var underWay: ({})

    readonly property Timer refreshTimer: Timer {
        interval: (store.failed ? store.retryMinutes : store.everyMinutes) * 60 * 1000
        repeat: true
        running: store.active

        onTriggered: store.load(false)
    }

    // The timers of Qt do not count the time a computer sleeps: woken in the morning, it showed the
    // forecast of the evening for up to half an hour. The clock on the wall does count it.
    readonly property Timer wakeTimer: Timer {
        interval: 60 * 1000
        repeat: true
        running: store.active

        // From the last try, success or not: after a refusal the pause of an hour holds.
        onTriggered: {
            if (!store.loading && Date.now() - Math.max(store.askedAt, store.updatedAt.getTime() || 0) >= store.refreshTimer.interval + 60 * 1000) {
                store.load(false);
            }
        }
    }

    // A place is asked for once the wheel has stopped on it, not each place it went past.
    readonly property Timer settleTimer: Timer {
        interval: 500

        onTriggered: store.load(false)
    }

    readonly property Timer patienceTimer: Timer {
        interval: store.patienceSeconds * 1000
        running: store.loading

        onTriggered: {
            // Whatever the request still answers is ignored from here on.
            store.requestSerial++;

            if (store.forecastRequest !== null) {
                store.forecastRequest.abort();
                store.forecastRequest = null;
            }

            store.loading = false;
            store.failed = true;
            store.failures++;
            store.failureStatus = 0;
            store.errorText = "The forecast request timed out";
            console.warn(`${store.logName}: the forecast request timed out`);
        }
    }

    readonly property Timer quartersTimer: Timer {
        interval: store.quarterMinutes * 60 * 1000
        repeat: true
        running: store.active && store.quartersEnabled

        onTriggered: store.refreshQuarters()
    }

    readonly property Timer kpTimer: Timer {
        interval: store.kpMinutes * 60 * 1000
        repeat: true
        running: store.active
        triggeredOnStart: true

        onTriggered: store.refreshKp()
    }

    readonly property Timer alertsTimer: Timer {
        interval: store.alertMinutes * 60 * 1000
        repeat: true
        running: store.active && (store.feedUrl !== "" || store.nowcastUrl !== "" || store.publicAlertsUrl !== "")

        onTriggered: store.refreshAlerts()
    }

    function textKey(capUrl: string): string {
        return `${language}|${capUrl}`;
    }

    /**
     * Hands the body of a successful response to `receive`, or the one fetched from `url` less than
     * `freshMinutes` ago; a failed request goes to `fail` if there is one, else it is left alone and
     * the next refresh retries.
     */
    function fetchText(url: string, freshMinutes: int, receive: var, fail: var): void {
        const kept = Cache.remembered(url, freshMinutes * 60 * 1000);
        const running = underWay[url];

        if (kept !== undefined) {
            receive(kept);

            return;
        }

        if (running !== undefined && Date.now() - running.since < patienceSeconds * 1000) {
            running.waiting.push({ receive, fail });

            return;
        }

        if (running !== undefined) {
            running.request.abort();
        }

        const request = new XMLHttpRequest();
        const entry = { request, since: Date.now(), waiting: [{ receive, fail }] };

        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            if (store.underWay[url] === entry) {
                delete store.underWay[url];
            }

            const answered = request.status === 200 && request.responseText.length <= store.mostCharacters;

            if (answered) {
                Cache.remember(url, request.responseText);
            }

            entry.waiting.forEach(asker => {
                if (answered) {
                    asker.receive(request.responseText);
                } else if (asker.fail) {
                    asker.fail();
                }
            });
        };

        underWay[url] = entry;
        request.open("GET", url);
        request.send();
    }

    /** The refresh asked for by hand: from the server, but not again while one runs or has just run. */
    function refresh(): void {
        const since = Date.now() - askedAt;

        // A clock set back makes the last request seem to come from the future: no pause then.
        if (!loading && (since < 0 || since >= refreshPauseSeconds * 1000)) {
            load(true);
        }
    }

    /** The forecast of the place, from the cache while it is fresh there, unless `fromServer`. */
    function load(fromServer: bool): void {
        const url = requestUrl;
        const kept = fromServer ? undefined : Cache.remembered(url, forecastFresh * 60 * 1000);

        settleTimer.stop();

        if (!active) {
            return;
        }

        const serial = ++requestSerial;

        if (forecastRequest !== null) {
            forecastRequest.abort();
            forecastRequest = null;
            loading = false;
        }

        if (kept !== undefined) {
            receiveForecast(url, kept, 200);

            return;
        }

        const request = new XMLHttpRequest();

        forecastRequest = request;
        askedAt = Date.now();
        loading = true;

        request.onreadystatechange = () => {
            // A newer request makes this answer obsolete.
            if (request.readyState !== XMLHttpRequest.DONE || serial !== store.requestSerial) {
                return;
            }

            store.forecastRequest = null;
            store.loading = false;

            if (request.status === 200) {
                Cache.remember(url, request.responseText);
            }

            store.receiveForecast(url, request.responseText, request.status);
        };

        request.open("GET", url);
        request.send();
    }

    function receiveForecast(url: string, text: string, status: int): void {
        try {
            forecast = OpenMeteo.parseForecast(JSON.parse(text));
            minutely = forecast.minutely;
            now = forecast.current.time;
            loadedUrl = url;
            // From the cache, the forecast is as old as when it was fetched.
            updatedAt = new Date(Cache.fetchedAt(url) || Date.now());
            failed = false;
            failures = 0;
            refused = false;
            errorText = "";
        } catch (error) {
            failed = true;
            failures++;
            failureStatus = status;
            refused = status === 429;
            errorText = status === 200 ? String(error.message || error) : status === 0 ? "No answer from Open-Meteo" : `HTTP ${status}`;
            console.warn(`${logName}: the forecast could not be loaded:`, errorText);

            return;
        }

        // The next refresh, and the next quarter hours, counted from this forecast, which brought both;
        // restart() would start a timer its binding keeps stopped.
        [refreshTimer, quartersTimer].filter(timer => timer.running).forEach(timer => timer.restart());
        refreshAlerts();
        refreshAirQuality();
    }

    /** Another place or unit: at once if it was loaded a moment ago, else once it has been settled on. */
    function placeChanged(): void {
        if (Cache.remembered(requestUrl, forecastFresh * 60 * 1000) !== undefined) {
            load(false);
        } else {
            settleTimer.restart();
        }
    }

    /** Fresher quarter hours of rain, for the place of the forecast on hand. */
    function refreshQuarters(): void {
        const url = quartersUrl;

        if (!ready) {
            return;
        }

        fetchText(url, 0, text => {
            if (url !== store.quartersUrl || !store.ready) {
                return;
            }

            try {
                const quarters = OpenMeteo.parseQuarters(JSON.parse(text));

                store.minutely = quarters.minutely;
                store.now = quarters.now;
            } catch (error) {
                console.warn(`${store.logName}: the quarter hours could not be read:`, String(error.message || error));
            }
        }, null);
    }

    function refreshKp(): void {
        fetchText(Aurora.KP_FORECAST_URL, kpFresh, text => {
            try {
                store.kpForecast = Aurora.parseKpForecast(JSON.parse(text));
            } catch (error) {
                console.warn(`${store.logName}: the Kp of NOAA could not be read:`, String(error.message || error));
            }
        }, null);
    }

    /** The air goes with the forecast; when it cannot be had, the tile shows the gusts again instead. */
    function refreshAirQuality(): void {
        const url = airQualityUrl;

        if (url === "") {
            airQuality = null;

            return;
        }

        fetchText(url, airFresh, text => {
            if (url !== store.airQualityUrl) {
                return;
            }

            try {
                store.airQuality = AirQuality.parseAirQuality(JSON.parse(text));
            } catch (error) {
                store.airQuality = null;
                console.warn(`${store.logName}: the air quality could not be read:`, String(error.message || error));
            }
        }, null);
    }

    /**
     * Needs the forecast of the place: the feeds give times in UTC, and the forecast knows the offset
     * of the place. Until it is in, after a change of place, the forecast that loads asks again.
     */
    function refreshAlerts(): void {
        const serial = ++alertSerial;

        if (!ready) {
            return;
        }

        if (publicAlertsUrl === "") {
            publicWarnings = [];
        } else {
            fetchText(publicAlertsUrl, feedFresh, text => {
                if (serial !== store.alertSerial) {
                    return;
                }

                let ids = [];

                try {
                    ids = Alerts.parsePublicAlertIds(JSON.parse(text));
                } catch (error) {
                    console.warn(`${store.logName}: the public alert server sent an answer that could not be read`);
                }

                store.showPublicWarnings(ids, serial);
                ids.forEach(id => store.fetchPublicWarning(id, ids, serial));
            }, null);
        }

        if (feedUrl === "") {
            countyWarnings = [];
        } else {
            fetchText(feedUrl, feedFresh, text => {
                if (serial !== store.alertSerial) {
                    return;
                }

                const texts = {};

                store.countyWarnings = Alerts.parseFeed(text, store.region, store.forecast.utcOffsetSeconds);
                store.feedChecked = true;
                // Only the texts of the warnings in the feed are kept; those of expired ones are let go.
                store.countyWarnings.forEach(warning => {
                    const key = store.textKey(warning.capUrl);

                    if (store.warningTexts[key] !== undefined) {
                        texts[key] = store.warningTexts[key];
                    }
                });
                store.warningTexts = texts;
                store.countyWarnings.forEach(warning => store.fetchWarningText(warning.capUrl));
            }, null);
        }

        if (nowcastUrl === "") {
            immediateWarnings = [];
        } else {
            fetchText(nowcastUrl, feedFresh, text => {
                if (serial === store.alertSerial) {
                    store.immediateWarnings = Alerts.parseNowcast(text, store.region, store.locality);
                }
            }, null);
        }
    }

    /** A document is kept by its id, and by the language and the offset from UTC it was read for. */
    function documentKey(id: string): string {
        return `${language}|${forecast.utcOffsetSeconds}|${id}`;
    }

    /**
     * The warnings of `ids`, the list of refresh `serial`, without the ones that say the same; shown
     * only once every document of the list is in, so that a copy that comes late does not count as a
     * new warning. Documents no longer listed are let go.
     */
    function showPublicWarnings(ids: var, serial: int): void {
        if (serial !== alertSerial || !ids.every(id => publicDocuments[documentKey(id)] !== undefined)) {
            return;
        }

        const documents = {};

        ids.forEach(id => {
            documents[documentKey(id)] = publicDocuments[documentKey(id)];
        });
        publicDocuments = documents;
        publicWarnings = Alerts.distinctAlerts(ids.map(id => documents[documentKey(id)]).filter(warning => warning));
        publicChecked = true;
    }

    /** A document is fetched once: a warning does not change under its id, an update gets a new one. */
    function fetchPublicWarning(id: string, ids: var, serial: int): void {
        const key = documentKey(id);
        const wanted = language;
        const offset = forecast.utcOffsetSeconds;

        if (publicDocuments[key] !== undefined && publicDocuments[key] !== false) {
            return;
        }

        // One document that cannot be had, or read, leaves out that warning, not the others with it.
        const keep = warning => {
            // An answer for a list that has since been replaced is of no use.
            if (serial !== store.alertSerial) {
                return;
            }

            const documents = Object.assign({}, store.publicDocuments);

            documents[key] = warning;
            store.publicDocuments = documents;
            store.showPublicWarnings(ids, serial);
        };

        fetchText(Alerts.publicAlertUrl(id), documentFresh, text => {
            try {
                keep(Alerts.parsePublicAlert(text, wanted, offset));
            } catch (error) {
                console.warn(`${store.logName}: a warning of the public alert server could not be read:`, String(error.message || error));
                keep(null);
            }
        }, () => keep(false));
    }

    function fetchWarningText(capUrl: string): void {
        const key = textKey(capUrl);
        const wanted = language;

        if (capUrl === "" || warningTexts[key] !== undefined) {
            return;
        }

        // A new object each time, so that everything bound to the texts notices. One that cannot be
        // had is kept empty, so that the warning is told without it rather than not at all.
        const keep = found => {
            const texts = Object.assign({}, store.warningTexts);

            texts[key] = found;
            store.warningTexts = texts;
        };

        fetchText(capUrl, documentFresh, text => keep(Alerts.parseCap(text, wanted)), () => keep({ headline: "", description: "" }));
    }

    onActiveChanged: Qt.callLater(store.load, false)
    // Latitude and longitude change one after the other: callLater sees the place once both have.
    onRequestUrlChanged: Qt.callLater(store.placeChanged)
    // The warnings and the air of another place, or in another language, are not shown in the meantime.
    onAlertsKeyChanged: {
        feedChecked = false;
        publicChecked = false;
        countyWarnings = [];
        immediateWarnings = [];
        publicWarnings = [];
        Qt.callLater(store.refreshAlerts);
    }
    // Asked for with the forecast of the place: here, only what was shown for the place before is let go.
    onAirQualityUrlChanged: airQuality = null
    onAirQualityEnabledChanged: Qt.callLater(store.refreshAirQuality)
    onQuartersEnabledChanged: Qt.callLater(store.refreshQuarters)
    Component.onCompleted: Qt.callLater(store.load, false)
}
