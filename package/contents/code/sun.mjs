// The sun through the day: where sunrise and sunset fall among the hours, and how much daylight is left.

/** Minutes since 1970 of a wall-clock time such as "2026-10-13T07:17", read as UTC so that it is never shifted. */
function minutes(iso) {
    return Date.parse(`${String(iso).slice(0, 16)}:00Z`) / 60000;
}

/**
 * The sunrises and sunsets of `days` that fall among `hours`, the first of which starts the strip,
 * in order. `column` is where in the strip: 3.5 is half way through the fourth hour.
 */
export function sunEvents(days, hours) {
    if (hours.length === 0) {
        return [];
    }

    const first = minutes(hours[0].time);
    const last = first + hours.length * 60;
    const events = [];

    days.forEach((day) => {
        [['sunrise', day.sunrise], ['sunset', day.sunset]].forEach(([kind, time]) => {
            const at = time ? minutes(time) : NaN;

            if (at >= first && at < last) {
                events.push({ kind, time, column: (at - first) / 60 });
            }
        });
    });

    return events.sort((early, late) => early.column - late.column);
}

/** Minutes of daylight left until sunset; 0 once the sun has set or before it rose. */
export function daylightLeft(nowIso, sunriseIso, sunsetIso) {
    const now = minutes(nowIso);

    return now >= minutes(sunriseIso) && now < minutes(sunsetIso) ? Math.round(minutes(sunsetIso) - now) : 0;
}
