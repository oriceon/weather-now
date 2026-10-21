import test from 'node:test';
import assert from 'node:assert/strict';
import { addDays, addMinutes, calendarWeeks, clockShown, clockText, hourShown, timeShown, useClock, dateOf, dateRange, dayOfMonth, dayWord, firstOfMonth, fullDate, localNow, resolveFirstDay, timeLabel, weekStart, weekTitle, weekday, weekdayOrder } from '../package/contents/code/dates.mjs';

test('weekday returns the Date#getDay index of an ISO date', () => {
    assert.equal(weekday('2026-10-13'), 2);
    assert.equal(weekday('2026-10-18'), 0);
    assert.equal(weekday('2026-10-19'), 1);
});

test('weekday does not shift with the timezone of the machine', () => {
    const original = process.env.TZ;

    try {
        for (const zone of ['Pacific/Kiritimati', 'America/Los_Angeles', 'Europe/Bucharest']) {
            process.env.TZ = zone;
            assert.equal(weekday('2026-10-13'), 2, zone);
        }
    } finally {
        process.env.TZ = original;
    }
});

test('timeLabel keeps the wall-clock time the API reported for the location', () => {
    assert.equal(timeLabel('2026-10-13T07:17'), '07:17');
    assert.equal(timeLabel('2026-10-13T16:30'), '16:30');
});

test('dateOf strips the time from a timestamp and leaves a date untouched', () => {
    assert.equal(dateOf('2026-10-13T16:30'), '2026-10-13');
    assert.equal(dateOf('2026-10-13'), '2026-10-13');
});

test('fullDate writes the date the way each language does', () => {
    assert.equal(fullDate('2026-10-13', 'ro'), 'marți, 13 octombrie');
    assert.equal(fullDate('2026-10-13', 'en'), 'Tuesday, 13 October');
    assert.equal(fullDate('2026-01-05T09:00', 'ro'), 'luni, 5 ianuarie');
    assert.equal(fullDate('2026-10-13', 'de'), 'Dienstag, 13. Oktober');
    assert.equal(fullDate('2026-10-13', 'es'), 'martes, 13 de octubre');
    assert.equal(fullDate('2026-10-13', 'pl'), 'wtorek, 13 października');
});

const MONDAY = 1;
const SUNDAY = 0;

function daysBetween(first, last) {
    const days = [];

    for (let date = first; date <= last; date = addDays(date, 1)) {
        days.push({ date });
    }

    return days;
}

test('addDays crosses month and year ends', () => {
    assert.equal(addDays('2026-10-13', 1), '2026-10-14');
    assert.equal(addDays('2026-10-13', -1), '2026-10-12');
    assert.equal(addDays('2026-10-30', 3), '2026-11-02');
    assert.equal(addDays('2026-12-31', 1), '2027-01-01');
    assert.equal(addDays('2026-10-13T17:00', 1), '2026-10-14');
});

test('dayOfMonth reads the day number', () => {
    assert.equal(dayOfMonth('2026-10-07'), 7);
    assert.equal(dayOfMonth('2026-10-13T17:00'), 13);
});

test('weekStart finds the first day of the week a date falls in', () => {
    assert.equal(weekStart('2026-10-13', MONDAY), '2026-10-12');
    assert.equal(weekStart('2026-10-12', MONDAY), '2026-10-12');
    assert.equal(weekStart('2026-10-18', MONDAY), '2026-10-12');
    assert.equal(weekStart('2026-10-13', SUNDAY), '2026-10-11');
    assert.equal(weekStart('2026-10-18', SUNDAY), '2026-10-18');
    assert.equal(weekStart('2026-11-01', MONDAY), '2026-10-26');
});

test('weekdayOrder lists the weekdays starting with the first day of the week', () => {
    assert.deepEqual(weekdayOrder(MONDAY), [1, 2, 3, 4, 5, 6, 0]);
    assert.deepEqual(weekdayOrder(SUNDAY), [0, 1, 2, 3, 4, 5, 6]);
    assert.deepEqual(weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5]);
});

