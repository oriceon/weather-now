import { hourCode, representativeCode } from './conditions.mjs';
import { addMinutes, dateOf } from './dates.mjs';

const FORECAST_ENDPOINT = 'https://api.open-meteo.com/v1/forecast';
const GEOCODE_ENDPOINT = 'https://geocoding-api.open-meteo.com/v1/search';

const FORECAST_DAYS = 16;
/** Enough to fill a calendar week that began up to six days ago. */
const PAST_DAYS = 6;
/** The hours the Hours tab and everything about the coming hours goes by. */
const FORECAST_HOURS = 48;
/** Two hours of quarter hours, and the one that has just ended, which is let go: see quartersFrom(). */
const FORECAST_QUARTERS = 9;
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
    visibility: 'visibility',
    dewPoint: 'dew_point_2m',
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
    windGusts: 'wind_gusts_10m',
    uvIndex: 'uv_index',
    sunshineDuration: 'sunshine_duration',
    pressure: 'pressure_msl',
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

/**
 * The quarter hours of precipitation, each at the time it starts, from the one under way on.
 * Open-Meteo gives the sum of a quarter at its end: "17:15" for what falls from 17:00 to 17:15.
 */
function quartersFrom(block, now) {
    const start = String(now).slice(0, 16);

    return rows(block, MINUTELY_FIELDS)
        .map((quarter) => Object.assign({}, quarter, { time: addMinutes(quarter.time, -15) }))
        .filter((quarter) => addMinutes(quarter.time, 15) > start);
}

/** The API sends one array per field; this turns a block of them into one object per moment. */
function rows(block, fields) {
    if (!block || !Array.isArray(block.time)) {
        return [];
    }

    return block.time.map((time, index) => mapped(fields, (field) => (block[field] || [])[index]));
}

/** Knots, however the settings write them: kn or kt only changes what is shown after the number. */
const KNOTS = ['kn', 'kt'];

export function forecastUrl({ latitude, longitude, temperatureUnit, windUnit }) {
    return `${FORECAST_ENDPOINT}?${queryString({
        latitude,
        longitude,
        current: requestable(CURRENT_FIELDS),
        hourly: requestable(HOURLY_FIELDS),
        minutely_15: requestable(MINUTELY_FIELDS),
        daily: requestable(DAILY_FIELDS),
        timezone: 'auto',
        // The hours of every day, the past ones too, so that a day of the calendar opens on its hours.
        past_days: PAST_DAYS,
        forecast_days: FORECAST_DAYS,
        forecast_minutely_15: FORECAST_QUARTERS,
        temperature_unit: temperatureUnit,
        wind_speed_unit: KNOTS.includes(windUnit) ? 'kn' : windUnit,
        // The amounts stay in mm, which the conditions and the sky count in; inches are only shown (format.mjs).
        precipitation_unit: 'mm',
    })}`;
}

/**
 * The little the animated wallpaper needs, asked for every quarter of an hour: the conditions now
 * and the days of today and tomorrow, with their sun; of the hours, only what tells sunshine from
 * cloud. In °C and km/h, which the picture goes by.
 */
export function sceneUrl({ latitude, longitude }) {
    return `${FORECAST_ENDPOINT}?${queryString({
        latitude,
        longitude,
        current: requestable(CURRENT_FIELDS),
        hourly: 'weather_code,is_day,cloud_cover,sunshine_duration',
        daily: requestable(DAILY_FIELDS),
        timezone: 'auto',
        forecast_days: 2,
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
    const allHours = rows(response.hourly, HOURLY_FIELDS);
    const today = daily.find((day) => day.date === dateOf(current.time));

    if (!today) {
        throw new Error('Incomplete forecast response');
    }

    for (const day of daily) {
        day.conditionCode = representativeCode(day);
    }

    for (const hour of allHours) {
        hour.isDay = hour.isDay === 1;
        hour.conditionCode = hourCode(hour);
    }

    // From the current hour on: "2026-10-21T14" for 14:15.
    const thisHour = current.time.slice(0, 13);
    const first = allHours.findIndex((hour) => hour.time.slice(0, 13) >= thisHour);
    const hourly = allHours.slice(Math.max(0, first), Math.max(0, first) + FORECAST_HOURS);

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
        /** 48 hours, from the current hour on. */
        hourly,
        /** Every hour of the days in `daily`, past ones included. */
        allHours,
        /** Quarter hours of precipitation, each at its start, from the one under way on. */
        minutely: quartersFrom(response.minutely_15, current.time),
    };
}

/**
 * Only the quarter hours of precipitation, asked for in between forecasts while the notification of
 * rain is on: a small request, for a warning that comes in time.
 */
export function quartersUrl({ latitude, longitude }) {
    return `${FORECAST_ENDPOINT}?${queryString({
        latitude,
        longitude,
        current: 'precipitation',
        minutely_15: requestable(MINUTELY_FIELDS),
        timezone: 'auto',
        forecast_minutely_15: FORECAST_QUARTERS,
        precipitation_unit: 'mm',
    })}`;
}

/** `{ now, minutely }`: the time at the place, and the quarter hours from the current one on. */
export function parseQuarters(response) {
    if (!response || !response.current || !response.minutely_15) {
        throw new Error('Incomplete answer for the quarter hours');
    }

    return { now: response.current.time, minutely: quartersFrom(response.minutely_15, response.current.time) };
}

export function geocodeUrl(name, language, count = GEOCODE_RESULTS) {
    return `${GEOCODE_ENDPOINT}?${queryString({ name, count, language, format: 'json' })}`;
}

export function parseGeocode(response) {
    const places = (response && response.results) || [];

    // The names are GeoNames', which anyone may edit: markup in one broke the buttons that showed it.
    const named = (text) => String(text || '').replace(/[<>]/g, '');

    return places.map((place) => ({
        name: named(place.name),
        label: [place.name, place.admin1, place.country].map(named).filter(Boolean).join(', '),
        latitude: place.latitude,
        longitude: place.longitude,
        /** First-level administrative area; in Romania, the county. */
        region: named(place.admin1),
        country: named(place.country),
        countryCode: place.country_code || '',
    }));
}
