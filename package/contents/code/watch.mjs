// Decides what is worth a desktop notification: news, told once, not a state repeated with every refresh.

import { precipitationKind } from './wmo.mjs';

/**
 * What the widget knows before its first look. `knownAlerts` holds, by id, until when each warning
 * seen is in force; `frostTold`, the day the frost was told, which the widget keeps in its settings.
 */
export const STARTING = { knownAlerts: null, rainSoon: false, frostTold: '', morningTold: '' };

/** The end of a warning without one. */
const FOREVER = '9999-12-31T23:59';

/** Rain is "soon" when it starts within this many quarters of an hour, and it is dry now. */
const SOON_QUARTERS = 2;
const WET_MM = 0.2;
/** The frost of the night is told once, in the evening, so that there is time to cover the plants. */
const EVENING = ['17:00', '22:00'];
/** The summary of the day is not sent after noon: by then the day is half gone. */
const LATEST_MORNING = '12:00';
const NIGHT_HOURS = 14;

/**
 * @param state    what the previous call returned, or STARTING
 * @param reading  `{ now, alerts, minutely, hourly, frostCelsius }`: the time at the place, the active
 *                 warnings, or null while they have not all come in yet, the quarter hours and hours
 *                 of parseForecast(), and the coldest of the coming night in °C, or null when not known
 * @param settings `{ notifyAlerts, notifyRain, notifyFrost, notifyMorning, morningTime }`, the time
 *                 as "07:30"
 * @returns `{ state, events }`, where an event is `{ kind: 'alert', alert }`, `{ kind: 'rain', at, snow }`,
 *          `{ kind: 'frost', celsius }` or `{ kind: 'morning' }`
 */
export function watch(state, reading, settings) {
    const events = [];
    const next = Object.assign({}, state);
    const seen = {};

    if (reading.alerts !== null) {
        const known = state.knownAlerts || {};

        // A warning is remembered until it expires, so that one missing from a list for a while is not news when it is back.
        Object.keys(known).filter((id) => known[id] >= reading.now).forEach((id) => {
            seen[id] = known[id];
        });

        reading.alerts.forEach((alert) => {
            // A warning kept for several that say the same, see distinctAlerts(), is known by any of them.
            const ids = [alert.id].concat(alert.sameAs || []);
            const isKnown = ids.some((id) => known[id] !== undefined);

            ids.forEach((id) => {
                seen[id] = alert.expires || FOREVER;
            });

            // The first list is what was there already; only what appears after it is news.
            if (settings.notifyAlerts && state.knownAlerts !== null && !isKnown) {
                events.push({ kind: 'alert', alert });
            }
        });
        next.knownAlerts = seen;
    }

    const quarters = reading.minutely || [];
    const dryNow = quarters.length > 0 && quarters[0].precipitation < WET_MM;
    const comingQuarter = quarters.slice(1, SOON_QUARTERS + 1).find((quarter) => quarter.precipitation >= WET_MM);

    next.rainSoon = dryNow && comingQuarter !== undefined;

    if (settings.notifyRain && next.rainSoon && !state.rainSoon) {
        const hour = (reading.hourly || [])[0];

        events.push({ kind: 'rain', at: comingQuarter.time.slice(11, 16), snow: hour ? precipitationKind(hour.weatherCode) === 'snow' : false });
    }

    const time = String(reading.now).slice(11, 16);
    const date = String(reading.now).slice(0, 10);

    if (time >= EVENING[0] && time < EVENING[1] && reading.frostCelsius !== null && reading.frostCelsius <= 0 && state.frostTold !== date) {
        next.frostTold = date;

        if (settings.notifyFrost) {
            events.push({ kind: 'frost', celsius: reading.frostCelsius });
        }
    }

    // Once a day, from the time chosen until noon: a computer started late in the morning still gets it.
    if (settings.notifyMorning && time >= (settings.morningTime || '07:00') && time < LATEST_MORNING && state.morningTold !== date) {
        next.morningTold = date;
        events.push({ kind: 'morning' });
    }

    return { state: next, events };
}

/** The coldest temperature of the night ahead, from the hours of parseForecast(), in their unit. */
export function coldestOfNight(hourly) {
    const night = hourly.slice(0, NIGHT_HOURS).map((hour) => hour.temperature).filter((value) => typeof value === 'number');

    return night.length > 0 ? Math.min(...night) : null;
}
