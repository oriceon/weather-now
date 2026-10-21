import test from 'node:test';
import assert from 'node:assert/strict';
import { comparedWithYesterday, scalePosition, temperatureColour, temperatureScale, toCelsius } from '../package/contents/code/temperature.mjs';

test('the colour of a temperature goes from violet in frost to red in heat', () => {
    assert.equal(temperatureColour(-30), '#8b7cf6');
    assert.equal(temperatureColour(12), '#45d08f');
    assert.equal(temperatureColour(45), '#ea4848');
});

test('between two colours of the scale, the colour mixes them', () => {
    assert.equal(temperatureColour(16), '#9cd066');
});

// The colour says how warm it is, whatever the unit the numbers are in.
test('Fahrenheit is turned to Celsius for the colour', () => {
    assert.equal(toCelsius(50, 'fahrenheit'), 10);
    assert.equal(toCelsius(10, 'celsius'), 10);
});

test('the bars share one scale, from the coldest night to the warmest day', () => {
    const days = [{ temperatureMin: 4, temperatureMax: 12 }, null, { temperatureMin: -2, temperatureMax: 9 }, { temperatureMin: null, temperatureMax: null }];

    assert.deepEqual(temperatureScale(days), { low: -2, high: 12 });
    assert.equal(scalePosition(5, { low: -2, high: 12 }), 0.5);
    assert.equal(scalePosition(20, { low: -2, high: 12 }), 1);
});

test('days that are all one temperature still get a scale', () => {
    assert.deepEqual(temperatureScale([{ temperatureMin: 5, temperatureMax: 5 }]), { low: 4, high: 6 });
});

test('today is compared with yesterday by the highest temperature of each', () => {
    const days = [{ date: '2026-10-20', temperatureMax: 14.2 }, { date: '2026-10-21', temperatureMax: 17.4 }, { date: '2026-10-22', temperatureMax: 12 }];

    assert.deepEqual(comparedWithYesterday(days, '2026-10-21'), { kind: 'warmer', difference: 3 });
    assert.deepEqual(comparedWithYesterday(days, '2026-10-22'), { kind: 'colder', difference: 5 });
    assert.deepEqual(comparedWithYesterday([{ date: 'a', temperatureMax: 10 }, { date: 'b', temperatureMax: 11.2 }], 'b'), { kind: 'similar', difference: 0 });
    assert.equal(comparedWithYesterday(days, '2026-10-20'), null);
    assert.equal(comparedWithYesterday([{ date: 'a', temperatureMax: null }, { date: 'b', temperatureMax: 11 }], 'b'), null);
});
