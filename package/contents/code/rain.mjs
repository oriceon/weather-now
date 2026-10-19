import { addDays, dateOf, dayWord, timeLabel } from './dates.mjs';
import { t } from './i18n.mjs';
import { precipitationKind } from './wmo.mjs';

/** Less than this in an hour goes unnoticed. */
const NOTICEABLE_MM = 0.1;

function isWet(hour) {
    return hour.precipitation >= NOTICEABLE_MM;
}

/**
 * When the next precipitation starts and stops, for the `hourly` entries of parseForecast(),
 * the first of which is the current hour. `end` is the first dry hour after it, or null when
 * it does not stop within the forecast.
 */
export function rainSummary(hourly) {
    const first = hourly.findIndex(isWet);

    if (first === -1) {
        return { kind: 'none', snow: false, start: null, end: null };
    }

    let afterLast = first + 1;

    while (afterLast < hourly.length && isWet(hourly[afterLast])) {
        afterLast++;
    }

    return {
        kind: first === 0 ? 'now' : 'later',
        snow: precipitationKind(hourly[first].weatherCode) === 'snow',
        start: hourly[first].time,
        end: afterLast < hourly.length ? hourly[afterLast].time : null,
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
