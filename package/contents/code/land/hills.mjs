// Rolling hills, as the countryside of Romania has them: fields in strips and patches, with hedges
// of trees between them and woods on the tops, the slopes lit on the side of the sun, a lone oak in
// front, and by night the lights of a few villages. No mountains behind them: grey with distance,
// they were taken for clouds.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { CONIFER, clamp01, drawTrees, fractal, landColour, lightColour, lineAcross, lineAt, paletteOf, patchNoise, pathBelow, rgba, strokeLine, treeTones } from './shared.mjs';

/**
 * The ranges of hills, from the farthest: where their crest can reach, as a share of the height of
 * the land from its top, how much it rises and falls below that, how many swells fit across, how
 * fine its outline is, how much of the haze of distance lies on it and how far off it is, 0 to 1.
 * They are green, or not, with the season, and bear woods, `trees` the half-width of a crown as a
 * share of the height of the land; the two farther are farmed, in fields of about `fields` of the
 * width each. `seed` keeps the shape each had beside the mountains, which the user liked.
 */
export const HILL_RANGES = [
    { part: 'back', top: 0.1, rise: 0.2, waves: 2.1, octaves: 5, haze: 0.16, far: 0.5, seed: 2, night: '#151d31', trees: 0.007, fields: 0.07 },
    { part: 'middle', top: 0.3, rise: 0.18, waves: 1.7, octaves: 5, haze: 0.13, far: 0.75, seed: 3, night: '#111829', trees: 0.012, fields: 0.1 },
    { part: 'front', top: 0.52, rise: 0.15, waves: 1.2, octaves: 4, haze: 0, far: 1, seed: 4, night: '#0b111e', trees: 0.022 },
];
/** The nearest range, with the oak, the longer grass and no fields. */
const NEAREST = HILL_RANGES.length - 1;

/** By day, the fields of each season: green crops, ploughed earth, ripe grain or stubble, meadow. */
const FIELDS = {
    spring: ['#7aa34e', '#7a6448', '#d2c34c', '#5f8f45'],
    summer: ['#c9b25a', '#6f8f3e', '#b59a52', '#7a6448'],
    autumn: ['#b59c62', '#6e5640', '#6f8a45', '#8c7a4a'],
    winter: ['#77705f', '#6c7a55', '#857b66', '#5d6650'],
};
/** Ploughed earth, the second of each season, shows its furrows. */
const PLOUGHED = 1;
/** About as many trees as a range of hills bears at most, so that a wide view still paints at once. */
const TREES_PER_RANGE = 2500;

/** Where the crest of range `range` is at `along` (0 left, 1 right), as a share of the height of the land from its top. */
export function crest(range, along) {
    const shape = HILL_RANGES[range];
    const value = fractal(along * shape.waves + shape.seed * 7.31, 40 + shape.seed, shape.octaves);

    return shape.top + shape.rise * (1 - clamp01((value - 0.22) / 0.56));
}

/** How far down from its crest a range shows before the next one hides it, in pixels. */
function shownDepth(look, index) {
    const next = HILL_RANGES[index + 1];

    return (next ? next.top + next.rise - HILL_RANGES[index].top : 1 - HILL_RANGES[index].top) * look.height;
}

