import QtQuick
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

/**
 * A page of the settings dialog. Plasma hands every setting of config/main.xml, and its default, to
 * every page, and writes them all back from the page on Apply. A page without one of them gets a
 * line in the journal. Each page changes the ones it shows; the others are taken afresh from the
 * widget just before, see saveConfig().
 */
KCM.SimpleKCM {
    id: page

    /** Each setting as the page was given it, as JSON, by name. */
    property var given: ({})

    /**
     * Called by Plasma before it writes the settings back from this page. A setting the page did not
     * change is taken from the widget, which may have changed it while the dialog was open: the place
     * switched from the title, the tiles moved, or the day the summary of the morning was sent, which
     * went out again after a restart when Apply put back the day before.
     */
    function saveConfig(): void {
        try {
            Object.keys(given).forEach(key => {
                if (JSON.stringify(page[`cfg_${key}`]) === given[key]) {
                    page[`cfg_${key}`] = Plasmoid.configuration[key];
                }
            });
        } catch (error) {
            // Without the settings of the widget at hand, the page writes back what it was given, as before.
            console.warn("Weather Now: the settings could not be taken afresh:", String(error.message || error));
        }

        // What is written now is what the next Apply, the dialog left open, compares with: else a setting
        // put back as it was when the dialog opened looked unchanged, and the one applied stayed.
        remember();
    }

    function remember(): void {
        const snapshot = {};

        try {
            Plasmoid.configuration.keys().forEach(key => {
                if (page[`cfg_${key}`] !== undefined) {
                    snapshot[key] = JSON.stringify(page[`cfg_${key}`]);
                }
            });
        } catch (error) {
            console.warn("Weather Now: the settings of the widget are not at hand:", String(error.message || error));
        }

        given = snapshot;
    }

    // A moment later, once the settings have been handed to the page however its host does it.
    Component.onCompleted: Qt.callLater(page.remember)

    property string cfg_locationName
    property string cfg_locationNameDefault
    property real cfg_latitude
    property real cfg_latitudeDefault
    property real cfg_longitude
    property real cfg_longitudeDefault
    property string cfg_region
    property string cfg_regionDefault
    property string cfg_countryCode
    property string cfg_countryCodeDefault
    property bool cfg_showAlerts
    property bool cfg_showAlertsDefault
    property bool cfg_showAirQuality
    property bool cfg_showAirQualityDefault
    property bool cfg_notifyAlerts
    property bool cfg_notifyAlertsDefault
    property bool cfg_notifyRain
    property bool cfg_notifyRainDefault
    property bool cfg_notifyFrost
    property bool cfg_notifyFrostDefault
    property bool cfg_showNowcasting
    property bool cfg_showNowcastingDefault
    property string cfg_language
    property string cfg_languageDefault
    property int cfg_firstDayOfWeek
    property int cfg_firstDayOfWeekDefault
    property int cfg_fontScale
    property int cfg_fontScaleDefault
    property string cfg_fontFamily
    property string cfg_fontFamilyDefault
    property string cfg_background
    property string cfg_backgroundDefault
    property int cfg_backgroundTransparency
    property int cfg_backgroundTransparencyDefault
    property bool cfg_showRainInPanel
    property bool cfg_showRainInPanelDefault
    property string cfg_iconSet
    property string cfg_iconSetDefault
    property string cfg_animations
    property string cfg_animationsDefault
    property var cfg_savedPlaces: []
    property var cfg_savedPlacesDefault: []
    property bool cfg_notifyMorning
    property bool cfg_notifyMorningDefault
    property string cfg_morningTime
    property string cfg_morningTimeDefault
    property var cfg_morningParts: []
    property var cfg_morningPartsDefault: []
    property string cfg_morningTold
    property string cfg_morningToldDefault
    property var cfg_todayParts: []
    property var cfg_todayPartsDefault: []
    property int cfg_todayGlass
    property int cfg_todayGlassDefault
    property string cfg_todayBackground
    property string cfg_todayBackgroundDefault
    property string cfg_landscape
    property string cfg_landscapeDefault
    property int cfg_landscapeHeight
    property int cfg_landscapeHeightDefault
    property var cfg_activities: []
    property var cfg_activitiesDefault: []
    property string cfg_detailsBoxes
    property string cfg_detailsBoxesDefault
    property int cfg_detailsGlass
    property int cfg_detailsGlassDefault
    property var cfg_detailsOrder: []
    property var cfg_detailsOrderDefault: []
    property var cfg_hiddenTiles: []
    property var cfg_hiddenTilesDefault: []
    property string cfg_frostTold
    property string cfg_frostToldDefault
    property var cfg_hiddenTabs: []
    property var cfg_hiddenTabsDefault: []
    property string cfg_temperatureUnit
    property string cfg_temperatureUnitDefault
    property string cfg_precipitationUnit
    property string cfg_precipitationUnitDefault
    property string cfg_windUnit
    property string cfg_windUnitDefault
    property int cfg_refreshMinutes
    property int cfg_refreshMinutesDefault
}
