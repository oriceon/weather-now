const DAY_MS = 24 * 60 * 60 * 1000;
const SYNODIC_MONTH_DAYS = 29.530588853;
/** A new moon to count the cycles from: 6 January 2000, 18:14 UTC. */
const REFERENCE_NEW_MOON = Date.UTC(2000, 0, 6, 18, 14);

/** Translation keys of the eight phases, in the order the moon goes through them. */
export const PHASE_KEYS = [
    'moon.new',
    'moon.waxingCrescent',
    'moon.firstQuarter',
    'moon.waxingGibbous',
    'moon.full',
    'moon.waningGibbous',
    'moon.lastQuarter',
    'moon.waningCrescent',
];

/**
 * The phase of the moon at noon UTC of a date, from the mean length of the lunar month.
 * Good to about half a day, which is enough to name the phase and to draw it.
 */
export function moonPhase(isoDate) {
    const text = String(isoDate);
    const noon = Date.UTC(Number(text.slice(0, 4)), Number(text.slice(5, 7)) - 1, Number(text.slice(8, 10)), 12);
    const cycles = (noon - REFERENCE_NEW_MOON) / DAY_MS / SYNODIC_MONTH_DAYS;
    const fraction = cycles - Math.floor(cycles);

    return {
        /** 0 at new moon, 0.5 at full moon. */
        fraction,
        key: PHASE_KEYS[Math.round(fraction * PHASE_KEYS.length) % PHASE_KEYS.length],
        /** Share of the disc that is lit, 0..1. */
        illumination: (1 - Math.cos(2 * Math.PI * fraction)) / 2,
    };
}
