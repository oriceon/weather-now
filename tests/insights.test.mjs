import test from 'node:test';
import assert from 'node:assert/strict';
import { insights } from '../package/contents/code/insights.mjs';

const UNITS = { windUnit: 'kmh', temperatureUnit: 'celsius' };

/** A forecast of `count` hours from 10:00, each with `fields`, for a mild day. */
function forecast(fields = () => ({}), today = {}) {
    const hourly = Array.from({ length: 24 }, (unused, index) => Object.assign({
        time: `2026-10-21T${String((10 + index) % 24).padStart(2, '0')}:00`.replace('2026-10-21T0', index >= 14 ? '2026-10-22T0' : '2026-10-21T0'),
        temperature: 15,
        weatherCode: 1,
        windGusts: 20,
        uvIndex: 2,
    }, fields(index)));

    return { hourly, today: Object.assign({ date: '2026-10-21', temperatureMax: 18, temperatureMin: 10 }, today) };
}

test('a quiet day has nothing to tell', () => {
    assert.deepEqual(insights(forecast(), UNITS, 'en'), []);
});

test('a storm comes first, then the gusts', () => {
    const stormy = forecast((index) => (index === 5 ? { weatherCode: 95, windGusts: 72 } : {}));

    assert.deepEqual(insights(stormy, UNITS, 'en'), ['A thunderstorm possible around 15:00', 'Gusts up to 72 km/h around 15:00']);
});

test('frost, heat, strong sun, fog and a wide swing are told, two at most', () => {
    const cold = forecast((index) => ({ temperature: index === 8 ? -2 : 3 }));

    assert.deepEqual(insights(cold, UNITS, 'ro'), ['Îngheț la noapte, până la -2°']);

    const summer = forecast((index) => ({ uvIndex: index >= 1 && index <= 4 ? 7 : 3 }), { temperatureMax: 33, temperatureMin: 19 });

    assert.deepEqual(insights(summer, UNITS, 'en'), ['Heat, up to 33°', 'Strong sun between 11:00 and 15:00']);
    assert.deepEqual(insights(summer, UNITS, 'en', 3)[2], 'A 14° swing between day and night');
});

test('fog is told with its time', () => {
    assert.deepEqual(insights(forecast((index) => (index === 9 ? { weatherCode: 45 } : {})), UNITS, 'en'), ['Fog around 19:00']);
});

test('gusts are weighed in km/h, whatever unit they come in', () => {
    const knots = forecast((index) => (index === 2 ? { windGusts: 30 } : { windGusts: 10 }));

    assert.deepEqual(insights(knots, { windUnit: 'kn', temperatureUnit: 'celsius' }, 'en'), ['Gusts up to 30 kn around 12:00']);
});
