pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/activities.mjs" as Activities
import "../code/alerts.mjs" as Alerts
import "../code/aurora.mjs" as Aurora
import "../code/dates.mjs" as Dates
import "../code/details.mjs" as Details
import "../code/format.mjs" as Format
import "../code/i18n.mjs" as I18n
import "../code/places.mjs" as Places
import "../code/rain.mjs" as Rain
import "../code/temperature.mjs" as Temperature
import "../code/watch.mjs" as Watch
import "../code/wmo.mjs" as Wmo

PlasmoidItem {
    id: root

    /** The language of the Plasma interface, unless one is chosen in the settings. */
    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    readonly property real fontScale: Plasmoid.configuration.fontScale / 100
    readonly property WidgetFonts widgetFonts: WidgetFonts {}
    /** Inter, which comes with the widget, unless another font is chosen in the settings; empty for the theme's. */
    readonly property string fontFamily: Plasmoid.configuration.fontFamily !== "" ? Plasmoid.configuration.fontFamily : widgetFonts.text
    /** A new widget has no place yet; it asks for one before anything else. */
    readonly property bool located: Plasmoid.configuration.locationName !== ""
    readonly property string conditionText: store.ready ? I18n.t(language, Wmo.conditionKey(store.forecast.current.conditionCode)) : ""
    readonly property var warningTitles: store.ready
        ? Alerts.activeAlerts(store.alerts, store.forecast.current.time).map(warning => [Alerts.alertTitle(warning, language), warning.issuer].filter(part => part !== "").join(" · "))
        : []
    /** Plasma's own speed of animations, at "Instant", stops the widget too, whatever its settings say. */
    readonly property string animations: Kirigami.Units.longDuration > 0 ? Plasmoid.configuration.animations : "off"
    /** The aurora tonight, see auroraOutlook() in code/aurora.mjs; null without a Kp for the night. */
    readonly property var aurora: {
        if (!store.ready || store.kpForecast.length === 0) {
            return null;
        }

        const daily = store.forecast.daily;
        const today = daily.findIndex(day => day.date === store.forecast.today.date);
        const night = Aurora.tonight(store.forecast.current.time, daily[today], daily[today + 1], store.forecast.utcOffsetSeconds);

        return Aurora.auroraOutlook(store.kpForecast, { latitude: Plasmoid.configuration.latitude, longitude: Plasmoid.configuration.longitude }, night);
    }

    // On the desktop the widget is always shown whole, and Plasma keeps it at least as big as that
    // needs; in a panel it is the icon that opens it. With switch sizes, a desktop widget smaller
    // than them, even one at its own minimum, which was the same size, turned into an oversized icon.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical ? compactRepresentation : fullRepresentation

    // The logo, as in Add Widgets: Plasma shows it in the notification of a removed widget. The panel draws the weather itself.
    Plasmoid.icon: Qt.resolvedUrl("../icons/weather-now.png").toString()
    // On the desktop the frame of the Plasma theme, unless the widget draws its own black one or none at all.
    Plasmoid.backgroundHints: Plasmoid.configuration.background === "theme" ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground
    // The text stays for whatever reads it instead of the tooltip, such as a screen reader.
    toolTipMainText: located ? Plasmoid.configuration.locationName : Plasmoid.title
    toolTipSubText: {
        if (!located) {
            return I18n.t(language, "state.noLocation");
        }

        return store.ready
            ? [`${Format.temperatureUnit(store.forecast.current.temperature, Plasmoid.configuration.temperatureUnit)} · ${conditionText}`].concat(warningTitles).join("\n")
            : I18n.t(language, store.failed ? "state.error" : "state.loading");
    }
    // In a panel, the weather now, the next hours and days, and the warnings, at a glance. Until a
    // place is chosen, none: an empty one took the place of the text, which says to choose one.
    toolTipItem: located ? toolTipLoader : null
    readonly property Loader toolTipLoader: Loader {
        Layout.minimumWidth: item ? item.implicitWidth : 0
        Layout.maximumWidth: item ? item.implicitWidth : 0
        Layout.minimumHeight: item ? item.implicitHeight : 0
        Layout.maximumHeight: item ? item.implicitHeight : 0

        active: root.located

        sourceComponent: ToolTipContent {
            forecast: store.ready ? store.forecast : null
            alerts: store.alerts
            language: root.language
            locationName: Plasmoid.configuration.locationName
            statusText: root.toolTipSubText
            iconSet: Plasmoid.configuration.iconSet
            fontFamily: root.fontFamily
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: I18n.t(root.language, "header.refresh")
            icon.name: "view-refresh"
            onTriggered: store.refresh()
        }
    ]

    /** What the notifications already told of, see code/watch.mjs; the days of the frost and of the summary told outlive a restart. */
    property var watchState: Object.assign({}, Watch.STARTING, { frostTold: Plasmoid.configuration.frostTold, morningTold: Plasmoid.configuration.morningTold })
    /** The other places kept, to switch to from the header. */
    readonly property var savedPlaces: Places.parsePlaces(Plasmoid.configuration.savedPlaces)
    readonly property string placeKey: `${Plasmoid.configuration.latitude}|${Plasmoid.configuration.longitude}`
    /** The tiles of the Details tab, in the order they were dragged into, those turned off included. */
    readonly property var detailsOrder: Details.tileOrder(Plasmoid.configuration.detailsOrder)
    /** The activities of their tile, as chosen; those of a new widget while none is. */
    readonly property var activities: {
        const chosen = Activities.ACTIVITIES.filter(activity => Plasmoid.configuration.activities.indexOf(activity) !== -1);

        return chosen.length > 0 ? chosen : Activities.DEFAULT_ACTIVITIES;
    }
    /** The ids of the tiles turned off, as an array. */
    readonly property var hiddenTiles: Details.TILES.filter(tile => Plasmoid.configuration.hiddenTiles.indexOf(tile) !== -1)

    // Another place: its warnings are not news, they were only never seen. The frost is told once an evening, whatever the place.
    onPlaceKeyChanged: watchState = Object.assign({}, Watch.STARTING, { frostTold: watchState.frostTold, morningTold: watchState.morningTold })

    /** Puts a kept place on show; the place that was on show takes its spot among the kept ones. */
    function switchPlace(place: var): void {
        const current = { name: Plasmoid.configuration.locationName, latitude: Plasmoid.configuration.latitude, longitude: Plasmoid.configuration.longitude, region: Plasmoid.configuration.region, countryCode: Plasmoid.configuration.countryCode };

        Plasmoid.configuration.savedPlaces = Places.serializePlaces(Places.switchPlaces(savedPlaces, place, current));
        usePlace(place);
    }

    /** Looks at the forecast and the warnings on hand for something worth a desktop notification. */
    function watch(): void {
        if (!store.ready) {
            return;
        }

        const forecast = store.forecast;
        const unit = Plasmoid.configuration.temperatureUnit;
        const coldest = Watch.coldestOfNight(forecast.hourly);
        // The clock of the place, which goes on between the answers of the forecast.
        const now = Dates.localNow(forecast.utcOffsetSeconds);

        // Woken after a night asleep, the computer still has the forecast of the evening until the
        // next one comes, a minute later, and while Open-Meteo fails it keeps an old one: the morning,
        // the rain and the frost are not told from it, the warnings, which come apart, still are.
        const stale = Date.now() - store.updatedAt.getTime() > (store.everyMinutes + 5) * 60 * 1000 || forecast.today.date !== Dates.dateOf(now);
        const result = Watch.watch(watchState, {
            now: now,
            alerts: store.alertsChecked ? Alerts.activeAlerts(store.alerts, now) : null,
            minutely: stale ? [] : store.minutely,
            hourly: forecast.hourly,
            frostCelsius: coldest !== null && !stale ? Temperature.toCelsius(coldest, unit) : null,
        }, {
            notifyAlerts: Plasmoid.configuration.notifyAlerts,
            notifyRain: Plasmoid.configuration.notifyRain,
            notifyFrost: Plasmoid.configuration.notifyFrost,
            notifyMorning: Plasmoid.configuration.notifyMorning && !stale,
            morningTime: Plasmoid.configuration.morningTime,
        });
        const place = Plasmoid.configuration.locationName;

        watchState = result.state;

        if (result.state.frostTold !== Plasmoid.configuration.frostTold) {
            Plasmoid.configuration.frostTold = result.state.frostTold;
        }

        if (result.state.morningTold !== Plasmoid.configuration.morningTold) {
            Plasmoid.configuration.morningTold = result.state.morningTold;
        }

        if (notifierLoader.item === null) {
            return;
        }

        result.events.forEach(event => {
            if (event.kind === "alert") {
                const details = [Alerts.alertInterval(event.alert, forecast.current.time, language), event.alert.headline || event.alert.description].filter(part => part !== "");

                notifierLoader.item.send(`${place}: ${Alerts.alertTitle(event.alert, language)}`, details.join(". "));
            } else if (event.kind === "morning") {
                notifierLoader.item.send(I18n.t(language, "notify.morningTitle", { place: place, condition: conditionText }), morningSummary());
            } else if (event.kind === "rain") {
                notifierLoader.item.send(I18n.t(language, event.snow ? "notify.snowTitle" : "notify.rainTitle", { place: place }), I18n.t(language, event.snow ? "notify.snowText" : "notify.rainText", { time: event.at }));
            } else {
                notifierLoader.item.send(I18n.t(language, "notify.frostTitle", { place: place }), I18n.t(language, "notify.frostText", { temperature: Format.temperatureUnit(coldest, unit) }));
            }
        });
    }

    /** The summary of the day, sentence after sentence, without the parts left out in the settings. */
    function morningSummary(): string {
        const forecast = store.forecast;
        const today = forecast.today;
        const left = Plasmoid.configuration.morningParts;
        const wanted = part => left.indexOf(part) === -1;
        const sentences = [];

        if (wanted("temperatures")) {
            sentences.push(I18n.t(language, "notify.morningTemperatures", { min: Format.temperature(today.temperatureMin), max: Format.temperature(today.temperatureMax) }));
        }

        if (wanted("rain")) {
            sentences.push(`${Rain.rainSentence(Rain.rainSummary(forecast.hourly), forecast.current.time, language)}.`);
        }

        if (wanted("uv") && today.uvIndexMax >= 3) {
            sentences.push(I18n.t(language, "notify.morningUv", { level: I18n.t(language, Format.uvKey(today.uvIndexMax)).toLowerCase(), index: Format.number(today.uvIndexMax, 0, language) }));
        }

        if (wanted("alerts")) {
            warningTitles.forEach(title => sentences.push(`${title}.`));
        }

        if (wanted("pollen") && store.airQuality !== null && store.airQuality.pollen !== null) {
            const pollen = store.airQuality.pollen;

            sentences.push(`${Format.sentenceCase(I18n.t(language, `pollen.${pollen.level}`, { name: I18n.t(language, `pollen.name.${pollen.name}`) }))}.`);
        }

        if (wanted("yesterday")) {
            const compared = Temperature.comparedWithYesterday(forecast.daily, today.date);

            if (compared !== null) {
                sentences.push(`${I18n.t(language, `today.${compared.kind}`, { difference: `${compared.difference}°` })}.`);
            }
        }

        return sentences.join(" ");
    }

    /** Keeps the place picked at the first-run prompt; `place` is one of parseGeocode() in code/openmeteo.mjs. */
    function usePlace(place: var): void {
        Plasmoid.configuration.latitude = place.latitude;
        Plasmoid.configuration.longitude = place.longitude;
        Plasmoid.configuration.region = place.region;
        Plasmoid.configuration.countryCode = place.countryCode;
        // Last, because the name is what tells the widget it has a place.
        Plasmoid.configuration.locationName = place.name;
    }

    compactRepresentation: CompactRepresentation {
        conditionCode: store.ready ? store.forecast.current.conditionCode : undefined
        isDay: store.ready ? store.forecast.current.isDay : true
        iconSet: Plasmoid.configuration.iconSet
        temperatureText: store.ready ? Format.temperature(store.forecast.current.temperature) : ""
        fontFamily: root.fontFamily
        rainStart: store.ready && Plasmoid.configuration.showRainInPanel ? Rain.upcomingStart(Rain.rainSummary(store.forecast.hourly), store.forecast.current.time) : ""

        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        forecast: store.forecast
        alerts: store.alerts
        airQuality: store.airQuality
        aurora: root.aurora
        minutely: store.minutely
        detailsOrder: Details.shownTiles(root.detailsOrder, root.hiddenTiles)
        located: root.located
        ready: store.ready
        loading: store.loading
        failed: store.failed
        failureText: !store.failed ? ""
            : store.failureStatus === 0 ? I18n.t(root.language, "state.offline")
            : store.failureStatus === 429 ? I18n.t(root.language, "state.refused")
            : store.failureStatus === 200 ? I18n.t(root.language, "state.badAnswer")
            : I18n.t(root.language, "state.serverError", { code: store.failureStatus })
        updatedAt: store.updatedAt
        language: root.language
        locationName: Plasmoid.configuration.locationName
        windUnit: Plasmoid.configuration.windUnit
        precipitationUnit: Plasmoid.configuration.precipitationUnit
        temperatureUnit: Plasmoid.configuration.temperatureUnit
        firstDayOfWeek: Dates.resolveFirstDay(Plasmoid.configuration.firstDayOfWeek, Qt.locale().firstDayOfWeek)
        animations: root.animations
        hiddenTabs: Plasmoid.configuration.hiddenTabs
        fontScale: root.fontScale
        fontFamily: root.fontFamily
        // Its display cut, for the big numbers, goes with Inter only.
        displayFontFamily: Plasmoid.configuration.fontFamily === "" ? root.widgetFonts.display : ""
        iconSet: Plasmoid.configuration.iconSet
        background: Plasmoid.configuration.background
        landscape: Plasmoid.configuration.landscape
        landscapeHeight: Plasmoid.configuration.landscapeHeight
        todayGlass: Plasmoid.configuration.todayGlass
        // As an array: the setting is a sequence of Qt.
        todayParts: ["clock", "hours", "conditions", "insights", "rain", "yesterday"].filter(part => Plasmoid.configuration.todayParts.indexOf(part) !== -1)
        latitude: Plasmoid.configuration.latitude
        longitude: Plasmoid.configuration.longitude
        activities: root.activities
        backgroundTransparency: Plasmoid.configuration.backgroundTransparency

        onRefreshRequested: store.refresh()
        places: root.savedPlaces

        onPlaceChosen: place => root.usePlace(place)
        onPlaceSwitched: place => root.switchPlace(place)
        // Kept only when it differs from the order of a new widget, which can then change in a later version.
        onTilesReordered: shown => {
            const order = Details.withShownOrder(root.detailsOrder, shown);

            Plasmoid.configuration.detailsOrder = Details.isDefaultOrder(order) ? [] : order;
        }
        onTileHidden: tile => Plasmoid.configuration.hiddenTiles = root.hiddenTiles.concat([tile])
    }

    WeatherStore {
        id: store

        active: root.located
        logName: Plasmoid.pluginName
        latitude: Plasmoid.configuration.latitude
        longitude: Plasmoid.configuration.longitude
        temperatureUnit: Plasmoid.configuration.temperatureUnit
        windUnit: Plasmoid.configuration.windUnit
        refreshMinutes: Plasmoid.configuration.refreshMinutes
        countryCode: Plasmoid.configuration.countryCode
        region: Plasmoid.configuration.region
        locality: Plasmoid.configuration.locationName
        alertsEnabled: Plasmoid.configuration.showAlerts
        airQualityEnabled: Plasmoid.configuration.showAirQuality
        quartersEnabled: Plasmoid.configuration.notifyRain
        nowcastingEnabled: Plasmoid.configuration.showNowcasting
        language: root.language
    }

    // Loaded on its own: without the notification module, only the notifications are lost.
    Loader {
        id: notifierLoader

        active: Plasmoid.configuration.notifyAlerts || Plasmoid.configuration.notifyRain || Plasmoid.configuration.notifyFrost || Plasmoid.configuration.notifyMorning
        source: "Notifier.qml"
    }

    // The summary of the morning and the frost of the evening go by the clock, not only by the answers of the forecast.
    Timer {
        interval: 60 * 1000
        repeat: true
        running: store.ready && (Plasmoid.configuration.notifyMorning || Plasmoid.configuration.notifyFrost)

        onTriggered: root.watch()
    }

    Connections {
        target: store

        function onForecastChanged(): void {
            root.watch();
        }

        function onAlertsChanged(): void {
            root.watch();
        }

        function onAlertsCheckedChanged(): void {
            root.watch();
        }

        function onMinutelyChanged(): void {
            root.watch();
        }
    }
}
