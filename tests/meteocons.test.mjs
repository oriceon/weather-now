import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, openSync, readSync, closeSync } from 'node:fs';
import { DETAIL_ICONS, SHEET, moonIcon } from '../package/contents/code/meteocons.mjs';
import { PHASE_KEYS } from '../package/contents/code/moon.mjs';
import { CODES, METEOCONS, meteocon } from '../package/contents/code/wmo.mjs';

const ICONS = new URL('../package/contents/icons/', import.meta.url);

/** Width and height of a PNG, from its header. */
function pngSize(url) {
    const header = Buffer.alloc(24);
    const file = openSync(url, 'r');

    readSync(file, header, 0, 24, 0);
    closeSync(file);

    return { width: header.readUInt32BE(16), height: header.readUInt32BE(20) };
}

test('meteocon names the icon of a weather code, by day and by night', () => {
    const cases = [
        [0, true, 'clear-day'], [0, false, 'clear-night'],
        [1, true, 'partly-cloudy-day'], [1, false, 'partly-cloudy-night'],
        [2, true, 'overcast-day'], [2, false, 'overcast-night'],
        [3, true, 'overcast'], [3, false, 'overcast'],
        [45, true, 'fog'], [53, true, 'drizzle'], [57, true, 'sleet'],
        [61, true, 'rain'], [63, false, 'rain'], [65, true, 'extreme-rain'], [67, true, 'sleet'],
        [73, true, 'snow'], [75, true, 'extreme-snow'],
        [80, true, 'partly-cloudy-day-drizzle'], [80, false, 'partly-cloudy-night-drizzle'],
        [81, true, 'partly-cloudy-day-rain'], [81, false, 'partly-cloudy-night-rain'],
        [82, true, 'extreme-day-rain'], [82, false, 'extreme-night-rain'],
        [85, true, 'partly-cloudy-day-snow'], [86, false, 'partly-cloudy-night-snow'],
        [95, true, 'thunderstorms-rain'], [99, false, 'thunderstorms-hail'],
    ];

    for (const [code, isDay, want] of cases) {
        assert.equal(meteocon(code, isDay), want, `code ${code} day=${isDay}`);
    }
});

test('an unknown or missing code has no Meteocon, so that the widget falls back to the icon of the theme', () => {
    for (const code of [999, null, undefined]) {
        assert.equal(meteocon(code, true), '');
        assert.equal(meteocon(code, false), '');
    }
});

test('METEOCONS lists every icon a weather code can ask for, once', () => {
    const asked = new Set();

    for (const code of CODES) {
        asked.add(meteocon(code, true));
        asked.add(meteocon(code, false));
    }

    assert.deepEqual(METEOCONS.slice().sort(), [...asked].sort());
});

test('every weather icon is bundled, as a still picture and as an animation', () => {
    for (const name of METEOCONS) {
        assert.ok(existsSync(new URL(`static/${name}.svg`, ICONS)), `static/${name}.svg`);
        assert.ok(existsSync(new URL(`animated/${name}.png`, ICONS)), `animated/${name}.png`);
    }
});

test('the animations are film strips of the geometry the widget plays them with', () => {
    assert.equal(SHEET.frames, SHEET.columns * SHEET.rows);

    for (const name of METEOCONS) {
        assert.deepEqual(pngSize(new URL(`animated/${name}.png`, ICONS)), {
            width: SHEET.columns * SHEET.frameSize,
            height: SHEET.rows * SHEET.frameSize,
        }, name);
    }
});

test('moonIcon names the icon of each phase of the moon, and all of them are bundled', () => {
    assert.equal(moonIcon('moon.new'), 'moon-new');
    assert.equal(moonIcon('moon.waxingCrescent'), 'moon-waxing-crescent');
    assert.equal(moonIcon('moon.firstQuarter'), 'moon-first-quarter');
    assert.equal(moonIcon('moon.waningGibbous'), 'moon-waning-gibbous');

    for (const key of PHASE_KEYS) {
        assert.ok(existsSync(new URL(`static/${moonIcon(key)}.svg`, ICONS)), moonIcon(key));
    }
});

test('the icons of the details are bundled', () => {
    assert.ok(DETAIL_ICONS.length > 0);

    for (const name of DETAIL_ICONS) {
        assert.ok(existsSync(new URL(`static/${name}.svg`, ICONS)), name);
    }
});

test('the licence of the icons travels with them', () => {
    assert.ok(existsSync(new URL('LICENSE', ICONS)));
});
