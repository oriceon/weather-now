const MISSING = '–';

/** Where the decimal point is a comma; elsewhere it stays a point. */
const DECIMAL_SEPARATOR = { ro: ',', de: ',', fr: ',', es: ',', it: ',', pl: ',' };
const MM_PER_INCH = 25.4;
const METRES_PER_MILE = 1609.344;

function isMissing(value) {
    return value === null || value === undefined || Number.isNaN(value);
}

function rounded(value) {
    return String(Math.round(value) || 0);
}

export function temperature(value) {
    return isMissing(value) ? MISSING : `${rounded(value)}°`;
}

export function temperatureUnit(value, unit) {
    return isMissing(value) ? MISSING : `${rounded(value)} ${unit === 'fahrenheit' ? '°F' : '°C'}`;
}

export function number(value, decimals, language) {
    return isMissing(value) ? MISSING : value.toFixed(decimals).replace('.', DECIMAL_SEPARATOR[language] || '.');
}

export function wind(value, unit, language) {
    if (isMissing(value)) {
        return MISSING;
    }

    if (unit === 'ms') {
        return `${number(value, 1, language)} m/s`;
    }

    return `${rounded(value)} ${{ mph: 'mph', kn: 'kn', kt: 'kt' }[unit] || 'km/h'}`;
}

export function percent(value) {
    return isMissing(value) ? MISSING : `${rounded(value)}%`;
}

export function sentenceCase(text) {
    return text.charAt(0).toUpperCase() + text.slice(1);
}

export function millimetres(value, language) {
    if (isMissing(value)) {
        return MISSING;
    }

    const tenths = Math.round(value * 10) / 10;

    return `${number(tenths, Number.isInteger(tenths) ? 0 : 1, language)} mm`;
}

/**
 * An amount of rain or melted snow, which the forecast gives in mm, as a number in `unit` without
 * the unit: mm to a tenth, inches to a hundredth. An amount too small for a hundredth of an inch
 * is "<0.01", not 0, so that it does not read as dry.
 */
export function precipitationNumber(value, unit, language) {
    if (isMissing(value)) {
        return MISSING;
    }

    if (unit !== 'inch') {
        return number(value, 1, language);
    }

    const hundredths = Math.round(value / MM_PER_INCH * 100) / 100;

    if (hundredths === 0 && value > 0) {
        return `<${number(0.01, 2, language)}`;
    }

    return number(hundredths, hundredths === 0 ? 0 : 2, language);
}

/** The same amount with its unit: mm, or inches. */
export function precipitation(value, unit, language) {
    if (unit !== 'inch') {
        return millimetres(value, language);
    }

    return isMissing(value) ? MISSING : `${precipitationNumber(value, unit, language)} in`;
}

/** A span of minutes as hours and minutes: "1 h 25 min", "11 h", "25 min". */
export function duration(minutes) {
    // Whole minutes first: 659.6 is 11 h, not 10 h 60 min.
    const total = Math.round(minutes);
    const hours = Math.floor(total / 60);
    const rest = total - hours * 60;

    if (hours === 0) {
        return `${rest} min`;
    }

    return rest === 0 ? `${hours} h` : `${hours} h ${rest} min`;
}

/**
 * How far one can see, which the forecast gives in metres: in km, or in miles beside inches of
 * rain, to a tenth while it is short and whole beyond 10.
 */
export function distance(metres, unit, language) {
    if (isMissing(metres)) {
        return MISSING;
    }

    const length = unit === 'inch' ? metres / METRES_PER_MILE : metres / 1000;
    const shown = length < 10 ? number(Math.round(length * 10) / 10, 1, language).replace(/[.,]0$/, '') : rounded(length);

    return `${shown} ${unit === 'inch' ? 'mi' : 'km'}`;
}

export function pressure(value) {
    return isMissing(value) ? MISSING : `${rounded(value)} hPa`;
}

/** Translation key of the WHO exposure category of a UV index. */
export function uvKey(index) {
    if (index >= 11) {
        return 'uv.extreme';
    }

    if (index >= 8) {
        return 'uv.veryHigh';
    }

    if (index >= 6) {
        return 'uv.high';
    }

    return index >= 3 ? 'uv.moderate' : 'uv.low';
}
