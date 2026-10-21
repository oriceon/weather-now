// A city: a far skyline in the haze, with a television tower; nearer, blocks of every height and
// facing, their towers lit on the side of the sun, a domed church among them; in front, the street,
// its trees, lamp posts and cars. By night the windows light up floor by floor, the towers show
// their red lights, and the city lights the bottom of the sky.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { drawTrees, landColour, paletteOf, rgba } from './shared.mjs';

/**
 * The blocks of the city, from the farthest: their height as a share of that of the land, between
 * `low` and `high`, and up to `tower` for the share `towers` of them that are towers; their width as
 * a share of the layer, between `narrow` and `wide`; the haze on them; and the size of a window and
 * of a floor, in pixels. The farthest is only a skyline.
 */
export const CITY_LAYERS = [
    { part: 'back', low: 0.4, high: 0.62, tower: 0.8, towers: 0.18, narrow: 0.018, wide: 0.04, haze: 0.72, day: '#9fb0c6', night: '#232b42', window: null },
    { part: 'back', low: 0.32, high: 0.58, tower: 0.9, towers: 0.14, narrow: 0.022, wide: 0.05, haze: 0.5, day: '#8f9fb6', night: '#1c2338', window: [2.4, 3.2] },
    { part: 'middle', low: 0.22, high: 0.46, tower: 0.72, towers: 0.12, narrow: 0.03, wide: 0.07, haze: 0.26, day: '#61728b', night: '#131a2a', window: [3.2, 4.2] },
    { part: 'front', low: 0.1, high: 0.3, tower: 0.48, towers: 0.08, narrow: 0.045, wide: 0.1, haze: 0, day: '#3e4b5f', night: '#0b101b', window: [4.4, 5.8] },
];
const TOWER_ROOFS = ['setback', 'spire', 'antenna', 'setback', 'flat', 'box'];
const LOW_ROOFS = ['flat', 'box', 'flat', 'pitched', 'box', 'dome'];
/** By day, what the blocks are faced with: stone, concrete, white plaster, glass, brick. */
const FACADES = ['#b8a68e', '#9b948c', '#d3cdc2', '#7f93a8', '#a56c55', '#8a8f96'];
/** The light of a window by night: mostly warm, a few cold. */
const LIT = ['#ffd58a', '#ffe3a8', '#ffc978', '#fff0cf', '#cfe0ff'];
/** The colours of cars. */
const CARS = ['#b8bcc2', '#2f3a4a', '#8c1f1f', '#e8e6e1', '#1d1f24', '#3d5f8c', '#6b6f75'];
/** Where the television tower and the domed church stand, as shares of the width of their layer. */
const TV_TOWER = 0.64;
const CHURCH = 0.3;
/** The street, in front: its height as a share of the land. */
const STREET = 0.045;

/**
 * The blocks of a layer of the city, left to right across it: `{ left, width, height, roof, windows,
 * seed }`, the first three as shares of the width of the layer and of the height of the land.
 */
export function skyline(layer) {
    const shape = CITY_LAYERS[layer];
    const blocks = [];

    for (let left = 0, block = 0; left < 1; block++) {
        const seed = block + layer * 97;
        const tower = noise(seed, 211) < shape.towers;
        const width = (shape.narrow + noise(seed, 212) * (shape.wide - shape.narrow)) * (tower ? 0.75 : 1);
        const height = tower ? shape.high + noise(seed, 213) * (shape.tower - shape.high) : shape.low + Math.pow(noise(seed, 214), 1.4) * (shape.high - shape.low);
        const roofs = tower ? TOWER_ROOFS : LOW_ROOFS.slice(0, layer === 3 ? 6 : 5);
        const glassy = noise(seed, 216);

        blocks.push({
            left,
            width,
            height,
            roof: roofs[Math.floor(noise(seed, 215) * roofs.length)],
            windows: tower && glassy < 0.35 ? 'glass' : glassy > 0.72 ? 'bands' : 'grid',
            seed,
        });

        // Here and there, a little room between two blocks.
        left += width * (noise(seed, 217) < 0.18 ? 1.35 : 1);
    }

    // The last block reaches the edge, whatever room was left before it.
    const last = blocks[blocks.length - 1];

    last.width = Math.max(last.width, 1 - last.left);

    return blocks;
}

/** How far above its roof a block reaches with its spire or mast, as a share of the height of the land. */
function mast(block) {
    return { spire: 0.12, antenna: 0.09 }[block.roof] * block.height || 0;
}

/**
 * The red lights on top of the towers, warning aircraft: `{ part, x, y }`, `x` as a share of the width
 * of the layer and `y` of the height of the land, from its top; the television tower has one too.
 */
