// What the animated wallpaper adds to the scene of the widget: the clock, which moves the sun and the
// moon on between two answers of Open-Meteo, and a calm sky for as long as no place is chosen.

/**
 * The weather now at the time of the clock (`now`, YYYY-MM-DDTHH:MM at the place):
 * `{ current, today }`, the conditions of the last answer with the time moved on, and the day of
 * the clock, by whose sun day and night are told again. An answer left from the day before, on a
 * computer that was offline overnight, lends its sunrise and sunset to the new day.
 */
export function atTheClock(forecast, now) {
    const date = now.slice(0, 10);
    const known = (forecast.daily || []).find((day) => day.date === date);
    const today = known || Object.assign({}, forecast.today, {
        date,
        sunrise: date + forecast.today.sunrise.slice(10),
        sunset: date + forecast.today.sunset.slice(10),
    });
    const current = Object.assign({}, forecast.current);

    current.time = now;
    current.isDay = now >= today.sunrise && now < today.sunset;

    return { current, today };
}

/**
 * A mild, mostly clear day or night, with the sun up from 7 to 19, for a wallpaper that has no place
 * yet: `{ current, today, utcOffsetSeconds }` like an answer of Open-Meteo, at the time of the computer.
 */
export function calmForecast(now) {
    const date = now.slice(0, 10);
    const today = { date, sunrise: `${date}T07:00`, sunset: `${date}T19:00` };
    const current = {
        time: now,
        temperature: 16,
        apparentTemperature: 16,
        isDay: true,
        weatherCode: 1,
        conditionCode: 1,
        cloudCover: 20,
        windSpeed: 8,
        windDirection: 270,
        precipitation: 0,
    };

    return Object.assign(atTheClock({ current, today }, now), { utcOffsetSeconds: 0 });
}
