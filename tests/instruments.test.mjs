import test from 'node:test';
import assert from 'node:assert/strict';
import { PRESSURE_SCALE, UV_SCALE, beaufort, cloudsTurn, dialPosition, humidityKey, pressureChange, pressureTrend, dewPointKey, uvWindow, visibilityKey } from '../package/contents/code/instruments.mjs';
import { duration } from '../package/contents/code/format.mjs';

const hours = (...pressures) => pressures.map(pressure => ({ pressure }));

test('the pressure rises, falls or stays, by what it does over three hours', () => {
    assert.equal(pressureTrend(hours(1010, 1011, 1012, 1013)), 'rising');
    assert.equal(pressureTrend(hours(1013, 1012, 1011, 1009.5)), 'falling');
    assert.equal(pressureTrend(hours(1013, 1013.2, 1013.4, 1013.6)), 'steady');
});

test('without the pressure of three hours from now, there is no trend', () => {
    assert.equal(pressureTrend(hours(1010, 1011)), null);
    assert.equal(pressureTrend(hours(null, 1011, 1012, 1013)), null);
    assert.equal(pressureTrend([{}, {}, {}, {}]), null);
});

test('a dial puts a value between its ends, and keeps it on the dial', () => {
    assert.equal(dialPosition(6, UV_SCALE), 0.5);
    assert.equal(dialPosition(14, UV_SCALE), 1);
    assert.equal(dialPosition(1010, PRESSURE_SCALE), 0.5);
    assert.equal(dialPosition(950, PRESSURE_SCALE), 0);
});

test('a span of minutes reads as hours and minutes', () => {
    assert.equal(duration(85), '1 h 25 min');
    assert.equal(duration(25), '25 min');
    assert.equal(duration(660), '11 h');
    // Fractions of a minute are rounded first: never "10 h 60 min".
    assert.equal(duration(659.6), '11 h');
});

test('the dew point says how humid the air feels', () => {
    assert.equal(dewPointKey(4), 'dewPoint.dry');
    assert.equal(dewPointKey(12), 'dewPoint.comfortable');
    assert.equal(dewPointKey(17), 'dewPoint.humid');
    assert.equal(dewPointKey(22), 'dewPoint.oppressive');
});

test('the visibility goes from fog to the far hills', () => {
    assert.equal(visibilityKey(400), 'visibility.veryPoor');
    assert.equal(visibilityKey(2500), 'visibility.poor');
    assert.equal(visibilityKey(7000), 'visibility.moderate');
    assert.equal(visibilityKey(15000), 'visibility.good');
    assert.equal(visibilityKey(29660), 'visibility.excellent');
});

test('the Beaufort force goes with the speed of the wind', () => {
    assert.equal(beaufort(0.5), 0);
    assert.equal(beaufort(12), 3);
    assert.equal(beaufort(40), 6);
    assert.equal(beaufort(130), 12);
});

test('the humidity says how dry or damp the air is', () => {
    assert.equal(humidityKey(25), 'humidity.dry');
    assert.equal(humidityKey(45), 'humidity.comfortable');
    assert.equal(humidityKey(70), 'humidity.humid');
    assert.equal(humidityKey(90), 'humidity.veryHumid');
});

const series = (start, field, values) => values.map((value, index) => ({ time: `2026-10-21T${String(start + index).padStart(2, '0')}:00`, [field]: value }));

test('uvWindow gives the hours of today that call for sun protection', () => {
    assert.deepEqual(uvWindow(series(9, 'uvIndex', [2, 3.5, 5, 6, 4, 2.9, 1])), { from: '10:00', until: '14:00' });
    assert.equal(uvWindow(series(18, 'uvIndex', [0, 0, 0])), null);
    assert.equal(uvWindow([]), null);
});

test('pressureChange is the change over the next three hours', () => {
    assert.ok(Math.abs(pressureChange(series(9, 'pressure', [1015, 1014, 1013, 1011.5])) + 3.5) < 1e-9);
    assert.equal(pressureChange(series(9, 'pressure', [1015])), null);
});

test('cloudsTurn tells when a cloudy sky clears, or a clear one clouds over', () => {
    assert.deepEqual(cloudsTurn(series(9, 'cloudCover', [90, 80, 50, 20])), { kind: 'clearing', time: '12:00' });
    assert.deepEqual(cloudsTurn(series(9, 'cloudCover', [10, 40, 75])), { kind: 'clouding', time: '11:00' });
    assert.equal(cloudsTurn(series(9, 'cloudCover', [50, 60, 40])), null);
});
