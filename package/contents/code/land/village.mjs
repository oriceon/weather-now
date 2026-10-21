// A village of Romania on a gentle slope under wooded hills: whitewashed houses, some blue, some
// ochre, under roofs of red tiles or tin, with fruit trees and fences between them and a church
// with a tall pointed tower; in front a meadow with haystacks and a well with its sweep. By night
// the windows light up; in the cold, smoke rises from the chimneys (in QML, see chimneys()).

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { CONIFER, drawTrees, fractal, landColour, lineAcross, lineAt, paletteOf, pathBelow, rgba, treeTones } from './shared.mjs';

const HILLS = [
    { top: 0.12, rise: 0.12, waves: 2.2, haze: 0.5, night: '#1a2339' },
    { top: 0.26, rise: 0.1, waves: 1.8, haze: 0.3, night: '#141b2e' },
];
/** The slope the village stands on: its crest, as a share of the height of the land. */
const SLOPE = { top: 0.4, rise: 0.06, waves: 1.3 };
/** The rows of houses, from the farthest: how far below the crest, and how big, as shares of the height of the land. */
const ROWS = [
    { below: 0.06, size: 0.075 },
    { below: 0.14, size: 0.1 },
    { below: 0.25, size: 0.13 },
];
const WALLS = ['#ebe5d6', '#e2d8c2', '#c3d1de', '#dcc283', '#ece8df'];
const ROOFS = ['#a4442c', '#8f3b27', '#7a4a33', '#8e979f', '#b1553a'];
/** Where the church stands, as a share of the width, and in which row. */
const CHURCH = { along: 0.58, row: 0 };
/** Where the well with its sweep stands in the meadow. */
const WELL = 0.2;

function hillLine(index, along) {
    const hill = HILLS[index];

    return hill.top + hill.rise * (1 - fractal(along * hill.waves + index * 3.3, 800 + index, 4));
}

function slopeLine(along) {
    return SLOPE.top + SLOPE.rise * (1 - fractal(along * SLOPE.waves, 810, 3));
}

/**
 * The dirt road that winds up through the village: where its middle is across, and how wide it is,
 * as shares of the width, at `share` of the way from the crest (0) to the bottom (1).
 */
function road(share) {
    return { along: 0.47 + 0.1 * Math.sin(share * 4.2 + 0.6) - share * 0.06, wide: 0.006 + share * 0.07 };
}

/** How far down from the crest to the bottom a height on the slope is, 0 to 1. */
function shareDown(along, height) {
    const crest = slopeLine(along);

    return Math.max(0, Math.min(1, (height - crest) / (1 - crest)));
}

/**
 * The houses of the village on land `aspect` times as wide as it is high: `{ x, foot, size, walls,
 * roof, chimney, row, seed }`, `x` and `size` in shares of the width and the height of the land,
 * `foot` of its height; the church apart.
 */
export function houses(aspect = 3) {
    const all = [];

    ROWS.forEach((row, index) => {
        for (let along = 0.02 + noise(index, 821) * 0.03, house = 0; along < 0.98; house++) {
            const seed = house + index * 100;
            const gap = row.size * (1.5 + noise(seed, 822) * 1.4) * 0.9 / aspect;
            const church = index === CHURCH.row && Math.abs(along - CHURCH.along) < gap * 1.2;
            const foot = slopeLine(along) + row.below + (noise(seed, 824) - 0.5) * 0.02;
            const lane = road(shareDown(along, foot));
            // Not on the road: the houses stand along it.
            const onRoad = Math.abs(along + row.size * 0.6 / aspect - lane.along) < lane.wide / 2 + row.size * 0.75 / aspect;

            if (!church && !onRoad && noise(seed, 823) > 0.1) {
                all.push({
                    x: along,
                    foot,
                    size: row.size * (0.85 + noise(seed, 825) * 0.3),
                    walls: WALLS[Math.floor(noise(seed, 826) * WALLS.length)],
                    roof: ROOFS[Math.floor(noise(seed, 827) * ROOFS.length)],
                    chimney: noise(seed, 828) < 0.7,
                    row: index,
                    seed,
                });
            }

            along += gap;
        }
    });

    return all;
}

