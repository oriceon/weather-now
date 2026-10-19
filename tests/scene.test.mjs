import test from 'node:test';
import assert from 'node:assert/strict';
import { celestial, noise, sceneFor, toKmh, twilight } from '../package/contents/code/scene.mjs';

const SUNRISE = '2026-10-13T07:17';
const SUNSET = '2026-10-13T18:25';

const CLEAR = 0;
const MAINLY_CLEAR = 1;
const PARTLY_CLOUDY = 2;
const OVERCAST = 3;
const SHOWERS = 81;
const FOG = 45;
const RAIN_LIGHT = 61;
const RAIN_HEAVY = 65;
const SNOW = 73;
const STORM = 95;

function scene(overrides) {
    return sceneFor({ weatherCode: CLEAR, isDay: true, windKmh: 0, quality: 'full', ...overrides });
}

test('noise is a repeatable value between 0 and 1', () => {
    for (let index = 0; index < 200; index++) {
        const value = noise(index, 3);

        assert.ok(value >= 0 && value < 1, `index ${index}`);
        assert.equal(noise(index, 3), value);
    }
});

test('noise spreads over the whole range and differs per salt', () => {
    const values = Array.from({ length: 200 }, (unused, index) => noise(index, 1));

    assert.ok(Math.min(...values) < 0.1);
    assert.ok(Math.max(...values) > 0.9);
    assert.notEqual(noise(5, 1), noise(5, 2));
});

test('toKmh converts the wind units the widget can be set to', () => {
    assert.equal(toKmh(17, 'kmh'), 17);
    assert.equal(toKmh(10, 'ms'), 36);
    assert.ok(Math.abs(toKmh(10, 'mph') - 16.09) < 0.01);
});

test('celestial tracks the sun from sunrise (0) to sunset (1)', () => {
    assert.deepEqual(celestial(SUNRISE, SUNRISE, SUNSET), { isDay: true, progress: 0 });
    assert.deepEqual(celestial('2026-10-13T12:51', SUNRISE, SUNSET), { isDay: true, progress: 0.5 });
    assert.equal(celestial('2026-10-13T18:24', SUNRISE, SUNSET).isDay, true);
});

test('celestial tracks the night from sunset (0) to the next sunrise (1)', () => {
    assert.deepEqual(celestial(SUNSET, SUNRISE, SUNSET), { isDay: false, progress: 0 });
    assert.deepEqual(celestial('2026-10-13T00:51', SUNRISE, SUNSET), { isDay: false, progress: 0.5 });

    const beforeSunrise = celestial('2026-10-13T07:00', SUNRISE, SUNSET);

    assert.equal(beforeSunrise.isDay, false);
    assert.ok(beforeSunrise.progress > 0.95 && beforeSunrise.progress < 1);
});

test('twilight peaks at sunrise and sunset and is gone 45 minutes away', () => {
    assert.equal(twilight(SUNRISE, SUNRISE, SUNSET), 1);
    assert.equal(twilight(SUNSET, SUNRISE, SUNSET), 1);
    assert.equal(twilight('2026-10-13T12:00', SUNRISE, SUNSET), 0);
    assert.equal(twilight('2026-10-13T19:10', SUNRISE, SUNSET), 0);
    assert.equal(twilight('2026-10-13T02:00', SUNRISE, SUNSET), 0);
    assert.ok(Math.abs(twilight('2026-10-13T18:02', SUNRISE, SUNSET) - 0.49) < 0.02);
    assert.ok(Math.abs(twilight('2026-10-13T07:40', SUNRISE, SUNSET) - 0.49) < 0.02);
});

test('a clear day has the sun and nothing else', () => {
    const result = scene({});

    assert.equal(result.clouds, 0);
    assert.equal(result.rain, 0);
    assert.equal(result.snow, 0);
    assert.equal(result.stars, 0);
    assert.equal(result.fog, false);
    assert.equal(result.lightning, false);
    assert.equal(result.celestialOpacity, 1);
});

