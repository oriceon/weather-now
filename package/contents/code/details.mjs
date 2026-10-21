// The tiles of the Details tab, in the order the user dragged them into.

/** Every tile, in the order of a new widget. `air` shows the gusts while there is no air quality. */
export const TILES = ['wind', 'air', 'humidity', 'dewPoint', 'pressure', 'uv', 'clouds', 'visibility', 'sun', 'moon', 'aurora', 'pollen', 'activities'];

/** A tile looks best a little wider than tall. */
const IDEAL_SHAPE = 1.1;
/** What it costs a layout to have tiles too short for their instruments, and each cell of its last row a tile takes twice. */
const CRAMPED = 0.6;
const SPAN = 0.25;
/** The tiles that gain most from more width, first: the way of the sun, the hills of the visibility, the dials… */
const WIDE_FIRST = ['activities', 'sun', 'pollen', 'moon', 'visibility', 'aurora', 'pressure', 'air', 'dewPoint', 'uv', 'wind', 'humidity', 'clouds'];
const MOST_COLUMNS = 6;

/** The name of each tile in the settings, as a translation key. */
export const TILE_NAMES = {
    wind: 'details.wind',
    air: 'config.tileAir',
    humidity: 'details.humidity',
    dewPoint: 'details.dewPoint',
    pressure: 'details.pressure',
    uv: 'details.uv',
    clouds: 'details.clouds',
    visibility: 'details.visibility',
    sun: 'details.sun',
    moon: 'details.moon',
    aurora: 'details.aurora',
    pollen: 'details.pollen',
    activities: 'details.activities',
};

/**
 * The order kept in the settings, made whole: what is not a tile goes, a tile it lacks, one added
 * by a later version, goes right after the tile it follows in TILES.
 */
export function tileOrder(saved) {
    const order = [];
    const kept = saved || [];

    // By index: the list of the settings is a sequence of Qt, not an array.
    for (let index = 0; index < kept.length; index++) {
        const tile = String(kept[index]);

        if (TILES.includes(tile) && !order.includes(tile)) {
            order.push(tile);
        }
    }

    TILES.forEach((tile, index) => {
        if (order.includes(tile)) {
            return;
        }

        const before = index > 0 ? order.indexOf(TILES[index - 1]) : -1;

        order.splice(before + 1, 0, tile);
    });

    return order;
}

/** The order with the tile at `from` moved to `to`, the others closing up. */
export function moveTile(order, from, to) {
    const moved = order.slice();
    const target = Math.max(0, Math.min(order.length - 1, to));

    if (from < 0 || from >= order.length || from === target) {
        return moved;
    }

    moved.splice(target, 0, moved.splice(from, 1)[0]);

    return moved;
}

/** Whether `order` is the order of a new widget: then nothing needs to be kept in the settings. */
export function isDefaultOrder(order) {
    return order.length === TILES.length && order.every((tile, index) => tile === TILES[index]);
}

/** The tiles of `order` that are not among `hidden`, the ids turned off in the settings; never none. */
export function shownTiles(order, hidden) {
    const off = [];

    // By index: the list of the settings is a sequence of Qt, not an array.
    for (let index = 0; index < (hidden || []).length; index++) {
        off.push(String(hidden[index]));
    }

    const shown = order.filter((tile) => !off.includes(tile));

    return shown.length > 0 ? shown : order.slice(0, 1);
}

/**
 * The whole order, hidden tiles included, after the tiles shown were dragged into `shown`: the
 * hidden ones keep their places, the shown ones fill the others in their new order.
 */
export function withShownOrder(order, shown) {
    const queue = shown.slice();

    return order.map((tile) => (shown.includes(tile) ? queue.shift() : tile));
}

/**
 * How to lay out `count` tiles in an area of `width` by `height`: `{ columns, rows, rowsShown }`.
 * Of the layouts whose tiles are no smaller than `minimumWidth` by `minimumHeight`, the one whose
 * tiles come nearest to a little wider than tall, tall enough for their instruments (`roomyHeight`),
 * with a last row as full as can be: what it lacks, tiles of it take twice, see tileCells(). Fewer
 * tiles thus grow to fill the area. With too many for it, they keep a usable size and the rest scrolls.
 */
export function tileGrid(count, width, height, { minimumWidth, minimumHeight, roomyHeight }) {
    let best = null;

    for (let columns = 1; columns <= Math.min(count, MOST_COLUMNS); columns++) {
        const rows = Math.ceil(count / columns);
        const cellWidth = width / columns;
        const cellHeight = height / rows;

        if (cellWidth < minimumWidth || cellHeight < minimumHeight) {
            continue;
        }

        const last = count - columns * (rows - 1);
        const score = Math.abs(Math.log(cellWidth / cellHeight / IDEAL_SHAPE))
            + (cellHeight < roomyHeight ? CRAMPED : 0)
            + (columns - last) * SPAN;

        if (best === null || score < best.score) {
            best = { columns, rows, rowsShown: rows, score };
        }
    }

    if (best !== null) {
        return { columns: best.columns, rows: best.rows, rowsShown: best.rows };
    }

    const columns = Math.max(1, Math.min(MOST_COLUMNS, count, Math.floor(width / minimumWidth)));
    const rows = Math.ceil(count / columns);

    return { columns, rows, rowsShown: Math.max(1, Math.min(rows, Math.floor(height / roomyHeight) || Math.floor(height / minimumHeight) || 1)) };
}

/**
 * Where each tile of `order` goes in a tileGrid() layout: `{ row, x, width }`, the left edge and
 * the width as shares of the width of the area. Every row is full and the columns line up: the
 * cells a last row lacks are taken by its tiles that gain most from width, each one cell more,
 * so that a tile is one cell wide or a whole number of them, never in between.
 */
export function tileCells(order, layout) {
    const { columns, rows } = layout;
    const lastStart = columns * (rows - 1);
    const lastRow = order.slice(lastStart);
    const spans = lastRow.map(() => 1);
    const rank = (tile) => (WIDE_FIRST.includes(tile) ? WIDE_FIRST.indexOf(tile) : WIDE_FIRST.length);
    const widest = lastRow.map((tile, index) => index).sort((first, second) => rank(lastRow[first]) - rank(lastRow[second]));

    for (let extra = columns - lastRow.length, turn = 0; extra > 0 && widest.length > 0; extra--, turn = (turn + 1) % widest.length) {
        spans[widest[turn]]++;
    }

    const cells = order.slice(0, lastStart).map((tile, index) => ({ row: Math.floor(index / columns), x: (index % columns) / columns, width: 1 / columns }));
    let column = 0;

    spans.forEach((span) => {
        cells.push({ row: rows - 1, x: column / columns, width: span / columns });
        column += span;
    });

    return cells;
}
