// A plain of poppies: the field runs flat to a line of trees and poplars on the horizon, red with
// poppies in drifts that are only a blush of colour far away and whole flowers close by, among
// grass, a few cornflowers and camomiles; the nearest blades lean with the wind. Snow hides them.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { CONIFER, clamp01, drawTrees, fractal, landColour, lineAcross, paletteOf, patchNoise, pathBelow, rgba, treeTones } from './shared.mjs';

/** Where the far edge of the field is, as a share of the height of the land. */
export const FIELD_EDGE = 0.32;
/** From here down the poppies are drawn as flowers, in front. */
const NEAR = 0.62;
/** The grass of the plain in each season, far and near. */
const GRASS = {
    spring: ['#93b061', '#5f8a3a'],
    summer: ['#a8aa5c', '#6d7d34'],
    autumn: ['#a49c5e', '#6f6a36'],
    winter: ['#8a8670', '#5e5c48'],
};

/** How far down the plain a share of its depth is, the nearer the more spread out: perspective. */
function rowAt(share) {
    return FIELD_EDGE + (1 - FIELD_EDGE) * Math.pow(share, 1.7);
}

/** How thick the poppies are at a place: in drifts, 0 to 1. */
function drift(along, share) {
    return clamp01((patchNoise(along * 5, share * 4, 610) - 0.38) / 0.4);
}

export function paintPoppies(context, look, part) {
    if (part === 'back') {
        paintHorizon(context, look);
    } else if (part === 'middle') {
        paintPlain(context, look);
    } else {
        paintNear(context, look);
    }
}

/**
 * The far edge of the plain: low hills blue with distance, and in front of them a line of trees,
 * crown after crown, with poplars standing out of it here and there, in the colours of the season.
 */
function paintHorizon(context, look) {
    const palette = paletteOf(look);
    const edge = look.height * FIELD_EDGE;
    const hills = lineAcross(look, (along) => FIELD_EDGE - 0.025 - 0.04 * fractal(along * 1.6, 620, 2));

    pathBelow(context, look, hills);
    context.fillStyle = landColour(look.isDay ? '#7f98a3' : '#1a2238', look, 0.55, 0.2);
    context.fill();

    const haze = 0.32;
    const tones = treeTones(look, palette.leaves.concat([CONIFER]), palette.ranges[1], '#141c30', haze, 0.35);
    const trees = [];
    const crown = look.height * 0.02;

    // The tree line, broken here and there by a field reaching to the hills.
    for (let x = 0, tree = 0; x < look.width; tree++) {
        x += crown * (0.9 + noise(tree, 626) * 0.7);

        if (fractal(x / look.width * 7, 627, 3) < 0.42) {
            continue;
        }

        trees.push({ x, foot: edge + crown * 0.4, size: crown * (0.8 + noise(tree, 628) * 0.6), fir: false, tone: Math.floor(noise(tree, 629) * tones.length) });

        if (noise(tree, 621) < 0.12) {
            trees.push({ x, foot: edge, size: crown * (0.55 + noise(tree, 622) * 0.25), fir: true, poplar: true, tall: 4.5 + noise(tree, 623) * 2.5, tone: Math.floor(noise(tree, 624) * 2) * 2 });
        }
    }

    drawTrees(context, look, trees, tones);
}

/** The plain, from its far edge down: grass that comes nearer and greener, poppies as a blush, then as dots. */
function paintPlain(context, look) {
    const grass = GRASS[look.season] || GRASS.summer;
    const edge = look.height * FIELD_EDGE;
    const ground = context.createLinearGradient(0, edge, 0, look.height);

    ground.addColorStop(0, landColour(look.isDay ? grass[0] : '#1a2232', look, 0.4, 0.4));
    ground.addColorStop(0.35, landColour(look.isDay ? mixHex(grass[0], grass[1], 0.5) : '#141b29', look, 0.12, 0.7));
    ground.addColorStop(1, landColour(look.isDay ? grass[1] : '#0c111c', look, 0, 1));
    context.fillStyle = ground;
    context.fillRect(0, edge, look.width, look.height - edge);

    const hidden = 1 - look.snow;

    if (hidden <= 0.05) {
        return;
    }

    const red = look.isDay ? '#d6342a' : '#4a1a20';

    // Far off, the drifts of poppies are only specks of colour, thick where the drifts are.
    context.fillStyle = rgba(red, (look.isDay ? 0.55 : 0.3) * hidden);
    context.beginPath();

    for (let speck = 0; speck < look.width * 3; speck++) {
        const share = Math.pow(noise(speck, 631), 1.5) * 0.4;
        const along = noise(speck, 632);

        if (noise(speck, 633) > drift(along, share) * 0.9) {
            continue;
        }

        context.rect(along * look.width, rowAt(share) * look.height, 0.8 + share * 2, 0.5 + share);
    }

    context.fill();

    // The wind combs the grass into lighter and darker bands across the plain.
    for (let band = 0; band < 7; band++) {
        const share = 0.08 + band * 0.12 + noise(band, 634) * 0.05;
        const y = rowAt(share) * look.height;

        context.fillStyle = band % 2 === 0 ? `rgba(255, 250, 220, ${look.isDay ? 0.05 : 0.015})` : 'rgba(0, 10, 0, 0.05)';
        context.fillRect(0, y, look.width, look.height * (0.01 + share * 0.05));
    }

    // Nearer, the poppies one by one, still dots, and a few blades of grass catching the light.
    const dots = Math.round(look.width * 2.4);
    const paths = [[rgba(red, 0.9 * hidden), []], [rgba(mixHex(red, '#ff7a5c', 0.4), 0.8 * hidden), []], [`rgba(255, 252, 230, ${(look.isDay ? 0.06 : 0.02) * hidden})`, []]];

    for (let dot = 0; dot < dots; dot++) {
        const share = noise(dot, 641) * 0.75;
        const along = noise(dot, 642);
        const y = rowAt(share) * look.height;
        const size = 0.5 + share * 2.2;

        if (noise(dot, 643) > 0.25 + drift(along, share) * 0.75) {
            paths[2][1].push([along * look.width, y, size * 3, 0.6]);
            continue;
        }

        paths[noise(dot, 644) > 0.7 ? 1 : 0][1].push([along * look.width, y - size, size * 1.2, size]);
    }

    paths.forEach(([colour, rects]) => {
        context.fillStyle = colour;
        context.beginPath();
        rects.forEach(([x, y, wide, tall]) => context.rect(x, y, wide, tall));
        context.fill();
    });
}

