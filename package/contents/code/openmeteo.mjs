import { hourCode, representativeCode } from './conditions.mjs';
import { dateOf } from './dates.mjs';

const FORECAST_ENDPOINT = 'https://api.open-meteo.com/v1/forecast';
const GEOCODE_ENDPOINT = 'https://geocoding-api.open-meteo.com/v1/search';

const FORECAST_DAYS = 16;
/** Enough to fill a calendar week that began up to six days ago. */
const PAST_DAYS = 6;
const FORECAST_HOURS = 48;
/** Two hours of quarter hours. */
const FORECAST_QUARTERS = 8;
const GEOCODE_RESULTS = 8;

/** Name used by the widget => name of the field in the Open-Meteo response. */
const CURRENT_FIELDS = {
    time: 'time',
    temperature: 'temperature_2m',
    apparentTemperature: 'apparent_temperature',
    humidity: 'relative_humidity_2m',
    isDay: 'is_day',
    precipitation: 'precipitation',
    weatherCode: 'weather_code',
    cloudCover: 'cloud_cover',
    pressure: 'pressure_msl',
    windSpeed: 'wind_speed_10m',
    windDirection: 'wind_direction_10m',
    windGusts: 'wind_gusts_10m',
};

const HOURLY_FIELDS = {
    time: 'time',
    temperature: 'temperature_2m',
    apparentTemperature: 'apparent_temperature',
    humidity: 'relative_humidity_2m',
    precipitationProbability: 'precipitation_probability',
    precipitation: 'precipitation',
    weatherCode: 'weather_code',
    isDay: 'is_day',
    cloudCover: 'cloud_cover',
    windSpeed: 'wind_speed_10m',
    windDirection: 'wind_direction_10m',
    uvIndex: 'uv_index',
    sunshineDuration: 'sunshine_duration',
};

const MINUTELY_FIELDS = {
    time: 'time',
    precipitation: 'precipitation',
};

const DAILY_FIELDS = {
    date: 'time',
    weatherCode: 'weather_code',
    temperatureMax: 'temperature_2m_max',
    temperatureMin: 'temperature_2m_min',
    sunrise: 'sunrise',
    sunset: 'sunset',
    uvIndexMax: 'uv_index_max',
    precipitationSum: 'precipitation_sum',
    precipitationHours: 'precipitation_hours',
    precipitationProbability: 'precipitation_probability_max',
    windSpeedMax: 'wind_speed_10m_max',
    windGustsMax: 'wind_gusts_10m_max',
    windDirection: 'wind_direction_10m_dominant',
    sunshineDuration: 'sunshine_duration',
    daylightDuration: 'daylight_duration',
    cloudCoverMean: 'cloud_cover_mean',
    snowfallSum: 'snowfall_sum',
};

function queryString(parameters) {
    return Object.keys(parameters)
        .map((name) => `${name}=${encodeURIComponent(parameters[name])}`)
        .join('&');
}

/** "time" comes with every block, it is not a field that can be requested. */
function requestable(fields) {
    return Object.keys(fields)
        .map((name) => fields[name])
        .filter((field) => field !== 'time')
        .join(',');
}

function mapped(fields, read) {
    const result = {};

    for (const name of Object.keys(fields)) {
        const value = read(fields[name]);

        result[name] = value === undefined ? null : value;
    }

    return result;
}

/** The API sends one array per field; this turns a block of them into one object per moment. */
function rows(block, fields) {
    if (!block || !Array.isArray(block.time)) {
        return [];
    }

    return block.time.map((time, index) => mapped(fields, (field) => (block[field] || [])[index]));
}

export function forecastUrl({ latitude, longitude, temperatureUnit, windUnit }) {
    return `${FORECAST_ENDPOINT}?${queryString({
        latitude,
        longitude,
        current: requestable(CURRENT_FIELDS),
        hourly: requestable(HOURLY_FIELDS),
        minutely_15: requestable(MINUTELY_FIELDS),
        daily: requestable(DAILY_FIELDS),
        timezone: 'auto',
        past_days: PAST_DAYS,
        forecast_days: FORECAST_DAYS,
        forecast_hours: FORECAST_HOURS,
        forecast_minutely_15: FORECAST_QUARTERS,
        temperature_unit: temperatureUnit,
        wind_speed_unit: windUnit,
        // The amounts stay in mm, which the conditions and the sky count in; inches are only shown (format.mjs).
        precipitation_unit: 'mm',
    })}`;
}

/**
 * Besides the fields of the API, the current conditions, every hour and every day get a
 * `conditionCode`: the WMO code to show, see conditions.mjs. `weatherCode` stays as reported.
 */
export function parseForecast(response) {
    if (response && response.error) {
        throw new Error(response.reason || 'Open-Meteo reported an error');
    }

    if (!response || !response.current || !response.daily) {
        throw new Error('Incomplete forecast response');
    }

    const current = mapped(CURRENT_FIELDS, (field) => response.current[field]);
    const daily = rows(response.daily, DAILY_FIELDS);
    const hourly = rows(response.hourly, HOURLY_FIELDS);
    const today = daily.find((day) => day.date === dateOf(current.time));

    if (!today) {
        throw new Error('Incomplete forecast response');
    }

    for (const day of daily) {
        day.conditionCode = representativeCode(day);
    }

    for (const hour of hourly) {
        hour.isDay = hour.isDay === 1;
        hour.conditionCode = hourCode(hour);
    }

    current.isDay = current.isDay === 1;
    current.conditionCode = hourCode({
        weatherCode: current.weatherCode,
        isDay: current.isDay,
        cloudCover: current.cloudCover,
        sunshineDuration: hourly.length > 0 ? hourly[0].sunshineDuration : null,
    });

    return {
        timezone: response.timezone,
        /** What to add to UTC to get the wall-clock time of the forecast location. */
        utcOffsetSeconds: response.utc_offset_seconds || 0,
        current,
        today,
        /** Past days first; `today` is one of the entries. */
        daily,
        /** From the current hour on. */
        hourly,
        /** Quarter hours of precipitation, from the current one on. */
        minutely: rows(response.minutely_15, MINUTELY_FIELDS),
    };
}

export function geocodeUrl(name, language) {
    return `${GEOCODE_ENDPOINT}?${queryString({ name, count: GEOCODE_RESULTS, language, format: 'json' })}`;
}

export function parseGeocode(response) {
    const places = (response && response.results) || [];

    return places.map((place) => ({
        name: place.name,
        label: [place.name, place.admin1, place.country].filter(Boolean).join(', '),
        latitude: place.latitude,
        longitude: place.longitude,
        /** First-level administrative area; in Romania, the county. */
        region: place.admin1 || '',
        countryCode: place.country_code || '',
    }));
}
