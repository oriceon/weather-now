// The colours of temperatures, for the bars of the days and the curve of the hours.

import { mixHex } from './sky.mjs';

/** °C and their colour, from frost to heat; in between, the colours mix. */
const STOPS = [
    [-15, '#8b7cf6'],
    [-5, '#5b8def'],
    [3, '#3cc4e6'],
    [12, '#45d08f'],
    [20, '#f2cf3d'],
    [28, '#f9933a'],
    [36, '#ea4848'],
];

export function toCelsius(value, unit) {
    return unit === 'fahrenheit' ? (value - 32) * 5 / 9 : value;
}

/** The colour of a temperature in °C, as #rrggbb. */
export function temperatureColour(celsius) {
    if (celsius <= STOPS[0][0]) {
        return STOPS[0][1];
    }

    for (let index = 1; index < STOPS.length; index++) {
        const [upper, colour] = STOPS[index];

        if (celsius <= upper) {
            const [lower, lowerColour] = STOPS[index - 1];

            return mixHex(lowerColour, colour, (celsius - lower) / (upper - lower));
        }
    }

    return STOPS[STOPS.length - 1][1];
}

/** The lowest and the highest temperature of the days that have them: the scale of the bars. */
export function temperatureScale(days) {
    const known = days.filter((day) => day && day.temperatureMin !== null && day.temperatureMax !== null);

    if (known.length === 0) {
        return { low: 0, high: 1 };
    }

    const low = Math.min(...known.map((day) => day.temperatureMin));
    const high = Math.max(...known.map((day) => day.temperatureMax));

    return high > low ? { low, high } : { low: low - 1, high: high + 1 };
}

/** Where a temperature is on the scale: 0 at the lowest, 1 at the highest. */
export function scalePosition(value, scale) {
    return Math.max(0, Math.min(1, (value - scale.low) / (scale.high - scale.low)));
}

/** Below this difference of the maxima, in the unit of the forecast, two days are much alike. */
const ALIKE = 1.5;

/**
 * How the highest temperature of today compares with that of yesterday, from the `daily` of
 * parseForecast(): `{ kind: 'warmer' | 'colder' | 'similar', difference }`, the difference being
 * whole degrees, or null when yesterday is not known.
 */
export function comparedWithYesterday(days, today) {
    const index = days.findIndex((day) => day.date === today);
    const yesterday = index > 0 ? days[index - 1] : null;

    if (yesterday === null || typeof yesterday.temperatureMax !== 'number' || typeof days[index].temperatureMax !== 'number') {
        return null;
    }

    const change = days[index].temperatureMax - yesterday.temperatureMax;

    if (Math.abs(change) < ALIKE) {
        return { kind: 'similar', difference: 0 };
    }

    return { kind: change > 0 ? 'warmer' : 'colder', difference: Math.round(Math.abs(change)) };
}
