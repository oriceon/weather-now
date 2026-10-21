// The rain radar of the Rain tab: the images of RainViewer over the last two hours, ten minutes
// apart, laid over a map of NASA GIBS, around the place. Neither asks for a key. RainViewer is free
// for personal and educational use, credited with a link to it, at most 100 requests a minute from
// one address and no closer than its zoom 7; it keeps a single colour scheme, Universal Blue. GIBS
// asks to be acknowledged, and its borders and names are drawn from OpenStreetMap, credited as such.
// Nothing is asked of either until the radar is opened.

export const RADAR_INDEX_URL = 'https://api.rainviewer.com/public/weather-maps.json';
const GIBS = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best';

/** The zooms of the map, in tiles of 256 pixels: the radar goes no closer than 7 in tiles of 512, that is 8 here. */
export const MIN_ZOOM = 5;
export const MAX_ZOOM = 8;
export const DEFAULT_ZOOM = 7;
/** The size of a tile of the map, and of one of the radar, which covers four of the map's. */
export const MAP_TILE = 256;
export const RADAR_TILE = 512;
/** The requests to RainViewer allowed in a minute: theirs is 100 from one address; this leaves room for the index. */
export const RADAR_BUDGET = 90;
/** How long the index of the images stays fresh: RainViewer adds one every ten minutes. */
export const INDEX_LIFETIME = 10 * 60 * 1000;

/**
 * The layers of the map, under and over the radar: the relief of the Blue Marble, the coasts and
 * borders, and the names of places; with the closest zoom of each, beyond which GIBS has nothing.
 */
const MAP_LAYERS = {
    relief: { name: 'BlueMarble_ShadedRelief', matrix: 'GoogleMapsCompatible_Level8', format: 'jpeg', deepest: 8 },
    borders: { name: 'Reference_Features', matrix: 'GoogleMapsCompatible_Level9', format: 'png', deepest: 9 },
    names: { name: 'Reference_Labels', matrix: 'GoogleMapsCompatible_Level9', format: 'png', deepest: 9 },
};

/**
 * The colours of Universal Blue, from the faintest drizzle to the heaviest downpour, for the legend:
 * sampled from its images, which RainViewer publishes no table for.
 */
export const RADAR_COLOURS = ['#d6c88f', '#88ddee', '#1baee2', '#0088bf', '#005588', '#ffee00', '#ffaa00', '#ff4400', '#c10000'];

/**
 * The images are asked of RainViewer only, whatever host its index names: the tiles carry where the
 * place is, and their pictures are decoded on the desktop.
 */
const RADAR_HOST = /^https:\/\/[a-z0-9-]+\.rainviewer\.com$/;
const RADAR_PATH = /^\/v2\/radar\/[0-9a-z]+$/i;

/** `{ host, frames: [{ time, path }] }` from the index of RainViewer, oldest image first; throws without any. */
export function parseRadarIndex(response) {
    const past = response && response.radar && Array.isArray(response.radar.past) ? response.radar.past : [];
    const frames = past
        .filter((frame) => frame && Number.isFinite(frame.time) && typeof frame.path === 'string' && RADAR_PATH.test(frame.path))
        .map((frame) => ({ time: frame.time, path: frame.path }))
        .sort((first, second) => first.time - second.time);

    if (!response || typeof response.host !== 'string' || !RADAR_HOST.test(response.host) || frames.length === 0) {
        throw new Error('The radar index has no images');
    }

    return { host: response.host, frames };
}

/** Where a place is on the map at a zoom, in tiles from the top left of the world, as Web Mercator has it. */
export function tileOf(latitude, longitude, zoom) {
    const count = Math.pow(2, zoom);
    const sine = Math.sin(Math.max(-85.0511, Math.min(85.0511, latitude)) * Math.PI / 180);

    return {
        x: (longitude + 180) / 360 * count,
        y: (0.5 - Math.log((1 + sine) / (1 - sine)) / (4 * Math.PI)) * count,
    };
}

/**
 * The tiles of `size` pixels that cover a view of `width` × `height` with `centre` (in tiles) in its
 * middle: `{ x, y, left, top }`, the tile and where it goes in the view. Across the date line the
 * world repeats; above and below it, there are no tiles.
 */
export function tilesAround(centre, zoom, width, height, size) {
    const count = Math.pow(2, zoom);
    const tiles = [];

    for (let y = Math.floor(centre.y - height / 2 / size); y < centre.y + height / 2 / size; y++) {
        if (y < 0 || y >= count) {
            continue;
        }

        for (let x = Math.floor(centre.x - width / 2 / size); x < centre.x + width / 2 / size; x++) {
            tiles.push({
                x: ((x % count) + count) % count,
                y,
                left: Math.round(width / 2 + (x - centre.x) * size),
                top: Math.round(height / 2 + (y - centre.y) * size),
            });
        }
    }

    return tiles;
}

/** A tile of the radar: Universal Blue (2), smoothed, with snow in its own colours. */
export function radarTileUrl(index, frame, zoom, tile) {
    return `${index.host}${frame.path}/${RADAR_TILE}/${zoom}/${tile.x}/${tile.y}/2/1_1.png`;
}

/** A tile of a layer of the map (relief, borders or names); none past the closest zoom of the layer. */
export function mapTileUrl(layer, zoom, tile) {
    const shape = MAP_LAYERS[layer];

    return zoom > shape.deepest ? '' : `${GIBS}/${shape.name}/default/${shape.matrix}/${zoom}/${tile.y}/${tile.x}.${shape.format}`;
}

/**
 * Whether `count` more requests to RainViewer fit in the minute, after those `spent`, which are
 * `[{ at, count }]`, `at` in milliseconds like `now`.
 */
export function fitsBudget(spent, now, count, budget = RADAR_BUDGET) {
    const used = recentSpending(spent, now).reduce((sum, entry) => sum + entry.count, 0);

    return used + count <= budget;
}

/** The requests spent within the last minute, the older ones forgotten, and those "from the future" of a clock set back. */
export function recentSpending(spent, now) {
    return spent.filter((entry) => now - entry.at >= 0 && now - entry.at < 60000);
}

/**
 * The requests made to RainViewer in the last minute by every radar of the desktop: its limit is
 * per address, and a radar made again, after a change of place, used to start from nothing.
 */
const ledger = [];

/** Spends `count` requests to RainViewer if the minute has room for them; whether it had. */
export function spend(count, now = Date.now()) {
    const recent = recentSpending(ledger, now);

    if (!fitsBudget(recent, now, count)) {
        return false;
    }

    ledger.splice(0, ledger.length, ...recent, { at: now, count });

    return true;
}

/** "x/y x/y…": the same for two lists of tiles only when they hold the same tiles. */
export function tileKeys(tiles) {
    return tiles.map((tile) => `${tile.x}/${tile.y}`).join(' ');
}

/** The wall-clock time of an image (seconds since 1970) at the place, HH:MM. */
export function frameClock(time, utcOffsetSeconds) {
    return new Date((time + utcOffsetSeconds) * 1000).toISOString().slice(11, 16);
}
