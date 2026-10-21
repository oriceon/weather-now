import test from 'node:test';
import assert from 'node:assert/strict';
import { mixHex, skyGradient } from '../package/contents/code/sky.mjs';

const HEX = /^#[0-9a-f]{6}$/;

test('every weather family has a day and a night gradient', () => {
    for (const family of ['clear', 'cloudy', 'fog', 'rain', 'snow', 'storm']) {
        for (const isDay of [true, false]) {
            const { top, bottom } = skyGradient(family, isDay);

            assert.match(top, HEX, `${family} day=${isDay} top`);
            assert.match(bottom, HEX, `${family} day=${isDay} bottom`);
        }
    }
});

test('night is drawn differently from day', () => {
    assert.notDeepEqual(skyGradient('clear', true), skyGradient('clear', false));
});

test('an unknown family is drawn like a cloudy sky', () => {
    assert.deepEqual(skyGradient('plasma-storm', true), skyGradient('cloudy', true));
});

const red = (hex) => parseInt(hex.slice(1, 3), 16);

test('mixHex blends two colours channel by channel', () => {
    assert.equal(mixHex('#000000', '#ffffff', 0), '#000000');
    assert.equal(mixHex('#000000', '#ffffff', 1), '#ffffff');
    assert.equal(mixHex('#000000', '#ffffff', 0.5), '#808080');
    assert.equal(mixHex('#102030', '#304050', 0.5), '#203040');
});

test('mixHex clamps the amount', () => {
    assert.equal(mixHex('#000000', '#ffffff', -1), '#000000');
    assert.equal(mixHex('#000000', '#ffffff', 7), '#ffffff');
});

test('without twilight the sky keeps its plain colours', () => {
    assert.deepEqual(skyGradient('clear', true, 0), skyGradient('clear', true));
});

test('twilight warms the horizon of a clear sky', () => {
    assert.ok(red(skyGradient('clear', true, 1).bottom) > red(skyGradient('clear', true, 0).bottom));
    assert.ok(red(skyGradient('clear', true, 1).bottom) > red(skyGradient('clear', true, 0.5).bottom));
});

test('twilight barely shows through a storm', () => {
    const clearShift = red(skyGradient('clear', true, 1).bottom) - red(skyGradient('clear', true, 0).bottom);
    const stormShift = red(skyGradient('storm', true, 1).bottom) - red(skyGradient('storm', true, 0).bottom);

    assert.ok(stormShift < clearShift / 2);
});

test('every sky has a middle colour between its top and its horizon', () => {
    assert.match(skyGradient('clear', true).middle, HEX);
    assert.match(skyGradient('storm', false).middle, HEX);
});

const blue = (hex) => parseInt(hex.slice(5, 7), 16);

// Partly cloudy was the grey of an overcast sky: its clouds are painted on a blue one now.
test('a partly cloudy sky stays blue, and an overcast one is grey', () => {
    const partly = skyGradient('cloudy', true, 0, { weatherCode: 2 });
    const overcast = skyGradient('cloudy', true, 0, { weatherCode: 3 });

    assert.ok(blue(partly.top) - red(partly.top) > 120, partly.top);
    assert.ok(blue(overcast.top) - red(overcast.top) < 40, overcast.top);
});

test('a clear sky deepens to a full blue as the sun climbs, and is warm at the horizon with the sun low', () => {
    const low = skyGradient('clear', true, 0, { sunHeight: 0.1 });
    const high = skyGradient('clear', true, 0, { sunHeight: 1 });

    assert.ok(red(low.bottom) > red(high.bottom));
    assert.ok(red(high.top) < red(low.top));
});