export function paintHills(context, look, part) {
    const palette = paletteOf(look);

    HILL_RANGES.forEach((range, index) => {
        if (range.part !== part) {
            return;
        }

        const own = look.isDay ? palette.ranges[index] : range.night;
        const colour = landColour(own, look, range.haze, range.far);
        const points = lineAcross(look, (along) => crest(index, along));
        const next = HILL_RANGES[index + 1];
        const front = next ? lineAcross(look, (along) => crest(index + 1, along)) : null;
        const top = Math.min(...points.map((point) => point[1]));

        pathBelow(context, look, points);

        // The mist that lies in the valleys: each range pales towards its foot, by night less. The
        // nearest darkens instead, as the ground does close to the eye.
        const body = context.createLinearGradient(0, top, 0, Math.min(look.height, top + look.height * 0.34));

        if (index === NEAREST) {
            body.addColorStop(0, mixHex(colour, look.horizon, 0.06));
            body.addColorStop(1, mixHex(colour, '#000000', 0.22));
        } else {
            const mist = (look.isDay ? 0.34 : 0.16) + range.haze * 0.3;

            body.addColorStop(0, colour);
            body.addColorStop(0.55, mixHex(colour, look.horizon, mist * 0.45));
            body.addColorStop(1, mixHex(colour, look.horizon, mist));
        }

        context.fillStyle = body;
        context.fill();

        const hedges = range.fields ? paintFields(context, look, index, points) : [];

        paintShading(context, look, index, points);

        // The side turned to the sun, or to the moon, takes its light.
        const light = lightColour(look);
        const glow = context.createRadialGradient(look.lightX, top - look.height * 0.2, 0, look.lightX, top - look.height * 0.2, look.width * 0.65);

        glow.addColorStop(0, rgba(light, (look.isDay ? 0.1 + 0.12 * look.warmth : 0.05) * (1 - range.haze * 0.6)));
        glow.addColorStop(1, rgba(light, 0));
        pathBelow(context, look, points);
        context.fillStyle = glow;
        context.fill();

        paintGrass(context, look, index, points);
        paintWoods(context, look, index, points, palette, front, hedges);

        if (index === NEAREST) {
            paintOak(context, look, points, palette);
        }

        // A low sun, or the moon, lights the crest from behind; under snow a shadow keeps it apart.
        context.lineWidth = 1.2;
        context.strokeStyle = look.snow > 0
            ? `rgba(70, 90, 120, ${0.3 * look.snow})`
            : rgba(light, look.isDay ? 0.35 * look.warmth * (1 - range.haze * 0.5) : 0.1);
        strokeLine(context, points);

        if (!look.isDay && index !== NEAREST) {
            paintVillages(context, look, index, points);
        }
    });
}

/**
 * The broad light and shade of a rounded hill: the slopes that face the sun a little lighter, the
 * others darker, fading down from the crest; measured over a wide stretch, so that they change slowly.
 */
function paintShading(context, look, index, points) {
    const down = shownDepth(look, index);
    const step = 4;

    for (let x = 0; x < look.width; x += step) {
        const slope = lineAt(points, Math.min(look.width, x + 24)) - lineAt(points, Math.max(0, x - 24));
        const strength = clamp01(Math.abs(slope) / 22) * (look.isDay ? 0.14 : 0.06) * (1 - HILL_RANGES[index].haze);
        const lit = slope * (look.lightX - x) > 0;
        const y = lineAt(points, x);

        [[0, 0.4, 1], [0.4, 1, 0.45]].forEach(([from, to, share]) => {
            context.fillStyle = lit ? `rgba(255, 244, 214, ${strength * share * 0.8})` : `rgba(10, 18, 30, ${strength * share})`;
            context.fillRect(x, y + down * from, step, down * (to - from));
        });
    }
}

/**
 * Fields on a farmed range: strips that fan out down the slope as they come nearer, each sown with
 * the crop of the season, some ploughed into furrows, some cut across in two; and along some of
 * their edges, a hedge of trees, which is handed back to be drawn with the woods.
 */
