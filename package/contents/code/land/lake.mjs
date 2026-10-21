// A lake in the mountains: rocky peaks with snow on them, slopes dark with firs down to the shore,
// and the still water that mirrors them, broken into ripples as the wind rises; frozen in winter,
// under snow. Rocks and reeds at the near shore.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { CONIFER, clamp01, drawTrees, fractal, landColour, lineAcross, lineAt, paintFacets, paletteOf, pathBelow, rgba, treeTones } from './shared.mjs';

/** Where the far shore is, as a share of the height of the land: the water lies below it. */
export const SHORE = 0.54;
/** Where the near shore begins. */
export const NEAR_SHORE = 0.95;

/**
 * The ranges: two of bare rock and snow, the nearer the darker, and the wooded slope that comes
 * down to the water; as the ranges of hills.mjs, `snow` how far down the snow comes on each.
 */
const RANGES = [
    { top: 0.0, rise: 0.3, waves: 2.6, octaves: 6, haze: 0.5, day: '#8496ab', night: '#232c45', snow: 0.5 },
    { top: 0.14, rise: 0.24, waves: 3.4, octaves: 6, haze: 0.3, day: '#65727f', night: '#1a2136', snow: 0.3 },
    { top: 0.36, rise: 0.12, waves: 2.2, octaves: 4, haze: 0.12, day: '#34503e', night: '#101828' },
];

function ridge(index, along) {
    const range = RANGES[index];
    const value = fractal(along * range.waves + index * 5.7, 700 + index, range.octaves, index < 2);

    return range.top + range.rise * (1 - clamp01((value - 0.22) / 0.56));
}

/** The colour of a range, by day or night, hazed and snowed on. */
function rangeColour(look, index) {
    const range = RANGES[index];

    return landColour(look.isDay ? range.day : range.night, look, range.haze, index / 2);
}

export function paintLake(context, look, part) {
    if (part === 'back') {
        [0, 1].forEach((index) => paintPeaks(context, look, index));
    } else if (part === 'middle') {
        paintForest(context, look);
    } else {
        paintWater(context, look);
    }
}

function paintPeaks(context, look, index) {
    const range = RANGES[index];
    const points = lineAcross(look, (along) => ridge(index, along));
    const colour = rangeColour(look, index);
    const top = Math.min(...points.map((point) => point[1]));
    const body = context.createLinearGradient(0, top, 0, look.height * SHORE);

    pathBelow(context, look, points);
    body.addColorStop(0, colour);
    body.addColorStop(1, mixHex(colour, look.horizon, 0.45));
    context.fillStyle = body;
    context.fill();

    // The snow lies higher in summer than in winter, lower on the higher range, and all the way
    // down under fresh snow.
    const season = { summer: 0.3, autumn: 0.45, spring: 0.55, winter: 0.8 }[look.season] || 0.45;
    const snowLine = (range.top + range.rise * season * range.snow * 2) * look.height;

    paintFacets(context, look, points, { haze: range.haze, snowLine: look.snow > 0 ? look.height : snowLine, capped: true, colour, seed: 710 + index });
}

/** The slopes of firs down to the shore, the far shore itself a line of lighter stones. */
function paintForest(context, look) {
    const range = RANGES[2];
    const palette = paletteOf(look);
    const points = lineAcross(look, (along) => ridge(2, along));
    const shore = look.height * SHORE;
    const colour = rangeColour(look, 2);

    context.beginPath();
    context.moveTo(0, shore);
    points.forEach(([x, y]) => context.lineTo(x, Math.min(y, shore)));
    context.lineTo(look.width, shore);
    context.closePath();
    context.fillStyle = colour;
    context.fill();

    const tones = treeTones(look, [CONIFER, mixHex(CONIFER, '#1c2f24', 0.5), palette.leaves[0]], range.day, range.night, range.haze, 0.6);
    const crown = look.height * 0.011;
    const trees = [];

    for (let row = 0; row < 14; row++) {
        for (let x = -crown + (row % 2) * crown, tree = 0; x < look.width + crown; tree++) {
            const seed = tree * 31 + row * 977;
            const crest = lineAt(points, Math.max(0, Math.min(look.width, x)));
            const foot = crest + (shore - crest) * (row / 13) + crown;

            x += crown * (1.3 + noise(seed, 721) * 0.9);

            if (foot > shore + crown || noise(seed, 722) < 0.12) {
                continue;
            }

            trees.push({ x, foot, size: crown * (0.8 + noise(seed, 723) * 0.5), fir: noise(seed, 724) < 0.85, tall: 2.8, tone: noise(seed, 725) < 0.85 ? Math.floor(noise(seed, 726) * 4) : 4 + Math.floor(noise(seed, 727) * 2) });
        }
    }

    drawTrees(context, look, trees, tones);

    // The far shore: a line of pale stones where the water begins.
    context.fillStyle = landColour(look.isDay ? '#a59a86' : '#2a2f3c', look, range.haze, 0.6);
    context.fillRect(0, shore - 1.2, look.width, 1.6);
}

/**
 * The water: the sky near the far shore, deeper nearer; over it, upside down, the mountains and
 * the woods, a little darker; ripples that break the picture more as the wind rises. Frozen,
 * it shows no picture and takes the snow.
 */
