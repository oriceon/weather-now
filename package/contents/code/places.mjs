// The other places kept besides the one on show, to switch to from the header.

/** A place is the same place when its name and its position to about a kilometre are. */
export function samePlace(first, second) {
    const near = (a, b) => Math.abs(a - b) < 0.01;

    return first.name === second.name && near(first.latitude, second.latitude) && near(first.longitude, second.longitude);
}

/** The settings keep each place as JSON; one that cannot be read is skipped. */
export function parsePlaces(list) {
    const places = [];

    for (const text of list || []) {
        try {
            const place = JSON.parse(String(text));

            if (place && typeof place.name === 'string' && typeof place.latitude === 'number' && typeof place.longitude === 'number') {
                places.push({ name: place.name, latitude: place.latitude, longitude: place.longitude, region: place.region || '', countryCode: place.countryCode || '' });
            }
        } catch (error) {
            // Skipped: a hand-edited setting should not take the others with it.
        }
    }

    return places;
}

export function serializePlaces(places) {
    return places.map((place) => JSON.stringify({ name: place.name, latitude: place.latitude, longitude: place.longitude, region: place.region, countryCode: place.countryCode }));
}

/** The kept places with `place` added at the end, unless it is kept already or is the one on show. */
export function addPlace(places, place, current) {
    if (places.some((kept) => samePlace(kept, place)) || (current && samePlace(current, place))) {
        return places;
    }

    return places.concat([place]);
}

export function removePlace(places, place) {
    return places.filter((kept) => !samePlace(kept, place));
}

/**
 * The kept places once `chosen` is put on show: the place that was on show takes its spot in the
 * list, so that switching back and forth keeps the order.
 */
export function switchPlaces(places, chosen, current) {
    return places
        .map((kept) => (samePlace(kept, chosen) ? current : kept))
        .filter((kept) => kept && kept.name);
}

/** The place on show and the kept ones in one ring, by name, as the dots under the name show them. */
export function placeRing(current, places) {
    return [current].concat(places).sort((first, second) => first.name.localeCompare(second.name) || first.latitude - second.latitude);
}

/** The place `step` places away from the one on show, round the ring; null without other places. */
export function neighbourPlace(current, places, step) {
    if (places.length === 0) {
        return null;
    }

    const ring = placeRing(current, places);
    const here = ring.findIndex((place) => samePlace(place, current));

    return ring[((here + step) % ring.length + ring.length) % ring.length];
}
