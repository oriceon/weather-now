import test from 'node:test';
import assert from 'node:assert/strict';
import { STRINGS } from '../package/contents/code/i18n.mjs';
import { CODES, conditionKey, group, iconName, intensity, precipitationKind } from '../package/contents/code/wmo.mjs';

test('conditionKey maps WMO codes to a translation key', () => {
    const cases = [
        [0, 'condition.clear'], [1, 'condition.mainlyClear'], [2, 'condition.partlyCloudy'], [3, 'condition.overcast'],
        [45, 'condition.fog'], [53, 'condition.drizzle'], [63, 'condition.rain'], [65, 'condition.rainHeavy'],
        [67, 'condition.freezingRain'], [73, 'condition.snow'], [81, 'condition.showers'], [86, 'condition.snowShowers'],
        [95, 'condition.thunderstorm'], [99, 'condition.thunderstormHail'],
    ];

    for (const [code, want] of cases) {
        assert.equal(conditionKey(code), want, `code ${code}`);
    }
});

test('every WMO code Open-Meteo documents is known', () => {
    const documented = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];

    assert.deepEqual(CODES.slice().sort((a, b) => a - b), documented);
});

test('every known code has a description in every language', () => {
    for (const code of CODES) {
        for (const language of Object.keys(STRINGS)) {
            assert.ok(STRINGS[language][conditionKey(code)], `code ${code} in ${language}`);
        }
    }
});

test('iconName picks the night variant only where the theme has one', () => {
    const cases = [
        [0, true, 'weather-clear'], [0, false, 'weather-clear-night'],
        [1, true, 'weather-few-clouds'], [1, false, 'weather-few-clouds-night'],
        [2, true, 'weather-clouds'], [2, false, 'weather-clouds-night'],
        [3, true, 'weather-many-clouds'], [3, false, 'weather-many-clouds'],
        [45, true, 'weather-fog'], [63, true, 'weather-showers'], [63, false, 'weather-showers'],
        [80, true, 'weather-showers-scattered-day'], [80, false, 'weather-showers-scattered-night'],
        [81, true, 'weather-showers-day'], [82, false, 'weather-showers-night'],
        [85, true, 'weather-snow-scattered-day'], [86, false, 'weather-snow-scattered-night'],
        [73, true, 'weather-snow'], [66, true, 'weather-freezing-rain'],
        [95, true, 'weather-storm'], [99, false, 'weather-hail'],
    ];

    for (const [code, isDay, want] of cases) {
        assert.equal(iconName(code, isDay), want, `code ${code} day=${isDay}`);
    }
});

test('group buckets codes into the families the background is drawn for', () => {
    const cases = [
        [0, 'clear'], [1, 'clear'], [2, 'cloudy'], [3, 'cloudy'], [48, 'fog'], [55, 'rain'], [61, 'rain'],
        [82, 'rain'], [66, 'rain'], [75, 'snow'], [85, 'snow'], [95, 'storm'], [96, 'storm'],
    ];

    for (const [code, want] of cases) {
        assert.equal(group(code), want, `code ${code}`);
    }
});

test('an unknown or missing code degrades to a neutral answer instead of throwing', () => {
    for (const code of [999, null, undefined]) {
        assert.equal(conditionKey(code), 'condition.unknown');
        assert.equal(iconName(code, true), 'weather-none-available');
        assert.equal(group(code), 'cloudy');
    }
});

test('precipitationKind tells rain from snow and from dry weather', () => {
    const cases = [
        [0, null], [3, null], [45, null], [51, 'rain'], [63, 'rain'], [67, 'rain'], [82, 'rain'], [95, 'rain'], [99, 'rain'],
        [71, 'snow'], [77, 'snow'], [86, 'snow'], [999, null], [undefined, null],
    ];

    for (const [code, want] of cases) {
        assert.equal(precipitationKind(code), want, `code ${code}`);
    }
});

test('intensity is zero for dry weather and stays between 0 and 1', () => {
    for (const code of CODES) {
        const value = intensity(code);

        assert.ok(value >= 0 && value <= 1, `code ${code}`);
        assert.equal(value === 0, precipitationKind(code) === null, `code ${code}`);
    }

    assert.equal(intensity(999), 0);
});

test('intensity grows from light to heavy within each kind of precipitation', () => {
    for (const [light, moderate, heavy] of [[51, 53, 55], [61, 63, 65], [71, 73, 75], [80, 81, 82]]) {
        assert.ok(intensity(light) < intensity(moderate), `${light} < ${moderate}`);
        assert.ok(intensity(moderate) < intensity(heavy), `${moderate} < ${heavy}`);
    }
});
