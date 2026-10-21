// What the kinds of land have in common: noise for their outlines, the colours of distance, light,
// season and snow, and trees, drawn in batches. See ../land.mjs for `look`.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';

/** By day, the colours of the three nearer ranges of green land in each season, the farthest first, and those of the leaves. */
export const SEASONS = {
    spring: { ranges: ['#5f8f4f', '#4f8642', '#3c7535'], leaves: ['#6aa84f', '#7cb85a', '#5e9a45', '#efd3dd'] },
    summer: { ranges: ['#557f4a', '#45723d', '#325c2f'], leaves: ['#3f6b35', '#4a7a3a', '#365e2f', '#55833f'] },
    autumn: { ranges: ['#7d8253', '#6e7643', '#57602f'], leaves: ['#b8692f', '#c79a3a', '#9c4a2e', '#7f8434', '#4f6a33'] },
    winter: { ranges: ['#747867', '#64695b', '#505648'], leaves: ['#6b6052', '#5d554a', '#77695a', '#4f4a42'] },
};
/** Fir and spruce, green the whole year. */
export const CONIFER = '#25402c';

export function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

export function rgba(hex, alpha) {
    return `rgba(${parseInt(hex.slice(1, 3), 16)}, ${parseInt(hex.slice(3, 5), 16)}, ${parseInt(hex.slice(5, 7), 16)}, ${clamp01(alpha)})`;
}

export function paletteOf(look) {
    return SEASONS[look.season] || SEASONS.summer;
}

/** Noise that changes smoothly along a line, 0 to 1. */
export function smoothNoise(x, salt) {
    const left = Math.floor(x);
    const share = x - left;
    const ease = share * share * (3 - 2 * share);

    return noise(left, salt) * (1 - ease) + noise(left + 1, salt) * ease;
}

/** Noise that changes smoothly across a plane, 0 to 1: for patches, such as woods and clearings. */
export function patchNoise(x, y, salt) {
    const left = Math.floor(x);
    const top = Math.floor(y);
    const easeX = (x - left) * (x - left) * (3 - 2 * (x - left));
    const easeY = (y - top) * (y - top) * (3 - 2 * (y - top));
    const at = (column, row) => noise(column * 57 + row * 131, salt);
    const upper = at(left, top) * (1 - easeX) + at(left + 1, top) * easeX;
    const lower = at(left, top + 1) * (1 - easeX) + at(left + 1, top + 1) * easeX;

    return upper * (1 - easeY) + lower * easeY;
}

/**
 * Fractal noise, 0 to 1: octave over octave of finer and fainter detail, as the outline of a range
 * of hills has. Ridged, the peaks come out sharp, as those of mountains.
 */
export function fractal(x, salt, octaves, ridged = false) {
    let sum = 0;
    let total = 0;

    for (let octave = 0, amplitude = 1, frequency = 1; octave < octaves; octave++, amplitude *= 0.5, frequency *= 2.03) {
        const value = smoothNoise(x * frequency, salt + octave * 17);

        sum += (ridged ? 1 - Math.abs(2 * value - 1) : value) * amplitude;
        total += amplitude;
    }

    return sum / total;
}

/** spring, summer, autumn or winter at a place on a date (YYYY-MM-DD); between the tropics the leaves stay green. */
export function seasonOf(date, latitude) {
    if (Math.abs(latitude) < 23.5) {
        return 'summer';
    }

    const north = ['winter', 'winter', 'spring', 'spring', 'spring', 'summer', 'summer', 'summer', 'autumn', 'autumn', 'autumn', 'winter'][Number(date.slice(5, 7)) - 1];

    return latitude >= 0 ? north : { winter: 'summer', spring: 'autumn', summer: 'winter', autumn: 'spring' }[north];
}

/**
 * The colour of a layer of land: its own colour, hazed by distance towards the horizon, warmed by a
 * low sun and, `snowy`, whitened by the snow that has settled; `depth` 0 for the farthest layer and
 * 1 for the nearest, which takes the whitest snow, so that the layers stay apart on a white day.
 */
