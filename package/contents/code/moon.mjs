const DAY_MS = 24 * 60 * 60 * 1000;
const SYNODIC_MONTH_DAYS = 29.530588853;
/** A new moon to count the cycles from: 6 January 2000, 18:14 UTC. */
const REFERENCE_NEW_MOON = Date.UTC(2000, 0, 6, 18, 14);

/** Translation keys of the eight phases, in the order the moon goes through them. */
export const PHASE_KEYS = [
    'moon.new',
    'moon.waxingCrescent',
    'moon.firstQuarter',
    'moon.waxingGibbous',
    'moon.full',
    'moon.waningGibbous',
    'moon.lastQuarter',
    'moon.waningCrescent',
];

/**
 * The phase of the moon at noon UTC of a date, from the mean length of the lunar month.
 * Good to about half a day, which is enough to name the phase and to draw it.
 */
export function moonPhase(isoDate) {
    const text = String(isoDate);
    const noon = Date.UTC(Number(text.slice(0, 4)), Number(text.slice(5, 7)) - 1, Number(text.slice(8, 10)), 12);
    const cycles = (noon - REFERENCE_NEW_MOON) / DAY_MS / SYNODIC_MONTH_DAYS;
    const fraction = cycles - Math.floor(cycles);

    return {
        /** 0 at new moon, 0.5 at full moon. */
        fraction,
        key: PHASE_KEYS[Math.round(fraction * PHASE_KEYS.length) % PHASE_KEYS.length],
        /** Share of the disc that is lit, 0..1. */
        illumination: (1 - Math.cos(2 * Math.PI * fraction)) / 2,
    };
}

const RADIAN = Math.PI / 180;
/** Days of the Julian calendar at the Unix epoch, and at noon of 1 January 2000. */
const JULIAN_EPOCH = 2440587.5;
const J2000 = 2451545;
const OBLIQUITY = 23.4397 * RADIAN;
/**
 * The height, in degrees, of the centre of the moon when its upper edge meets the horizon, seen from
 * the centre of the Earth: the refraction and the size of the moon raise it, the parallax lowers it.
 */
const RISING_HEIGHT = 0.125;
const STEP_MINUTES = 10;

/**
 * How high the moon stands, in degrees, at `time` (milliseconds since the epoch) over a place,
 * from the low-precision lunar theory: good to some minutes of rising and setting, which is all a
 * weather widget tells.
 */
export function moonHeight(time, latitude, longitude) {
    const days = time / DAY_MS + JULIAN_EPOCH - J2000;
    const meanLongitude = RADIAN * (218.316 + 13.176396 * days);
    const meanAnomaly = RADIAN * (134.963 + 13.064993 * days);
    const meanDistance = RADIAN * (93.272 + 13.22935 * days);
    const eclipticLongitude = meanLongitude + RADIAN * 6.289 * Math.sin(meanAnomaly);
    const eclipticLatitude = RADIAN * 5.128 * Math.sin(meanDistance);
    const rightAscension = Math.atan2(Math.sin(eclipticLongitude) * Math.cos(OBLIQUITY) - Math.tan(eclipticLatitude) * Math.sin(OBLIQUITY), Math.cos(eclipticLongitude));
    const declination = Math.asin(Math.sin(eclipticLatitude) * Math.cos(OBLIQUITY) + Math.cos(eclipticLatitude) * Math.sin(OBLIQUITY) * Math.sin(eclipticLongitude));
    const siderealTime = RADIAN * (280.16 + 360.9856235 * days) + RADIAN * longitude;
    const hourAngle = siderealTime - rightAscension;
    const place = RADIAN * latitude;

    return Math.asin(Math.sin(place) * Math.sin(declination) + Math.cos(place) * Math.cos(declination) * Math.cos(hourAngle)) / RADIAN;
}

/** The moments the moon rises and sets between `from` and `to`, in milliseconds, in order. */
function crossings(from, to, latitude, longitude) {
    const found = [];
    const step = STEP_MINUTES * 60000;
    let before = moonHeight(from, latitude, longitude) - RISING_HEIGHT;

    for (let time = from + step; time <= to; time += step) {
        const after = moonHeight(time, latitude, longitude) - RISING_HEIGHT;

        if ((before < 0) !== (after < 0)) {
            found.push({ kind: after >= 0 ? 'rise' : 'set', time: time - step + step * before / (before - after) });
        }

        before = after;
    }

    return found;
}

/** A moment in milliseconds as the wall-clock time of the place, "18:40". */
function clock(time, utcOffsetSeconds) {
    return new Date(time + utcOffsetSeconds * 1000).toISOString().slice(11, 16);
}

/**
 * When the moon rises and sets on a date at a place, as the wall-clock times of the place, "18:40";
 * '' for a day it does not rise or set, which happens about once a month.
 */
export function moonTimes(isoDate, latitude, longitude, utcOffsetSeconds) {
    const midnight = Date.parse(`${String(isoDate).slice(0, 10)}T00:00:00Z`) - utcOffsetSeconds * 1000;
    const events = crossings(midnight, midnight + DAY_MS, latitude, longitude);
    const first = (kind) => events.find((event) => event.kind === kind);

    return {
        rise: first('rise') ? clock(first('rise').time, utcOffsetSeconds) : '',
        set: first('set') ? clock(first('set').time, utcOffsetSeconds) : '',
    };
}

/**
 * Where the moon is on its way across the sky at `nowIso`, a wall-clock time of the place:
 * `{ up, progress }`, progress going from 0 as it rises to 1 as it sets; 0 while it is down.
 */
export function moonWay(nowIso, latitude, longitude, utcOffsetSeconds) {
    const now = Date.parse(`${String(nowIso).slice(0, 16)}:00Z`) - utcOffsetSeconds * 1000;
    const span = 26 * 3600000;
    const events = crossings(now - span, now + span, latitude, longitude);
    const rise = events.filter((event) => event.kind === 'rise' && event.time <= now).pop();
    const set = events.find((event) => event.kind === 'set' && event.time > now);

    if (!rise || !set || events.some((event) => event.kind === 'set' && event.time > rise.time && event.time <= now)) {
        return { up: false, progress: 0 };
    }

    return { up: true, progress: (now - rise.time) / (set.time - rise.time) };
}
