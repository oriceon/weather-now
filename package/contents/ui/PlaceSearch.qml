import QtQuick

import "../code/openmeteo.mjs" as OpenMeteo

/** Looks places up by name, for the first-run prompt and for the settings. */
QtObject {
    id: lookup

    /** Places found by the last search, see parseGeocode() in code/openmeteo.mjs. */
    property var places: []
    /** Translation key of what there is to say about the search, empty when there is nothing. */
    property string message: ""
    property int serial: 0

    /** `language` is the one the names of the places are wanted in. */
    function search(text: string, language: string): void {
        const current = ++serial;
        const request = new XMLHttpRequest();

        places = [];
        message = "config.searching";

        request.onreadystatechange = () => {
            // A newer search makes this answer obsolete.
            if (request.readyState !== XMLHttpRequest.DONE || current !== lookup.serial) {
                return;
            }

            try {
                lookup.places = OpenMeteo.parseGeocode(JSON.parse(request.responseText));
                lookup.message = lookup.places.length > 0 ? "" : "config.noResults";
            } catch (error) {
                lookup.message = "config.searchFailed";
            }
        };

        request.open("GET", OpenMeteo.geocodeUrl(text.trim(), language));
        request.send();
    }
}