function paintFields(context, look, index, points) {
    const range = HILL_RANGES[index];
    const crops = FIELDS[look.season] || FIELDS.summer;
    const down = shownDepth(look, index);
    const middle = look.width / 2;
    const spread = 0.22;
    const hedges = [];
    const crown = look.height * range.trees * 1.1;

    // The foot of a boundary that starts on the crest at `x`: farther out, as the slope comes nearer.
    const foot = (x) => x + (x - middle) * spread;

    for (let left = -look.width * 0.05, field = 0; left < look.width; field++) {
        const seed = field + range.seed * 300;
        const right = left + look.width * range.fields * (0.6 + noise(seed, 371) * 0.9);
        const split = 0.35 + noise(seed, 372) * 0.4;

        [[0, split], [split, 1]].forEach(([from, to], half) => {
            const crop = Math.floor(noise(seed * 2 + half, 373) * crops.length);
            const tone = look.isDay ? landColour(crops[crop], look, range.haze + 0.08, range.far) : mixHex(range.night, crops[crop], 0.08);
            const at = (x, share) => [x + (foot(x) - x) * share, lineAt(points, Math.max(0, Math.min(look.width, x))) + 1 + down * share];
            const corners = [at(left, from), at(right, from), at(right, to), at(left, to)];

            context.fillStyle = rgba(tone, look.isDay ? 0.4 : 0.25);
            context.beginPath();
            corners.forEach(([x, y], corner) => (corner === 0 ? context.moveTo(x, y) : context.lineTo(x, y)));
            context.closePath();
            context.fill();

            // Furrows run down the slope, as the strip does.
            if (crop === PLOUGHED && look.isDay) {
                context.strokeStyle = 'rgba(40, 28, 15, 0.08)';
                context.lineWidth = 0.6;
                context.beginPath();

                for (let x = left + 4; x < right - 2; x += 6) {
                    const [topX, topY] = at(x, from);
                    const [bottomX, bottomY] = at(x, to);

                    context.moveTo(topX, topY);
                    context.lineTo(bottomX, bottomY);
                }

                context.stroke();
            }
        });

        // Here and there a hedge along the edge on the right, down the slope, with gaps in it.
        if (noise(seed, 374) < 0.3) {
            for (let share = noise(seed, 376) * 0.3; share <= 1; share += crown * (1.6 + noise(seed + share * 50, 377) * 1.6) / down) {
                const x = right + (foot(right) - right) * share;

                if (noise(seed + share * 100, 378) < 0.8) {
                    hedges.push({ x, foot: lineAt(points, Math.max(0, Math.min(look.width, right))) + down * share + crown * 0.5, size: crown * (0.7 + noise(seed + share * 100, 375) * 0.7), fir: false, tone: 0 });
                }
            }
        }

        left = right;
    }

    return hedges;
}

/** The grain of the grass, in short strokes lighter and darker: one path for each. */
function paintGrass(context, look, index, points) {
    const depth = shownDepth(look, index);
    const strokes = Math.round(look.width * depth / (index === NEAREST ? 45 : 90));

    [[true, `rgba(255, 250, 220, ${look.isDay ? 0.07 : 0.02})`], [false, `rgba(0, 10, 0, ${look.isDay ? 0.09 : 0.06})`]].forEach(([light, colour]) => {
        context.fillStyle = colour;
        context.beginPath();

        for (let stroke = 0; stroke < strokes; stroke++) {
            const seed = stroke + HILL_RANGES[index].seed * 5000;

            if ((noise(seed, 363) > 0.5) !== light) {
                continue;
            }

            const x = noise(seed, 361) * look.width;

            context.rect(x, lineAt(points, x) + noise(seed, 362) * depth, (2 + noise(seed, 364) * 8) * (index === NEAREST ? 1.4 : 0.8), index === NEAREST ? 1.2 : 0.8);
        }

        context.fill();
    });
}

/**
 * Woods on the hillsides: crown by crown, row by row down the slope, each with its shadow and, by
 * day, the side turned to the sun lit; leafy trees in the colours of the season, among firs that
 * stay green, and clearings between the woods; and `hedges`, the trees along the fields. Far away
 * the crowns are small enough to read as the texture of a wood. Only the trees the range in front
 * (`front`, its crest) leaves in sight are drawn, and in batches, see drawTrees(): one by one, the
 * crowns of a wide view took seconds.
 */