export function landColour(colour, look, haze, depth, snowy = true) {
    const base = mixHex(colour, look.horizon, haze);
    const warm = mixHex(base, '#8a5a4a', look.warmth * 0.3);
    const white = look.isDay ? mixHex('#b9c5d6', '#f6f8fb', depth) : mixHex('#5e6983', '#a7b2c9', depth);

    return snowy ? mixHex(warm, white, look.snow * 0.9) : warm;
}

/** The light of the hour: of the sun, warmer as it is lower, or of the moon. */
export function lightColour(look) {
    return look.isDay ? mixHex('#fff2d8', '#ffc48a', look.warmth) : '#c3cff5';
}

/** A line across the layer, a point every `step` pixels: `[x, y]`, `y` given by `at(along)` as a share of the height. */
export function lineAcross(look, at, step = 3) {
    const points = [];

    for (let x = 0; x <= look.width + step; x += step) {
        points.push([x, at(x / look.width) * look.height]);
    }

    return points;
}

/** Where a line of points every `step` pixels is at `x`. */
export function lineAt(points, x, step = 3) {
    const at = Math.max(0, Math.min(points.length - 2, Math.floor(x / step)));
    const share = clamp01((x - points[at][0]) / step);

    return points[at][1] + (points[at + 1][1] - points[at][1]) * share;
}

/** The path of what lies below a line, down to the bottom of the layer. */
export function pathBelow(context, look, points) {
    context.beginPath();
    context.moveTo(0, look.height);
    points.forEach(([x, y]) => context.lineTo(x, y));
    context.lineTo(look.width, look.height);
    context.closePath();
}

/** Strokes a line of points. */
export function strokeLine(context, points) {
    context.beginPath();
    points.forEach(([x, y], at) => (at === 0 ? context.moveTo(x, y) : context.lineTo(x, y)));
    context.stroke();
}

/**
 * The facets of a ridge of mountains, a point every 3 pixels: the slopes turned to the light lighter,
 * the others in shade, only along the ridge and fading down from it, so that they do not run down in
 * stripes; and above `snowLine`, in pixels, when `capped`, their snow.
 */
export function paintFacets(context, look, points, { haze, snowLine, capped, colour, seed }) {
    const light = look.isDay ? '#fff4e0' : '#c3cff5';
    const fall = look.height * 0.025;

    for (let at = 1; at < points.length - 1; at++) {
        const [x, y] = points[at];
        // The slope over a stretch of the ridge, not from one point to the next: broad facets.
        const slope = points[Math.min(points.length - 1, at + 5)][1] - points[Math.max(0, at - 5)][1];
        const strength = clamp01(Math.abs(slope) / 14) * (look.isDay ? 0.18 : 0.09) * (1 - haze * 0.5);
        const lit = slope * (look.lightX - x) > 0;

        [1, 0.55, 0.25].forEach((share, step) => {
            context.fillStyle = lit ? rgba(light, strength * share) : `rgba(10, 20, 45, ${strength * share})`;
            context.fillRect(x - 1.5, y + fall * step, 3, fall);
        });
    }

    if (capped) {
        paintSnowCaps(context, look, points, snowLine, colour, haze, seed);
    }
}

/**
 * The snow on the peaks above `snowLine`: one shape for each stretch of the ridge above it, its
 * lower edge ragged as snow lies in gullies, a little shaded on the side away from the light.
 */
function paintSnowCaps(context, look, points, snowLine, colour, haze, seed) {
    const white = look.isDay ? mixHex('#f4f7fb', colour, haze * 0.5) : '#7d89a6';
    const reach = look.height * 0.05;
    const edge = (x) => snowLine + (smoothNoise(x / 14, seed) - 0.5) * reach + (smoothNoise(x / 4, seed + 1) - 0.5) * reach * 0.35;

    context.fillStyle = rgba(white, 0.85);
    context.beginPath();

    for (let at = 0; at < points.length; at++) {
        if (points[at][1] >= edge(points[at][0])) {
            continue;
        }

        const first = at;

        while (at + 1 < points.length && points[at + 1][1] < edge(points[at + 1][0])) {
            at++;
        }

        // Down the ridge, then back along the ragged edge of the snow.
        context.moveTo(points[first][0], points[first][1]);

        for (let along = first + 1; along <= at; along++) {
            context.lineTo(points[along][0], points[along][1]);
        }

        for (let along = at; along >= first; along--) {
            context.lineTo(points[along][0], Math.max(points[along][1], edge(points[along][0])));
        }

        context.closePath();
    }

    context.fill();
}

