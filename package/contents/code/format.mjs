const MISSING = '–';

const DECIMAL_SEPARATOR = { ro: ',' };

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

    return `${rounded(value)} ${unit === 'mph' ? 'mph' : 'km/h'}`;
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
