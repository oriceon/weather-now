import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { auroraOutlook, geomagneticLatitude, kpNeeded, parseKpForecast, stormScale, tonight } from '../package/contents/code/aurora.mjs';

const recorded = JSON.parse(readFileSync(new URL('./fixtures/kp-forecast.json', import.meta.url), 'utf8'));
const hour = (iso) => Date.parse(`${iso}Z`);
const slots = (...pairs) => pairs.map(([time, kp]) => ({ start: hour(time), kp }));

test('parseKpForecast reads the 3-hour slots of NOAA, in UTC', () => {
    const parsed = parseKpForecast(recorded);

    assert.equal(parsed.length, recorded.length);
    assert.deepEqual(parsed[0], { start: hour('2026-10-14T00:00:00'), kp: 2.33 });
    assert.deepEqual(parseKpForecast([{ time_tag: 'nonsense', kp: 3 }, { time_tag: '2026-10-21T00:00:00', kp: '4.33' }]), [{ start: hour('2026-10-21T00:00:00'), kp: 4.33 }]);
    assert.deepEqual(parseKpForecast(null), []);
});

test('the geomagnetic latitude leans towards the magnetic pole, in Canada', () => {
    assert.ok(Math.abs(geomagneticLatitude(44.43, 26.1) - 42.3) < 0.5);
    assert.ok(Math.abs(geomagneticLatitude(43.65, -79.38) - 52.8) < 0.5);
    assert.ok(geomagneticLatitude(-42.88, 147.33) < -49);
});

test('the Kp it takes matches where the aurora has been seen', () => {
    const needed = (latitude, longitude) => kpNeeded(geomagneticLatitude(latitude, longitude));

    assert.equal(Math.round(needed(55.95, -3.19).horizon), 5, 'Edinburgh');
    assert.equal(Math.round(needed(52.52, 13.4).horizon), 7, 'Berlin');
    assert.ok(needed(44.43, 26.1).camera > 8.5, 'Bucharest, in photos only in the great storms');
    assert.equal(Math.round(needed(-42.88, 147.33).horizon), 5, 'Hobart');
    assert.ok(needed(64.84, -147.72).overhead < needed(55.95, -3.19).horizon, 'Fairbanks');
});

test('the storms of NOAA start at 5- for G1 and at a whole 9 for G5', () => {
    assert.equal(stormScale(4.33), '');
    assert.equal(stormScale(4.67), 'G1');
    assert.equal(stormScale(6.67), 'G3');
    assert.equal(stormScale(8.67), 'G4');
    assert.equal(stormScale(9), 'G5');
});

test('tonight is the coming night by day, and the rest of the night by night', () => {
    const today = { sunrise: '2026-10-21T07:30', sunset: '2026-10-21T18:20' };
    const tomorrow = { sunrise: '2026-10-22T07:31', sunset: '2026-10-22T18:18' };

    assert.deepEqual(tonight('2026-10-21T12:00', today, tomorrow, 10800), [hour('2026-10-21T15:20'), hour('2026-10-22T04:31')]);
    assert.deepEqual(tonight('2026-10-21T22:00', today, tomorrow, 10800), [hour('2026-10-21T19:00'), hour('2026-10-22T04:31')]);
    assert.deepEqual(tonight('2026-10-21T03:00', today, tomorrow, 10800), [hour('2026-10-21T00:00'), hour('2026-10-21T04:30')]);
    assert.deepEqual(tonight('2026-10-21T03:00', { sunrise: null, sunset: null }, tomorrow, 0), [hour('2026-10-21T03:00'), hour('2026-10-21T15:00')]);
});

test('the outlook takes the highest Kp of the dark hours, and says where to look', () => {
    const night = [hour('2026-10-21T16:00'), hour('2026-10-22T05:00')];
    const kp = slots(['2026-10-21T12:00', 8], ['2026-10-21T15:00', 3], ['2026-10-21T21:00', 5.33], ['2026-10-22T06:00', 9]);

    assert.deepEqual(auroraOutlook(kp, { latitude: 55.95, longitude: -3.19 }, night), { kp: 5.33, storm: 'G1', sight: 'horizon', needed: 5, direction: 'north' });
    assert.equal(auroraOutlook(kp, { latitude: 44.43, longitude: 26.1 }, night).sight, 'none');
    assert.equal(auroraOutlook(kp, { latitude: 44.43, longitude: 26.1 }, night).needed, 9);
    assert.equal(auroraOutlook(kp, { latitude: 69.65, longitude: 18.96 }, night).sight, 'overhead');
    assert.equal(auroraOutlook(kp, { latitude: 52.52, longitude: 13.4 }, night).sight, 'none');
    assert.equal(auroraOutlook(kp, { latitude: -42.88, longitude: 147.33 }, night).direction, 'south');
    assert.equal(auroraOutlook([], { latitude: 55.95, longitude: -3.19 }, night), null);
});
