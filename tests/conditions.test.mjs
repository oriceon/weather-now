import test from 'node:test';
import assert from 'node:assert/strict';
import { hourCode, representativeCode, skyCode } from '../package/contents/code/conditions.mjs';

const CLEAR = 0;
const MAINLY_CLEAR = 1;
const PARTLY_CLOUDY = 2;
const OVERCAST = 3;
const FOG = 45;

const DAYLIGHT = 40000;

/** A dry, overcast day as the API would report it; `sun` is the share of the daylight with sunshine. */
function day({ sun = 0, ...overrides } = {}) {
    return {
        weatherCode: OVERCAST,
        precipitationSum: 0,
        snowfallSum: 0,
        sunshineDuration: sun * DAYLIGHT,
        daylightDuration: DAYLIGHT,
        cloudCoverMean: 100,
        ...overrides,
    };
}

function hour(overrides) {
    return { weatherCode: OVERCAST, isDay: true, cloudCover: 100, sunshineDuration: 0, ...overrides };
}

test('skyCode names the sky from the share of sunshine and the cloud cover', () => {
    const cases = [
        [0.95, 5, CLEAR], [0.6, 20, CLEAR], [0.88, 27, MAINLY_CLEAR], [0.6, 60, MAINLY_CLEAR],
        [0.74, 77, PARTLY_CLOUDY], [0.91, 81, PARTLY_CLOUDY], [0.4, 90, PARTLY_CLOUDY], [0.25, 100, PARTLY_CLOUDY],
        [0.24, 100, OVERCAST], [0.1, 95, OVERCAST], [0, 100, OVERCAST],
    ];

    for (const [sunFraction, cloudCover, want] of cases) {
        assert.equal(skyCode(sunFraction, cloudCover), want, `sun ${sunFraction}, clouds ${cloudCover}`);
    }
});

test('skyCode relies on sunshine alone when the cloud cover is unknown', () => {
    assert.equal(skyCode(0.9, null), CLEAR);
    assert.equal(skyCode(0.7, null), MAINLY_CLEAR);
    assert.equal(skyCode(0.1, undefined), OVERCAST);
});

test('a day the API calls overcast shows the sun it actually gets', () => {
    const thursday = day({ sunshineDuration: 29365.94, daylightDuration: 39728.61, cloudCoverMean: 77 });

    assert.equal(representativeCode(thursday), PARTLY_CLOUDY);
});

test('dry days are named by their sky', () => {
    assert.equal(representativeCode(day({ sun: 0.95, cloudCoverMean: 5 })), CLEAR);
    assert.equal(representativeCode(day({ sun: 0.88, cloudCoverMean: 27 })), MAINLY_CLEAR);
    assert.equal(representativeCode(day({ sun: 0.1, cloudCoverMean: 95 })), OVERCAST);
});

test('a day is never shown cloudier than the API reports it', () => {
    assert.equal(representativeCode(day({ weatherCode: MAINLY_CLEAR, sun: 0.5, cloudCoverMean: 40 })), MAINLY_CLEAR);
    assert.equal(representativeCode(day({ weatherCode: CLEAR, sun: 0.3, cloudCoverMean: 10 })), CLEAR);
});

test('morning fog does not make a sunny day a foggy one', () => {
    assert.equal(representativeCode(day({ weatherCode: FOG, sun: 0.9, cloudCoverMean: 29 })), MAINLY_CLEAR);
    assert.equal(representativeCode(day({ weatherCode: FOG, sun: 0.05, cloudCoverMean: 100 })), FOG);
});

test('rain on a day without sun is graded by how much falls', () => {
    assert.equal(representativeCode(day({ weatherCode: 61, precipitationSum: 0.7 })), 61);
    assert.equal(representativeCode(day({ weatherCode: 63, precipitationSum: 11.2 })), 63);
    assert.equal(representativeCode(day({ weatherCode: 81, precipitationSum: 21.6 })), 65);
});

