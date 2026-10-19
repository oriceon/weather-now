import test from 'node:test';
import assert from 'node:assert/strict';
import { rainSentence, rainSummary } from '../package/contents/code/rain.mjs';

const NOW = '2026-10-13T17:00';
const RAIN = 61;
const SNOW = 73;
const DRY = 3;

/** One entry per hour starting at NOW (a Tuesday), the way parseForecast returns them. */
function hours(amounts, wetCode = RAIN) {
    return amounts.map((precipitation, index) => {
        const moment = new Date(Date.UTC(2026, 9, 13, 17 + index));

        return {
            time: moment.toISOString().slice(0, 16),
            precipitation,
            weatherCode: precipitation > 0 ? wetCode : DRY,
        };
    });
}

function repeated(amount, count) {
    return new Array(count).fill(amount);
}

test('rainSummary reports a dry period', () => {
    assert.deepEqual(rainSummary(hours([0, 0, 0, 0])), { kind: 'none', snow: false, start: null, end: null });
    assert.deepEqual(rainSummary([]), { kind: 'none', snow: false, start: null, end: null });
});

test('rainSummary finds when the next precipitation starts and stops', () => {
    assert.deepEqual(rainSummary(hours([0, 1, 1.5, 0.1, 0, 0, 0.4])), {
        kind: 'later',
        snow: false,
        start: '2026-10-13T18:00',
        end: '2026-10-13T21:00',
    });
});

test('rainSummary reports precipitation that is already falling', () => {
    assert.deepEqual(rainSummary(hours([0.5, 0.4, 0, 0])), {
        kind: 'now',
        snow: false,
        start: '2026-10-13T17:00',
        end: '2026-10-13T19:00',
    });
});

test('rainSummary has no end when it does not stop within the forecast', () => {
    assert.equal(rainSummary(hours([0.5, 0.4, 0.3])).end, null);
    assert.equal(rainSummary(hours([0, 0.4, 0.3])).end, null);
});

test('rainSummary ignores traces too small to notice', () => {
    assert.equal(rainSummary(hours([0.05, 0.09, 0])).kind, 'none');
    assert.equal(rainSummary(hours([0.05, 0.1, 0])).kind, 'later');
});

test('rainSummary recognises snow by the weather code of the first wet hour', () => {
    assert.equal(rainSummary(hours([0, 1, 1], SNOW)).snow, true);
    assert.equal(rainSummary(hours([1, 1], SNOW)).snow, true);
});

test('rainSentence describes a dry period', () => {
    assert.equal(rainSentence(rainSummary(hours([0, 0])), NOW, 'ro'), 'Fără precipitații în următoarele 48 de ore');
    assert.equal(rainSentence(rainSummary(hours([0, 0])), NOW, 'en'), 'No precipitation in the next 48 hours');
});

test('rainSentence gives the interval of rain later today', () => {
    const summary = rainSummary(hours([0, 1, 1.5, 0.1, 0]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Ploaie între 18:00 și 21:00');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Rain between 18:00 and 21:00');
});

test('rainSentence gives only the start when the rain does not stop within the forecast', () => {
    const summary = rainSummary(hours([0, 1, 1]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Ploaie de la 18:00');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Rain from 18:00');
});

test('rainSentence says "tomorrow" for rain that starts the next day', () => {
    const summary = rainSummary(hours([...repeated(0, 10), 1, 1, 0]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Ploaie mâine, între 03:00 și 05:00');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Rain tomorrow, between 03:00 and 05:00');
});

test('rainSentence names the weekday for rain that starts later than tomorrow', () => {
    const summary = rainSummary(hours([...repeated(0, 40), 1, 1]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Ploaie joi, de la 09:00');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Rain on Thursday, from 09:00');
});

test('rainSentence says when rain that is falling now will stop', () => {
    const summary = rainSummary(hours([0.5, 0.4, 0, 0]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Plouă acum, până în jurul orei 19:00');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Raining now, until around 19:00');
});

test('rainSentence says so when the rain does not let up', () => {
    const summary = rainSummary(hours([0.5, 0.4, 0.3]));

    assert.equal(rainSentence(summary, NOW, 'ro'), 'Plouă acum, fără pauză în următoarele 48 de ore');
    assert.equal(rainSentence(summary, NOW, 'en'), 'Raining now, without a break in the next 48 hours');
});

test('rainSentence speaks of snow when it snows', () => {
    assert.equal(rainSentence(rainSummary(hours([0, 1, 1, 0], SNOW)), NOW, 'ro'), 'Ninsoare între 18:00 și 20:00');
    assert.equal(rainSentence(rainSummary(hours([1, 0], SNOW)), NOW, 'ro'), 'Ninge acum, până în jurul orei 18:00');
    assert.equal(rainSentence(rainSummary(hours([1, 0], SNOW)), NOW, 'en'), 'Snowing now, until around 18:00');
});