/**
 * The flowers in front: poppies with their dark hearts, on stems, lit on the side of the sun, a few
 * cornflowers and camomiles, and blades of grass that lean with the wind.
 */
function paintNear(context, look) {
    const grass = GRASS[look.season] || GRASS.summer;
    const hidden = 1 - look.snow;
    const lean = clamp01(look.wind / 40) * 0.5 * (noise(1, 650) > 0.5 ? 1 : -1);
    const top = look.height * NEAR;
    const blade = landColour(look.isDay ? mixHex(grass[1], '#2f4a1e', 0.4) : '#080d16', look, 0, 1);
    const lightBlade = look.isDay ? mixHex(grass[0], '#e8e2a0', 0.25) : '#141c2a';

    // Blades of grass, dark and light.
    [[blade, 1.1], [lightBlade, 0.8]].forEach(([colour, thick], kind) => {
        context.strokeStyle = colour;
        context.lineWidth = thick;
        context.beginPath();

        for (let stroke = 0; stroke < look.width * 0.9; stroke++) {
            const seed = stroke * 2 + kind;
            const share = noise(seed, 651);
            const x = noise(seed, 652) * look.width;
            const y = top + (look.height - top) * Math.pow(share, 0.8) + 4;
            const tall = (4 + share * 16) * (0.6 + noise(seed, 653) * 0.8);
            const bend = (lean + (noise(seed, 654) - 0.5) * 0.4) * tall;

            context.moveTo(x, y);
            context.quadraticCurveTo(x + bend * 0.3, y - tall * 0.6, x + bend, y - tall);
        }

        context.stroke();
    });

    if (hidden <= 0.05) {
        return;
    }

    const flowers = [];

    for (let flower = 0; flower < Math.round(look.width * 0.45); flower++) {
        const share = noise(flower, 661);
        const along = noise(flower, 662);

        if (noise(flower, 663) > 0.2 + drift(along, 0.75 + share * 0.25) * 0.8) {
            continue;
        }

        const size = 1.6 + Math.pow(share, 1.4) * look.height * 0.03;
        const kind = noise(flower, 664);

        flowers.push({ x: along * look.width, y: top + (look.height - top) * Math.pow(share, 0.9) - size, size, kind: kind > 0.94 ? 'cornflower' : kind > 0.88 ? 'camomile' : 'poppy' });
    }

    // Nearer flowers over farther ones.
    flowers.sort((first, second) => first.y - second.y);

    // Their stems, all in one path.
    context.strokeStyle = rgba(blade, hidden);
    context.lineWidth = 0.8;
    context.beginPath();
    flowers.filter((flower) => flower.size > 3).forEach((flower) => {
        context.moveTo(flower.x, flower.y + flower.size * 0.6);
        context.quadraticCurveTo(flower.x - lean * flower.size, flower.y + flower.size * 2, flower.x - lean * flower.size * 2, flower.y + flower.size * 4);
    });
    context.stroke();

    const colours = {
        poppy: look.isDay ? ['#c8241c', '#ec4a35', '#1b0d0d'] : ['#3d141a', '#55202a', '#0a0608'],
        cornflower: look.isDay ? ['#3d5fd0', '#6d8cf0', '#1d2450'] : ['#1c2440', '#283258', '#0a0c18'],
        camomile: look.isDay ? ['#ecebe2', '#ffffff', '#e0b62c'] : ['#3a3f4c', '#4a5060', '#3a3420'],
    };

    // Petals in shade, petals in the light, then the hearts: one path each, flower kind by flower kind.
    Object.keys(colours).forEach((kind) => {
        const own = flowers.filter((flower) => flower.kind === kind);

        colours[kind].forEach((colour, layer) => {
            context.fillStyle = rgba(colour, hidden);
            context.beginPath();

            own.forEach(({ x, y, size }) => {
                const lit = look.lightX > x ? 1 : -1;

                if (layer === 0) {
                    context.moveTo(x + size, y);
                    context.arc(x, y, size, 0, Math.PI * 2);
                } else if (layer === 1) {
                    context.moveTo(x + lit * size * 0.25 + size * 0.6, y - size * 0.2);
                    context.arc(x + lit * size * 0.25, y - size * 0.2, size * 0.6, 0, Math.PI * 2);
                } else if (size > 2.2) {
                    context.moveTo(x + size * 0.28, y);
                    context.arc(x, y, size * 0.28, 0, Math.PI * 2);
                }
            });

            context.fill();
        });
    });
}
