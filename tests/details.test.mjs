import test from 'node:test';
import assert from 'node:assert/strict';
import { TILES, TILE_NAMES, isDefaultOrder, moveTile, shownTiles, tileCells, tileGrid, tileOrder, withShownOrder } from '../package/contents/code/details.mjs';

test('a new widget shows every tile in the default order', () => {
    assert.deepEqual(tileOrder([]), TILES);
    assert.deepEqual(tileOrder(undefined), TILES);
});

test('the order kept is followed, without what is not a tile or a tile twice', () => {
    const order = tileOrder(['moon', 'wind', 'radar', 'wind']);

    assert.deepEqual(order.slice(0, 2), ['moon', 'aurora']);
    assert.equal(order.length, TILES.length);
    assert.equal(new Set(order).size, TILES.length);
});

test('a tile added by a later version goes after the tile it follows', () => {
    const saved = TILES.filter((tile) => tile !== 'visibility').reverse();
    const order = tileOrder(saved);

    assert.equal(order[order.indexOf('clouds') + 1], 'visibility');
});

test('moveTile moves one tile and closes up the others', () => {
    assert.deepEqual(moveTile(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
    assert.deepEqual(moveTile(['a', 'b', 'c', 'd'], 3, 0), ['d', 'a', 'b', 'c']);
    assert.deepEqual(moveTile(['a', 'b', 'c'], 1, 9), ['a', 'c', 'b']);
    assert.deepEqual(moveTile(['a', 'b', 'c'], 5, 0), ['a', 'b', 'c']);
});

test('only the default order needs nothing kept', () => {
    assert.equal(isDefaultOrder(TILES.slice()), true);
    assert.equal(isDefaultOrder(moveTile(TILES, 0, 1)), false);
});

test('the tiles turned off are not shown, but one always is', () => {
    assert.deepEqual(shownTiles(['a', 'b', 'c'], ['b']), ['a', 'c']);
    assert.deepEqual(shownTiles(['a', 'b'], ['a', 'b']), ['a']);
    assert.deepEqual(shownTiles(['a', 'b'], undefined), ['a', 'b']);
});

test('dragging the tiles shown keeps the hidden ones in their places', () => {
    assert.deepEqual(withShownOrder(['a', 'b', 'c', 'd'], ['d', 'a', 'c']), ['d', 'b', 'a', 'c']);
    assert.deepEqual(withShownOrder(['a', 'b'], ['b', 'a']), ['b', 'a']);
});

test('every tile has a name in the settings', () => {
    assert.deepEqual(Object.keys(TILE_NAMES).sort(), TILES.slice().sort());
});

// The Details tab of a widget at its usual size: 600 by 330 pixels.
const AREA = [600, 330, { minimumWidth: 85, minimumHeight: 76, roomyHeight: 140 }];
const grid = (count) => tileGrid(count, ...AREA);

test('all the tiles fit in two rows of six at the usual size', () => {
    assert.deepEqual(grid(11), { columns: 6, rows: 2, rowsShown: 2 });
});

test('fewer tiles grow wider, rather than leave the area empty', () => {
    assert.deepEqual(grid(8), { columns: 4, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(6), { columns: 3, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(5), { columns: 3, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(4), { columns: 2, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(2), { columns: 2, rows: 1, rowsShown: 1 });
    assert.deepEqual(grid(1), { columns: 1, rows: 1, rowsShown: 1 });
});

test('every row is full: what the last one lacks, the tile that gains most from width takes', () => {
    const order = ['wind', 'pressure', 'moon', 'sun', 'clouds'];
    const cells = tileCells(order, grid(5));

    assert.deepEqual(cells.slice(0, 3).map((cell) => [cell.row, cell.x, cell.width]), [[0, 0, 1 / 3], [0, 1 / 3, 1 / 3], [0, 2 / 3, 1 / 3]]);
    // The way of the sun takes two cells; the clouds keep one.
    assert.deepEqual(cells.slice(3).map((cell) => [cell.row, cell.x, cell.width]), [[1, 0, 2 / 3], [1, 2 / 3, 1 / 3]]);
});

test('eleven tiles in rows of six: one of the second row takes two cells, and the columns line up', () => {
    const order = ['wind', 'air', 'humidity', 'dewPoint', 'pressure', 'uv', 'clouds', 'visibility', 'sun', 'moon', 'aurora'];
    const cells = tileCells(order, grid(11));

    assert.deepEqual(cells.map((cell) => cell.width * 6), [1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1]);
    assert.ok(cells.every((cell) => Number.isInteger(Math.round(cell.x * 6 * 1e9) / 1e9)));
});

test('full rows are preferred, so that no row is shorter than the others', () => {
    assert.deepEqual(grid(10), { columns: 5, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(7), { columns: 4, rows: 2, rowsShown: 2 });
    assert.deepEqual(grid(3), { columns: 3, rows: 1, rowsShown: 1 });
});

test('too many tiles for the area keep a usable size and scroll', () => {
    const layout = tileGrid(11, 300, 200, { minimumWidth: 85, minimumHeight: 76, roomyHeight: 140 });

    assert.equal(layout.columns, 3);
    assert.equal(layout.rows, 4);
    assert.equal(layout.rowsShown, 1);
});