export function beacons() {
    // Not flatMap(): the JavaScript of QML has none.
    return CITY_LAYERS.slice(1, 3).reduce((lights, shape, at) => lights.concat(skyline(at + 1)
        .filter((block) => block.height > shape.high)
        .map((block) => ({ part: shape.part, x: block.left + block.width / 2, y: 1 - block.height - mast(block) }))), [{ part: 'back', x: TV_TOWER, y: 1 - 0.97 }]);
}

export function paintCity(context, look, part) {
    const { width, height } = look;

    CITY_LAYERS.forEach((shape, layer) => {
        if (shape.part !== part) {
            return;
        }

        const depth = layer / (CITY_LAYERS.length - 1);
        const colour = landColour(look.isDay ? shape.day : shape.night, look, shape.haze, depth, false);

        // By night the city lights the bottom of the sky, the more under cloud.
        if (layer === 0 && !look.isDay) {
            const glow = context.createLinearGradient(0, 0, 0, height);

            glow.addColorStop(0, 'rgba(255, 160, 90, 0)');
            glow.addColorStop(1, 'rgba(255, 150, 80, 0.26)');
            context.fillStyle = glow;
            context.fillRect(0, 0, width, height);
        }

        if (layer === 0) {
            paintTvTower(context, look, colour);
        }

        let church = false;

        skyline(layer).forEach((block) => {
            const x = block.left * width;
            const wide = block.width * width - 1;
            const top = height - block.height * height;
            // Nearer, each block shows its own facing; far off, the haze makes them one.
            const facing = look.isDay ? mixHex(colour, landColour(FACADES[Math.floor(noise(block.seed, 218) * FACADES.length)], look, shape.haze, depth, false), 0.5 * (1 - shape.haze)) : colour;

            if (layer === 2 && !church && Math.abs(block.left + block.width / 2 - CHURCH) < block.width) {
                church = true;
                paintChurch(context, look, colour, x + wide / 2, height - shape.low * height * 0.9, wide);

                return;
            }

            paintBlock(context, look, shape, facing, block, x, wide, top);
        });

        if (layer === 3) {
            paintStreet(context, look);
        }
    });
}

/** The television tower, far off: a shaft, the round cabin near its top, and its mast. */
function paintTvTower(context, look, colour) {
    const x = TV_TOWER * look.width;
    const height = look.height;
    const tone = mixHex(colour, '#000000', 0.05);

    context.fillStyle = tone;
    context.beginPath();
    context.moveTo(x - 3, height);
    context.lineTo(x - 1.2, height * 0.28);
    context.lineTo(x + 1.2, height * 0.28);
    context.lineTo(x + 3, height);
    context.closePath();
    context.fill();
    context.fillRect(x - 0.5, height * 0.03, 1, height * 0.25);
    context.beginPath();
    context.ellipse(x - 6, height * 0.25, 12, height * 0.05);
    context.fill();

    if (!look.isDay) {
        context.fillStyle = 'rgba(255, 220, 160, 0.7)';
        context.fillRect(x - 5, height * 0.27, 10, 1);
    }
}

/** A church with a dome on a drum, and a cross on top, its tin roof catching the light. */
function paintChurch(context, look, colour, x, top, wide) {
    const height = look.height;
    const body = Math.max(wide, height * 0.12);
    const dome = body * 0.36;

    context.fillStyle = look.isDay ? mixHex(colour, '#d8cfc0', 0.35) : colour;
    context.fillRect(x - body / 2, top, body, height - top);
    context.fillRect(x - dome * 0.8, top - dome * 0.9, dome * 1.6, dome * 0.95);
    context.fillStyle = look.isDay ? mixHex(colour, '#8fa3a8', 0.45) : mixHex(colour, '#000000', 0.2);
    context.beginPath();
    context.ellipse(x - dome, top - dome * 1.9, dome * 2, dome * 2);
    context.fill();

    if (look.isDay) {
        context.fillStyle = 'rgba(255, 255, 255, 0.22)';
        context.beginPath();
        context.ellipse(x - dome * 0.6, top - dome * 1.75, dome * 0.7, dome * 0.9);
        context.fill();
    }

    context.fillStyle = look.isDay ? '#c9a640' : '#4a4030';
    context.fillRect(x - 0.6, top - dome * 2.6, 1.2, dome * 0.8);
    context.fillRect(x - dome * 0.18, top - dome * 2.4, dome * 0.36, 1);

    // Its tall windows.
    context.fillStyle = look.isDay ? 'rgba(40, 50, 70, 0.45)' : 'rgba(255, 210, 140, 0.55)';

    for (let window = -1; window <= 1; window++) {
        context.fillRect(x + window * body * 0.28 - 1, top + (height - top) * 0.2, 2, (height - top) * 0.35);
    }
}

