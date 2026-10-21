import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { MAP_TILE, MAX_ZOOM, RADAR_BUDGET, RADAR_TILE, fitsBudget, frameClock, mapTileUrl, parseRadarIndex, radarTileUrl, recentSpending, spend, tileKeys, tileOf, tilesAround } from '../package/contents/code/radar.mjs';

const recorded = JSON.parse(readFileSync(new URL('./fixtures/radar-index.json', import.meta.url), 'utf8'));

test('the index of RainViewer gives the images of the last two hours, oldest first', () => {
    const index = parseRadarIndex(recorded);

    assert.equal(index.host, 'https://tilecache.rainviewer.com');
    assert.equal(index.frames.length, 13);
    assert.ok(index.frames.every((frame, at) => at === 0 || frame.time - index.frames[at - 1].time === 600));
    assert.match(index.frames[0].path, /^\/v2\/radar\/[0-9a-f]+$/);
});

test('an index without images, or with a host that is not https, is refused', () => {
    assert.throws(() => parseRadarIndex({ host: 'https://tilecache.rainviewer.com', radar: { past: [] } }));
    assert.throws(() => parseRadarIndex({ ...recorded, host: 'http://tilecache.rainviewer.com' }));
    assert.throws(() => parseRadarIndex({ ...recorded, host: 'https://192.168.1.1' }));
    assert.throws(() => parseRadarIndex({ ...recorded, host: 'https://rainviewer.com.example.org' }));
    assert.equal(parseRadarIndex({ ...recorded, radar: { past: [...recorded.radar.past, { time: 1, path: '/../../x?y' }] } }).frames.length, recorded.radar.past.length);
    assert.throws(() => parseRadarIndex(null));
});

test('a place falls in the tile of the map that holds it', () => {
    const constanta = tileOf(44.18, 28.65, 6);

    assert.equal(Math.floor(constanta.x), 37);
    assert.equal(Math.floor(constanta.y), 23);
    assert.deepEqual(tileOf(0, 0, 0), { x: 0.5, y: 0.5 });
});

test('the tiles around a place cover the whole view, the place in its middle', () => {
    const centre = tileOf(44.18, 28.65, 7);
    const tiles = tilesAround(centre, 7, 600, 330, MAP_TILE);

    assert.ok(tiles.some((tile) => tile.left <= 0 && tile.top <= 0));
    assert.ok(tiles.some((tile) => tile.left + MAP_TILE >= 600 && tile.top + MAP_TILE >= 330));

    const holding = tiles.find((tile) => tile.x === Math.floor(centre.x) && tile.y === Math.floor(centre.y));

    assert.ok(holding.left <= 300 && holding.left + MAP_TILE >= 300);
    assert.ok(holding.top <= 165 && holding.top + MAP_TILE >= 165);
});

test('a tile of the radar lies over the four tiles of the map it covers', () => {
    const centre = tileOf(44.18, 28.65, 7);
    const map = tilesAround(centre, 7, 600, 330, MAP_TILE);
    const radar = tilesAround({ x: centre.x / 2, y: centre.y / 2 }, 6, 600, 330, RADAR_TILE);

    radar.forEach((tile) => {
        const under = map.find((other) => other.x === tile.x * 2 && other.y === tile.y * 2);

        if (under) {
            assert.ok(Math.abs(under.left - tile.left) <= 1 && Math.abs(under.top - tile.top) <= 1);
        }
    });
});

test('across the date line the world goes on, and beyond the poles there are no tiles', () => {
    const tiles = tilesAround(tileOf(0, 179.9, 3), 3, 600, 300, MAP_TILE);

    assert.ok(tiles.some((tile) => tile.x === 0));
    assert.ok(tiles.every((tile) => tile.x >= 0 && tile.x < 8));
    assert.ok(tilesAround(tileOf(85, 0, 2), 2, 600, 600, MAP_TILE).every((tile) => tile.y >= 0));
});

test('the radar asks for Universal Blue, smoothed, with snow apart, in tiles of 512', () => {
    const index = parseRadarIndex(recorded);

    assert.equal(radarTileUrl(index, index.frames[0], 6, { x: 37, y: 23 }), 'https://tilecache.rainviewer.com/v2/radar/c833039ddfbe/512/6/37/23/2/1_1.png');
});

test('the map comes from GIBS, row before column, and only as close as each layer goes', () => {
    assert.equal(mapTileUrl('relief', 7, { x: 74, y: 46 }), 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/BlueMarble_ShadedRelief/default/GoogleMapsCompatible_Level8/7/46/74.jpeg');
    assert.match(mapTileUrl('names', MAX_ZOOM, { x: 1, y: 2 }), /Reference_Labels\/default\/GoogleMapsCompatible_Level9\/8\/2\/1\.png$/);
    assert.equal(mapTileUrl('relief', 9, { x: 1, y: 2 }), '');
});

test('the requests of the last minute count against the budget, older ones do not', () => {
    const now = 1_000_000;

    assert.ok(fitsBudget([], now, RADAR_BUDGET));
    assert.ok(!fitsBudget([{ at: now - 1000, count: 80 }], now, 12));
    assert.ok(fitsBudget([{ at: now - 61000, count: 80 }, { at: now - 1000, count: 4 }], now, 12));
    assert.deepEqual(recentSpending([{ at: now - 61000, count: 80 }, { at: now - 5, count: 4 }], now), [{ at: now - 5, count: 4 }]);
    // Spent "in the future", before the clock was set back: not counted, or the radar stood still.
    assert.ok(fitsBudget([{ at: now + 3600000, count: 90 }], now, 12));
});

test('the time of an image is told on the clock of the place', () => {
    assert.equal(frameClock(1792578600, 10800), '13:30');
    assert.equal(frameClock(1792578600, -18000), '05:30');
});

// The limit of RainViewer is per address: every radar of the desktop spends from the same minute.
test('the requests of every radar count against one minute', () => {
    const now = 4e12;

    assert.ok(spend(RADAR_BUDGET - 4, now));
    assert.ok(!spend(5, now + 1000));
    assert.ok(spend(4, now + 2000));
    assert.ok(!spend(1, now + 3000));
    assert.ok(spend(RADAR_BUDGET, now + 62001));
});

test('two lists of tiles are told apart by the tiles they hold, not by where they go', () => {
    assert.equal(tileKeys([{ x: 1, y: 2, left: 0, top: 0 }, { x: 2, y: 2, left: 512, top: 0 }]), tileKeys([{ x: 1, y: 2, left: 30, top: 8 }, { x: 2, y: 2, left: 542, top: 8 }]));
    assert.notEqual(tileKeys([{ x: 1, y: 2 }]), tileKeys([{ x: 1, y: 3 }]));
});
