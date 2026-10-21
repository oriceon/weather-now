import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { forecastUrl, geocodeUrl, parseForecast, parseGeocode, parseQuarters, quartersUrl, sceneUrl } from '../package/contents/code/openmeteo.mjs';

const fixture = (name) => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));

test('forecastUrl asks for the configured place and units in the timezone of that place', () => {
    const url = new URL(forecastUrl({ latitude: 44.1807, longitude: 28.6343, temperatureUnit: 'fahrenheit', windUnit: 'ms' }));

    assert.equal(url.origin + url.pathname, 'https://api.open-meteo.com/v1/forecast');
    assert.equal(url.searchParams.get('latitude'), '44.1807');
    assert.equal(url.searchParams.get('longitude'), '28.6343');
    assert.equal(url.searchParams.get('timezone'), 'auto');
    assert.equal(url.searchParams.get('temperature_unit'), 'fahrenheit');
    assert.equal(url.searchParams.get('wind_speed_unit'), 'ms');
});

// kt only changes what is written after the number; the forecast is the same, and is not asked for again.
test('forecastUrl asks for knots however they are written', () => {
    for (const windUnit of ['kn', 'kt']) {
        const url = new URL(forecastUrl({ latitude: 44.1807, longitude: 28.6343, temperatureUnit: 'celsius', windUnit }));

        assert.equal(url.searchParams.get('wind_speed_unit'), 'kn');
    }
});

test('forecastUrl asks for enough past days to fill a week that began up to six days ago', () => {
    const url = new URL(forecastUrl({ latitude: 1, longitude: 2, temperatureUnit: 'celsius', windUnit: 'kmh' }));

    assert.equal(url.searchParams.get('past_days'), '6');
    assert.equal(url.searchParams.get('forecast_days'), '16');
    assert.equal(url.searchParams.get('forecast_minutely_15'), '9');
});

test('forecastUrl asks for the hours of every day, so that each day of the calendar can open on them', () => {
    const url = new URL(forecastUrl({ latitude: 1, longitude: 2, temperatureUnit: 'celsius', windUnit: 'kmh' }));

    assert.equal(url.searchParams.get('forecast_hours'), null);
    assert.equal(url.searchParams.get('past_hours'), null);
});

test('forecastUrl requests every field parseForecast reads', () => {
    const url = new URL(forecastUrl({ latitude: 1, longitude: 2, temperatureUnit: 'celsius', windUnit: 'kmh' }));
    const wanted = {
        current: ['temperature_2m', 'apparent_temperature', 'relative_humidity_2m', 'is_day', 'precipitation', 'weather_code', 'cloud_cover', 'pressure_msl', 'wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m', 'visibility', 'dew_point_2m'],
        hourly: ['temperature_2m', 'apparent_temperature', 'relative_humidity_2m', 'precipitation_probability', 'precipitation', 'weather_code', 'is_day', 'cloud_cover', 'wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m', 'uv_index', 'sunshine_duration', 'pressure_msl'],
        minutely_15: ['precipitation'],
        daily: ['weather_code', 'temperature_2m_max', 'temperature_2m_min', 'sunrise', 'sunset', 'uv_index_max', 'precipitation_sum', 'precipitation_hours', 'precipitation_probability_max', 'wind_speed_10m_max', 'wind_gusts_10m_max', 'wind_direction_10m_dominant', 'sunshine_duration', 'daylight_duration', 'cloud_cover_mean', 'snowfall_sum'],
    };

    for (const block of Object.keys(wanted)) {
        assert.deepEqual(url.searchParams.get(block).split(',').sort(), wanted[block].slice().sort(), block);
    }
});

test('parseForecast reads the current conditions', () => {
    const { current, timezone, utcOffsetSeconds } = parseForecast(fixture('forecast-constanta'));

    assert.equal(timezone, 'Europe/Bucharest');
    assert.equal(utcOffsetSeconds, 10800);
    assert.deepEqual(current, {
        time: '2026-10-13T17:00',
        temperature: 12.5,
        apparentTemperature: 9.7,
        humidity: 77,
        isDay: true,
        precipitation: 0,
        weatherCode: 3,
        cloudCover: 100,
        pressure: 1018,
        windSpeed: 17,
        windDirection: 355,
        windGusts: 40.7,
        // The answer was recorded before these were asked for.
        visibility: null,
        dewPoint: null,
        conditionCode: 3,
    });
});

test('parseForecast reads how far one sees and the dew point', () => {
    const { current } = parseForecast(fixture('forecast-constanta-week'));

    assert.equal(current.visibility, 29660);
    assert.equal(current.dewPoint, 14.6);
});

