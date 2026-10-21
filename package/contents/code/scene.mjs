import { group, intensity, precipitationKind } from './wmo.mjs';

const MAX_RAIN_DROPS = 130;
const MAX_SNOW_FLAKES = 90;
const MIN_PARTICLES = 8;
const REDUCED_SHARE = 0.5;

/** Clouds drawn for each sky code (0 clear … 3 overcast), and for the families that bring their own. */
const CLOUDS_BY_SKY = { 0: 0, 1: 2, 2: 4, 3: 6 };
const CLOUDS_BY_FAMILY = { fog: 3, rain: 4, snow: 4, storm: 5 };
const CLOUDS_UNKNOWN = 4;

/** Stars on a clear night, fewer through broken cloud; a bright moon washes out the faint ones. */
const STARS_BY_SKY = { 0: 420, 1: 300, 2: 140 };
const MOON_WASH = 0.55;
/** Of the stars, so many are bright enough to twinkle, at most so many. */
const TWINKLE_SHARE = 1 / 8;
const MOST_TWINKLES = 36;

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

/** Rain showers, not snow showers: they are what leaves a rainbow, with the sun low behind the viewer. */
const RAIN_SHOWERS = [80, 81, 82];
/** The sun is low enough for a rainbow in the first and the last share of its way. */
const LOW_SUN = 0.3;

/** How much of the sky a continuous deck of cloud covers: all of it overcast, most of it when it rains or snows. */
const DECK_BY_FAMILY = { rain: 0.85, snow: 0.8, storm: 1, fog: 0.4 };
const OVERCAST = 3;
/** Drops on the glass in the hardest rain. */
const MOST_GLASS_DROPS = 18;

/** The aurora shows through a clear or a broken sky, not through an overcast one or what falls. */
const AURORA_SKIES = [0, 1, 2];

/** The Milky Way shows on a clear night only while the moon is dim. */
const DIM_MOON = 0.35;

/** From this wind on, it is seen: streaks across the sky, and leaves where nothing falls but rain. */
const VISIBLE_WIND_KMH = 30;
const MAX_STREAKS = 9;
const MAX_LEAVES = 7;

/** Frost on the edges at and below this; heat haze over the horizon at and above that, by day. */
const FROST_CELSIUS = 0;
const HEAT_CELSIUS = 30;

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
    return speed * ({ ms: 3.6, mph: 1.609344, kn: 1.852, kt: 1.852 }[unit] || 1);
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
 * "full", "reduced" and "off". `sunProgress` is where the sun is on its way, see celestial();
 * `moonIllumination` the lit share of the moon, `celsius` the temperature, `aurora` how the aurora
 * can be seen tonight: overhead, horizon, camera or none, see auroraOutlook() in aurora.mjs.
 */
export function sceneFor({ weatherCode, isDay, windKmh, quality, sunProgress = 0.5, moonIllumination = 1, celsius = 15, aurora = 'none' }) {
    const family = group(weatherCode);
    const kind = precipitationKind(weatherCode);
    const share = quality === 'full' ? 1 : REDUCED_SHARE;
    const particles = (most) => Math.max(MIN_PARTICLES, Math.round(most * intensity(weatherCode) * share));
    const windy = windKmh >= VISIBLE_WIND_KMH;
    const gusts = Math.min(1, (windKmh - VISIBLE_WIND_KMH + 10) / 40);
    const clearNight = !isDay && (weatherCode === 0 || weatherCode === 1);

    return {
        family,
        clouds: Math.ceil(fromTables(weatherCode, family, CLOUDS_BY_SKY, CLOUDS_BY_FAMILY, CLOUDS_UNKNOWN) * share),
        cloudTone: family === 'storm' ? 'dark' : weatherCode === 3 || family in CLOUDS_BY_FAMILY ? 'grey' : 'white',
        celestialOpacity: SHOWERS.includes(weatherCode) ? CELESTIAL_IN_SHOWERS : fromTables(weatherCode, family, CELESTIAL_BY_SKY, CELESTIAL_BY_FAMILY, 0.5),
        stars: isDay ? 0 : Math.round((STARS_BY_SKY[weatherCode] || 0) * (1 - MOON_WASH * moonIllumination)),
        twinkles: isDay ? 0 : Math.round(Math.min(MOST_TWINKLES, (STARS_BY_SKY[weatherCode] || 0) * TWINKLE_SHARE) * share),
        fog: family === 'fog',
        rain: kind === 'rain' ? particles(MAX_RAIN_DROPS) : 0,
        snow: kind === 'snow' ? particles(MAX_SNOW_FLAKES) : 0,
        slant: Math.min(MAX_SLANT, Math.round(windKmh * SLANT_PER_KMH)),
        lightning: family === 'storm',
        driftSeconds: driftSeconds(windKmh),
        rainbow: isDay && RAIN_SHOWERS.includes(weatherCode) && (sunProgress < LOW_SUN || sunProgress > 1 - LOW_SUN),
        shootingStars: clearNight && quality === 'full',
        milkyWay: !isDay && weatherCode === 0 && moonIllumination < DIM_MOON,
        streaks: windy ? Math.max(2, Math.round(MAX_STREAKS * gusts * share)) : 0,
        leaves: windy && kind !== 'snow' ? Math.max(2, Math.round(MAX_LEAVES * gusts * share)) : 0,
        frost: celsius <= FROST_CELSIUS,
        heat: isDay && celsius >= HEAT_CELSIUS,
        snowCover: kind === 'snow' ? intensity(weatherCode) : 0,
        deck: weatherCode === OVERCAST ? 1 : DECK_BY_FAMILY[family] || 0,
        glassDrops: kind === 'rain' ? Math.max(4, Math.round(MOST_GLASS_DROPS * intensity(weatherCode) * share)) : 0,
        // What only a camera catches is not painted.
        aurora: !isDay && AURORA_SKIES.includes(weatherCode) && (aurora === 'overhead' || aurora === 'horizon') ? aurora : 'none',
    };
}
