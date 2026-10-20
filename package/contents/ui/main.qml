pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/alerts.mjs" as Alerts
import "../code/dates.mjs" as Dates
import "../code/format.mjs" as Format
import "../code/i18n.mjs" as I18n
import "../code/wmo.mjs" as Wmo

PlasmoidItem {
    id: root

    /** The language of the Plasma interface, unless one is chosen in the settings. */
    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    readonly property real fontScale: Plasmoid.configuration.fontScale / 100
    /** A new widget has no place yet; it asks for one before anything else. */
    readonly property bool located: Plasmoid.configuration.locationName !== ""
    readonly property string conditionText: store.ready ? I18n.t(language, Wmo.conditionKey(store.forecast.current.conditionCode)) : ""
    readonly property var warningTitles: store.ready
        ? Alerts.activeAlerts(store.alerts, store.forecast.current.time).map(warning => [Alerts.alertTitle(warning, language), warning.issuer].filter(part => part !== "").join(" · "))
        : []

    // On the desktop the widget is always shown whole, and Plasma keeps it at least as big as that
    // needs; in a panel it is the icon that opens it. With switch sizes, a desktop widget smaller
    // than them, even one at its own minimum, which was the same size, turned into an oversized icon.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical ? compactRepresentation : fullRepresentation

    // The logo, as in Add Widgets: Plasma shows it in the notification of a removed widget. The panel draws the weather itself.
    Plasmoid.icon: Qt.resolvedUrl("../icons/weather-now.png").toString()
    // On the desktop the frame of the Plasma theme, unless the widget draws its own black one or none at all.
    Plasmoid.backgroundHints: Plasmoid.configuration.background === "theme" ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground
    toolTipMainText: located ? Plasmoid.configuration.locationName : Plasmoid.title
    toolTipSubText: {
        if (!located) {
            return I18n.t(language, "state.noLocation");
        }

        return store.ready
            ? [`${Format.temperatureUnit(store.forecast.current.temperature, Plasmoid.configuration.temperatureUnit)} · ${conditionText}`].concat(warningTitles).join("\n")
            : I18n.t(language, store.failed ? "state.error" : "state.loading");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: I18n.t(root.language, "header.refresh")
            icon.name: "view-refresh"
            onTriggered: store.refresh()
        }
    ]

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

        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        forecast: store.forecast
        alerts: store.alerts
        located: root.located
        ready: store.ready
        loading: store.loading
        failed: store.failed
        updatedAt: store.updatedAt
        language: root.language
        locationName: Plasmoid.configuration.locationName
        windUnit: Plasmoid.configuration.windUnit
        firstDayOfWeek: Dates.resolveFirstDay(Plasmoid.configuration.firstDayOfWeek, Qt.locale().firstDayOfWeek)
        animations: Plasmoid.configuration.animations
        hiddenTabs: Plasmoid.configuration.hiddenTabs
        fontScale: root.fontScale
        fontFamily: Plasmoid.configuration.fontFamily
        iconSet: Plasmoid.configuration.iconSet
        background: Plasmoid.configuration.background
        backgroundTransparency: Plasmoid.configuration.backgroundTransparency

        onRefreshRequested: store.refresh()
        onPlaceChosen: place => root.usePlace(place)
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
        nowcastingEnabled: Plasmoid.configuration.showNowcasting
        language: root.language
    }
}