test('resolveFirstDay follows the system unless a day is chosen in the settings', () => {
    assert.equal(resolveFirstDay(-1, MONDAY), MONDAY);
    assert.equal(resolveFirstDay(-1, SUNDAY), SUNDAY);
    assert.equal(resolveFirstDay(SUNDAY, MONDAY), SUNDAY);
    assert.equal(resolveFirstDay(MONDAY, SUNDAY), MONDAY);
});

test('resolveFirstDay falls back to Monday when the system reports nothing usable', () => {
    assert.equal(resolveFirstDay(-1, undefined), MONDAY);
    assert.equal(resolveFirstDay(-1, 9), MONDAY);
});

test('calendarWeeks starts with the week of today and puts every day under its weekday', () => {
    const weeks = calendarWeeks(daysBetween('2026-10-07', '2026-10-28'), '2026-10-13T17:00', MONDAY);

    assert.equal(weeks.length, 3);
    assert.deepEqual(weeks[0].map((cell) => cell.date), ['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18']);
    assert.deepEqual(weeks[1].map((cell) => cell.date), ['2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', '2026-10-24', '2026-10-25']);
    assert.equal(weeks[0][0].day.date, '2026-10-12');
});

test('calendarWeeks keeps the cells of days without a forecast, empty', () => {
    const weeks = calendarWeeks(daysBetween('2026-10-13', '2026-10-28'), '2026-10-13', MONDAY);

    assert.equal(weeks[0][0].date, '2026-10-12');
    assert.equal(weeks[0][0].day, null);
    assert.equal(weeks[0][1].day.date, '2026-10-13');
    assert.deepEqual(weeks[2].map((cell) => (cell.day ? cell.day.date : null)), ['2026-10-26', '2026-10-27', '2026-10-28', null, null, null, null]);
});

test('calendarWeeks starts the week on Sunday when asked to', () => {
    const weeks = calendarWeeks(daysBetween('2026-10-07', '2026-10-28'), '2026-10-13', SUNDAY);

    assert.equal(weeks.length, 3);
    assert.equal(weeks[0][0].date, '2026-10-11');
    assert.equal(weeks[0][2].date, '2026-10-13');
});

test('calendarWeeks tells today and the past apart', () => {
    const [week] = calendarWeeks(daysBetween('2026-10-07', '2026-10-28'), '2026-10-13T17:00', MONDAY);

    assert.deepEqual(week.map((cell) => cell.isPast), [true, false, false, false, false, false, false]);
    assert.deepEqual(week.map((cell) => cell.isToday), [false, true, false, false, false, false, false]);
});

test('calendarWeeks shows the whole week even when today is its last day', () => {
    const weeks = calendarWeeks(daysBetween('2026-10-12', '2026-11-02'), '2026-10-18', MONDAY);

    assert.equal(weeks[0][0].date, '2026-10-12');
    assert.equal(weeks[0][6].isToday, true);
    assert.equal(weeks[0][0].day.date, '2026-10-12');
});

test('dayWord says today and tomorrow in words and names the other days', () => {
    const now = '2026-10-13T17:00';

    assert.equal(dayWord('2026-10-13T20:00', now, 'ro'), 'azi');
    assert.equal(dayWord('2026-10-14T03:00', now, 'ro'), 'mâine');
    assert.equal(dayWord('2026-10-15', now, 'ro'), 'joi');
    assert.equal(dayWord('2026-10-13', now, 'en'), 'today');
    assert.equal(dayWord('2026-10-14', now, 'en'), 'tomorrow');
    assert.equal(dayWord('2026-10-15', now, 'en'), 'Thursday');
});

test('dateRange names the month once when both ends are in it', () => {
    assert.equal(dateRange('2026-10-12', '2026-10-18', 'ro'), '12–18 octombrie');
    assert.equal(dateRange('2026-10-12', '2026-10-18', 'en'), '12–18 October');
    assert.equal(dateRange('2026-10-12', '2026-10-18', 'de'), '12.–18. Oktober');
});

