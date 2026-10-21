import QtQuick

import "../code/openmeteo.mjs" as OpenMeteo
import "../code/search.mjs" as Search

/**
 * Looks places up by name, for the first-run prompt and for the settings: in turn, as searchPlan()
 * of code/search.mjs has it, until one of the lookups finds something.
 */
QtObject {
    id: lookup

    /** Places found by the last search, see parseGeocode() in code/openmeteo.mjs. */
    property var places: []
    /** Translation key of what there is to say about the search, empty when there is nothing. */
    property string message: ""
    property int serial: 0
    /** The lookup under way, which the watchdog gives up on after a while. */
    property var pending: null
    readonly property Timer watchdog: Timer {
        interval: 10000

        onTriggered: {
            if (lookup.pending !== null) {
                lookup.pending.abort();
            }
        }
    }

    /** Lets go of the places found and of a search under way, as when the field is emptied. */
    function clear(): void {
        // First, so that the answer of the request given up is not taken.
        serial++;
        watchdog.stop();

        if (pending !== null) {
            pending.abort();
            pending = null;
        }

        places = [];
        message = "";
    }

    /** `language` is the one the names of the places are wanted in. */
    function search(text: string, language: string): void {
        const current = ++serial;
        const plan = Search.searchPlan(text.trim());

        places = [];
        message = "config.searching";
        ask(plan, 0, language, current);
    }

    function ask(plan: var, step: int, language: string, current: int): void {
        if (step >= plan.queries.length) {
            message = "config.noResults";

            return;
        }

        const query = plan.queries[step];
        const request = new XMLHttpRequest();

        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            if (lookup.pending === request) {
                lookup.watchdog.stop();
                lookup.pending = null;
            }

            // A newer search makes this answer obsolete.
            if (current !== lookup.serial) {
                return;
            }

            try {
                if (request.status !== 200) {
                    throw new Error(`HTTP ${request.status} ${request.statusText}`);
                }

                const found = Search.placesFound(OpenMeteo.parseGeocode(JSON.parse(request.responseText)), query, plan);

                if (found.length > 0 && language !== "ro" && found.some(place => place.countryCode === "RO")) {
                    lookup.askRomanian(found, query, current);
                } else if (found.length > 0) {
                    lookup.places = found;
                    lookup.message = "";
                } else {
                    lookup.ask(plan, step + 1, language, current);
                }
            } catch (error) {
                console.warn(`Weather Now: looking up "${query.name}" failed:`, String(error.message || error));
                lookup.message = "config.searchFailed";
            }
        };

        if (pending !== null) {
            pending.abort();
        }

        pending = request;
        watchdog.restart();
        request.open("GET", OpenMeteo.geocodeUrl(query.name, language, query.count));
        request.send();
    }

    /**
     * The counties of places in Romania, in Romanian, as MeteoAlarm names them: in another language
     * the geocoder names them otherwise, "Kreis Constanța", "Costanza", and their warnings were not
     * found. The places are shown once they have come, or as they were if they do not.
     */
    function askRomanian(found: var, query: var, current: int): void {
        const request = new XMLHttpRequest();

        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            if (lookup.pending === request) {
                lookup.watchdog.stop();
                lookup.pending = null;
            }

            if (current !== lookup.serial) {
                return;
            }

            let romanian = [];

            try {
                romanian = request.status === 200 ? OpenMeteo.parseGeocode(JSON.parse(request.responseText)) : [];
            } catch (error) {
                console.warn(`Weather Now: the counties of "${query.name}" could not be read in Romanian:`, String(error.message || error));
            }

            lookup.places = found.map(place => {
                const same = place.countryCode === "RO" ? romanian.find(other => other.latitude === place.latitude && other.longitude === place.longitude) : undefined;

                return same !== undefined && same.region !== "" ? Object.assign({}, place, { region: same.region }) : place;
            });
            lookup.message = "";
        };

        pending = request;
        watchdog.restart();
        request.open("GET", OpenMeteo.geocodeUrl(query.name, "ro", query.count));
        request.send();
    }
}
