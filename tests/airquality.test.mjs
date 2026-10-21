import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { airQualityUrl, aqiKey, parseAirQuality, pollenLevel } from '../package/contents/code/airquality.mjs';

const recorded = JSON.parse(readFileSync(new URL('./fixtures/airquality-constanta.json', import.meta.url), 'utf8'));

test('the air is asked for at the place rounded to about a kilometre, with the index and every pollen', () => {
    const url = new URL(airQualityUrl(44.18073, 28.63432));

    assert.equal(url.searchParams.get('latitude'), '44.18');
    assert.equal(url.searchParams.get('longitude'), '28.63');
    assert.deepEqual(url.searchParams.get('current').split(','), ['european_aqi', 'pm10', 'pm2_5', 'alder_pollen', 'birch_pollen', 'grass_pollen', 'mugwort_pollen', 'olive_pollen', 'ragweed_pollen']);
});

test('the index is banded as the European Environment Agency bands it', () => {
    assert.equal(aqiKey(15), 'good');
    assert.equal(aqiKey(20), 'good');
    assert.equal(aqiKey(41), 'moderate');
    assert.equal(aqiKey(95), 'veryPoor');
    assert.equal(aqiKey(180), 'extremelyPoor');
});

test('a recorded answer gives the index and the fine dust', () => {
    const air = parseAirQuality(recorded);

    assert.equal(typeof air.aqi, 'number');
    assert.equal(typeof air.pm25, 'number');
});

test('the pollen told of is the one most felt, with its level, not the most numerous', () => {
    const air = parseAirQuality({ current: { european_aqi: 30, grass_pollen: 60, birch_pollen: 90 } });

    assert.deepEqual(air.pollen, { name: 'grass', grains: 60, level: 'high' });
});

test('trees count as high later than grasses and weeds', () => {
    assert.equal(pollenLevel('grass', 60), 'high');
    assert.equal(pollenLevel('birch', 60), 'moderate');
    assert.equal(pollenLevel('ragweed', 3), 'low');
});

// Out of season, and outside Europe, there is no pollen to tell of.
test('less than a grain per m³ is no pollen', () => {
    assert.equal(parseAirQuality({ current: { european_aqi: 30, grass_pollen: 0.4 } }).pollen, null);
    assert.equal(parseAirQuality({ current: { european_aqi: 30 } }).pollen, null);
});

test('an answer without the index is refused', () => {
    assert.throws(() => parseAirQuality({ current: {} }), /Incomplete/);
});

test('the url asks for the pollen of the next four days, hour by hour', () => {
    const url = new URL(airQualityUrl(44.18, 28.63));

    assert.equal(url.searchParams.get('forecast_days'), '4');
    assert.match(url.searchParams.get('hourly'), /birch_pollen/);
});

test('every pollen in the air is listed, the most felt first, and each day of them at its highest', () => {
    const answer = {
        current: { european_aqi: 30, birch_pollen: 120, grass_pollen: 12, ragweed_pollen: 0.4 },
        hourly: {
            time: ['2026-04-21T00:00', '2026-04-21T12:00', '2026-04-22T00:00', '2026-04-22T12:00'],
            birch_pollen: [20, 150, 5, 8],
            grass_pollen: [2, 30, 60, 1],
        },
    };
    const air = parseAirQuality(answer);

    assert.deepEqual(air.pollens.map((pollen) => [pollen.name, pollen.level]), [['birch', 'high'], ['grass', 'moderate']]);
    assert.equal(air.pollen.name, 'birch');
    assert.deepEqual(air.pollenDays.map((day) => [day.date, day.pollens.map((pollen) => `${pollen.name}:${pollen.level}`)]), [
        ['2026-04-21', ['birch:high', 'grass:moderate']],
        ['2026-04-22', ['grass:high', 'birch:low']],
    ]);
});

test('an answer without hours has no days of pollen', () => {
    assert.deepEqual(parseAirQuality({ current: { european_aqi: 30 } }).pollenDays, []);
});