/**
 * The tops of the chimneys, where the smoke comes out: `{ part, x, y, size }`, `x` as a share of the
 * width of the land, `y` and the size of the house of its height.
 */
export function chimneys(aspect = 3) {
    return houses(aspect).filter((house) => house.chimney).map((house) => ({
        part: 'middle',
        x: house.x + house.size * 1.2 * 0.66 / aspect,
        y: house.foot - house.size * 0.62 * 1.95,
        size: house.size,
    }));
}

export function paintVillage(context, look, part) {
    if (part === 'back') {
        paintHills(context, look);
    } else if (part === 'middle') {
        paintSlope(context, look);
    } else {
        paintMeadow(context, look);
    }
}

function paintHills(context, look) {
    const palette = paletteOf(look);

    HILLS.forEach((hill, index) => {
        const points = lineAcross(look, (along) => hillLine(index, along));
        const colour = landColour(look.isDay ? palette.ranges[index] : hill.night, look, hill.haze, index / 3);
        const top = Math.min(...points.map((point) => point[1]));
        const body = context.createLinearGradient(0, top, 0, top + look.height * 0.25);

        pathBelow(context, look, points);
        body.addColorStop(0, colour);
        body.addColorStop(1, mixHex(colour, look.horizon, 0.3 + hill.haze * 0.3));
        context.fillStyle = body;
        context.fill();

        // Woods along the tops.
        const tones = treeTones(look, palette.leaves.concat([CONIFER]), palette.ranges[index], hill.night, hill.haze, index / 3);
        const trees = [];
        const crown = look.height * (0.006 + index * 0.003);

        for (let x = 0, tree = 0; x < look.width; tree++) {
            const along = x / look.width;

            x += crown * (1 + noise(tree, 831));

            if (fractal(along * 6 + index, 832 + index, 2) < 0.5) {
                continue;
            }

            for (let row = 0; row < 3; row++) {
                trees.push({ x: x + row * crown * 0.5, foot: lineAt(points, Math.min(look.width, x)) + crown * (0.8 + row * 1.2), size: crown, fir: noise(tree + row, 833) < 0.3, tone: Math.floor(noise(tree * 3 + row, 834) * tones.length) });
            }
        }

        drawTrees(context, look, trees, tones);
    });
}

