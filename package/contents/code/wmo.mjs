/**
 * WMO weather interpretation codes, as Open-Meteo reports them.
 * Each row: [translation key, background family, day icon, night icon, kind of precipitation, its intensity 0..1,
 * day Meteocon, night Meteocon]. The icons are named as in the Breeze icon theme; the Meteocons are the files
 * bundled in contents/icons. A night icon of null means the day one serves both.
 */
const TABLE = {
    0: ['clear', 'clear', 'weather-clear', 'weather-clear-night', null, 0, 'clear-day', 'clear-night'],
    1: ['mainlyClear', 'clear', 'weather-few-clouds', 'weather-few-clouds-night', null, 0, 'partly-cloudy-day', 'partly-cloudy-night'],
    2: ['partlyCloudy', 'cloudy', 'weather-clouds', 'weather-clouds-night', null, 0, 'overcast-day', 'overcast-night'],
    3: ['overcast', 'cloudy', 'weather-many-clouds', null, null, 0, 'overcast', null],
    45: ['fog', 'fog', 'weather-fog', null, null, 0, 'fog', null],
    48: ['rimeFog', 'fog', 'weather-fog', null, null, 0, 'fog', null],
    51: ['drizzleLight', 'rain', 'weather-showers-scattered', null, 'rain', 0.15, 'drizzle', null],
    53: ['drizzle', 'rain', 'weather-showers-scattered', null, 'rain', 0.25, 'drizzle', null],
    55: ['drizzleDense', 'rain', 'weather-showers-scattered', null, 'rain', 0.4, 'drizzle', null],
    56: ['freezingDrizzle', 'rain', 'weather-freezing-rain', null, 'rain', 0.2, 'sleet', null],
    57: ['freezingDrizzle', 'rain', 'weather-freezing-rain', null, 'rain', 0.4, 'sleet', null],
    61: ['rainLight', 'rain', 'weather-showers-scattered', null, 'rain', 0.35, 'rain', null],
    63: ['rain', 'rain', 'weather-showers', null, 'rain', 0.6, 'rain', null],
    65: ['rainHeavy', 'rain', 'weather-showers', null, 'rain', 1, 'extreme-rain', null],
    66: ['freezingRain', 'rain', 'weather-freezing-rain', null, 'rain', 0.35, 'sleet', null],
    67: ['freezingRain', 'rain', 'weather-freezing-rain', null, 'rain', 0.8, 'sleet', null],
    71: ['snowLight', 'snow', 'weather-snow-scattered', null, 'snow', 0.3, 'snow', null],
    73: ['snow', 'snow', 'weather-snow', null, 'snow', 0.6, 'snow', null],
    75: ['snowHeavy', 'snow', 'weather-snow', null, 'snow', 1, 'extreme-snow', null],
    77: ['snowGrains', 'snow', 'weather-snow', null, 'snow', 0.4, 'snow', null],
    80: ['showersLight', 'rain', 'weather-showers-scattered-day', 'weather-showers-scattered-night', 'rain', 0.4, 'partly-cloudy-day-drizzle', 'partly-cloudy-night-drizzle'],
    81: ['showers', 'rain', 'weather-showers-day', 'weather-showers-night', 'rain', 0.7, 'partly-cloudy-day-rain', 'partly-cloudy-night-rain'],
    82: ['showersHeavy', 'rain', 'weather-showers-day', 'weather-showers-night', 'rain', 1, 'extreme-day-rain', 'extreme-night-rain'],
    85: ['snowShowersLight', 'snow', 'weather-snow-scattered-day', 'weather-snow-scattered-night', 'snow', 0.4, 'partly-cloudy-day-snow', 'partly-cloudy-night-snow'],
    86: ['snowShowers', 'snow', 'weather-snow-scattered-day', 'weather-snow-scattered-night', 'snow', 0.8, 'partly-cloudy-day-snow', 'partly-cloudy-night-snow'],
    95: ['thunderstorm', 'storm', 'weather-storm', null, 'rain', 0.8, 'thunderstorms-rain', null],
    96: ['thunderstormHail', 'storm', 'weather-hail', null, 'rain', 0.9, 'thunderstorms-hail', null],
    99: ['thunderstormHail', 'storm', 'weather-hail', null, 'rain', 1, 'thunderstorms-hail', null],
};

const UNKNOWN = ['unknown', 'cloudy', 'weather-none-available', null, null, 0, '', null];

export const CODES = Object.keys(TABLE).map(Number);

function row(code) {
    return TABLE[code] || UNKNOWN;
}

export function conditionKey(code) {
    return `condition.${row(code)[0]}`;
}

export function group(code) {
    return row(code)[1];
}

export function iconName(code, isDay) {
    const [, , dayIcon, nightIcon] = row(code);

    return isDay ? dayIcon : nightIcon || dayIcon;
}

export function precipitationKind(code) {
    return row(code)[4];
}

export function intensity(code) {
    return row(code)[5];
}

/** File name, without extension, of the Meteocons icon of a weather code; empty for a code that is not known. */
export function meteocon(code, isDay) {
    const [, , , , , , dayIcon, nightIcon] = row(code);

    return isDay ? dayIcon : nightIcon || dayIcon;
}

/** Every Meteocons icon a weather code can ask for. */
export const METEOCONS = [];

// Written with a loop on purpose: the JavaScript engine of QML has no Array#flatMap.
for (const entry of CODES.map(row)) {
    for (const name of [entry[6], entry[7]]) {
        if (name && !METEOCONS.includes(name)) {
            METEOCONS.push(name);
        }
    }
}
