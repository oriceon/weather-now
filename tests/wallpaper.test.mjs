import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseForecast } from '../package/contents/code/openmeteo.mjs';
import { atTheClock, calmForecast } from '../package/contents/code/wallpaper.mjs';

const forecast = parseForecast(JSON.parse(readFileSync(new URL('./fixtures/forecast-constanta.json', import.meta.url), 'utf8')));

test('the clock moves the time on, and tells day from night by the sun of today', () => {
    const date = forecast.today.date;
    const noon = atTheClock(forecast, `${date}T12:00`).current;
    const late = atTheClock(forecast, `${date}T23:30`).current;

    assert.equal(noon.time, `${date}T12:00`);
    assert.equal(noon.isDay, true);
    assert.equal(late.isDay, false);
    assert.equal(atTheClock(forecast, forecast.today.sunset).current.isDay, false);
    assert.equal(noon.temperature, forecast.current.temperature);
});

test('after midnight the sun of the next day counts, from the days of the answer', () => {
    const tomorrow = forecast.daily[forecast.daily.indexOf(forecast.today) + 1];
    const { current, today } = atTheClock(forecast, `${tomorrow.date}T12:00`);

    assert.equal(today.date, tomorrow.date);
    assert.equal(today.sunrise, tomorrow.sunrise);
    assert.equal(current.isDay, true);
});

test('an answer from days ago lends its sunrise and sunset to the day of the clock', () => {
    const { current, today } = atTheClock(forecast, '2099-06-01T12:00');

    assert.equal(today.date, '2099-06-01');
    assert.equal(today.sunrise, `2099-06-01${forecast.today.sunrise.slice(10)}`);
    assert.equal(current.isDay, true);
});

test('the clock leaves the last answer as it was', () => {
    const before = forecast.current.time;

    atTheClock(forecast, '2099-01-01T00:00');
    assert.equal(forecast.current.time, before);
});

test('without a place, the sky is calm and mostly clear, by day from 7 to 19', () => {
    const morning = calmForecast('2026-10-21T08:15');
    const night = calmForecast('2026-10-21T21:40');

    assert.equal(morning.current.conditionCode, 1);
    assert.equal(morning.current.isDay, true);
    assert.equal(night.current.isDay, false);
    assert.equal(night.today.date, '2026-10-21');
});
