pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../code/cache.mjs" as Cache
import "../code/dates.mjs" as Dates
import "../code/i18n.mjs" as I18n
import "../code/openmeteo.mjs" as OpenMeteo
import "../code/wallpaper.mjs" as Wallpaper
import "scene" as Scenery

/**
 * Weather Now as the wallpaper: the animated sky of the widget across the screen, with the weather of
 * the place chosen in its settings, asked of Open-Meteo every quarter of an hour; in between, the sun
 * and the moon move on with the clock. Until a place is chosen, a calm sky. It stands still while a
 * window fills the screen, and when its settings, or Plasma's own speed of animations, ask for a
 * still picture.
 */
WallpaperItem {
    id: wallpaper

    readonly property bool located: configuration.locationName !== ""
    readonly property string placeKey: `${configuration.latitude}|${configuration.longitude}`
    readonly property string language: I18n.resolveLanguage("auto", Qt.locale().uiLanguages)
    /** The last answer of Open-Meteo, see parseForecast() in code/openmeteo.mjs; null before the first. */
    property var forecast: null
    /** The wall-clock time at the place, or of the computer without one, every minute. */
    property string now: ""
    /** What the scene shows: the last answer at the time of the clock, or a calm sky. */
    readonly property var shown: forecast !== null && now !== ""
        ? Wallpaper.atTheClock(forecast, now)
        : Wallpaper.calmForecast(now !== "" ? now : Dates.localNow(-new Date().getTimezoneOffset() * 60))
    /** Plasma's own speed of animations, at "Instant", stops the wallpaper too. */
    readonly property string quality: Kirigami.Units.longDuration > 0 ? configuration.animations : "off"
    readonly property bool covered: configuration.pauseWhenCovered && coverage.item !== null && coverage.item.covered
    /** When the forecast on show was fetched, in milliseconds like Date.now(); 0 before the first. */
    property double loadedAt: 0
    /** When the last request went, and whether it is under way; one that has not answered in a minute is given up. */
    property double askedAt: 0
    property bool asking: false
    /** Failures in a row since the last answer, and whether Open-Meteo said it is asked too often. */
    property int failures: 0
    property bool refused: false
    /**
     * After a failure, the next try: 15 s, 30 s, 1 min… at most a quarter of an hour, as at login,
     * when the network may not be up yet; an hour after a refusal for too many requests.
     */
    readonly property int retrySeconds: refused ? 3600 : Math.min(15 * 60, 15 * Math.pow(2, Math.max(0, failures - 1)))

    /**
     * The forecast of the place, from code/cache.mjs while it is fresh there: the wallpaper of each
     * screen, and of the lock screen, asks for the same.
     */
    function refresh(): void {
        if (!located || (asking && Date.now() - askedAt < 60 * 1000)) {
            return;
        }

        const asked = placeKey;
        const url = OpenMeteo.sceneUrl({ latitude: configuration.latitude, longitude: configuration.longitude });
        const kept = Cache.remembered(url, 10 * 60 * 1000);

        if (kept !== undefined) {
            receive(url, kept);

            return;
        }

        const request = new XMLHttpRequest();

        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            wallpaper.asking = false;

            // An answer for a place no longer chosen is dropped.
            if (asked !== wallpaper.placeKey) {
                return;
            }

            if (request.status === 200) {
                Cache.remember(url, request.responseText);
                wallpaper.receive(url, request.responseText);
            } else {
                wallpaper.failures++;
                wallpaper.refused = request.status === 429;
            }
        };

        asking = true;
        askedAt = Date.now();
        request.open("GET", url);
        request.send();
    }

    function receive(url: string, text: string): void {
        try {
            forecast = OpenMeteo.parseForecast(JSON.parse(text));
            loadedAt = Cache.fetchedAt(url) || Date.now();
            failures = 0;
            refused = false;
            tick();
        } catch (error) {
            failures++;
            console.warn("Weather Now wallpaper: the forecast could not be read:", String(error.message || error));
        }
    }

    function tick(): void {
        now = Dates.localNow(forecast !== null ? forecast.utcOffsetSeconds : -new Date().getTimezoneOffset() * 60);
    }

    onPlaceKeyChanged: {
        forecast = null;
        loadedAt = 0;
        // The request for the place before is dropped when it answers: this one does not wait for it.
        asking = false;
        failures = 0;
        refused = false;
        tick();
        soon.restart();
    }
    Component.onCompleted: {
        tick();
        soon.restart();
    }

    // The settings arrive one by one: a single request once they have.
    Timer {
        id: soon

        interval: 200

        onTriggered: wallpaper.refresh()
    }

    Timer {
        // Every quarter of an hour, as Open-Meteo updates the conditions now; after a failure, as retrySeconds says.
        interval: (wallpaper.failures > 0 ? wallpaper.retrySeconds : 15 * 60) * 1000
        repeat: true
        running: wallpaper.located

        onTriggered: wallpaper.refresh()
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: true

        onTriggered: {
            wallpaper.tick();

            // The timers of Qt do not count the time the computer sleeps; the clock on the wall does:
            // woken in the morning, the sky of the evening stayed for up to a quarter of an hour.
            // Counted from the last try, so that the pause after a failure holds.
            const since = Date.now() - Math.max(wallpaper.loadedAt, wallpaper.askedAt);
            const pause = (wallpaper.failures > 0 ? wallpaper.retrySeconds : 15 * 60) * 1000;

            if (wallpaper.located && since >= pause + 60 * 1000) {
                wallpaper.refresh();
            }
        }
    }

    Scenery.WeatherScene {
        anchors.fill: parent
        current: wallpaper.shown.current
        today: wallpaper.shown.today
        windUnit: "kmh"
        temperatureUnit: "celsius"
        quality: wallpaper.quality
        landscape: wallpaper.configuration.landscape
        landscapeHeight: wallpaper.configuration.landscapeHeight
        latitude: wallpaper.located ? wallpaper.configuration.latitude : 45
        running: wallpaper.visible && !wallpaper.covered
    }

    // Until a place is chosen, a word on where to choose it.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        visible: !wallpaper.located
        color: "#ffffff"
        style: Text.Raised
        styleColor: "#73000000"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
        text: `Weather Now · ${I18n.t(wallpaper.language, "wallpaper.choosePlace")}`
    }

    // Apart, so that where the task manager of Plasma is missing, as on the lock screen, the
    // wallpaper simply never stops.
    Loader {
        id: coverage

        active: wallpaper.configuration.pauseWhenCovered
        source: "Coverage.qml"
    }
}