/** The slope of the village: its meadow, its houses row by row with trees and fences between, the church. */
function paintSlope(context, look) {
    const palette = paletteOf(look);
    const points = lineAcross(look, (along) => slopeLine(along));
    const top = Math.min(...points.map((point) => point[1]));
    const ground = context.createLinearGradient(0, top, 0, look.height);

    pathBelow(context, look, points);
    ground.addColorStop(0, landColour(look.isDay ? palette.ranges[1] : '#121a2a', look, 0.12, 0.6));
    ground.addColorStop(1, landColour(look.isDay ? palette.ranges[2] : '#0c121e', look, 0, 0.9));
    context.fillStyle = ground;
    context.fill();

    const all = houses(look.width / look.height);
    const tones = treeTones(look, palette.leaves, palette.ranges[2], '#0c121e', 0.05, 0.8);

    // The road, a pale band winding up the slope, wider nearer.
    context.fillStyle = landColour(look.isDay ? '#b3a585' : '#1a1c24', look, 0.05, 0.8);
    context.beginPath();

    for (let step = 0; step <= 20; step++) {
        const share = step / 20;
        const lane = road(share);
        const y = (slopeLine(lane.along) + (1 - slopeLine(lane.along)) * share) * look.height;

        (step === 0 ? context.moveTo : context.lineTo).call(context, (lane.along - lane.wide / 2) * look.width, y);
    }

    for (let step = 20; step >= 0; step--) {
        const share = step / 20;
        const lane = road(share);
        const y = (slopeLine(lane.along) + (1 - slopeLine(lane.along)) * share) * look.height;

        context.lineTo((lane.along + lane.wide / 2) * look.width, y);
    }

    context.closePath();
    context.fill();

    // A garden by each house: a patch of tilled earth or greens, in rows.
    all.forEach((house) => {
        const width = house.size * look.height * 1.6;
        const x = house.x * look.width - width * 0.15 + (noise(house.seed, 844) > 0.5 ? width * 0.75 : -width * 0.85);
        const y = house.foot * look.height - house.size * look.height * 0.15;
        const tilled = noise(house.seed, 845) > 0.5;

        context.fillStyle = rgba(look.isDay ? (tilled ? '#7a6448' : '#5f8a3e') : '#0a0f1a', look.isDay ? 0.45 : 0.3);
        context.fillRect(x, y, width, house.size * look.height * 0.3);
    });

    ROWS.forEach((row, index) => {
        const own = all.filter((house) => house.row === index);
        const trees = [];

        // Fruit trees behind and between the houses, and now and then a tall walnut.
        own.forEach((house) => {
            const unit = house.size * look.height;

            [[1.3, 0.38, 841], [-0.5, 0.34, 846], [0.55, 0.6, 847]].forEach(([side, size, salt], tree) => {
                if (noise(house.seed, salt) < [0.75, 0.55, 0.22][tree]) {
                    trees.push({ x: house.x * look.width + unit * side * 1.2, foot: house.foot * look.height - unit * (tree === 2 ? 0.5 : 0.08), size: unit * size, fir: false, tone: Math.floor(noise(house.seed, salt + 10) * tones.length) });
                }
            });
        });

        drawTrees(context, look, trees, tones);

        if (index === CHURCH.row) {
            paintChurch(context, look, slopeLine(CHURCH.along) + row.below, row.size);
        }

        own.forEach((house) => paintHouse(context, look, house));

        // A fence in front of each house.
        context.strokeStyle = look.isDay ? rgba('#6b5a44', 0.55) : 'rgba(10, 12, 18, 0.6)';
        context.lineWidth = 0.6;
        context.beginPath();

        own.forEach((house) => {
            const left = house.x * look.width - house.size * look.height * 0.4;
            const right = house.x * look.width + house.size * look.height * 1.6;
            const y = house.foot * look.height + 1.5;

            context.moveTo(left, y);
            context.lineTo(right, y);

            for (let post = left; post <= right; post += 3 + index) {
                context.moveTo(post, y - 1.5 - index * 0.6);
                context.lineTo(post, y + 0.6);
            }
        });

        context.stroke();
    });
}

/** A house: whitewashed walls, a hipped roof of tiles or tin, a chimney, two windows, lit by night. */
function paintHouse(context, look, house) {
    const width = house.size * look.height * 1.2;
    const tall = house.size * look.height * 0.62;
    const x = house.x * look.width;
    const foot = house.foot * look.height;
    const lightOnRight = look.lightX > x + width / 2;
    const walls = landColour(look.isDay ? house.walls : '#1d2333', look, 0.05 * (2 - house.row), 0.8, false);
    const roof = landColour(look.isDay ? house.roof : '#141821', look, 0.05 * (2 - house.row), 0.8);

    context.fillStyle = walls;
    context.fillRect(x, foot - tall, width, tall);

    // The side away from the light.
    context.fillStyle = `rgba(0, 0, 0, ${look.isDay ? 0.12 : 0.05})`;
    context.fillRect(lightOnRight ? x : x + width * 0.7, foot - tall, width * 0.3, tall);

    context.fillStyle = roof;
    context.beginPath();
    context.moveTo(x - width * 0.08, foot - tall);
    context.lineTo(x + width * 0.22, foot - tall - tall * 0.75);
    context.lineTo(x + width * 0.78, foot - tall - tall * 0.75);
    context.lineTo(x + width * 1.08, foot - tall);
    context.closePath();
    context.fill();

    if (look.isDay) {
        context.fillStyle = 'rgba(255, 240, 220, 0.15)';
        context.fillRect(x + width * (lightOnRight ? 0.5 : 0.22), foot - tall - tall * 0.74, width * 0.28, tall * 0.35);
    }

    if (house.chimney) {
        context.fillStyle = landColour(look.isDay ? '#cfc6b6' : '#151922', look, 0, 0.8);
        context.fillRect(x + width * 0.62, foot - tall - tall * 0.95, width * 0.08, tall * 0.35);
    }

    // Two windows, and by night a warm light in one or both.
    const pane = Math.max(1, width * 0.12);

    [0.22, 0.62].forEach((at, window) => {
        const lit = !look.isDay && noise(house.seed + window, 851) < 0.65;

        context.fillStyle = lit ? `rgba(255, 210, 140, ${0.75 + 0.2 * noise(house.seed, 852)})` : look.isDay ? 'rgba(45, 55, 70, 0.6)' : 'rgba(8, 10, 16, 0.8)';
        context.fillRect(x + width * at, foot - tall * 0.68, pane, pane * 1.15);
    });

    if (look.snow > 0) {
        context.fillStyle = `rgba(245, 248, 252, ${0.85 * look.snow})`;
        context.beginPath();
        context.moveTo(x - width * 0.06, foot - tall);
        context.lineTo(x + width * 0.22, foot - tall - tall * 0.75);
        context.lineTo(x + width * 0.78, foot - tall - tall * 0.75);
        context.lineTo(x + width * 1.06, foot - tall);
        context.lineTo(x + width * 0.9, foot - tall - tall * 0.18);
        context.lineTo(x + width * 0.1, foot - tall - tall * 0.18);
        context.closePath();
        context.fill();
    }
}

