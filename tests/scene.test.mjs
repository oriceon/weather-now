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
    assert.ok(Math.abs(toKmh(10, 'kn') - 18.52) < 0.01);
    assert.ok(Math.abs(toKmh(10, 'kt') - 18.52) < 0.01);
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
    assert.ok(scene({ isDay: false, moonIllumination: 0 }).stars > 300);
    assert.ok(scene({ isDay: false }).twinkles > 20);
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

test('a rainbow shows after rain showers, by day, with the sun low', () => {
    assert.equal(scene({ weatherCode: 81, sunProgress: 0.15 }).rainbow, true);
    assert.equal(scene({ weatherCode: 81, sunProgress: 0.5 }).rainbow, false);
    assert.equal(scene({ weatherCode: 81, sunProgress: 0.85, isDay: false }).rainbow, false);
    assert.equal(scene({ weatherCode: 85, sunProgress: 0.15 }).rainbow, false);
});

test('a clear night has shooting stars, and the Milky Way while the moon is dim', () => {
    assert.equal(scene({ isDay: false }).shootingStars, true);
    assert.equal(scene({ isDay: false, quality: 'reduced' }).shootingStars, false);
    assert.equal(scene({ isDay: false, moonIllumination: 0.1 }).milkyWay, true);
    assert.equal(scene({ isDay: false, moonIllumination: 0.9 }).milkyWay, false);
    assert.equal(scene({ isDay: false, weatherCode: 3, moonIllumination: 0.1 }).milkyWay, false);
});

test('a strong wind shows as streaks, and as leaves where no snow falls', () => {
    assert.equal(scene({ windKmh: 20 }).streaks, 0);
    assert.ok(scene({ windKmh: 45 }).streaks > scene({ windKmh: 32 }).streaks);
    assert.ok(scene({ windKmh: 45 }).leaves > 0);
    assert.equal(scene({ windKmh: 45, weatherCode: 73 }).leaves, 0);
});

test('frost covers the edges below freezing, and heat haze rises in the heat of the day', () => {
    assert.equal(scene({ celsius: -3 }).frost, true);
    assert.equal(scene({ celsius: 4 }).frost, false);
    assert.equal(scene({ celsius: 33 }).heat, true);
    assert.equal(scene({ celsius: 33, isDay: false }).heat, false);
});

test('falling snow piles up, the more the harder it falls', () => {
    assert.equal(scene({ weatherCode: CLEAR }).snowCover, 0);
    assert.ok(scene({ weatherCode: 75 }).snowCover > scene({ weatherCode: 71 }).snowCover);
});

test('the aurora is painted at night, through a clear or a broken sky, as high as it can be seen', () => {
    const night = { isDay: false, windKmh: 5, quality: 'full' };

    assert.equal(sceneFor({ ...night, weatherCode: 0, aurora: 'overhead' }).aurora, 'overhead');
    assert.equal(sceneFor({ ...night, weatherCode: 2, aurora: 'horizon' }).aurora, 'horizon');
    assert.equal(sceneFor({ ...night, weatherCode: 3, aurora: 'overhead' }).aurora, 'none');
    assert.equal(sceneFor({ ...night, weatherCode: 61, aurora: 'overhead' }).aurora, 'none');
    assert.equal(sceneFor({ ...night, weatherCode: 0, aurora: 'camera' }).aurora, 'none');
    assert.equal(sceneFor({ isDay: true, windKmh: 5, quality: 'full', weatherCode: 0, aurora: 'overhead' }).aurora, 'none');
    assert.equal(sceneFor({ ...night, weatherCode: 0 }).aurora, 'none');
});

test('a bright moon washes out the faint stars', () => {
    assert.ok(scene({ isDay: false, moonIllumination: 1 }).stars < scene({ isDay: false, moonIllumination: 0 }).stars * 0.6);
});

test('an overcast sky, and one that rains or snows, is covered by a deck of cloud; a broken one is not', () => {
    assert.equal(scene({ weatherCode: OVERCAST }).deck, 1);
    assert.ok(scene({ weatherCode: 63 }).deck > 0.5);
    assert.equal(scene({ weatherCode: PARTLY_CLOUDY }).deck, 0);
    assert.equal(scene({ weatherCode: CLEAR }).deck, 0);
});

test('rain runs down the glass, the more the harder it falls; nothing else does', () => {
    assert.ok(scene({ weatherCode: 65 }).glassDrops > scene({ weatherCode: 61 }).glassDrops);
    assert.ok(scene({ weatherCode: 61 }).glassDrops >= 4);
    assert.equal(scene({ weatherCode: 73 }).glassDrops, 0);
    assert.equal(scene({ weatherCode: CLEAR }).glassDrops, 0);
});
