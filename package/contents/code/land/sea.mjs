// The sea from its shore: the water mirrors the sky towards the horizon, with a far coast on
// either side, a swell that the wind raises into whitecaps, and in front a beach, with the foam of
// the last wave, which the swash moves up and down in QML.

import { noise } from '../scene.mjs';
import { mixHex } from '../sky.mjs';
import { clamp01, fractal, landColour, rgba } from './shared.mjs';

/** Where the horizon of the sea is, and where its beach begins, as shares of the height of the land. */
export const HORIZON = 0.3;
export const BEACH = 0.86;

/** Where the water meets the sand, at `along`, as a share of the height of the land from its top. */
export function shoreline(along) {
    return BEACH + 0.035 * (fractal(along * 3.2, 330, 4) - 0.5);
}

export function paintSea(context, look, part) {
    const { width, height } = look;
    const horizon = height * HORIZON;

    if (part === 'front') {
        paintBeach(context, look);

        return;
    }

    if (part !== 'back') {
        return;
    }

    // The water: near the horizon it mirrors the sky, nearer it shows its own colour, deeper.
    const open = look.isDay ? '#4d84ab' : '#16243a';
    const deep = look.isDay ? '#1b4a6c' : '#070d18';
    const water = context.createLinearGradient(0, horizon, 0, height);

    water.addColorStop(0, mixHex(open, look.horizon, 0.55));
    water.addColorStop(0.12, mixHex(open, look.horizon, 0.28));
    water.addColorStop(1, mixHex(deep, look.horizon, 0.08));
    context.fillStyle = water;
    context.fillRect(0, horizon, width, height - horizon);

    // A far coast on the left, and a fainter one on the right, blue with distance.
    [[0, 0.34, 0.075, 0.62], [0.82, 1, 0.025, 0.78]].forEach(([from, to, rise, haze], coast) => {
        context.fillStyle = mixHex(look.isDay ? '#5b7468' : '#151d31', look.horizon, haze);
        context.beginPath();
        context.moveTo(from * width, horizon);

        for (let x = from * width; x <= to * width + 3; x += 3) {
            const along = (x / width - from) / (to - from);
            // The headland falls to the sea in a cliff; the far coast is a low line of hills.
            const slope = coast === 0 ? Math.min(1, (1 - clamp01(along)) * 3.5) * (0.75 + 0.25 * Math.cos(along * 4)) : Math.sin(Math.PI * clamp01(along));

            context.lineTo(x, horizon - height * rise * slope * (0.55 + 0.6 * fractal(x / width * 9, 340 + coast, 5)));
        }

        context.lineTo(to * width, horizon);
        context.closePath();
        context.fill();
    });

    // The swell: crests caught by the light over troughs in shade, longer and farther apart closer to the eye.
    const windy = clamp01(look.wind / 40);
    const crestColour = look.isDay ? mixHex(look.horizon, '#ffffff', 0.55) : mixHex(look.horizon, '#c8d4ff', 0.4);

    for (let row = 0; row < 48; row++) {
        const near = (row + 0.5) / 48;
        const y = horizon + (height - horizon) * Math.pow(near, 1.8);
        const count = Math.round((14 + 26 * (1 - near)) * (0.6 + 0.6 * windy));

        for (let wave = 0; wave < count; wave++) {
            const seed = row * 131 + wave;
            const x = noise(seed, 301) * width;
            const length = (2 + 32 * Math.pow(near, 1.2)) * (0.5 + noise(seed, 302)) * (0.7 + 0.5 * windy);
            const thick = 0.5 + 1.5 * near;

            context.strokeStyle = rgba(crestColour, (look.isDay ? 0.07 : 0.05) + 0.13 * near);
            context.lineWidth = thick;
            context.beginPath();
            context.moveTo(x, y);
            context.quadraticCurveTo(x + length / 2, y - thick * 1.4, x + length, y);
            context.stroke();

            context.strokeStyle = `rgba(0, 18, 36, ${0.04 + 0.14 * near})`;
            context.beginPath();
            context.moveTo(x - length * 0.1, y + thick * 1.6);
            context.lineTo(x + length * 0.9, y + thick * 1.6);
            context.stroke();
        }
    }

    // In a strong wind the waves break into whitecaps.
    const whitecaps = Math.round(Math.max(0, (look.wind - 18) / 30) * 70);

    for (let cap = 0; cap < whitecaps; cap++) {
        const near = 0.2 + 0.8 * noise(cap, 311);
        const y = horizon + (height - horizon) * Math.pow(near, 1.8);
        const length = 2 + 9 * near;

        context.fillStyle = `rgba(255, 255, 255, ${look.isDay ? 0.6 : 0.3})`;
        context.fillRect(noise(cap, 312) * width, y - 1, length, 0.8 + near);
    }
}

/** The beach in front: wet sand at the edge of the water, dry sand nearer. */
function paintBeach(context, look) {
    const { width, height } = look;
    const sand = landColour(look.isDay ? '#d9c59c' : '#2c2e39', look, 0, 1);
    const points = [];

    for (let x = 0; x <= width + 4; x += 4) {
        points.push([x, shoreline(x / width) * height]);
    }

    const edge = Math.min(...points.map((point) => point[1]));
    const ground = context.createLinearGradient(0, edge, 0, height);

    ground.addColorStop(0, mixHex(sand, '#3a3020', 0.35));
    ground.addColorStop(0.3, mixHex(sand, '#3a3020', 0.12));
    ground.addColorStop(1, mixHex(sand, '#000000', 0.12));
    context.fillStyle = ground;
    context.beginPath();
    context.moveTo(0, height);
    points.forEach(([x, y]) => context.lineTo(x, y));
    context.lineTo(width, height);
    context.closePath();
    context.fill();

    // The grain of the sand.
    for (let grain = 0; grain < 260; grain++) {
        const x = noise(grain, 321) * width;
        const y = edge + noise(grain, 322) * (height - edge);

        context.fillStyle = noise(grain, 323) > 0.5 ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.08)';
        context.fillRect(x, y, 1.2, 1);
    }
}

/** The foam of the last wave on the sand, which the swash moves up and down. */
export function paintSurf(context, look) {
    const { width, height } = look;

    context.clearRect(0, 0, width, height);

    [[0, 2, 0.75], [-3, 5, 0.22], [-7, 1, 0.35]].forEach(([offset, thick, alpha]) => {
        context.strokeStyle = `rgba(255, 255, 255, ${alpha * (look.isDay ? 1 : 0.45)})`;
        context.lineWidth = thick;
        context.beginPath();

        for (let x = 0; x <= width + 4; x += 4) {
            const y = shoreline(x / width) * height + offset + Math.sin(x / 13 + offset) * 0.8;

            x === 0 ? context.moveTo(x, y) : context.lineTo(x, y);
        }

        context.stroke();
    });
}