function paintBlock(context, look, shape, colour, block, x, wide, top) {
    const height = look.height;
    const lightOnRight = look.lightX > x + wide / 2;
    const body = context.createLinearGradient(0, top, 0, height);

    // The top of a block reflects the sky; its foot sinks in the haze of the streets.
    body.addColorStop(0, mixHex(colour, look.isDay ? mixHex(look.horizon, '#ffffff', 0.4) : look.horizon, look.isDay ? 0.16 : 0.06));
    body.addColorStop(1, shape.haze > 0 ? mixHex(colour, look.horizon, shape.haze * 0.5) : mixHex(colour, '#000000', 0.18));
    context.fillStyle = body;

    // The roof.
    context.beginPath();
    if (block.roof === 'setback') {
        const inset = wide * 0.2;
        const step = (height - top) * 0.18;

        context.rect(x, top + step, wide, height - top - step);
        context.rect(x + inset, top, wide - inset * 2, step + 1);
    } else if (block.roof === 'pitched') {
        context.moveTo(x, height);
        context.lineTo(x, top + wide * 0.3);
        context.lineTo(x + wide / 2, top);
        context.lineTo(x + wide, top + wide * 0.3);
        context.lineTo(x + wide, height);
        context.closePath();
    } else if (block.roof === 'dome') {
        context.rect(x, top + wide * 0.3, wide, height - top - wide * 0.3);
        context.ellipse(x + wide * 0.15, top, wide * 0.7, wide * 0.6);
    } else {
        context.rect(x, top, wide, height - top);
    }
    context.fill();

    const masthead = mast(block) * height;

    // On flat roofs, the boxes of lifts and fans, and here and there a water tank.
    if (block.roof === 'box' || (block.roof === 'flat' && shape.window !== null)) {
        context.fillRect(x + wide * (0.15 + noise(block.seed, 221) * 0.4), top - 3, wide * 0.3, 3);

        if (noise(block.seed, 222) > 0.6) {
            context.fillRect(x + wide * 0.7, top - 2, wide * 0.12, 2);
        }
    } else if (masthead > 0) {
        context.fillRect(x + wide / 2 - (block.roof === 'spire' ? 1 : 0.5), top - masthead, block.roof === 'spire' ? 2 : 1, masthead);
    }

    // The face turned away from the light is in shade, its edge on the light side catches it.
    context.fillStyle = `rgba(0, 0, 0, ${look.isDay ? 0.17 : 0.1})`;
    context.fillRect(lightOnRight ? x : x + wide * 0.78, top, wide * 0.22, height - top);

    if (look.isDay) {
        context.fillStyle = rgba(mixHex('#fff4e2', '#ffc48a', look.warmth), 0.16 + 0.3 * look.warmth);
        context.fillRect(lightOnRight ? x + wide - 1 : x, top, 1, height - top);
    }

    if (shape.window !== null) {
        paintWindows(context, look, shape, block, x, wide, top);
    }

    if (look.snow > 0) {
        context.fillStyle = `rgba(240, 245, 250, ${look.snow * 0.9})`;
        context.fillRect(x, block.roof === 'setback' ? top + (height - top) * 0.18 : top, wide, 2.5);
    }
}

/**
 * The windows of a block: a grid, bands of glass, or a curtain wall that mirrors the sky. By day
 * some are dark, some catch the sky; by night some floors are lit more than others. Each colour in
 * a path of its own, as thousands of windows would take a while one by one.
 */
function paintWindows(context, look, shape, block, x, wide, top) {
    const height = look.height;
    const [cell, floor] = shape.window;
    const far = shape.part === 'back';

    if (look.isDay && far) {
        return;
    }

    if (block.windows === 'glass' && look.isDay) {
        const mirror = context.createLinearGradient(x, 0, x + wide, 0);

        mirror.addColorStop(0, rgba(mixHex(look.horizon, '#ffffff', 0.3), 0.28));
        mirror.addColorStop(1, rgba(look.horizon, 0.06));
        context.fillStyle = mirror;
        context.fillRect(x + 1, top + 2, wide - 2, height - top - 2);
        context.fillStyle = 'rgba(255, 255, 255, 0.07)';
        context.beginPath();

        for (let y = top + floor; y < height - 2; y += floor) {
            context.rect(x + 1, y, wide - 2, 0.6);
        }

        context.fill();

        return;
    }

    // How many windows are lit: more in some blocks than in others, and floor by floor.
    const busy = 0.25 + 0.45 * noise(block.seed, 231);
    const bands = block.windows === 'bands';
    const paths = {};
    const add = (colour, left, y, sizeX, sizeY) => {
        (paths[colour] = paths[colour] || []).push([left, y, sizeX, sizeY]);
    };

    for (let y = top + floor * 0.8, row = 0; y < height - floor * 0.6; y += floor, row++) {
        const floorLit = noise(block.seed * 13 + row, 232) < busy + 0.25;

        for (let left = x + cell * 0.45, column = 0; left < x + wide - cell * 0.7; left += cell, column++) {
            const chance = noise(block.seed * 131 + row * 17 + column, 233);
            const sizeX = bands ? cell + 0.2 : cell * 0.5;
            const sizeY = floor * (bands ? 0.42 : 0.5);

            if (look.isDay) {
                add(chance > 0.85 ? 'rgba(20, 30, 45, 0.25)' : chance > 0.55 ? 'rgba(215, 228, 245, 0.2)' : 'rgba(215, 228, 245, 0.11)', left, y, sizeX, sizeY);
            } else if (floorLit && chance < busy) {
                add(rgba(LIT[Math.floor(noise(block.seed + row * 7 + column, 234) * LIT.length)], far ? 0.55 : 0.8), left, y, far ? 1.1 : sizeX, far ? 1.3 : sizeY);
            }
        }
    }

    Object.keys(paths).forEach((colour) => {
        context.fillStyle = colour;
        context.beginPath();
        paths[colour].forEach(([left, y, sizeX, sizeY]) => context.rect(left, y, sizeX, sizeY));
        context.fill();
    });
}