function paintWoods(context, look, index, points, palette, front, hedges) {
    const range = HILL_RANGES[index];
    const down = shownDepth(look, index);
    const crown = look.height * range.trees;
    const step = crown * 0.95;
    const own = look.isDay ? palette.ranges[index] : range.night;
    const kinds = palette.leaves.concat([CONIFER]);
    // Two shades of each kind of leaves, so that a wood is not of one green.
    const tones = treeTones(look, kinds, own, range.night, range.haze, range.far);
    // Far woods read as a texture with fewer crowns than near ones need to look whole.
    const rowGap = step * (crown > 3 ? 0.55 : 0.75);
    const gap = crown > 3 ? 0.8 : 1.05;
    const trees = [];
    const hidden = (x, foot, size) => front !== null && foot - size * 2.5 > lineAt(front, Math.max(0, Math.min(look.width, x)));

    for (let row = 0; row * rowGap < down; row++) {
        const below = row * rowGap;

        for (let x = -crown + (row % 2) * step * 0.5, tree = 0; x < look.width + crown; tree++) {
            const seed = tree * 61 + row * 7919 + range.seed * 104729;
            const along = x / look.width;
            const wood = 0.8 * patchNoise(along * (3 + range.seed), below / look.height * 9, 500 + range.seed) + 0.2 * patchNoise(along * 16, below / look.height * 30, 520 + range.seed);

            x += step * (gap + noise(seed, 401) * 0.6);

            // On farmed land the woods keep to the tops and the steep places.
            if (wood < (range.fields ? 0.58 : 0.47)) {
                continue;
            }

            const size = crown * (0.75 + noise(seed, 402) * 0.5);
            const left = x + (noise(seed, 403) - 0.5) * step * 0.4;
            const foot = lineAt(points, Math.max(0, Math.min(look.width, left))) + below + size * 0.6;

            if (hidden(left, foot, size)) {
                continue;
            }

            const fir = noise(seed, 404) < (look.season === 'winter' ? 0.5 : 0.3);
            const kind = fir ? kinds.length - 1 : Math.floor(noise(seed, 405) * palette.leaves.length);

            trees.push({ x: left, foot, size, fir, row, seed, tone: kind * 2 + (noise(seed, 406) > 0.5 ? 1 : 0) });
        }
    }

    // On a view as wide as the wallpaper, fewer and bigger crowns cover the same wood, so that it
    // still paints at once.
    const keep = Math.min(1, TREES_PER_RANGE / Math.max(1, trees.length));
    const kept = keep < 1 ? trees.filter((tree) => noise(tree.seed, 407) < keep) : trees;

    kept.forEach((tree) => {
        tree.size *= keep < 1 ? Math.min(1.8, 1 / Math.sqrt(keep)) : 1;
    });

    hedges.filter((tree) => !hidden(tree.x, tree.foot, tree.size)).forEach((tree, at) => {
        kept.push(Object.assign(tree, { row: -1, tone: (at % (kinds.length - 1)) * 2 + 1 }));
    });

    // Near trees go row by row, so that the nearer stand in front, the hedges (row -1) behind them
    // all; far ones all at once.
    if (crown > 3) {
        const rows = {};

        kept.forEach((tree) => (rows[tree.row] = rows[tree.row] || []).push(tree));
        Object.keys(rows).map(Number).sort((first, second) => first - second).forEach((row) => drawTrees(context, look, rows[row], tones));
    } else {
        drawTrees(context, look, kept, tones);
    }
}

/** A lone oak in the meadow in front, broad and dark, with its trunk. */
function paintOak(context, look, points, palette) {
    const x = look.width * 0.78;
    const size = look.height * 0.065;
    const foot = lineAt(points, x) + look.height * 0.13;
    const tones = treeTones(look, [palette.leaves[0], palette.leaves[palette.leaves.length - 1]], palette.ranges[NEAREST], HILL_RANGES[NEAREST].night, 0, 1);

    context.fillStyle = look.isDay ? '#3b3024' : '#06090f';
    context.fillRect(x - size * 0.09, foot - size * 1.3, size * 0.18, size * 1.3);
    drawTrees(context, look, [
        { x: x - size * 0.55, foot: foot - size * 0.9, size: size * 0.7, fir: false, tone: 1 },
        { x: x + size * 0.5, foot: foot - size * 0.95, size: size * 0.75, fir: false, tone: 3 },
        { x, foot: foot - size * 1.25, size: size * 0.85, fir: false, tone: 0 },
    ], tones);
}

/** By night, the lights of a few villages on the hillsides. */
function paintVillages(context, look, index, points) {
    for (let village = 0; village < 3; village++) {
        const seed = village + HILL_RANGES[index].seed * 10;
        const centre = (0.12 + 0.3 * village + noise(seed, 411) * 0.2) * look.width;
        const houses = 5 + Math.floor(noise(seed, 412) * 9);

        for (let house = 0; house < houses; house++) {
            const x = centre + (noise(seed * 31 + house, 413) - 0.5) * look.width * 0.06;
            const y = lineAt(points, Math.max(0, x)) + look.height * (0.015 + noise(seed * 31 + house, 414) * 0.07);

            context.fillStyle = `rgba(255, 206, 130, ${0.5 + 0.45 * noise(seed * 31 + house, 415)})`;
            context.fillRect(x, y, index === 1 ? 1.8 : 1.3, index === 1 ? 1.6 : 1.2);
        }
    }
}
