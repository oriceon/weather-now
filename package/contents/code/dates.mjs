import { dayLong, monthLong, t } from './i18n.mjs';

const DAY_MS = 24 * 60 * 60 * 1000;
const MONDAY = 1;

/**
 * Open-Meteo reports wall-clock times of the forecast location ("2026-10-13T16:30").
 * They are read as text and never through the local timezone of the machine.
 */
function parts(iso) {
    const text = String(iso);

    return { year: Number(text.slice(0, 4)), month: Number(text.slice(5, 7)), day: Number(text.slice(8, 10)) };
}

function toUtc(iso) {
    const { year, month, day } = parts(iso);

    return Date.UTC(year, month - 1, day);
}

function isWeekday(value) {
    return Number.isInteger(value) && value >= 0 && value <= 6;
}

export function dateOf(iso) {
    return String(iso).slice(0, 10);
}

export function timeLabel(iso) {
    return String(iso).slice(11, 16);
}

export function dayOfMonth(iso) {
    return parts(iso).day;
}

export function monthOf(iso) {
    return parts(iso).month;
}

/** Index of the weekday, Sunday being 0, as Date#getDay counts. */
export function weekday(iso) {
    return new Date(toUtc(iso)).getUTCDay();
}

export function addDays(iso, count) {
    return new Date(toUtc(iso) + count * DAY_MS).toISOString().slice(0, 10);
}

export function weekStart(iso, firstDayOfWeek) {
    return addDays(iso, -((weekday(iso) - firstDayOfWeek + 7) % 7));
}

export function weekdayOrder(firstDayOfWeek) {
    return [0, 1, 2, 3, 4, 5, 6].map((offset) => (firstDayOfWeek + offset) % 7);
}

/** The first day of the week: the one chosen in the settings, else the one of the system, else Monday. */
export function resolveFirstDay(setting, systemFirstDay) {
    if (isWeekday(setting)) {
        return setting;
    }

    return isWeekday(systemFirstDay) ? systemFirstDay : MONDAY;
}

/**
 * Lays the days out as calendar weeks, from the week of today to the last day there is.
 * Every week has seven cells; a cell without a forecast has `day: null`.
 */
export function calendarWeeks(days, nowIso, firstDayOfWeek) {
    const today = dateOf(nowIso);
    const byDate = {};
    let lastDate = today;

    for (const day of days) {
        byDate[day.date] = day;

        if (day.date > lastDate) {
            lastDate = day.date;
        }
    }

    const weeks = [];

    for (let start = weekStart(today, firstDayOfWeek); start <= lastDate; start = addDays(start, 7)) {
        const week = [];

        for (let offset = 0; offset < 7; offset++) {
            const date = addDays(start, offset);

            week.push({ date, day: byDate[date] || null, isToday: date === today, isPast: date < today });
        }

        weeks.push(week);
    }

    return weeks;
}

/** "today", "tomorrow" or the name of the weekday, for use inside a sentence. */
export function dayWord(iso, nowIso, language) {
    const date = dateOf(iso);
    const today = dateOf(nowIso);

    if (date === today) {
        return t(language, 'day.todayWord');
    }

    return date === addDays(today, 1) ? t(language, 'day.tomorrow') : dayLong(language, weekday(date));
}

export function fullDate(iso, language) {
    const { month, day } = parts(iso);

    return `${dayLong(language, weekday(iso))}, ${day} ${monthLong(language, month)}`;
}

/** "12–18 octombrie", or "26 octombrie – 1 noiembrie" when the days are in two months. */
export function dateRange(firstIso, lastIso, language) {
    const first = parts(firstIso);
    const last = parts(lastIso);

    if (first.month === last.month) {
        return `${first.day}–${last.day} ${monthLong(language, last.month)}`;
    }

    return `${first.day} ${monthLong(language, first.month)} – ${last.day} ${monthLong(language, last.month)}`;
}

/** The heading of a week of calendarWeeks(), `index` being its place among them: the week of today is 0. */
export function weekTitle(week, index, language) {
    const range = dateRange(week[0].date, week[week.length - 1].date, language);
    const names = ['week.this', 'week.next'];

    return index < names.length ? `${t(language, names[index])} · ${range}` : range;
}