/** The street in front: its pavement and road, the trees along it, the lamp posts, the parked cars. */
function paintStreet(context, look) {
    const { width, height } = look;
    const street = height * STREET;
    const palette = paletteOf(look);
    const tones = palette.leaves.map((leaves) => (look.isDay ? landColour(mixHex(leaves, '#2a3a28', 0.5), look, 0, 1, false) : '#070b12'));
    const trees = [];

    // Trunks, then the crowns over them.
    context.fillStyle = look.isDay ? '#3a3228' : '#05080e';
    context.beginPath();

    for (let x = 4, tree = 0; x < width; tree++) {
        const size = height * (0.03 + noise(tree, 241) * 0.02);

        context.rect(x - 0.8, height - street - size * 1.2, 1.6, size * 1.2);
        trees.push({ x, foot: height - street - size * 0.9, size, fir: false, tone: Math.floor(noise(tree, 242) * tones.length) });
        x += size * (1.6 + noise(tree, 243) * 2.6);
    }

    context.fill();
    drawTrees(context, look, trees, tones);

    // The pavement, and the road.
    context.fillStyle = landColour(look.isDay ? '#8d8a84' : '#1a1c22', look, 0, 1);
    context.fillRect(0, height - street, width, street * 0.35);
    context.fillStyle = look.isDay ? '#3c3f45' : '#0c0e13';
    context.fillRect(0, height - street * 0.65, width, street * 0.65);

    // Cars along the kerb, their lights on by night.
    for (let x = 10, car = 0; x < width - 16; car++) {
        const long = 11 + noise(car, 251) * 5;
        const tall = street * 0.42;
        const y = height - street * 0.6;

        context.fillStyle = look.isDay ? CARS[Math.floor(noise(car, 252) * CARS.length)] : '#101319';
        context.fillRect(x, y, long, tall * 0.6);
        context.fillRect(x + long * 0.2, y - tall * 0.4, long * 0.55, tall * 0.45);
        context.fillStyle = look.isDay ? 'rgba(170, 200, 230, 0.5)' : 'rgba(255, 255, 255, 0.05)';
        context.fillRect(x + long * 0.25, y - tall * 0.32, long * 0.45, tall * 0.3);

        if (!look.isDay) {
            context.fillStyle = 'rgba(255, 60, 40, 0.8)';
            context.fillRect(x, y + 0.5, 1.2, 1);
            context.fillStyle = 'rgba(255, 245, 210, 0.85)';
            context.fillRect(x + long - 1.2, y + 0.5, 1.2, 1);
        }

        x += long + 6 + noise(car, 253) * 30;
    }

    // Lamp posts, and by night their light on the pavement.
    for (let x = 18; x < width; x += 46) {
        context.fillStyle = look.isDay ? '#2b2e33' : '#07090d';
        context.fillRect(x, height - street - height * 0.1, 1, height * 0.1);
        context.fillRect(x - 3, height - street - height * 0.1, 4, 1.2);

        if (!look.isDay) {
            const lamp = context.createRadialGradient(x - 2, height - street - height * 0.1, 0, x - 2, height - street - height * 0.1, 10);

            lamp.addColorStop(0, 'rgba(255, 205, 130, 0.75)');
            lamp.addColorStop(1, 'rgba(255, 205, 130, 0)');
            context.fillStyle = lamp;
            context.fillRect(x - 12, height - street - height * 0.1 - 10, 20, 20);
        }
    }
}
