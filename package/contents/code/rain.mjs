import { addDays, dateOf, dayWord, timeLabel } from './dates.mjs';
import { t } from './i18n.mjs';
import { precipitationKind } from './wmo.mjs';

/** Less than this in an hour goes unnoticed. */
const NOTICEABLE_MM = 0.1;

function isWet(hour) {
    return hour.precipitation >= NOTICEABLE_MM;
}

/**
 * When the next precipitation starts and stops, for the `hourly` entries of parseForecast(), the
 * first of which is the current hour. Open-Meteo gives the precipitation of an hour at its end:
 * the entry of 18:00 holds what falls from 17:00 to 18:00. So the entry of the current hour holds
 * the hour gone by, the next one the hour under way, and a wet entry means rain from the hour
 * before it. `end` is when the last wet hour ends, or null when it does not stop within the forecast.
 */
export function rainSummary(hourly) {
    const ahead = hourly.slice(1);
    const first = ahead.findIndex(isWet);

    if (first === -1) {
        return { kind: 'none', snow: false, start: null, end: null };
    }

    let last = first;

    while (last + 1 < ahead.length && isWet(ahead[last + 1])) {
        last++;
    }

    return {
        kind: first === 0 ? 'now' : 'later',
        snow: precipitationKind(ahead[first].weatherCode) === 'snow',
        start: hourly[first].time,
        end: last + 1 < ahead.length ? ahead[last].time : null,
    };
}

/** The summary as a sentence, e.g. "Ploaie mâine, între 03:00 și 05:00". */
export function rainSentence(summary, nowIso, language) {
    if (summary.kind === 'none') {
        return t(language, 'summary.none');
    }

    const what = summary.snow ? 'snow' : 'rain';
    const start = timeLabel(summary.start);
    const end = summary.end ? timeLabel(summary.end) : '';

    if (summary.kind === 'now') {
        const now = t(language, `summary.${what}.now`);

        return summary.end ? t(language, 'summary.until', { now, end }) : t(language, 'summary.noBreak', { now });
    }

    const noun = t(language, `summary.${what}.noun`);
    const today = dateOf(nowIso);

    if (dateOf(summary.start) === today) {
        return summary.end ? t(language, 'summary.between', { noun, start, end }) : t(language, 'summary.from', { noun, start });
    }

    const word = dayWord(summary.start, nowIso, language);
    const day = dateOf(summary.start) === addDays(today, 1) ? word : t(language, 'summary.onDay', { day: word });

    return summary.end ? t(language, 'summary.betweenDay', { noun, day, start, end }) : t(language, 'summary.fromDay', { noun, day, start });
}

/** The panel tells of rain no further ahead than this. */
const PANEL_HOURS = 12;

/**
 * When the next rain or snow starts, as "18:00", for the panel; empty while it is already falling,
 * when it is further ahead than half a day, and when none is coming.
 */
export function upcomingStart(summary, nowIso) {
    if (summary.kind !== 'later') {
        return '';
    }

    const ahead = (Date.parse(`${summary.start}:00Z`) - Date.parse(`${String(nowIso).slice(0, 16)}:00Z`)) / 3600000;

    return ahead <= PANEL_HOURS ? timeLabel(summary.start) : '';
}

