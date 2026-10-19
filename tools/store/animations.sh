#!/usr/bin/env bash
# Makes the animated pictures of the README in store/: the sky of the Today tab in several kinds of
# weather, and a tour of the tabs, in English, at one and a half times the size, on the background of
# a dark Plasma theme.
#
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README), with Pillow importable by PY.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${PY:?the python of the viewer}"
export QT_SCALE_FACTOR=1.5

COMMON=(--lang en --size 520x520)
# 36 frames, 66 ms apart: a little over two seconds of each sky.
MOVING=(--animations full --wait 1500 --frames 36)

# The current conditions of each sky; the rest of the recorded forecast stays.
declare -A SKIES=(
    [1-clear]='{"weatherCode":0,"conditionCode":0,"isDay":true,"cloudCover":0,"precipitation":0}'
    [2-cloudy]='{"weatherCode":2,"conditionCode":2,"isDay":true,"cloudCover":45,"precipitation":0}'
    [3-rain]='{"weatherCode":63,"conditionCode":63,"isDay":true,"cloudCover":100,"precipitation":2.4}'
    [4-storm]='{"weatherCode":95,"conditionCode":95,"isDay":true,"cloudCover":100,"precipitation":6.1}'
    [5-snow]='{"weatherCode":73,"conditionCode":73,"isDay":true,"cloudCover":100,"precipitation":1.2,"temperature":-1,"apparentTemperature":-5}'
    [6-night]='{"weatherCode":0,"conditionCode":0,"isDay":false,"cloudCover":0,"precipitation":0,"time":"2026-10-13T22:00"}'
)

cd "$ROOT/tests/qml"
for sky in $(printf '%s\n' "${!SKIES[@]}" | sort); do
    "$PY" viewer.py stage "$WORK/sky-$sky.png" "${COMMON[@]}" --current "${SKIES[$sky]}" "${MOVING[@]}" > /dev/null
done

"$PY" viewer.py stage "$WORK/today.png" "${COMMON[@]}" --alerts "${MOVING[@]}" > /dev/null

for tab in 1 2 3 4; do
    "$PY" viewer.py stage "$WORK/tab-$tab.png" "${COMMON[@]}" --tab "$tab" --alerts > /dev/null
done

# The viewer leaves 10 px of desktop around the widget and the Plasma frame has 6 px corners, both times 1.5.
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-sky.webp" 15 9 $(printf "$WORK/sky-%s\n" $(printf '%s\n' "${!SKIES[@]}" | sort))
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-tour.webp" 15 9 "$WORK/today" "$WORK/tab-1.png:2500" "$WORK/tab-2.png:2500" "$WORK/tab-3.png:2500" "$WORK/tab-4.png:2500"
