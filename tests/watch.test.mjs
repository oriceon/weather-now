import test from 'node:test';
import assert from 'node:assert/strict';
import { STARTING, coldestOfNight, watch } from '../package/contents/code/watch.mjs';

const ALL = { notifyAlerts: true, notifyRain: true, notifyFrost: true };
const quarters = (...amounts) => amounts.map((precipitation, index) => ({ time: `2026-10-13T17:${String(index * 15).padStart(2, '0')}`, precipitation }));
const reading = (overrides) => Object.assign({ now: '2026-10-13T12:00', alerts: [], minutely: [], hourly: [], frostCelsius: null }, overrides);

test('warnings there already at the first look are not news; a later one is', () => {
    const first = watch(STARTING, reading({ alerts: [{ id: 'a' }] }), ALL);

    assert.deepEqual(first.events, []);

    const second = watch(first.state, reading({ alerts: [{ id: 'a' }, { id: 'b' }] }), ALL);

    assert.deepEqual(second.events, [{ kind: 'alert', alert: { id: 'b' } }]);
    assert.deepEqual(watch(second.state, reading({ alerts: [{ id: 'a' }, { id: 'b' }] }), ALL).events, []);
});

test('rain about to start, while it is dry, is told once, with its time', () => {
    const first = watch(STARTING, reading({ minutely: quarters(0, 0, 0.6, 1) }), ALL);

    assert.deepEqual(first.events, [{ kind: 'rain', at: '17:30', snow: false }]);
    assert.deepEqual(watch(first.state, reading({ minutely: quarters(0, 0.5, 1) }), ALL).events, []);
});

test('rain that has started, or that is further off, is not told', () => {
    assert.deepEqual(watch(STARTING, reading({ minutely: quarters(0.5, 1, 1) }), ALL).events, []);
    assert.deepEqual(watch(STARTING, reading({ minutely: quarters(0, 0, 0, 0.8) }), ALL).events, []);
});

test('frost in the night ahead is told in the evening, once a day', () => {
    const evening = reading({ now: '2026-10-13T19:00', frostCelsius: -2 });
    const first = watch(STARTING, evening, ALL);

    assert.deepEqual(first.events, [{ kind: 'frost', celsius: -2 }]);
    assert.deepEqual(watch(first.state, evening, ALL).events, []);
    assert.deepEqual(watch(STARTING, reading({ now: '2026-10-13T12:00', frostCelsius: -2 }), ALL).events, []);
    assert.deepEqual(watch(STARTING, reading({ now: '2026-10-13T19:00', frostCelsius: 3 }), ALL).events, []);
});

// Turned off, a kind is still followed, so that turning it on does not announce old news.
test('what is turned off is not told, but still counted as known', () => {
    const quiet = watch(STARTING, reading({ alerts: [{ id: 'a' }] }), { notifyAlerts: false, notifyRain: false, notifyFrost: false });
    const later = watch(quiet.state, reading({ alerts: [{ id: 'a' }] }), ALL);

    assert.deepEqual(later.events, []);
});

test('the coldest of the night ahead comes from the next fourteen hours', () => {
    const hours = [5, 3, -1, 2].map(temperature => ({ temperature })).concat(Array.from({ length: 20 }, () => ({ temperature: -9 })));

    assert.equal(coldestOfNight(hours.slice(0, 4)), -1);
    assert.equal(coldestOfNight([]), null);
});

// The forecast comes before the warnings; until they are all in, nothing is known about them.
test('a list of warnings still on its way changes nothing', () => {
    const early = watch(STARTING, reading({ alerts: null }), ALL);
    const first = watch(early.state, reading({ alerts: [{ id: 'a' }] }), ALL);

    assert.deepEqual(first.events, []);
});

test('a warning kept for copies that say the same is not news when another copy is kept later', () => {
    const first = watch(STARTING, reading({ alerts: [] }), ALL);
    const second = watch(first.state, reading({ alerts: [{ id: 'B', sameAs: ['A'], expires: '2026-10-14T00:00' }] }), ALL);

    assert.equal(second.events.length, 1);
    assert.deepEqual(watch(second.state, reading({ alerts: [{ id: 'A', sameAs: ['B'], expires: '2026-10-14T00:00' }] }), ALL).events, []);
});

test('a warning missing from one list is not news when it is back, until it expires', () => {
    const first = watch(STARTING, reading({ alerts: [{ id: 'a', expires: '2026-10-13T18:00' }] }), ALL);
    const gap = watch(first.state, reading({ alerts: [] }), ALL);

    assert.deepEqual(watch(gap.state, reading({ alerts: [{ id: 'a', expires: '2026-10-13T18:00' }] }), ALL).events, []);
    assert.deepEqual(Object.keys(watch(gap.state, reading({ now: '2026-10-13T19:00', alerts: [] }), ALL).state.knownAlerts), []);
});

test('the summary of the day is sent once a morning, from the time chosen until noon', () => {
    const morning = { notifyAlerts: false, notifyRain: false, notifyFrost: false, notifyMorning: true, morningTime: '07:30' };
    const early = watch(STARTING, reading({ now: '2026-10-21T07:00' }), morning);

    assert.deepEqual(early.events, []);

    const time = watch(early.state, reading({ now: '2026-10-21T07:30' }), morning);

    assert.deepEqual(time.events, [{ kind: 'morning' }]);
    assert.deepEqual(watch(time.state, reading({ now: '2026-10-21T08:00' }), morning).events, []);
    assert.deepEqual(watch(STARTING, reading({ now: '2026-10-21T13:00' }), morning).events, []);
    assert.deepEqual(watch(STARTING, reading({ now: '2026-10-21T09:00' }), { ...morning, notifyMorning: false }).events, []);
});