test('the sky fills with clouds from clear to overcast', () => {
    const clouds = [CLEAR, MAINLY_CLEAR, PARTLY_CLOUDY, OVERCAST].map((weatherCode) => scene({ weatherCode }).clouds);

    assert.deepEqual(clouds.slice().sort((a, b) => a - b), clouds);
    assert.equal(new Set(clouds).size, 4);
});

test('an overcast sky is grey and hides the sun almost completely', () => {
    const result = scene({ weatherCode: OVERCAST });

    assert.equal(result.cloudTone, 'grey');
    assert.ok(result.celestialOpacity < 0.3);
});

test('fair-weather clouds are white and leave the sun out', () => {
    const result = scene({ weatherCode: PARTLY_CLOUDY });

    assert.equal(result.cloudTone, 'white');
    assert.ok(result.celestialOpacity > 0.8);
});

test('rain brings drops and clouds, more drops when it is heavy', () => {
    const light = scene({ weatherCode: RAIN_LIGHT });
    const heavy = scene({ weatherCode: RAIN_HEAVY });

    assert.ok(light.rain > 0);
    assert.ok(heavy.rain > light.rain);
    assert.equal(light.snow, 0);
    assert.ok(light.clouds >= 4);
});

test('showers leave more of the sun than steady rain', () => {
    assert.ok(scene({ weatherCode: SHOWERS }).celestialOpacity > scene({ weatherCode: RAIN_HEAVY }).celestialOpacity);
});

test('snow brings flakes instead of drops', () => {
    const result = scene({ weatherCode: SNOW });

    assert.ok(result.snow > 0);
    assert.equal(result.rain, 0);
});

test('a thunderstorm has lightning, rain and dark clouds', () => {
    const result = scene({ weatherCode: STORM });

    assert.equal(result.lightning, true);
    assert.ok(result.rain > 0);
    assert.equal(result.cloudTone, 'dark');
});

test('fog is drawn only for fog', () => {
    assert.equal(scene({ weatherCode: FOG }).fog, true);
    assert.equal(scene({ weatherCode: OVERCAST }).fog, false);
});

test('stars come out on a clear night and stay behind an overcast one', () => {
    assert.ok(scene({ isDay: false }).stars > 20);
    assert.equal(scene({ isDay: false, weatherCode: OVERCAST }).stars, 0);
    assert.ok(scene({ isDay: false, weatherCode: PARTLY_CLOUDY }).stars < scene({ isDay: false }).stars);
    assert.ok(scene({ isDay: false, weatherCode: PARTLY_CLOUDY }).stars > 0);
});

test('wind slants the rain, up to a limit', () => {
    assert.equal(scene({ weatherCode: RAIN_LIGHT, windKmh: 0 }).slant, 0);
    assert.ok(scene({ weatherCode: RAIN_LIGHT, windKmh: 20 }).slant < scene({ weatherCode: RAIN_LIGHT, windKmh: 50 }).slant);
    assert.equal(scene({ weatherCode: RAIN_LIGHT, windKmh: 90 }).slant, scene({ weatherCode: RAIN_LIGHT, windKmh: 300 }).slant);
    assert.ok(scene({ weatherCode: RAIN_LIGHT, windKmh: 300 }).slant <= 35);
});

test('wind makes the clouds cross the sky faster', () => {
    assert.ok(scene({ windKmh: 50 }).driftSeconds < scene({ windKmh: 2 }).driftSeconds);
});

test('a small change of wind does not change the pace of the clouds', () => {
    assert.equal(scene({ windKmh: 10 }).driftSeconds, scene({ windKmh: 14 }).driftSeconds);
});

test('the reduced quality draws about half of everything that moves', () => {
    const full = scene({ weatherCode: RAIN_HEAVY });
    const reduced = scene({ weatherCode: RAIN_HEAVY, quality: 'reduced' });

    assert.ok(reduced.rain > 0);
    assert.ok(reduced.rain <= full.rain / 2 + 1);
    assert.ok(reduced.clouds < full.clouds);
});
