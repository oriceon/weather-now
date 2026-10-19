/**
 * The weather code Open-Meteo gives a day is the most severe one of its hours, and the
 * cloud codes follow the total cloud cover, thin high clouds included. A day with a bright
 * morning and a grey evening, or one spent under a veil the sun shines through, comes out
 * as "overcast". The functions here pick the code that represents what the day or the hour
 * is mostly like, from the sunshine and the precipitation that are actually forecast.
 */

const CLEAR = 0;
const MAINLY_CLEAR = 1;
const PARTLY_CLOUDY = 2;
const OVERCAST = 3;

/** Shares of the time with sunshine. */
const SUNNY = 0.6;
const SOME_SUN = 0.25;
const SUN_BETWEEN_SHOWERS = 0.35;
const CLOUDLESS_WITHOUT_COVER = 0.85;

/** Cloud cover, in percent. */
const FEW_CLOUDS = 20;
const SCATTERED_CLOUDS = 60;

/** Less than this in a day is a trace, not a wet day. */
const WET_DAY_MM = 0.5;
const MODERATE_RAIN_MM = 3;
const HEAVY_RAIN_MM = 20;

const MODERATE_SNOW_CM = 1;
const HEAVY_SNOW_CM = 5;
const SNOW_SHOWERS_HEAVY_CM = 2;
/** Open-Meteo: 7 cm of snow hold 10 mm of water. */
const SNOW_MM_PER_CM = 10 / 7;

const HOUR_SECONDS = 3600;

/** Reported as they are: a thunderstorm or freezing rain matters however short it is. */
const SEVERE = [56, 57, 66, 67, 95, 96, 99];
const FOG = [45, 48];

function isMissing(value) {
    return value === null || value === undefined;
}

function isSkyCode(code) {
    return code >= CLEAR && code <= OVERCAST;
}

/** The sky as a WMO code (0 clear … 3 overcast), from the share of sunshine and the cloud cover in percent. */
export function skyCode(sunFraction, cloudCover) {
    if (sunFraction < SOME_SUN) {
        return OVERCAST;
    }

    if (sunFraction < SUNNY) {
        return PARTLY_CLOUDY;
    }

    if (isMissing(cloudCover)) {
        return sunFraction >= CLOUDLESS_WITHOUT_COVER ? CLEAR : MAINLY_CLEAR;
    }

    if (cloudCover <= FEW_CLOUDS) {
        return CLEAR;
    }

    return cloudCover <= SCATTERED_CLOUDS ? MAINLY_CLEAR : PARTLY_CLOUDY;
}

function rainCode(millimetres, withSun) {
    if (millimetres < MODERATE_RAIN_MM) {
        return withSun ? 80 : 61;
    }

    if (millimetres < HEAVY_RAIN_MM) {
        return withSun ? 81 : 63;
    }

    return withSun ? 82 : 65;
}

function snowCode(centimetres, withSun) {
    if (withSun) {
        return centimetres < SNOW_SHOWERS_HEAVY_CM ? 85 : 86;
    }

    if (centimetres < MODERATE_SNOW_CM) {
        return 71;
    }

    return centimetres < HEAVY_SNOW_CM ? 73 : 75;
}

/** The code that represents a day, for an entry of `daily` from parseForecast(). */
export function representativeCode(day) {
    const code = day.weatherCode;

    if (isMissing(day.sunshineDuration) || !(day.daylightDuration > 0) || SEVERE.includes(code)) {
        return code;
    }

    const sunFraction = Math.min(1, day.sunshineDuration / day.daylightDuration);
    const precipitation = day.precipitationSum || 0;
    const snowfall = day.snowfallSum || 0;

    if (precipitation >= WET_DAY_MM) {
        const withSun = sunFraction >= SUN_BETWEEN_SHOWERS;

        return snowfall * SNOW_MM_PER_CM >= precipitation / 2 ? snowCode(snowfall, withSun) : rainCode(precipitation, withSun);
    }

    const sky = skyCode(sunFraction, day.cloudCoverMean);

    if (FOG.includes(code)) {
        return sky === OVERCAST ? code : sky;
    }

    // Never cloudier than the API says: its code is already the gloomiest moment of the day.
    return isSkyCode(code) ? Math.min(code, sky) : sky;
}

/** The code that represents an hour, for an entry of `hourly`; only a cloudy daytime hour with the sun out changes. */
export function hourCode(hour) {
    const code = hour.weatherCode;

    if (!hour.isDay || !isSkyCode(code) || isMissing(hour.sunshineDuration)) {
        return code;
    }

    return Math.min(code, skyCode(Math.min(1, hour.sunshineDuration / HOUR_SECONDS), hour.cloudCover));
}
