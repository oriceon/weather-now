import test from 'node:test';
import assert from 'node:assert/strict';
import { millimetres, number, percent, pressure, sentenceCase, temperature, temperatureUnit, uvKey, wind } from '../package/contents/code/format.mjs';

test('temperature rounds to whole degrees', () => {
    assert.equal(temperature(12.6), '13°');
    assert.equal(temperature(12.4), '12°');
    assert.equal(temperature(-3.5), '-3°');
    assert.equal(temperature(-3.6), '-4°');
});

test('temperature never shows a negative zero', () => {
    assert.equal(temperature(-0.4), '0°');
});

test('temperature shows a dash while there is no value', () => {
    assert.equal(temperature(null), '–');
    assert.equal(temperature(undefined), '–');
});

test('temperatureUnit appends the configured unit', () => {
    assert.equal(temperatureUnit(12.6, 'celsius'), '13 °C');
    assert.equal(temperatureUnit(54.7, 'fahrenheit'), '55 °F');
});

test('number uses the decimal separator of the language', () => {
    assert.equal(number(1.94, 1, 'ro'), '1,9');
    assert.equal(number(1.94, 1, 'en'), '1.9');
    assert.equal(number(11.2, 0, 'ro'), '11');
});

test('wind shows whole km/h and one decimal for m/s', () => {
    assert.equal(wind(17, 'kmh', 'ro'), '17 km/h');
    assert.equal(wind(4.72, 'ms', 'ro'), '4,7 m/s');
    assert.equal(wind(4.72, 'ms', 'en'), '4.7 m/s');
    assert.equal(wind(10.6, 'mph', 'en'), '11 mph');
});

test('percent rounds and shows a dash while there is no value', () => {
    assert.equal(percent(75.6), '76%');
    assert.equal(percent(null), '–');
});

test('sentenceCase capitalises only the first letter, diacritics included', () => {
    assert.equal(sentenceCase('marți, 13 octombrie'), 'Marți, 13 octombrie');
    assert.equal(sentenceCase('sâmbătă'), 'Sâmbătă');
    assert.equal(sentenceCase('șapte zile'), 'Șapte zile');
    assert.equal(sentenceCase(''), '');
});

test('millimetres drops the decimal of a whole amount', () => {
    assert.equal(millimetres(11.2, 'ro'), '11,2 mm');
    assert.equal(millimetres(11.2, 'en'), '11.2 mm');
    assert.equal(millimetres(0, 'ro'), '0 mm');
    assert.equal(millimetres(3, 'ro'), '3 mm');
    assert.equal(millimetres(null, 'ro'), '–');
});

test('pressure is shown in whole hectopascals', () => {
    assert.equal(pressure(1017.9), '1018 hPa');
    assert.equal(pressure(undefined), '–');
});

test('uvKey names the exposure category of a UV index', () => {
    const cases = [[0, 'uv.low'], [2.9, 'uv.low'], [3, 'uv.moderate'], [5.9, 'uv.moderate'], [6, 'uv.high'], [8, 'uv.veryHigh'], [10.9, 'uv.veryHigh'], [11, 'uv.extreme']];

    for (const [index, want] of cases) {
        assert.equal(uvKey(index), want, `index ${index}`);
    }
});
