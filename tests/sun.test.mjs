import test from 'node:test';
import assert from 'node:assert/strict';
import { daylightLeft, sunEvents } from '../package/contents/code/sun.mjs';

const days = [
    { sunrise: '2026-10-13T07:17', sunset: '2026-10-13T18:25' },
    { sunrise: '2026-10-14T07:18', sunset: '2026-10-14T18:23' },
];
const hours = Array.from({ length: 24 }, (_, index) => ({ time: `2026-10-13T${String(17 + index).padStart(2, '0')}:00` }))
    .map((hour, index) => (index < 7 ? hour : { time: `2026-10-14T${String(index - 7).padStart(2, '0')}:00` }));

test('sunset and sunrise are placed among the hours, by the minute', () => {
    assert.deepEqual(sunEvents(days, hours), [
        { kind: 'sunset', time: '2026-10-13T18:25', column: 1 + 25 / 60 },
        { kind: 'sunrise', time: '2026-10-14T07:18', column: 14 + 18 / 60 },
    ]);
});

test('a sunrise or sunset outside the hours is left out', () => {
    assert.deepEqual(sunEvents(days, hours.slice(0, 1)), []);
    assert.deepEqual(sunEvents(days, []), []);
});

test('the daylight left counts down to sunset, and is none at night', () => {
    assert.equal(daylightLeft('2026-10-13T17:00', days[0].sunrise, days[0].sunset), 85);
    assert.equal(daylightLeft('2026-10-13T19:00', days[0].sunrise, days[0].sunset), 0);
    assert.equal(daylightLeft('2026-10-13T06:00', days[0].sunrise, days[0].sunset), 0);
});
