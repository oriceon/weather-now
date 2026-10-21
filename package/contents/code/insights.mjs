// A sentence or two on the Today tab about what stands out in the hours ahead: a storm, strong
// gusts, frost, heat, strong sun, fog, a wide swing of the temperature. Drawn from rules, not from a
// model: what they say can be checked against the forecast, and reads the same in every language.

import { temperature, wind } from './format.mjs';
import { t } from './i18n.mjs';
import { toKmh } from './scene.mjs';
import { toCelsius } from './temperature.mjs';
import { coldestOfNight } from './watch.mjs';

/** The hours a timed sentence looks at: near enough that "at 03:00" can only mean the coming night. */
const AHEAD_HOURS = 12;
const STORM_CODES = [95, 96, 99];
const FOG_CODES = [45, 48];
/** Gusts from this speed on are worth a word, as the yellow codes for wind begin about there. */
const STRONG_GUSTS_KMH = 50;
const STRONG_UV = 6;
const FROST_CELSIUS = 0;
const HEAT_CELSIUS = 30;
const WIDE_SWING_CELSIUS = 12;

const clock = (hour) => hour.time.slice(11, 16);

/**
 * What stands out, the most pressing first, at most `most` of them, each as a sentence.
 *
 * @param forecast parseForecast() of code/openmeteo.mjs
 * @param units    `{ windUnit, temperatureUnit }`
 */
export function insights(forecast, units, language, most = 2) {
    const ahead = forecast.hourly.slice(0, AHEAD_HOURS);
    const celsius = (value) => toCelsius(value, units.temperatureUnit);
    const found = [];

    const storm = ahead.find((hour) => STORM_CODES.includes(hour.weatherCode));

    if (storm) {
        found.push(t(language, 'insight.storm', { time: clock(storm) }));
    }

    const gusty = ahead.filter((hour) => typeof hour.windGusts === 'number');
    const strongest = gusty.length > 0 ? gusty.reduce((most, hour) => (hour.windGusts > most.windGusts ? hour : most)) : null;

    if (strongest && toKmh(strongest.windGusts, units.windUnit) >= STRONG_GUSTS_KMH) {
        found.push(t(language, 'insight.gusts', { speed: wind(strongest.windGusts, units.windUnit, language), time: clock(strongest) }));
    }

    const coldest = coldestOfNight(forecast.hourly);

    if (coldest !== null && celsius(coldest) <= FROST_CELSIUS) {
        found.push(t(language, 'insight.frost', { temperature: temperature(coldest) }));
    }

    const today = forecast.today;

    if (typeof today.temperatureMax === 'number' && celsius(today.temperatureMax) >= HEAT_CELSIUS) {
        found.push(t(language, 'insight.heat', { temperature: temperature(today.temperatureMax) }));
    }

    const sunny = forecast.hourly.filter((hour) => hour.time.startsWith(today.date) && hour.uvIndex >= STRONG_UV);

    if (sunny.length > 0) {
        found.push(t(language, 'insight.uv', { start: clock(sunny[0]), end: `${String(Number(clock(sunny[sunny.length - 1]).slice(0, 2)) + 1).padStart(2, '0')}:00` }));
    }

    const fog = ahead.find((hour) => FOG_CODES.includes(hour.weatherCode));

    if (fog) {
        found.push(t(language, 'insight.fog', { time: clock(fog) }));
    }

    if (typeof today.temperatureMax === 'number' && typeof today.temperatureMin === 'number'
        && celsius(today.temperatureMax) - celsius(today.temperatureMin) >= WIDE_SWING_CELSIUS) {
        found.push(t(language, 'insight.swing', { difference: `${Math.round(today.temperatureMax - today.temperatureMin)}°` }));
    }

    return found.slice(0, most);
}
