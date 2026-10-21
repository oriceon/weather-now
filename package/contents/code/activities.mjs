// How the hours ahead suit a few things done outdoors, and the best stretch of them: the life
// forecast of the Details tab. The thresholds are this widget's own, from common sense and the
// usual advice for each: no service publishes a formula to follow.

import { toKmh } from './scene.mjs';
import { toCelsius } from './temperature.mjs';

/** Every activity, in the order of the settings. */
export const ACTIVITIES = ['running', 'cycling', 'hiking', 'gardening', 'stargazing'];
/** Those a new widget shows. */
export const DEFAULT_ACTIVITIES = ['running', 'cycling', 'stargazing'];

/**
 * What makes an hour good, and what keeps it fair, for each activity: the feels-like temperature
 * in °C, the most chance of precipitation in percent, the most wind in km/h, and for some the
 * most UV, daylight, or the most cloud cover and moonlight of a night.
 */
const RULES = {
    running: { good: { feels: [5, 22], chance: 30, wind: 25, uv: 6 }, fair: { feels: [-2, 28], chance: 60, wind: 40 } },
    cycling: { good: { feels: [10, 26], chance: 20, wind: 20 }, fair: { feels: [5, 30], chance: 50, wind: 35 } },
    hiking: { good: { feels: [8, 24], chance: 25, wind: 30, day: true }, fair: { feels: [2, 29], chance: 50, wind: 45, day: true } },
    gardening: { good: { feels: [10, 28], chance: 30, wind: 30, day: true }, fair: { feels: [5, 32], chance: 60, wind: 40, day: true } },
    stargazing: { good: { night: true, clouds: 25, chance: 10, moon: 0.5 }, fair: { night: true, clouds: 50, chance: 30 } },
};
const RANKS = ['poor', 'fair', 'good'];
/** A night is looked at until this many hours ahead, enough to reach the small hours. */
const NIGHT_HOURS = 14;

function meets(rule, hour, units, moonIllumination) {
    const feels = toCelsius(hour.apparentTemperature, units.temperatureUnit);

    if (rule.feels && (typeof hour.apparentTemperature !== 'number' || feels < rule.feels[0] || feels > rule.feels[1])) {
        return false;
    }

    if (rule.chance !== undefined && hour.precipitationProbability > rule.chance) {
        return false;
    }

    if (rule.wind !== undefined && toKmh(hour.windSpeed, units.windUnit) > rule.wind) {
        return false;
    }

    if (rule.uv !== undefined && hour.uvIndex >= rule.uv) {
        return false;
    }

    if ((rule.day && !hour.isDay) || (rule.night && hour.isDay)) {
        return false;
    }

    if (rule.clouds !== undefined && hour.cloudCover > rule.clouds) {
        return false;
    }

    return rule.moon === undefined || moonIllumination <= rule.moon;
}

/** poor, fair or good: how an hour suits an activity. */
export function rateHour(activity, hour, units, moonIllumination = 0) {
    const rules = RULES[activity];

    if (meets(rules.good, hour, units, moonIllumination)) {
        return 'good';
    }

    return meets(rules.fair, hour, units, moonIllumination) ? 'fair' : 'poor';
}

/**
 * The best stretch of the hours ahead for an activity: the rest of today, or for the sky at night,
 * the coming night. `{ rating, start, end }`, the rating of its hours and their wall-clock times,
 * `end` being the end of the last one; poor, with no times, when no hour suits at all.
 *
 * @param hourly           the `hourly` of parseForecast(), from the current hour on
 * @param units            `{ windUnit, temperatureUnit }`
 * @param moonIllumination the lit share of the moon tonight, 0..1
 */
export function activityOutlook(activity, hourly, units, moonIllumination = 0) {
    const today = hourly.length > 0 ? hourly[0].time.slice(0, 10) : '';
    const hours = activity === 'stargazing' ? hourly.slice(0, NIGHT_HOURS) : hourly.filter((hour) => hour.time.startsWith(today));
    const ratings = hours.map((hour) => rateHour(activity, hour, units, moonIllumination));
    const best = Math.max(0, ...ratings.map((rating) => RANKS.indexOf(rating)));

    if (best === 0) {
        return { rating: 'poor', start: '', end: '' };
    }

    // The longest run of hours as good as the best one.
    let run = null;

    for (let first = 0; first < hours.length; first++) {
        if (RANKS.indexOf(ratings[first]) !== best) {
            continue;
        }

        let last = first;

        while (last + 1 < hours.length && RANKS.indexOf(ratings[last + 1]) === best) {
            last++;
        }

        if (run === null || last - first > run.last - run.first) {
            run = { first, last };
        }

        first = last;
    }

    // A stretch that lasts until midnight ends at 24:00, not at 00:00.
    const end = new Date(Date.parse(`${hours[run.last].time}:00Z`) + 3600000).toISOString().slice(11, 16).replace(/^00:00$/, '24:00');

    return { rating: RANKS[best], start: hours[run.first].time.slice(11, 16), end };
}
