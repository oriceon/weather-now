"""
Writes Open-Meteo answers for the animated pictures, one per kind of weather, made from the
recorded answer for Constanța. The current conditions, the hours, today and the quarter hours are
changed together, so that the sky, the words and the numbers agree.

    scenes.py RECORDED.json OUT_FOLDER

Writes storm.json, sunny.json, snow.json and night.json (partly cloudy, so that something moves), and
tour.json, the recorded answer with what it lacks for the tiles of Details.
"""
import copy
import json
import sys
from pathlib import Path


def set_hours(answer, values):
    """`values` maps an hourly field to a function of the hour's index and its old value."""
    hourly = answer["hourly"]

    for field, change in values.items():
        hourly[field] = [change(index, old) for index, old in enumerate(hourly[field])]


def set_today(answer, values):
    daily = answer["daily"]
    today = daily["time"].index(answer["current"]["time"][:10])

    for field, value in values.items():
        daily[field][today] = value


def cooling(start, end, hours=12):
    """A temperature that falls from `start` to `end` over `hours`, then stays."""
    return lambda index, old: round(start + (end - start) * min(index, hours) / hours, 1)


def storm(recorded):
    answer = copy.deepcopy(recorded)
    answer["current"].update(temperature_2m=17.4, apparent_temperature=17.0, relative_humidity_2m=88, precipitation=4.2,
                             weather_code=95, cloud_cover=100, wind_speed_10m=31.0, wind_gusts_10m=68.0, wind_direction_10m=290)
    rain = [4.2, 3.1, 1.2]
    set_hours(answer, {
        "weather_code": lambda index, old: [95, 95, 63][index] if index < 3 else 3,
        "precipitation": lambda index, old: rain[index] if index < 3 else 0.0,
        "precipitation_probability": lambda index, old: [95, 90, 70][index] if index < 3 else 15,
        "cloud_cover": lambda index, old: 100 if index < 6 else 60,
        "temperature_2m": cooling(17.4, 12.0),
        "apparent_temperature": cooling(17.0, 10.5),
        "sunshine_duration": lambda index, old: 0,
    })
    set_today(answer, {"weather_code": 95, "temperature_2m_max": 19.2, "temperature_2m_min": 11.6, "precipitation_sum": 9.6,
                       "precipitation_hours": 4, "precipitation_probability_max": 95, "snowfall_sum": 0})
    answer["minutely_15"]["precipitation"] = [1.2, 1.4, 1.1, 0.9, 0.8, 0.6, 0.3, 0.2]

    return answer


def sunny(recorded):
    answer = copy.deepcopy(recorded)
    answer["current"].update(temperature_2m=23.1, apparent_temperature=23.6, relative_humidity_2m=45, precipitation=0.0,
                             weather_code=0, cloud_cover=3, wind_speed_10m=9.0, wind_gusts_10m=18.0, wind_direction_10m=120)
    set_hours(answer, {
        "weather_code": lambda index, old: 0 if index % 7 else 1,
        "precipitation": lambda index, old: 0.0,
        "precipitation_probability": lambda index, old: 0 if index % 5 else 5,
        "cloud_cover": lambda index, old: 5 if index % 7 else 15,
        "temperature_2m": cooling(23.1, 14.0),
        "apparent_temperature": cooling(23.6, 13.5),
        "sunshine_duration": lambda index, old: 3600 if answer["hourly"]["is_day"][index] else 0,
    })
    set_today(answer, {"weather_code": 0, "temperature_2m_max": 24.3, "temperature_2m_min": 13.2, "precipitation_sum": 0.0,
                       "precipitation_hours": 0, "precipitation_probability_max": 5, "snowfall_sum": 0, "cloud_cover_mean": 8})
    answer["minutely_15"]["precipitation"] = [0.0] * len(answer["minutely_15"]["precipitation"])

    return answer


def snow(recorded):
    answer = copy.deepcopy(recorded)
    answer["current"].update(temperature_2m=-2.3, apparent_temperature=-6.8, relative_humidity_2m=92, precipitation=1.1,
                             weather_code=73, cloud_cover=100, wind_speed_10m=14.0, wind_gusts_10m=30.0, wind_direction_10m=20)
    falling = [1.1, 0.9, 0.6, 0.4, 0.2]
    set_hours(answer, {
        "weather_code": lambda index, old: [73, 73, 71, 71, 71][index] if index < 5 else 3,
        "precipitation": lambda index, old: falling[index] if index < 5 else 0.0,
        "precipitation_probability": lambda index, old: [90, 85, 75, 60, 45][index] if index < 5 else 10,
        "cloud_cover": lambda index, old: 100 if index < 8 else 70,
        "temperature_2m": cooling(-2.3, -5.4),
        "apparent_temperature": cooling(-6.8, -9.9),
        "sunshine_duration": lambda index, old: 0,
    })
    set_today(answer, {"weather_code": 73, "temperature_2m_max": 0.4, "temperature_2m_min": -5.6, "precipitation_sum": 6.3,
                       "precipitation_hours": 7, "precipitation_probability_max": 90, "snowfall_sum": 4.4})
    answer["minutely_15"]["precipitation"] = [0.3, 0.3, 0.2, 0.3, 0.2, 0.2, 0.1, 0.1]

    return answer


def night(recorded, hours_later=4):
    """A partly cloudy night, the clouds passing the moon: everything starts `hours_later` than the recorded answer, after sunset."""
    answer = copy.deepcopy(recorded)
    hourly = answer["hourly"]

    # The hours start with the current one; the last ones are repeated to keep the length.
    for field, values in hourly.items():
        hourly[field] = values[hours_later:] + values[-hours_later:]

    hourly["time"] = recorded["hourly"]["time"][hours_later:] + [
        f"{time[:11]}{(int(time[11:13]) + hours_later) % 24:02d}{time[13:]}" for time in recorded["hourly"]["time"][-hours_later:]
    ]
    start = hourly["time"][0]
    answer["current"].update(time=start, temperature_2m=10.8, apparent_temperature=9.1, relative_humidity_2m=70, is_day=0,
                             precipitation=0.0, weather_code=2, cloud_cover=35, wind_speed_10m=16.0, wind_gusts_10m=27.0,
                             wind_direction_10m=250)
    set_hours(answer, {
        "weather_code": lambda index, old: 2 if not hourly["is_day"][index] else 1,
        "precipitation": lambda index, old: 0.0,
        "precipitation_probability": lambda index, old: 0,
        "cloud_cover": lambda index, old: 35,
        "temperature_2m": cooling(10.8, 7.5),
        "apparent_temperature": cooling(9.1, 5.9),
    })
    set_today(answer, {"weather_code": 2, "precipitation_sum": 0.0, "precipitation_hours": 0, "precipitation_probability_max": 10})
    quarters = answer["minutely_15"]
    quarters["time"] = [f"{start[:11]}{int(start[11:13]) + index // 4:02d}:{index % 4 * 15:02d}" for index in range(len(quarters["time"]))]
    quarters["precipitation"] = [0.0] * len(quarters["time"])

    return answer


def tour(recorded):
    """The recorded answer, with the dew point and how far one sees, which it was recorded without."""
    answer = copy.deepcopy(recorded)
    answer["current"].update(dew_point_2m=8.9, visibility=24000)

    return answer


def main():
    recorded = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)

    for name, make in {"storm": storm, "sunny": sunny, "snow": snow, "night": night, "tour": tour}.items():
        (out / f"{name}.json").write_text(json.dumps(make(recorded)), encoding="utf-8")


if __name__ == "__main__":
    main()