/**
 * Trees `{ x, foot, size, fir, tone }`, `size` the half-width of a crown and `tone` an index in
 * `tones`: their shadows, then their crowns tone by tone, then, by day, the side of the big ones
 * turned to the light, and the snow on top; one path for each, as a path takes thousands of shapes
 * in the time a single fill of each would take. `tall` stretches firs, and `poplar` makes them
 * poplars, narrow and rounded at the top.
 */
export function drawTrees(context, look, trees, tones) {
    if (trees.length === 0) {
        return;
    }

    const batch = (colour, chosen, part) => {
        if (chosen.length === 0) {
            return;
        }

        context.fillStyle = colour;
        context.beginPath();
        chosen.forEach((tree) => treePath(context, look, tree, part));
        context.fill();
    };

    batch(`rgba(0, 8, 0, ${look.isDay ? 0.3 : 0.2})`, trees, 'shadow');
    tones.forEach((tone, at) => batch(tone, trees.filter((tree) => tree.tone === at), 'crown'));

    if (look.isDay) {
        batch('rgba(255, 244, 214, 0.1)', trees.filter((tree) => tree.size > 2.5), 'light');
    }

    // Less snow on the small crowns of far woods, so that they do not melt into one white.
    if (look.snow > 0) {
        batch(`rgba(245, 248, 252, ${0.85 * look.snow})`, trees.filter((tree) => tree.size > 3), 'snow');
        batch(`rgba(245, 248, 252, ${0.45 * look.snow})`, trees.filter((tree) => tree.size <= 3), 'snow');
    }
}

/** Adds one tree to the path: a fir, or the round crown of a leafy tree; a dot when it is that small. */
function treePath(context, look, tree, part) {
    const lit = look.lightX > tree.x ? 1 : -1;
    const [offsetX, offsetY, scale] = {
        shadow: [-lit * tree.size * 0.3, tree.size * 0.25, 1],
        crown: [0, 0, 1],
        light: [lit * tree.size * 0.25, -tree.size * 0.3, 0.5],
        snow: [0, -tree.size * (tree.fir ? 0.9 : 0.45), 0.6],
    }[part];
    const size = tree.size * scale;
    const x = tree.x + offsetX;
    const foot = tree.foot + offsetY;
    const tall = tree.tall || 2.4;

    if (tree.poplar) {
        // A poplar: tall and narrow, rounded at the top.
        context.moveTo(x + size * 0.55, foot - size * tall * 0.5);
        context.ellipse(x - size * 0.55, foot - size * tall, size * 1.1, size * tall);
    } else if (size <= 1.6) {
        context.rect(x - size, foot - size * (tree.fir ? tall : 2), size * 2, size * (tree.fir ? tall : 2));
    } else if (tree.fir) {
        context.moveTo(x, foot - size * tall);
        context.lineTo(x - size * 0.62, foot);
        context.lineTo(x + size * 0.62, foot);
        context.closePath();
    } else {
        // A crown is a few rounded masses of leaves, not a ball; its light, a single one.
        const masses = tree.size > 3 && part === 'crown' ? [[0, -0.15, 0.8], [-0.45, 0.15, 0.62], [0.45, 0.12, 0.66]] : [[0, 0, 1]];

        masses.forEach(([across, up, share]) => {
            const centreX = x + size * across;
            const centreY = foot - tree.size + size * up;

            context.moveTo(centreX + size * share, centreY);
            context.arc(centreX, centreY, size * share, 0, Math.PI * 2);
        });
    }
}

/**
 * The tones of a kind of trees in a layer: two shades of each colour of `leaves`, by day blended
 * with the colour of the ground and hazed by distance; by night, nearly the colour of the night.
 */
export function treeTones(look, leaves, ground, night, haze, depth) {
    const tones = [];

    leaves.forEach((colour) => [0.12, 0.3].forEach((dark) => {
        tones.push(look.isDay ? landColour(mixHex(mixHex(colour, ground, 0.4), '#000000', dark), look, haze, depth, false) : mixHex(night, colour, 0.12 - dark * 0.2));
    }));

    return tones;
}
