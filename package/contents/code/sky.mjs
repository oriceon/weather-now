/** Sky colours per weather family: [day top, day bottom, night top, night bottom]. */
const GRADIENTS = {
    clear: ['#2f7fe0', '#7cc0ff', '#0a1030', '#22315c'],
    cloudy: ['#55718f', '#9db2c7', '#161d2e', '#2e394d'],
    fog: ['#74808d', '#b4bdc7', '#1d222b', '#3a424e'],
    rain: ['#3b4b5f', '#66788c', '#10151f', '#252f3e'],
    snow: ['#7187a0', '#c3d0de', '#1a2233', '#3d4a5f'],
    storm: ['#23283a', '#454d63', '#0b0d16', '#1f2433'],
};

/** The colours the sky turns to around sunrise and sunset. */
const TWILIGHT = { top: '#4a4a8a', bottom: '#f6a25e' };

/** How much of the twilight colours gets through each kind of sky. */
const CLEARNESS = { clear: 1, cloudy: 0.55, fog: 0.3, rain: 0.25, snow: 0.3, storm: 0.1 };

/** The upper sky reddens less than the horizon. */
const TOP_SHARE = 0.6;

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

/** `twilight` is 1 at sunrise or sunset and 0 far from them, see twilight() in scene.mjs. */
export function skyGradient(family, isDay, twilight = 0) {
    const known = GRADIENTS[family] ? family : 'cloudy';
    const [dayTop, dayBottom, nightTop, nightBottom] = GRADIENTS[known];
    const top = isDay ? dayTop : nightTop;
    const bottom = isDay ? dayBottom : nightBottom;
    const warmth = twilight * CLEARNESS[known];

    return { top: mixHex(top, TWILIGHT.top, warmth * TOP_SHARE), bottom: mixHex(bottom, TWILIGHT.bottom, warmth) };
}