/** The church: a white nave, a tall tower with a pointed tin spire that shines, and its cross. */
function paintChurch(context, look, foot, size) {
    const x = CHURCH.along * look.width;
    const y = foot * look.height;
    const unit = size * look.height;
    const white = landColour(look.isDay ? '#eeeae0' : '#1f2535', look, 0.08, 0.7, false);
    const tin = look.isDay ? mixHex('#c4ccd4', '#ffffff', look.warmth * 0.3) : '#3a4252';

    context.fillStyle = white;
    context.fillRect(x - unit * 1.4, y - unit * 0.75, unit * 2.2, unit * 0.75);
    context.fillRect(x + unit * 0.6, y - unit * 1.9, unit * 0.55, unit * 1.9);
    context.fillStyle = landColour(look.isDay ? '#8e979f' : '#161a24', look, 0.08, 0.7);
    context.beginPath();
    context.moveTo(x - unit * 1.5, y - unit * 0.75);
    context.lineTo(x - unit * 1.2, y - unit * 1.15);
    context.lineTo(x + unit * 0.65, y - unit * 1.15);
    context.lineTo(x + unit * 0.65, y - unit * 0.75);
    context.closePath();
    context.fill();
    context.fillStyle = tin;
    context.beginPath();
    context.moveTo(x + unit * 0.55, y - unit * 1.9);
    context.lineTo(x + unit * 0.875, y - unit * 3.1);
    context.lineTo(x + unit * 1.2, y - unit * 1.9);
    context.closePath();
    context.fill();

    // The spire catches the light on one side.
    if (look.isDay) {
        context.fillStyle = 'rgba(255, 255, 255, 0.35)';
        context.beginPath();
        context.moveTo(x + unit * 0.875, y - unit * 3.1);
        context.lineTo(x + unit * (look.lightX > x ? 1.2 : 0.55), y - unit * 1.9);
        context.lineTo(x + unit * 0.875, y - unit * 1.9);
        context.closePath();
        context.fill();
    }

    context.fillStyle = look.isDay ? '#c9a640' : '#4a4030';
    context.fillRect(x + unit * 0.865, y - unit * 3.45, 1, unit * 0.36);
    context.fillRect(x + unit * 0.8, y - unit * 3.35, unit * 0.15, 1);
    context.fillStyle = !look.isDay ? 'rgba(255, 210, 140, 0.6)' : 'rgba(40, 50, 70, 0.5)';
    context.fillRect(x + unit * 0.8, y - unit * 1.5, unit * 0.15, unit * 0.3);
}

