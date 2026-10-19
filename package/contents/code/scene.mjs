import { group, intensity, precipitationKind } from './wmo.mjs';

const MAX_RAIN_DROPS = 130;
const MAX_SNOW_FLAKES = 90;
const MIN_PARTICLES = 8;
const REDUCED_SHARE = 0.5;

/** Clouds drawn for each sky code (0 clear … 3 overcast), and for the families that bring their own. */
const CLOUDS_BY_SKY = { 0: 0, 1: 2, 2: 4, 3: 6 };
const CLOUDS_BY_FAMILY = { fog: 3, rain: 5, snow: 5, storm: 6 };
const CLOUDS_UNKNOWN = 4;

const STARS_BY_SKY = { 0: 40, 1: 30, 2: 16 };

/** How much of the sun or the moon shows through. */
const CELESTIAL_BY_SKY = { 0: 1, 1: 1, 2: 0.9, 3: 0.2 };
const CELESTIAL_BY_FAMILY = { fog: 0.35, rain: 0.12, snow: 0.12, storm: 0.05 };
const CELESTIAL_IN_SHOWERS = 0.6;
const SHOWERS = [80, 81, 82, 85, 86];

/** Degrees the rain leans for every km/h of wind, and the most it leans. */
const SLANT_PER_KMH = 1 / 3;
const MAX_SLANT = 30;

/** Seconds a cloud takes to cross the sky; in steps, so that a small change of wind does not restart the drift. */
const DRIFT_STEPS = [[8, 300], [20, 200], [40, 120]];
const DRIFT_STORMY = 70;

const TWILIGHT_MINUTES = 45;
const DAY_MINUTES = 24 * 60;

function minutesOf(iso) {
    const text = String(iso);

    return Number(text.slice(11, 13)) * 60 + Number(text.slice(14, 16));
}

/** A repeatable pseudo-random value in [0, 1), so that the scene looks the same on every redraw. */
export function noise(index, salt) {
    const value = Math.sin(index * 127.1 + salt * 311.7) * 43758.5453;

    return value - Math.floor(value);
}

export function toKmh(speed, unit) {
    if (unit === 'ms') {
        return speed * 3.6;
    }

    return unit === 'mph' ? speed * 1.609344 : speed;
}

/** Where the sun (by day) or the moon (by night) is on its way across the sky: 0 rising, 1 setting. */
export function celestial(nowIso, sunriseIso, sunsetIso) {
    const now = minutesOf(nowIso);
    const sunrise = minutesOf(sunriseIso);
    const sunset = minutesOf(sunsetIso);

    if (now >= sunrise && now < sunset) {
        return { isDay: true, progress: (now - sunrise) / (sunset - sunrise) };
    }

    const sinceSunset = now >= sunset ? now - sunset : now + DAY_MINUTES - sunset;

    return { isDay: false, progress: sinceSunset / (DAY_MINUTES - (sunset - sunrise)) };
}

/** 1 at sunrise and at sunset, fading to 0 three quarters of an hour away. */
export function twilight(nowIso, sunriseIso, sunsetIso) {
    const now = minutesOf(nowIso);
    const distance = Math.min(Math.abs(now - minutesOf(sunriseIso)), Math.abs(now - minutesOf(sunsetIso)));

    return Math.max(0, 1 - distance / TWILIGHT_MINUTES);
}

function driftSeconds(windKmh) {
    for (const [below, seconds] of DRIFT_STEPS) {
        if (windKmh < below) {
            return seconds;
        }
    }

    return DRIFT_STORMY;
}

function fromTables(code, family, bySky, byFamily, otherwise) {
    if (code in bySky) {
        return bySky[code];
    }

    return family in byFamily ? byFamily[family] : otherwise;
}

/**
 * What the animated background shows for a weather: how many clouds, drops, flakes and stars,
 * and how they move. `weatherCode` is a condition code from parseForecast(), `quality` one of
 * "full", "reduced" and "off".
 */
export function sceneFor({ weatherCode, isDay, windKmh, quality }) {
    const family = group(weatherCode);
    const kind = precipitationKind(weatherCode);
    const share = quality === 'full' ? 1 : REDUCED_SHARE;
    const particles = (most) => Math.max(MIN_PARTICLES, Math.round(most * intensity(weatherCode) * share));

    return {
        family,
        clouds: Math.ceil(fromTables(weatherCode, family, CLOUDS_BY_SKY, CLOUDS_BY_FAMILY, CLOUDS_UNKNOWN) * share),
        cloudTone: family === 'storm' ? 'dark' : weatherCode === 3 || family in CLOUDS_BY_FAMILY ? 'grey' : 'white',
        celestialOpacity: SHOWERS.includes(weatherCode) ? CELESTIAL_IN_SHOWERS : fromTables(weatherCode, family, CELESTIAL_BY_SKY, CELESTIAL_BY_FAMILY, 0.5),
        stars: isDay ? 0 : Math.round((STARS_BY_SKY[weatherCode] || 0) * share),
        fog: family === 'fog',
        rain: kind === 'rain' ? particles(MAX_RAIN_DROPS) : 0,
        snow: kind === 'snow' ? particles(MAX_SNOW_FLAKES) : 0,
        slant: Math.min(MAX_SLANT, Math.round(windKmh * SLANT_PER_KMH)),
        lightning: family === 'storm',
        driftSeconds: driftSeconds(windKmh),
    };
}