test('dateRange names both months when it crosses from one into the next', () => {
    assert.equal(dateRange('2026-10-26', '2026-11-01', 'ro'), '26 octombrie – 1 noiembrie');
    assert.equal(dateRange('2026-12-28', '2027-01-03', 'en'), '28 December – 3 January');
});

test('weekTitle says which week a row of the calendar is', () => {
    const weeks = calendarWeeks(daysBetween('2026-10-07', '2026-10-28'), '2026-10-13T17:00', MONDAY);

    assert.equal(weekTitle(weeks[0], 0, 'ro'), 'Săptămâna aceasta · 12–18 octombrie');
    assert.equal(weekTitle(weeks[1], 1, 'ro'), 'Săptămâna viitoare · 19–25 octombrie');
    assert.equal(weekTitle(weeks[2], 2, 'ro'), '26 octombrie – 1 noiembrie');
    assert.equal(weekTitle(weeks[0], 0, 'en'), 'This week · 12–18 October');
    assert.equal(weekTitle(weeks[1], 1, 'en'), 'Next week · 19–25 October');
});

test('firstOfMonth writes the first day of a month as each language does', () => {
    assert.equal(firstOfMonth('2026-11-01', 'ro'), '1 nov.');
    assert.equal(firstOfMonth('2026-11-01', 'fr'), '1er nov.');
    assert.equal(firstOfMonth('2026-11-01', 'de'), '1. Nov.');
});

test('localNow is the clock of the place, from the offset of the forecast', () => {
    assert.equal(localNow(10800, Date.UTC(2026, 9, 21, 21, 5)), '2026-10-22T00:05');
    assert.equal(localNow(-14400, Date.UTC(2026, 9, 21, 2, 30)), '2026-10-20T22:30');
});

test('addMinutes moves a time of the day, across midnight and back', () => {
    assert.equal(addMinutes('2026-10-13T17:15', -15), '2026-10-13T17:00');
    assert.equal(addMinutes('2026-10-13T23:30', 60), '2026-10-14T00:30');
    assert.equal(addMinutes('2026-10-14T00:00', -60), '2026-10-13T23:00');
});

test('the clock tells the time of the place, to the second, in 24 or 12 hours', () => {
    const now = Date.UTC(2026, 9, 21, 13, 45, 9);

    assert.equal(clockText(10800, false, ['AM', 'PM'], now), '16:45:09');
    assert.equal(clockText(10800, true, ['AM', 'PM'], now), '4:45:09 PM');
    assert.equal(clockText(-13 * 3600, true, ['a.m.', 'p.m.'], now), '12:45:09 a.m.');
    assert.equal(clockText(-13 * 3600 - 2700, false, ['AM', 'PM'], now), '00:00:09');
});

// Where the regional settings keep twelve hours, as in the United States, every time follows them.
test('the times read as the clock of the user writes them, in 24 hours or in 12', () => {
    assert.equal(clockShown('17:05'), '17:05');
    assert.equal(hourShown('2026-10-13T18:00'), '18');

    useClock(true, ['AM', 'PM']);

    try {
        assert.equal(clockShown('17:05'), '5:05 PM');
        assert.equal(clockShown('17:00'), '5 PM');
        assert.equal(clockShown('00:30'), '12:30 AM');
        assert.equal(clockShown('12:00'), '12 PM');
        assert.equal(clockShown('24:00'), '12 AM');
        assert.equal(timeShown('2026-10-13T06:42'), '6:42 AM');
        assert.equal(hourShown('2026-10-13T18:00'), '6 PM');
        assert.equal(clockText(10800, undefined, undefined, Date.UTC(2026, 9, 21, 13, 45, 9)), '4:45:09 PM');
    } finally {
        useClock(false);
    }
});
