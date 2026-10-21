/**
 * Sky colours per weather family, from the top of the sky down to the horizon:
 * [day top, day middle, day bottom, night top, night middle, night bottom].
 */
const GRADIENTS = {
    clear: ['#1b63d0', '#4e93e6', '#a9d4ff', '#070b22', '#0f1a3d', '#24335e'],
    cloudy: ['#5f6f82', '#8494a6', '#aab6c3', '#141a26', '#1f2735', '#2e394d'],
    fog: ['#7d8793', '#a3acb6', '#c4cbd2', '#1d222b', '#2a3039', '#3a424e'],
    rain: ['#3e4c5e', '#56667a', '#728296', '#10151f', '#19202c', '#252f3e'],
    snow: ['#7488a0', '#9aabbf', '#cdd8e4', '#1a2233', '#27314a', '#3d4a5f'],
    storm: ['#1f2433', '#2f3649', '#4a5268', '#0b0d16', '#141824', '#1f2433'],
};

/** A clear sky with the sun low: paler above, warm towards the horizon, as in the hour before sunset. */
const LOW_SUN = ['#3a6fc4', '#7fa9e0', '#ffd3a0'];

/** The colours the sky turns to around sunrise and sunset. */
const TWILIGHT = { top: '#4a4a8a', middle: '#b06a8a', bottom: '#f6a25e' };

/** How much of the twilight colours gets through each kind of sky. */
const CLEARNESS = { clear: 1, cloudy: 0.55, fog: 0.3, rain: 0.25, snow: 0.3, storm: 0.1 };

/** The upper sky reddens less than the horizon. */
const TOP_SHARE = 0.6;
const MIDDLE_SHARE = 0.8;

/**
 * Clouds that only break up a blue sky, mainly clear and partly cloudy, keep it blue: they are
 * painted on it, and it turns only this much towards the grey of an overcast one.
 */
const GREYING = { 1: 0.06, 2: 0.18 };

function channel(hex, index) {
    return parseInt(hex.slice(1 + index * 2, 3 + index * 2), 16);
}

export function mixHex(from, to, amount) {
    const share = Math.max(0, Math.min(1, amount));
    let result = '#';

    for (let index = 0; index < 3; index++) {
        const value = Math.round(channel(from, index) + (channel(to, index) - channel(from, index)) * share);

        result += (value < 16 ? '0' : '') + value.toString(16);
    }

    return result;
}

/** The colour with each channel rounded to a multiple of `step`: two that differ by less look the same. */
export function roundedHex(hex, step) {
    let result = '#';

    for (let index = 0; index < 3; index++) {
        const value = Math.min(255, Math.round(channel(hex, index) / step) * step);

        result += (value < 16 ? '0' : '') + value.toString(16);
    }

    return result;
}

function smooth(edge0, edge1, value) {
    const share = Math.max(0, Math.min(1, (value - edge0) / (edge1 - edge0)));

    return share * share * (3 - 2 * share);
}

/**
 * The sky, `{ top, middle, bottom }`. `twilight` is 1 at sunrise or sunset and 0 far from them, see
 * twilight() in scene.mjs. `weatherCode` is the condition code shown; `sunHeight`, by day, how high
 * the sun is, 0 on the horizon and 1 at its highest: a clear sky deepens to a full blue as it climbs.
 */
export function skyGradient(family, isDay, twilight = 0, { weatherCode = null, sunHeight = 1 } = {}) {
    const greying = GREYING[weatherCode] || 0;
    const known = greying > 0 ? 'clear' : GRADIENTS[family] ? family : 'cloudy';
    const colours = GRADIENTS[known];
    let [top, middle, bottom] = isDay ? colours.slice(0, 3) : colours.slice(3, 6);

    if (isDay && known === 'clear') {
        const high = smooth(0.12, 0.6, sunHeight);

        [top, middle, bottom] = [0, 1, 2].map((index) => mixHex(LOW_SUN[index], [top, middle, bottom][index], high));
    }

    if (greying > 0) {
        const grey = isDay ? GRADIENTS.cloudy.slice(0, 3) : GRADIENTS.cloudy.slice(3, 6);

        [top, middle, bottom] = [top, middle, bottom].map((colour, index) => mixHex(colour, grey[index], greying));
    }

    const warmth = twilight * CLEARNESS[known];

    return {
        top: mixHex(top, TWILIGHT.top, warmth * TOP_SHARE),
        middle: mixHex(middle, TWILIGHT.middle, warmth * MIDDLE_SHARE),
        bottom: mixHex(bottom, TWILIGHT.bottom, warmth),
    };
}
