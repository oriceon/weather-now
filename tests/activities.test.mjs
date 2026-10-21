import test from 'node:test';
import assert from 'node:assert/strict';
import { ACTIVITIES, DEFAULT_ACTIVITIES, activityOutlook, rateHour } from '../package/contents/code/activities.mjs';
import { STRINGS } from '../package/contents/code/i18n.mjs';

const UNITS = { windUnit: 'kmh', temperatureUnit: 'celsius' };
const hour = (time, fields) => Object.assign({ time, apparentTemperature: 15, precipitationProbability: 0, windSpeed: 10, uvIndex: 2, isDay: true, cloudCover: 20 }, fields);

test('an hour is rated good, fair or poor for each activity', () => {
    assert.equal(rateHour('running', hour('2026-10-21T10:00'), UNITS), 'good');
    assert.equal(rateHour('running', hour('2026-10-21T10:00', { apparentTemperature: 26 }), UNITS), 'fair');
    assert.equal(rateHour('running', hour('2026-10-21T10:00', { precipitationProbability: 80 }), UNITS), 'poor');
    assert.equal(rateHour('cycling', hour('2026-10-21T10:00', { windSpeed: 30 }), UNITS), 'fair');
    assert.equal(rateHour('gardening', hour('2026-10-21T22:00', { isDay: false }), UNITS), 'poor');
});

test('the sky at night wants it dark, clear and the moon dim', () => {
    const night = hour('2026-10-21T22:00', { isDay: false, cloudCover: 10 });

    assert.equal(rateHour('stargazing', night, UNITS, 0.2), 'good');
    assert.equal(rateHour('stargazing', night, UNITS, 0.9), 'fair');
    assert.equal(rateHour('stargazing', hour('2026-10-21T12:00'), UNITS), 'poor');
});

test('the outlook gives the longest stretch of the best hours left today', () => {
    const day = ['10', '11', '12', '13', '14', '15', '16'].map((at, index) => hour(`2026-10-21T${at}:00`, { precipitationProbability: [80, 10, 10, 50, 10, 10, 10][index] }));

    assert.deepEqual(activityOutlook('running', day, UNITS), { rating: 'good', start: '14:00', end: '17:00' });
    assert.deepEqual(activityOutlook('running', day.map((entry) => Object.assign({}, entry, { precipitationProbability: 90 })), UNITS), { rating: 'poor', start: '', end: '' });
});

test('every activity has a name in every language, and the defaults are among them', () => {
    for (const activity of ACTIVITIES) {
        for (const language of Object.keys(STRINGS)) {
            if (STRINGS[language][`activity.${activity}`] === undefined && language !== 'ro' && language !== 'en') {
                continue;
            }

            assert.ok(STRINGS[language][`activity.${activity}`], `${activity} in ${language}`);
        }
    }

    assert.ok(DEFAULT_ACTIVITIES.every((activity) => ACTIVITIES.includes(activity)));
});

test('a stretch that lasts until midnight ends at 24:00', () => {
    const evening = ['21', '22', '23'].map((at) => hour(`2026-10-21T${at}:00`));

    assert.deepEqual(activityOutlook('running', evening, UNITS), { rating: 'good', start: '21:00', end: '24:00' });
});