test('parseForecast keeps every hour of every day, and singles out the 48 from the current one', () => {
    const { allHours, hourly, daily, current } = parseForecast(fixture('forecast-constanta-week'));

    assert.equal(current.time, '2026-10-21T11:45');
    assert.equal(allHours.length, daily.length * 24);
    assert.equal(allHours[0].time, `${daily[0].date}T00:00`);
    assert.equal(hourly.length, 48);
    assert.equal(hourly[0].time, '2026-10-21T11:00');
    assert.equal(hourly[47].time, '2026-10-23T10:00');
    assert.equal(typeof allHours[0].conditionCode, 'number');
});

test('parseForecast turns the column arrays of the API into one object per day, past days included', () => {
    const { daily } = parseForecast(fixture('forecast-constanta'));

    assert.equal(daily.length, 22);
    assert.equal(daily[0].date, '2026-10-07');
    assert.equal(daily[21].date, '2026-10-28');
});

test('parseForecast singles out today, by the date at the forecast location', () => {
    const { today } = parseForecast(fixture('forecast-constanta'));

    assert.deepEqual(today, {
        date: '2026-10-13',
        weatherCode: 63,
        temperatureMax: 15.2,
        temperatureMin: 11.3,
        sunrise: '2026-10-13T07:17',
        sunset: '2026-10-13T18:25',
        uvIndexMax: 0.6,
        precipitationSum: 11.2,
        precipitationHours: 13,
        precipitationProbability: 98,
        windSpeedMax: 19.1,
        windGustsMax: 45.4,
        windDirection: 354,
        sunshineDuration: 0,
        daylightDuration: 40085.07,
        cloudCoverMean: 100,
        snowfallSum: 0,
        conditionCode: 63,
    });
});

test('parseForecast reads the hours from the current one on', () => {
    const { hourly } = parseForecast(fixture('forecast-constanta'));

    assert.equal(hourly.length, 48);
    assert.deepEqual(hourly[0], {
        time: '2026-10-13T17:00',
        temperature: 12.5,
        apparentTemperature: 9.7,
        humidity: 77,
        precipitationProbability: 20,
        precipitation: 0,
        weatherCode: 3,
        isDay: true,
        cloudCover: 100,
        windSpeed: 17,
        windDirection: 355,
        // Not in the recorded answer either.
        windGusts: null,
        uvIndex: 0.4,
        sunshineDuration: 0,
        // The answer was recorded before the pressure of the hours was asked for.
        pressure: null,
        conditionCode: 3,
    });
    assert.equal(hourly[1].precipitation, 1);
    assert.equal(hourly[47].time, '2026-10-15T16:00');
});

test('parseForecast gives a day the sky it mostly has, not the most severe moment the API reports', () => {
    const thursday = parseForecast(fixture('forecast-constanta')).daily[8];

    assert.equal(thursday.date, '2026-10-15');
    assert.equal(thursday.weatherCode, 3);
    assert.equal(thursday.conditionCode, 2);
});

test('parseForecast lets a sunny hour show its sun', () => {
    const { hourly } = parseForecast(fixture('forecast-constanta'));

    assert.equal(hourly[40].time, '2026-10-15T09:00');
    assert.equal(hourly[40].conditionCode, 0);
    assert.equal(hourly[1].conditionCode, 61);
});

// Open-Meteo gives a quarter's sum at its end: its "17:00" is what fell from 16:45, before now.
test('parseForecast reads the quarter hours of precipitation, each at its start, from the one under way', () => {
    const { minutely } = parseForecast(fixture('forecast-constanta'));

    assert.equal(minutely.length, 7);
    assert.deepEqual(minutely[0], { time: '2026-10-13T17:00', precipitation: 0.3 });
    assert.deepEqual(minutely[6], { time: '2026-10-13T18:30', precipitation: 0.4 });
});

test('parseForecast copes with a response that has no hourly blocks', () => {
    const response = fixture('forecast-constanta');

    delete response.hourly;
    delete response.minutely_15;

    const { hourly, minutely, today } = parseForecast(response);

    assert.deepEqual(hourly, []);
    assert.deepEqual(minutely, []);
    assert.equal(today.date, '2026-10-13');
});

test('parseForecast reports the reason the API gave for an error', () => {
    assert.throws(() => parseForecast(fixture('forecast-error')), /Latitude must be in range/);
});

