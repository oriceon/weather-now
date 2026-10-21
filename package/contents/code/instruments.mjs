// What the dials of the Details tab show: the colours along them, and what their values mean.

/** UV index: the WHO categories, each to its upper bound, in the colours the WHO gives them. */
export const UV_SCALE = {
    minimum: 0,
    maximum: 12,
    segments: [[3, '#3ccf6b'], [6, '#f2cf3d'], [8, '#f9933a'], [11, '#ea4848'], [12, '#a855f7']],
};

/** Sea-level pressure in hPa: low brings unsettled weather, high a settled one; 1013 is the mean. */
export const PRESSURE_SCALE = {
    minimum: 970,
    maximum: 1050,
    segments: [[990, '#5b8def'], [1005, '#3cc4e6'], [1022, '#45d08f'], [1035, '#f2cf3d'], [1050, '#f9933a']],
};

/** Dew point in °C: how humid the air feels, from dry to oppressive, whatever the temperature. */
export const DEW_POINT_SCALE = {
    minimum: -10,
    maximum: 26,
    segments: [[10, '#3cc4e6'], [16, '#45d08f'], [20, '#f2cf3d'], [26, '#ea4848']],
};

/** Translation key of how a dew point in °C feels: the bands of DEW_POINT_SCALE. */
export function dewPointKey(celsius) {
    if (celsius >= 20) {
        return 'dewPoint.oppressive';
    }

    if (celsius >= 16) {
        return 'dewPoint.humid';
    }

    return celsius >= 10 ? 'dewPoint.comfortable' : 'dewPoint.dry';
}

/** Translation key of a visibility in metres, from fog to a clear view of the far hills. */
export function visibilityKey(metres) {
    if (metres >= 20000) {
        return 'visibility.excellent';
    }

    if (metres >= 10000) {
        return 'visibility.good';
    }

    if (metres >= 4000) {
        return 'visibility.moderate';
    }

    return metres >= 1000 ? 'visibility.poor' : 'visibility.veryPoor';
}

/** Less change than this in three hours is steady, as weather services count it. */
const STEADY_HPA = 1;
const TREND_HOURS = 3;

/**
 * Where the pressure goes over the next three hours, from the `hourly` of parseForecast(), the
 * first of which is the current hour: rising, falling, steady, or null when it is not known.
 */
export function pressureTrend(hourly) {
    const now = hourly[0];
    const later = hourly[TREND_HOURS];

    if (!now || !later || now.pressure === null || later.pressure === null || now.pressure === undefined || later.pressure === undefined) {
        return null;
    }

    const change = later.pressure - now.pressure;

    if (Math.abs(change) < STEADY_HPA) {
        return 'steady';
    }

    return change > 0 ? 'rising' : 'falling';
}

/** Where a value is on a scale, 0 at its minimum and 1 at its maximum. */
export function dialPosition(value, scale) {
    return Math.max(0, Math.min(1, (value - scale.minimum) / (scale.maximum - scale.minimum)));
}

/** The upper bounds of the forces of the Beaufort scale, in km/h; above the last is 12, a hurricane. */
const BEAUFORT_KMH = [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];

/** The force of a wind on the Beaufort scale, 0 to 12, from its speed in km/h. */
export function beaufort(kmh) {
    const force = BEAUFORT_KMH.findIndex((upper) => kmh < upper);

    return force === -1 ? 12 : force;
}

/** Translation key of how dry or damp the air is, by its relative humidity in percent. */
export function humidityKey(percent) {
    if (percent >= 80) {
        return 'humidity.veryHumid';
    }

    if (percent >= 60) {
        return 'humidity.humid';
    }

    return percent >= 30 ? 'humidity.comfortable' : 'humidity.dry';
}

/** From this UV index on, the skin wants protecting, as the WHO advises. */
const PROTECT_UV = 3;

/**
 * The hours of today, among the `hourly` of parseForecast(), when the UV index calls for sun
 * protection: `{ from, until }`, wall-clock times, `until` being the end of the last such hour;
 * null when there are none left today.
 */
export function uvWindow(hourly) {
    if (hourly.length === 0) {
        return null;
    }

    const today = hourly[0].time.slice(0, 10);
    const strong = hourly.filter((hour) => hour.time.startsWith(today) && hour.uvIndex >= PROTECT_UV);

    if (strong.length === 0) {
        return null;
    }

    const end = Number(strong[strong.length - 1].time.slice(11, 13)) + 1;

    return { from: strong[0].time.slice(11, 16), until: `${String(end).padStart(2, '0')}:00` };
}

/** How much the pressure changes over the next three hours, in hPa; null when it is not known. */
export function pressureChange(hourly) {
    const now = hourly[0];
    const later = hourly[TREND_HOURS];

    if (!now || !later || typeof now.pressure !== 'number' || typeof later.pressure !== 'number') {
        return null;
    }

    return later.pressure - now.pressure;
}

/** From this change in three hours on, the weather is about to turn, as barometers have long been read. */
export const FAST_CHANGE_HPA = 3;

/** Cloud cover in percent at and below which the sky is clear, and at and above which it is cloudy. */
const CLEAR_SKY = 30;
const CLOUDY_SKY = 70;
const CLOUD_HOURS = 12;

/**
 * When the sky turns within the next twelve hours: `{ kind: 'clearing' | 'clouding', time }` for
 * the first hour clear after a cloudy now, or cloudy after a clear one; null when it stays as it is.
 */
export function cloudsTurn(hourly) {
    const now = hourly[0];

    if (!now || typeof now.cloudCover !== 'number') {
        return null;
    }

    const coming = hourly.slice(1, CLOUD_HOURS + 1);
    const turn = now.cloudCover >= CLOUDY_SKY
        ? coming.find((hour) => hour.cloudCover <= CLEAR_SKY)
        : now.cloudCover <= CLEAR_SKY ? coming.find((hour) => hour.cloudCover >= CLOUDY_SKY) : undefined;

    return turn ? { kind: now.cloudCover >= CLOUDY_SKY ? 'clearing' : 'clouding', time: turn.time.slice(11, 16) } : null;
}
