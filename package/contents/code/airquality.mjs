// Air quality and pollen, from the CAMS European air quality forecasts that Open-Meteo passes on.

const ENDPOINT = 'https://air-quality-api.open-meteo.com/v1/air-quality';
const POLLEN = ['alder', 'birch', 'grass', 'mugwort', 'olive', 'ragweed'];
/**
 * Grains per m³ from which a pollen is moderate and high. Trees release far more grains than
 * grasses and weeds before people feel them, so their thresholds are higher.
 */
const POLLEN_LEVELS = { alder: [10, 100], birch: [10, 100], olive: [10, 100], grass: [10, 50], mugwort: [10, 50], ragweed: [10, 50] };
const LEVEL_ORDER = ['low', 'moderate', 'high'];
/** Less than a grain per m³ is no pollen worth telling of. */
const LEAST_GRAINS = 1;

/**
 * The European Air Quality Index, as the European Environment Agency bands and colours it, for
 * the dial of the Details tab: each band to its upper bound.
 */
export const AQI_SCALE = {
    minimum: 0,
    maximum: 120,
    segments: [[20, '#50f0e6'], [40, '#50ccaa'], [60, '#f0e641'], [80, '#ff5050'], [100, '#960032'], [120, '#7d2181']],
};
const AQI_KEYS = ['good', 'fair', 'moderate', 'poor', 'veryPoor', 'extremelyPoor'];

/** The days of pollen forecast CAMS gives. */
const POLLEN_DAYS = 4;

/**
 * The air of the place now, and the pollen of the next days. The place is rounded to about a kilometre,
 * finer than CAMS can tell; the forecast is not, its temperatures go by the height of the very place.
 */
export function airQualityUrl(latitude, longitude) {
    const round = (value) => (Math.round(value * 100) / 100).toFixed(2);
    const pollen = POLLEN.map((name) => `${name}_pollen`).join(',');

    return `${ENDPOINT}?latitude=${round(latitude)}&longitude=${round(longitude)}&current=european_aqi,pm10,pm2_5,${pollen}&hourly=${pollen}&forecast_days=${POLLEN_DAYS}&timezone=auto`;
}

/** Translation key of the band of an index: good, fair, moderate, poor, veryPoor or extremelyPoor. */
export function aqiKey(index) {
    const band = AQI_SCALE.segments.findIndex(([upper]) => index <= upper);

    return AQI_KEYS[band === -1 ? AQI_KEYS.length - 1 : band];
}

/** low, moderate or high, for the grains per m³ of a pollen. */
export function pollenLevel(name, grains) {
    const [moderate, high] = POLLEN_LEVELS[name];

    if (grains >= high) {
        return 'high';
    }

    return grains >= moderate ? 'moderate' : 'low';
}

/** The pollens of `grains`, a reading by name, worth telling of, the most felt first: by level, then by how near to high. */
function feltPollens(grains) {
    return POLLEN
        .map((name) => ({ name, grains: grains[name] }))
        .filter((pollen) => typeof pollen.grains === 'number' && pollen.grains >= LEAST_GRAINS)
        .map((pollen) => Object.assign(pollen, { level: pollenLevel(pollen.name, pollen.grains) }))
        .sort((first, second) => LEVEL_ORDER.indexOf(second.level) - LEVEL_ORDER.indexOf(first.level)
            || second.grains / POLLEN_LEVELS[second.name][1] - first.grains / POLLEN_LEVELS[first.name][1]);
}

/** Each day of the hourly pollen, `{ date, pollens }`, its pollens at their highest of the day, the most felt first. */
function pollenDays(hourly) {
    const days = [];

    ((hourly && hourly.time) || []).forEach((time, index) => {
        const date = String(time).slice(0, 10);
        let day = days.find((candidate) => candidate.date === date);

        if (!day) {
            day = { date, highest: {} };
            days.push(day);
        }

        POLLEN.forEach((name) => {
            const grains = (hourly[`${name}_pollen`] || [])[index];

            if (typeof grains === 'number' && !(grains <= day.highest[name])) {
                day.highest[name] = grains;
            }
        });
    });

    return days.map((day) => ({ date: day.date, pollens: feltPollens(day.highest) }));
}

/**
 * `{ aqi, pm25, pm10, pollen, pollens, pollenDays }` from an answer of the air quality API:
 * `pollens`, the pollens in the air now as `{ name, grains, level }`, the most felt first, and
 * `pollen` the first of them, or null where there is none to tell of, outside Europe or out of
 * season; `pollenDays`, the next days as `{ date, pollens }`. Throws on an answer without the index.
 */
export function parseAirQuality(response) {
    const current = (response && response.current) || {};

    if (typeof current.european_aqi !== 'number') {
        throw new Error('Incomplete air quality response');
    }

    const now = {};

    POLLEN.forEach((name) => {
        now[name] = current[`${name}_pollen`];
    });

    const pollens = feltPollens(now);

    return {
        aqi: current.european_aqi,
        pm25: typeof current.pm2_5 === 'number' ? current.pm2_5 : null,
        pm10: typeof current.pm10 === 'number' ? current.pm10 : null,
        pollen: pollens[0] || null,
        pollens,
        pollenDays: pollenDays(response.hourly),
    };
}

/** The colour of a level of pollen: green, yellow, red. */
export const POLLEN_COLOURS = { low: '#45d08f', moderate: '#f2cf3d', high: '#ea4848' };
