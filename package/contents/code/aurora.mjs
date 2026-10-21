// The planetary K index of NOAA, and whether the aurora can be seen from the place tonight.

/** Three days of the 3-hour Kp, observed, estimated and predicted; public domain, about 7 KB. */
export const KP_FORECAST_URL = 'https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json';

/** The north pole of the Earth's magnetic dipole (IGRF, 2025). */
const POLE_LATITUDE = 80.8;
const POLE_LONGITUDE = -72.7;

/**
 * Where the aurora can be seen, by geomagnetic latitude, for a Kp: low on the horizon from
 * HORIZON_BASE − KP_STEP × Kp poleward; overhead from OVERHEAD_SHIFT degrees nearer the pole; in
 * the photos of a phone, which catch the faint red tops, from CAMERA_SHIFT degrees farther away.
 * A rough fit, on the dipole latitudes, of where it has been seen: Kp 5 in Edinburgh, 7 in Berlin,
 * 9 in Romania, the photos a Kp sooner. The dipole is off the real field by some degrees, the other
 * way in the south, hence a base of its own there, fitted on Tasmania (5 to 6) and Melbourne (7 to 8).
 */
const HORIZON_BASE = { north: 73, south: 66 };
const KP_STEP = 3;
const OVERHEAD_SHIFT = 5;
const CAMERA_SHIFT = 3;
const KP_MAXIMUM = 9;
/** NOAA's geomagnetic storms, G1 to G5, by the Kp they start at: 5- (4.67) for G1, a whole 9 for G5. */
const STORMS = [[9, 'G5'], [7.67, 'G4'], [6.67, 'G3'], [5.67, 'G2'], [4.67, 'G1']];
const SLOT_HOURS = 3;
/** Without a sunrise and a sunset to go by, as in a polar night, "tonight" is this many hours ahead. */
const NIGHT_HOURS = 12;

/** The Kp dial: quiet in green, then the storms, each in its colour. */
export const KP_SCALE = {
    minimum: 0,
    maximum: 9,
    segments: [[4.67, '#45d08f'], [5.67, '#f2cf3d'], [6.67, '#f9933a'], [7.67, '#ea4848'], [9, '#a855f7']],
};

const radians = (degrees) => degrees * Math.PI / 180;

/**
 * The 3-hour slots of the NOAA product, `{ start, kp }`, `start` in milliseconds since the epoch;
 * whatever cannot be read is left out.
 */
export function parseKpForecast(rows) {
    return (Array.isArray(rows) ? rows : [])
        .map((row) => ({ start: Date.parse(`${row && row.time_tag}Z`), kp: Number(row && row.kp) }))
        .filter((slot) => !Number.isNaN(slot.start) && !Number.isNaN(slot.kp));
}

/** The latitude of a place on the magnetic dipole, negative in the south. */
export function geomagneticLatitude(latitude, longitude) {
    const sine = Math.sin(radians(latitude)) * Math.sin(radians(POLE_LATITUDE))
        + Math.cos(radians(latitude)) * Math.cos(radians(POLE_LATITUDE)) * Math.cos(radians(longitude - POLE_LONGITUDE));

    return Math.asin(Math.max(-1, Math.min(1, sine))) * 180 / Math.PI;
}

/** The Kp it takes to see the aurora from a geomagnetic latitude: `{ overhead, horizon, camera }`. */
export function kpNeeded(magneticLatitude) {
    const latitude = Math.abs(magneticLatitude);
    const base = magneticLatitude >= 0 ? HORIZON_BASE.north : HORIZON_BASE.south;
    const needed = (shift) => Math.max(0, (base + shift - latitude) / KP_STEP);

    return { overhead: needed(OVERHEAD_SHIFT), horizon: needed(0), camera: needed(-CAMERA_SHIFT) };
}

/** G1 … G5 for a Kp, or '' below a storm. */
export function stormScale(kp) {
    const storm = STORMS.find(([from]) => kp >= from);

    return storm ? storm[1] : '';
}

/** Local time of the forecast, "2026-10-21T18:05", as milliseconds since the epoch. */
function instant(localIso, utcOffsetSeconds) {
    return Date.parse(`${localIso}Z`) - utcOffsetSeconds * 1000;
}

/**
 * The dark hours ahead, as `[start, end]` in milliseconds: the rest of the night, or the coming
 * one by day. `today` and `tomorrow` are entries of the `daily` of parseForecast().
 */
export function tonight(nowIso, today, tomorrow, utcOffsetSeconds) {
    const now = instant(nowIso, utcOffsetSeconds);
    const hours = (count) => now + count * 3600 * 1000;

    if (!today || !today.sunrise || !today.sunset || !tomorrow || !tomorrow.sunrise) {
        return [now, hours(NIGHT_HOURS)];
    }

    if (nowIso < today.sunrise) {
        return [now, instant(today.sunrise, utcOffsetSeconds)];
    }

    if (nowIso < today.sunset) {
        return [instant(today.sunset, utcOffsetSeconds), instant(tomorrow.sunrise, utcOffsetSeconds)];
    }

    return [now, instant(tomorrow.sunrise, utcOffsetSeconds)];
}

/**
 * What the Details tab and the sky say of the aurora tonight, or null without a Kp for those hours.
 *
 * @param slots   parseKpForecast()
 * @param place   `{ latitude, longitude }`
 * @param night   tonight()
 * @returns `{ kp, storm, sight, needed, direction }`: the highest Kp of the night; its storm, G1 … G5
 *          or ''; overhead | horizon | camera | none; the Kp it takes to see it on the horizon, whole,
 *          at most 9; and north or south, where to look
 */
export function auroraOutlook(slots, place, night) {
    const [start, end] = night;
    const during = slots.filter((slot) => slot.start < end && slot.start + SLOT_HOURS * 3600 * 1000 > start);

    if (during.length === 0) {
        return null;
    }

    const kp = Math.max(...during.map((slot) => slot.kp));
    const magnetic = geomagneticLatitude(place.latitude, place.longitude);
    const needed = kpNeeded(magnetic);
    let sight = 'none';

    if (kp >= needed.overhead) {
        sight = 'overhead';
    } else if (kp >= needed.horizon) {
        sight = 'horizon';
    } else if (kp >= needed.camera) {
        sight = 'camera';
    }

    return {
        kp,
        storm: stormScale(kp),
        sight,
        needed: Math.min(KP_MAXIMUM, Math.ceil(needed.horizon)),
        direction: magnetic >= 0 ? 'north' : 'south',
    };
}
