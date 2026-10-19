/**
 * The Meteocons icons (https://meteocons.com, MIT licence) bundled in contents/icons:
 * static/<name>.svg is the still picture, animated/<name>.png the animation.
 */

/**
 * An animation is a film strip: its frames side by side, row after row, in one picture.
 * tools/build-icons.mjs draws the strips with this geometry.
 */
export const SHEET = {
    columns: 9,
    rows: 8,
    frames: 72,
    /** Width and height of a frame, in pixels. */
    frameSize: 128,
    /** How long the loop lasts. */
    seconds: 6,
};

/**
 * The icons of the measurements on the details tab; they have no animation. Only icons that
 * read well on a dark theme are used: "uv-index" and "sunrise" are dark drawings.
 */
export const DETAIL_ICONS = ['wind', 'windsock', 'humidity', 'barometer', 'cloudy', 'clear-day'];

/** "moon.waxingCrescent", a phase key of code/moon.mjs, as the icon "moon-waxing-crescent". */
export function moonIcon(phaseKey) {
    return phaseKey.replace('.', '-').replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}