test('parseForecast rejects a response without current conditions or days', () => {
    assert.throws(() => parseForecast({}), /incomplete/i);
    assert.throws(() => parseForecast(null), /incomplete/i);
    assert.throws(() => parseForecast({ current: { time: '2026-10-13T16:30' } }), /incomplete/i);
});

test('parseForecast rejects a response whose days do not include today', () => {
    const response = fixture('forecast-constanta');

    response.current.time = '2027-01-01T10:00';

    assert.throws(() => parseForecast(response), /incomplete/i);
});

test('geocodeUrl encodes the search text and asks for names in the given language', () => {
    const url = new URL(geocodeUrl('Constanța Nord', 'ro'));

    assert.equal(url.origin + url.pathname, 'https://geocoding-api.open-meteo.com/v1/search');
    assert.equal(url.searchParams.get('name'), 'Constanța Nord');
    assert.equal(url.searchParams.get('language'), 'ro');
    assert.ok(!geocodeUrl('Constanța Nord', 'ro').includes(' '), 'the raw URL has no unescaped space');
});

test('parseGeocode lists the places with a label that tells namesakes apart', () => {
    const places = parseGeocode(fixture('geocode-constanta'));

    assert.deepEqual(places[0], {
        name: 'Constanța',
        label: 'Constanța, Constanţa, România',
        latitude: 44.18073,
        longitude: 28.63432,
        region: 'Constanţa',
        country: 'România',
        countryCode: 'RO',
    });
    assert.equal(places[1].label, 'Constanța, Baden-Württemberg, Germania');
});

// The names come from GeoNames, which anyone may edit; markup in a button's text crashed it.
test('parseGeocode drops markup from the names', () => {
    const [place] = parseGeocode({ results: [{ name: 'Valu <img src=x>lui Traian', admin1: '<b>Constanța</b>', country: 'România', latitude: 44.16, longitude: 28.46 }] });

    assert.equal(place.name, 'Valu img src=xlui Traian');
    assert.equal(place.region, 'bConstanța/b');
    assert.doesNotMatch(place.label, /[<>]/);
});

test('parseGeocode returns no places when the API found nothing', () => {
    assert.deepEqual(parseGeocode(fixture('geocode-empty')), []);
    assert.deepEqual(parseGeocode(null), []);
});

test('quartersUrl asks only for the quarter hours of precipitation, and the time at the place', () => {
    const url = new URL(quartersUrl({ latitude: 44.18, longitude: 28.63 }));

    assert.equal(url.searchParams.get('minutely_15'), 'precipitation');
    assert.equal(url.searchParams.get('current'), 'precipitation');
    assert.equal(url.searchParams.get('forecast_minutely_15'), '9');
    assert.equal(url.searchParams.get('timezone'), 'auto');
    assert.equal(url.searchParams.get('hourly'), null);
    assert.equal(url.searchParams.get('daily'), null);
});

test('parseQuarters reads the time at the place and the quarter hours', () => {
    const quarters = parseQuarters({
        current: { time: '2026-10-21T11:45', precipitation: 0 },
        minutely_15: { time: ['2026-10-21T11:45', '2026-10-21T12:00'], precipitation: [0, 0.4] },
    });

    assert.equal(quarters.now, '2026-10-21T11:45');
    assert.deepEqual(quarters.minutely, [{ time: '2026-10-21T11:45', precipitation: 0.4 }]);
    assert.throws(() => parseQuarters({ current: { time: '2026-10-21T11:45' } }), /quarter hours/);
});

test('the wallpaper asks for little: the conditions now, two days, and of the hours only sun and cloud', () => {
    const url = new URL(sceneUrl({ latitude: 44.1807, longitude: 28.6343 }));

    assert.equal(url.searchParams.get('forecast_days'), '2');
    assert.equal(url.searchParams.get('hourly'), 'weather_code,is_day,cloud_cover,sunshine_duration');
    assert.equal(url.searchParams.get('minutely_15'), null);
    assert.equal(url.searchParams.get('temperature_unit'), null);
    assert.match(url.searchParams.get('current'), /weather_code/);
});

test('an answer as small as that of the wallpaper is still read', () => {
    const full = fixture('forecast-constanta');
    const kept = ['time', 'weather_code', 'is_day', 'cloud_cover', 'sunshine_duration'];
    const small = {
        ...full,
        hourly: Object.fromEntries(kept.filter((field) => field in full.hourly).map((field) => [field, full.hourly[field]])),
        minutely_15: undefined,
    };
    const { current, today, hourly } = parseForecast(small);

    assert.equal(today.date, current.time.slice(0, 10));
    assert.ok(hourly.length > 0);
    assert.equal(typeof current.conditionCode, 'number');
});