test('rain on a day that also has sun is shown as showers', () => {
    assert.equal(representativeCode(day({ weatherCode: 51, precipitationSum: 1.5, sun: 0.94 })), 80);
    assert.equal(representativeCode(day({ weatherCode: 80, precipitationSum: 9.9, sun: 0.93 })), 81);
    assert.equal(representativeCode(day({ weatherCode: 63, precipitationSum: 25, sun: 0.5 })), 82);
});

test('a trace of rain does not make a rainy day', () => {
    assert.equal(representativeCode(day({ weatherCode: 51, precipitationSum: 0.3, sun: 0.8, cloudCoverMean: 30 })), MAINLY_CLEAR);
});

test('snow is graded by the depth that falls', () => {
    assert.equal(representativeCode(day({ weatherCode: 71, snowfallSum: 0.6, precipitationSum: 0.9 })), 71);
    assert.equal(representativeCode(day({ weatherCode: 73, snowfallSum: 3, precipitationSum: 4.3 })), 73);
    assert.equal(representativeCode(day({ weatherCode: 75, snowfallSum: 8, precipitationSum: 11.4 })), 75);
});

test('snow on a day that also has sun is shown as snow showers', () => {
    assert.equal(representativeCode(day({ weatherCode: 71, snowfallSum: 1, precipitationSum: 1.4, sun: 0.6 })), 85);
    assert.equal(representativeCode(day({ weatherCode: 75, snowfallSum: 6, precipitationSum: 8.6, sun: 0.6 })), 86);
});

test('rain with a little snow in it stays rain', () => {
    assert.equal(representativeCode(day({ weatherCode: 73, snowfallSum: 0.2, precipitationSum: 10 })), 63);
});

test('thunderstorms and freezing rain are kept as the API reports them', () => {
    assert.equal(representativeCode(day({ weatherCode: 95, precipitationSum: 8, sun: 0.5 })), 95);
    assert.equal(representativeCode(day({ weatherCode: 96, precipitationSum: 0 })), 96);
    assert.equal(representativeCode(day({ weatherCode: 67, precipitationSum: 3 })), 67);
    assert.equal(representativeCode(day({ weatherCode: 56, precipitationSum: 1 })), 56);
});

test('without sunshine data the day keeps the code of the API', () => {
    assert.equal(representativeCode(day({ sunshineDuration: null })), OVERCAST);
    assert.equal(representativeCode(day({ weatherCode: CLEAR, sunshineDuration: 0, daylightDuration: 0, cloudCoverMean: 5 })), CLEAR);
    assert.equal(representativeCode(day({ weatherCode: 63, precipitationSum: 30, sunshineDuration: undefined })), 63);
});

test('a cloudy hour with the sun out is shown with the sun', () => {
    assert.equal(hourCode(hour({ sunshineDuration: 3600 })), PARTLY_CLOUDY);
    assert.equal(hourCode(hour({ weatherCode: PARTLY_CLOUDY, sunshineDuration: 3600, cloudCover: 30 })), MAINLY_CLEAR);
    assert.equal(hourCode(hour({ sunshineDuration: 0 })), OVERCAST);
});

test('an hour is never shown cloudier than the API reports it', () => {
    assert.equal(hourCode(hour({ weatherCode: CLEAR, sunshineDuration: 900, cloudCover: 0 })), CLEAR);
});

test('night hours, precipitation and fog keep the code of the API', () => {
    assert.equal(hourCode(hour({ isDay: false, sunshineDuration: 0 })), OVERCAST);
    assert.equal(hourCode(hour({ weatherCode: 61, sunshineDuration: 3600 })), 61);
    assert.equal(hourCode(hour({ weatherCode: FOG, sunshineDuration: 3600 })), FOG);
    assert.equal(hourCode(hour({ sunshineDuration: null })), OVERCAST);
});