/** The meadow in front: its grass, haystacks, a fence, and the well with its sweep. */
function paintMeadow(context, look) {
    const palette = paletteOf(look);
    const line = lineAcross(look, (along) => 0.74 + 0.04 * (fractal(along * 1.6, 860, 3) - 0.5));
    const top = Math.min(...line.map((point) => point[1]));
    const ground = context.createLinearGradient(0, top, 0, look.height);
    const grass = look.isDay ? palette.ranges[2] : '#0a0f1a';

    pathBelow(context, look, line);
    ground.addColorStop(0, landColour(grass, look, 0, 0.9));
    ground.addColorStop(1, landColour(mixHex(grass, '#000000', 0.2), look, 0, 1));
    context.fillStyle = ground;
    context.fill();

    // The grain of the grass.
    context.fillStyle = look.isDay ? 'rgba(255, 250, 220, 0.08)' : 'rgba(150, 170, 200, 0.03)';
    context.beginPath();

    for (let stroke = 0; stroke < look.width * 1.2; stroke++) {
        const x = noise(stroke, 861) * look.width;

        context.rect(x, lineAt(line, x) + noise(stroke, 862) * (look.height - top), 3 + noise(stroke, 863) * 9, 1);
    }

    context.fill();

    const unit = look.height * 0.1;

    // Haystacks: tall rounded stacks of hay, with the pole through them.
    [[0.68, 1], [0.8, 0.8]].forEach(([along, scale]) => {
        const x = along * look.width;
        const foot = lineAt(line, x) + unit * 0.5 * scale;
        const wide = unit * 0.55 * scale;
        const hay = landColour(look.isDay ? (look.season === 'summer' ? '#c9a95a' : '#a98b4e') : '#1b1a1c', look, 0, 1);

        context.fillStyle = hay;
        context.beginPath();
        context.moveTo(x - wide, foot);
        context.quadraticCurveTo(x - wide * 1.05, foot - unit * 0.9 * scale, x, foot - unit * 1.25 * scale);
        context.quadraticCurveTo(x + wide * 1.05, foot - unit * 0.9 * scale, x + wide, foot);
        context.closePath();
        context.fill();
        context.fillStyle = `rgba(0, 0, 0, ${look.isDay ? 0.18 : 0.1})`;
        context.fillRect(look.lightX > x ? x - wide : x + wide * 0.2, foot - unit * 0.8 * scale, wide * 0.8, unit * 0.8 * scale);
        context.fillStyle = look.isDay ? '#4a3a28' : '#08090d';
        context.fillRect(x - 0.6, foot - unit * 1.45 * scale, 1.2, unit * 0.3 * scale);
    });

    // The well with its sweep: the forked post, the long pole across it, and the bucket on its chain.
    const x = WELL * look.width;
    const foot = lineAt(line, x) + unit * 0.4;
    const wood = look.isDay ? '#5a4632' : '#07090e';

    context.strokeStyle = wood;
    context.lineCap = 'round';
    context.lineWidth = Math.max(1.5, unit * 0.05);
    context.beginPath();
    context.moveTo(x, foot);
    context.lineTo(x, foot - unit * 1.5);
    context.moveTo(x - unit * 0.9, foot - unit * 0.5);
    context.lineTo(x + unit * 1.3, foot - unit * 2.1);
    context.stroke();
    context.lineWidth = 0.7;
    context.beginPath();
    context.moveTo(x + unit * 1.3, foot - unit * 2.1);
    context.lineTo(x + unit * 1.3, foot - unit * 0.55);
    context.stroke();
    context.fillStyle = wood;
    context.fillRect(x + unit * 1.22, foot - unit * 0.62, unit * 0.16, unit * 0.16);
    context.fillStyle = landColour(look.isDay ? '#8a7a64' : '#111319', look, 0, 1);
    context.fillRect(x + unit * 1.0, foot - unit * 0.35, unit * 0.6, unit * 0.35);
    context.fillStyle = look.isDay ? '#4a3c2c' : '#06070b';
    context.fillRect(x + unit * 1.0, foot - unit * 0.38, unit * 0.6, unit * 0.06);

    // A fence along the meadow.
    context.strokeStyle = look.isDay ? rgba('#6b5a44', 0.8) : 'rgba(6, 8, 12, 0.9)';
    context.lineWidth = 1;
    context.beginPath();

    for (let post = look.width * 0.3; post < look.width * 0.95; post += unit * 0.35) {
        const y = lineAt(line, post) + unit * 0.75;

        context.moveTo(post, y);
        context.lineTo(post, y - unit * 0.42);
    }

    const start = look.width * 0.3;
    const end = look.width * 0.95;

    [0.32, 0.18].forEach((height) => {
        context.moveTo(start, lineAt(line, start) + unit * (0.75 - height));
        context.lineTo(end, lineAt(line, end) + unit * (0.75 - height));
    });

    context.stroke();
}
