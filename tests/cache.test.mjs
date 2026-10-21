import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchedAt, forgetAll, remember, remembered } from '../package/contents/code/cache.mjs';

test('an answer is taken from the cache while it is fresh, and asked again after', () => {
    forgetAll();
    remember('https://api.open-meteo.com/v1/forecast?latitude=44.18', '{"a":1}', 1000);

    assert.equal(remembered('https://api.open-meteo.com/v1/forecast?latitude=44.18', 60000, 30000), '{"a":1}');
    assert.equal(remembered('https://api.open-meteo.com/v1/forecast?latitude=44.18', 60000, 61000), undefined);
    assert.equal(remembered('https://api.open-meteo.com/v1/forecast?latitude=45.75', 60000, 30000), undefined);
    assert.equal(fetchedAt('https://api.open-meteo.com/v1/forecast?latitude=44.18'), 1000);
    assert.equal(fetchedAt('https://elsewhere'), 0);
});

test('the oldest answers make room, the newest is always kept', () => {
    forgetAll();

    const forecast = 'x'.repeat(1500000);

    ['a', 'b', 'c', 'd', 'e'].forEach((place, index) => remember(place, forecast, index));

    assert.equal(remembered('a', Infinity, 10), undefined);
    assert.equal(remembered('e', Infinity, 10), forecast);
    remember('huge', 'y'.repeat(7000000), 20);
    assert.equal(remembered('huge', Infinity, 21).length, 7000000);
});

// A computer whose clock is set back, as when the network corrects it, would keep an answer "from the future".
test('an answer fetched after the time of the clock now is not fresh', () => {
    forgetAll();
    remember('https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-romania', '<feed/>', 10000);

    assert.equal(remembered('https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-romania', 60000, 5000), undefined);
});