function paintWater(context, look) {
    const shore = look.height * SHORE;
    const bottom = look.height * NEAR_SHORE;
    const frozen = look.season === 'winter' && look.snow > 0.3;
    const windy = clamp01(look.wind / 35);
    const deep = look.isDay ? '#21485f' : '#070d18';
    const water = context.createLinearGradient(0, shore, 0, look.height);

    water.addColorStop(0, mixHex(deep, look.horizon, 0.5));
    water.addColorStop(1, mixHex(deep, look.horizon, 0.1));
    context.fillStyle = frozen ? landColour('#b8c6d2', look, 0.1, 1) : water;
    context.fillRect(0, shore, look.width, look.height - shore);

    if (!frozen) {
        // The mirror: each range upside down from the shore, a little squeezed, darker and bluer.
        const strength = 0.55 * (1 - windy * 0.6);

        [0, 1, 2].forEach((index) => {
            const colour = mixHex(rangeColour(look, index), deep, 0.35);
            // Fainter away from the shore, as a reflection is.
            const fade = context.createLinearGradient(0, shore, 0, look.height);

            fade.addColorStop(0, rgba(colour, strength));
            fade.addColorStop(1, rgba(colour, strength * 0.35));
            context.fillStyle = fade;
            context.beginPath();
            context.moveTo(0, shore);

            for (let x = 0; x <= look.width + 3; x += 3) {
                const height = shore - Math.min(ridge(index, x / look.width) * look.height, shore);

                context.lineTo(x, shore + height * 0.9);
            }

            context.lineTo(look.width, shore);
            context.closePath();
            context.fill();
        });

        // The tips of the firs, mirrored as a dark fringe.
        context.fillStyle = rgba(mixHex(CONIFER, deep, 0.5), strength);
        context.beginPath();
        context.moveTo(0, shore);

        for (let x = 0, tip = 0; x < look.width; tip++) {
            const tall = look.height * (0.02 + noise(tip, 731) * 0.025);

            context.lineTo(x + 2, shore + tall);
            x += 3 + noise(tip, 732) * 3;
            context.lineTo(x, shore + tall * 0.3);
        }

        context.lineTo(look.width, shore);
        context.closePath();
        context.fill();

        // Ripples, lighter, the more and longer as the wind rises; near the eye, wider apart.
        const ripple = look.isDay ? mixHex(look.horizon, '#ffffff', 0.45) : mixHex(look.horizon, '#c8d4ff', 0.3);

        context.strokeStyle = rgba(ripple, 0.18 + windy * 0.2);
        context.lineWidth = 0.8;
        context.beginPath();

        for (let line = 0; line < 30 + windy * 60; line++) {
            const share = Math.pow(noise(line, 741), 1.6);
            const y = shore + 2 + (bottom - shore) * share;
            const x = noise(line, 742) * look.width;
            const long = (8 + share * 60) * (0.4 + windy) * (0.5 + noise(line, 743));

            context.moveTo(x, y);
            context.lineTo(x + long, y);
        }

        context.stroke();
    } else {
        // Cracks in the ice.
        context.strokeStyle = 'rgba(90, 110, 130, 0.25)';
        context.lineWidth = 0.7;
        context.beginPath();

        for (let crack = 0; crack < 12; crack++) {
            const x = noise(crack, 751) * look.width;
            const y = shore + (bottom - shore) * noise(crack, 752);

            context.moveTo(x, y);
            context.lineTo(x + 20 + noise(crack, 753) * 40, y + (noise(crack, 754) - 0.5) * 6);
        }

        context.stroke();
    }

    paintNearShore(context, look, bottom);
}

/** The near shore: stones, and reeds at the corners. */
function paintNearShore(context, look, bottom) {
    const line = lineAcross(look, (along) => NEAR_SHORE + 0.03 * (fractal(along * 4, 760, 3) - 0.5), 4);
    const stone = landColour(look.isDay ? '#6f675c' : '#151821', look, 0, 1);

    pathBelow(context, look, line);
    context.fillStyle = stone;
    context.fill();

    context.fillStyle = look.isDay ? 'rgba(255, 250, 235, 0.25)' : 'rgba(150, 165, 200, 0.12)';
    context.beginPath();

    for (let pebble = 0; pebble < look.width / 6; pebble++) {
        const x = noise(pebble, 761) * look.width;
        const y = lineAt(line, x, 4) + 1 + noise(pebble, 762) * (look.height - bottom);
        const size = 1 + noise(pebble, 763) * 2.5;

        context.moveTo(x + size, y);
        context.ellipse(x - size, y - size * 0.5, size * 2, size);
    }

    context.fill();

    // Reeds, at both ends of the shore.
    context.strokeStyle = landColour(look.isDay ? '#5d6a35' : '#0b1018', look, 0, 1, false);
    context.lineWidth = 1;
    context.beginPath();

    for (let reed = 0; reed < 70; reed++) {
        const left = noise(reed, 771) < 0.5;
        const x = (left ? noise(reed, 772) * 0.16 : 0.84 + noise(reed, 772) * 0.16) * look.width;
        const foot = lineAt(line, x, 4) + 2;
        const tall = look.height * (0.06 + noise(reed, 773) * 0.08);
        const bend = (clamp01(look.wind / 40) * 0.4 + (noise(reed, 774) - 0.5) * 0.2) * tall;

        context.moveTo(x, foot);
        context.quadraticCurveTo(x + bend * 0.3, foot - tall * 0.6, x + bend, foot - tall);
    }

    context.stroke();
}
