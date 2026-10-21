import { dayLong, monthLong, monthShort, t } from './i18n.mjs';

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

/** "2026-10-13T17:05" as "17:05": the time of the day, in 24 hours, to compare or to read further. */
export function timeLabel(iso) {
    return String(iso).slice(11, 16);
}

/**
 * How the clock of the user writes the time: in 24 hours, or in 12 with the names of the halves of
 * the day, as the regional settings of the computer have it. Qt is at hand in a module that runs in
 * Plasma, already as it loads, so that every text, bound before any setting could be passed down,
 * follows them; in the tests, 24 hours, unless useClock() says otherwise.
 */
const clockStyle = (() => {
    try {
        const locale = Qt.locale();

        // Its short format of the time, "h:mm AP" or "HH:mm"; 1 is Locale.ShortFormat.
        return { twelveHour: /a/i.test(locale.timeFormat(1)), dayHalves: [locale.amText, locale.pmText] };
    } catch (error) {
        return { twelveHour: false, dayHalves: ['AM', 'PM'] };
    }
})();

/** For the tests: the clock in 12 hours, with these names of the halves of the day, or in 24. */
export function useClock(twelveHour, dayHalves = ['AM', 'PM']) {
    clockStyle.twelveHour = twelveHour;
    clockStyle.dayHalves = dayHalves;
}

/**
 * "17:05" as the clock of the user writes it: "17:05", or "5:05 PM", and a whole hour "5 PM", as the
 * columns of hours read best; "24:00", the end of a day, is midnight, "12 AM".
 */
export function clockShown(time) {
    if (!clockStyle.twelveHour) {
        return time;
    }

    const hours = Number(time.slice(0, 2)) % 24;
    const minutes = time.slice(3, 5);

    return `${hours % 12 || 12}${minutes === '00' ? '' : `:${minutes}`} ${clockStyle.dayHalves[hours < 12 ? 0 : 1]}`;
}

/** The time of an ISO moment, as the clock of the user writes it; see clockShown(). */
export function timeShown(iso) {
    return clockShown(timeLabel(iso));
}

/** The hour alone, for the scale of a chart: "18", or "6 PM". */
export function hourShown(iso) {
    return clockStyle.twelveHour ? clockShown(`${timeLabel(iso).slice(0, 2)}:00`) : timeLabel(iso).slice(0, 2);
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

/** "2026-10-13T17:00" moved by `count` minutes, in the same form. */
export function addMinutes(iso, count) {
    return new Date(Date.parse(`${String(iso).slice(0, 16)}:00Z`) + count * 60000).toISOString().slice(0, 16);
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

/** "marți, 21 octombrie", as each language writes it. */
export function fullDate(iso, language) {
    const { month, day } = parts(iso);

    return t(language, 'date.full', { weekday: dayLong(language, weekday(iso)), day, month: monthLong(language, month) });
}

/** "1 nov.", "1er nov." in French: the first day of the month of `iso`, with the short name of the month. */
export function firstOfMonth(iso, language) {
    return t(language, 'date.firstOfMonth', { month: monthShort(language, parts(iso).month) });
}

/** "12–18 octombrie", or "26 octombrie – 1 noiembrie" when the days are in two months. */
export function dateRange(firstIso, lastIso, language) {
    const first = parts(firstIso);
    const last = parts(lastIso);

    if (first.month === last.month) {
        return t(language, 'date.rangeOneMonth', { first: first.day, last: last.day, month: monthLong(language, last.month) });
    }

    return t(language, 'date.range', { first: first.day, firstMonth: monthLong(language, first.month), last: last.day, lastMonth: monthLong(language, last.month) });
}

/** The heading of a week of calendarWeeks(), `index` being its place among them: the week of today is 0. */
export function weekTitle(week, index, language) {
    const range = dateRange(week[0].date, week[week.length - 1].date, language);
    const names = ['week.this', 'week.next'];

    return index < names.length ? `${t(language, names[index])} · ${range}` : range;
}

/**
 * The clock of the place, "16:45:09", or "4:45:09 PM" where the regional settings keep twelve hours,
 * `dayHalves` naming the two halves of the day, from the clock of the computer and the offset of the place.
 */
export function clockText(utcOffsetSeconds, twelveHour = clockStyle.twelveHour, dayHalves = clockStyle.dayHalves, now = Date.now()) {
    const time = new Date(now + utcOffsetSeconds * 1000).toISOString().slice(11, 19);

    if (!twelveHour) {
        return time;
    }

    const hours = Number(time.slice(0, 2));

    return `${hours % 12 || 12}${time.slice(2)} ${dayHalves[hours < 12 ? 0 : 1]}`;
}

/** The wall-clock time at the place now, "2026-10-21T18:05", from the clock of the computer and the offset of the place. */
export function localNow(utcOffsetSeconds, now = Date.now()) {
    return new Date(now + utcOffsetSeconds * 1000).toISOString().slice(0, 16);
}
