import test from 'node:test';
import assert from 'node:assert/strict';
import { BEACH, CITY_LAYERS, HILL_RANGES, HORIZON, KINDS, PARTS, beacons, chimneys, crest, fractal, paintLand, paintSurf, seasonOf, shoreline, skyline, smoothNoise, waterBand } from '../package/contents/code/land.mjs';

/**
 * A 2D context that only records what it is asked: every number it is given, and every colour, so
 * that a picture with a NaN in it, or a colour the Canvas does not read, shows.
 */
function recordingContext() {
    const numbers = [];
    const colours = [];
    const gradient = () => ({ addColorStop: (stop, colour) => (numbers.push(stop), colours.push(colour)) });
    const context = new Proxy({ numbers, colours }, {
        get(target, name) {
            if (name in target) {
                return target[name];
            }

            if (name === 'createLinearGradient' || name === 'createRadialGradient') {
                return (...values) => (numbers.push(...values), gradient());
            }

            return (...values) => numbers.push(...values.filter((value) => typeof value === 'number'));
        },
        set(target, name, value) {
            if (name === 'fillStyle' || name === 'strokeStyle') {
                if (typeof value === 'string') {
                    colours.push(value);
                }
            } else if (typeof value === 'number') {
                numbers.push(value);
            }

            return true;
        },
    });

    return context;
}

const LOOK = { width: 560, height: 190, isDay: true, horizon: '#a9d4ff', warmth: 0.3, snow: 0, lightX: 200, season: 'autumn', wind: 30 };
const COLOUR = /^(#[0-9a-f]{6}|rgba\(\d+, \d+, \d+, (0|1|0?\.\d+|1e-\d+|\d\.\d+e-\d+)\))$/;

test('smooth noise passes through the noise at whole numbers and stays between 0 and 1', () => {
    for (let x = -3; x < 20; x += 0.37) {
        const value = smoothNoise(x, 5);

        assert.ok(value >= 0 && value <= 1);
    }

    assert.ok(Math.abs(smoothNoise(4.0001, 9) - smoothNoise(4, 9)) < 0.01);
});

test('fractal noise stays between 0 and 1, ridged or not', () => {
    for (let x = 0; x < 10; x += 0.13) {
        for (const ridged of [false, true]) {
            const value = fractal(x, 40, 6, ridged);

            assert.ok(value >= 0 && value <= 1, `${x} ${ridged} ${value}`);
        }
    }
});

test('every crest stays within its range, the farther ranges higher', () => {
    HILL_RANGES.forEach((range, index) => {
        for (let along = 0; along <= 1.1; along += 0.01) {
            const y = crest(index, along);

            assert.ok(y >= range.top && y <= range.top + range.rise, `${index} ${along} ${y}`);
        }
    });

    for (let index = 1; index < HILL_RANGES.length; index++) {
        assert.ok(HILL_RANGES[index].top > HILL_RANGES[index - 1].top);
    }
});

test('the season follows the hemisphere, and the leaves stay green between the tropics', () => {
    assert.equal(seasonOf('2026-10-21', 44.18), 'autumn');
    assert.equal(seasonOf('2026-10-21', -33.9), 'spring');
    assert.equal(seasonOf('2026-01-10', 52.2), 'winter');
    assert.equal(seasonOf('2026-07-10', -41.3), 'winter');
    assert.equal(seasonOf('2026-04-02', 45), 'spring');
    assert.equal(seasonOf('2026-12-31', 1.35), 'summer');
});

test('each layer of the city reaches across, with its blocks within their heights', () => {
    CITY_LAYERS.forEach((shape, layer) => {
        const blocks = skyline(layer);
        const last = blocks[blocks.length - 1];

        assert.ok(last.left + last.width >= 1);
        blocks.forEach((block) => {
            assert.ok(block.height >= shape.low && block.height <= shape.tower);
            assert.ok(block.width >= shape.narrow * 0.75 && block.width <= shape.wide);
        });
    });

    assert.deepEqual(skyline(1), skyline(1));
});

test('the red lights stand on the towers of the two farther layers, inside the land', () => {
    const lights = beacons();

    assert.ok(lights.length > 0);
    lights.forEach((light) => {
        assert.notEqual(light.part, 'front');
        assert.ok(light.y > 0 && light.y < 1 - CITY_LAYERS[0].low);
        assert.ok(light.x >= 0 && light.x <= 1.1);
    });
});

test('the beach lies below the horizon, near the bottom', () => {
    for (let along = 0; along <= 1; along += 0.02) {
        const y = shoreline(along);

        assert.ok(y > HORIZON + 0.4 && y < 1);
        assert.ok(Math.abs(y - BEACH) < 0.03);
    }
});

test('every kind of land paints each of its layers with numbers and colours a Canvas reads', () => {
    for (const kind of KINDS.filter((kind) => kind !== 'none')) {
        for (const isDay of [true, false]) {
            for (const snow of [0, 0.8]) {
                for (const part of PARTS) {
                    const context = recordingContext();

                    paintLand(context, kind, { ...LOOK, isDay, snow }, part);

                    assert.ok(context.numbers.every(Number.isFinite), `${kind} ${part} ${isDay}: a number is not finite`);
                    context.colours.forEach((colour) => assert.match(colour, COLOUR, `${kind} ${part} ${isDay}`));
                }
            }
        }
    }

    const surf = recordingContext();

    paintSurf(surf, LOOK);
    assert.ok(surf.numbers.every(Number.isFinite));
});

// Grey with distance, mountains behind the hills were taken for clouds.
test('the hills are all green ranges, with more trees in front than further back', () => {
    HILL_RANGES.forEach((range, index) => {
        assert.ok(range.trees > 0);
        assert.ok(index === 0 || range.trees > HILL_RANGES[index - 1].trees);
    });
});

test('the smoke of the village comes out of chimneys on the land, above the houses', () => {
    const tops = chimneys();

    assert.ok(tops.length > 5);
    tops.forEach((top) => {
        assert.ok(top.x > 0 && top.x < 1.1);
        assert.ok(top.y > 0.3 && top.y < 0.75);
    });
});

test('the sun glitters on the water of the sea and of the lake, and on no other land', () => {
    assert.deepEqual(waterBand('sea'), [HORIZON, BEACH]);
    assert.ok(waterBand('lake')[0] > 0.4 && waterBand('lake')[1] < 1);
    assert.equal(waterBand('hills'), null);
    assert.equal(waterBand('poppies'), null);
});

// A wide screen bears more trees, rows and houses than a widget: a loop that only ends at the size
// of a widget would freeze Plasma behind the wallpaper.
test('every kind of land paints at the size of a wide screen too, at once', { timeout: 10000 }, () => {
    for (const kind of KINDS.filter((kind) => kind !== 'none')) {
        for (const snow of [0, 1]) {
            for (const part of PARTS) {
                const context = recordingContext();
                const started = Date.now();

                paintLand(context, kind, { ...LOOK, width: 2608, height: 643, lightX: 900, snow }, part);

                assert.ok(context.numbers.every(Number.isFinite), `${kind} ${part}`);
                assert.ok(Date.now() - started < 2000, `${kind} ${part} took ${Date.now() - started} ms`);
            }
        }
    }
});
