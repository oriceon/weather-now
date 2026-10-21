#!/usr/bin/env bash
# Makes the animated pictures in store/, in English, 1020 × 500 once the desktop around the widget
# is cut off, as a widget usually sits on a desktop, on the background of a dark Plasma theme:
# - for the README, as WebP: the sky in four kinds of weather, and a tour of the tabs;
# - for the KDE Store, which takes five pictures at most and shows no WebP: five GIFs, the four skies
#   one by one, each over a landscape, the first with a yellow warning, and the tour of every tab,
#   the radar playing; and the product picture, animated.
#
# The skies come from answers made by scenes.py, so that the words and numbers agree with them.
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README), with Pillow importable by PY,
# and gifski (https://gif.ski) on the PATH or named in GIFSKI.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${PY:?the python of the viewer}"

COMMON=(--lang en --size 1040x520)
# 60 frames, 66 ms apart: about three seconds shown, and 12 frames more to fade the end into the start.
MOVING=(--animations full --wait 1500 --frames 60)
BLEND=12

"$PY" "$HERE/scenes.py" "$ROOT/tests/fixtures/forecast-constanta.json" "$WORK/scenes"

cd "$ROOT/tests/qml"
# The recorded warning is a yellow one, for wind.
"$PY" viewer.py stage "$WORK/storm.png" "${COMMON[@]}" --forecast "$WORK/scenes/storm.json" --alerts --landscape hills "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/sunny.png" "${COMMON[@]}" --forecast "$WORK/scenes/sunny.json" --landscape sea "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/snow.png" "${COMMON[@]}" --forecast "$WORK/scenes/snow.json" --locality Brașov --region Brașov --landscape village "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/night.png" "${COMMON[@]}" --forecast "$WORK/scenes/night.json" --landscape city "${MOVING[@]}" > /dev/null

# The tour: the recorded forecast and warnings, over the poppies; Details with the air, the pollen and the aurora.
TOURING=(--forecast "$WORK/scenes/tour.json" --alerts)
"$PY" viewer.py stage "$WORK/today.png" "${COMMON[@]}" "${TOURING[@]}" --landscape poppies "${MOVING[@]}" > /dev/null

for tab in 1 2 3 4; do
    extra=()
    [ "$tab" = 4 ] && extra=(--air --pollen --aurora horizon)
    "$PY" viewer.py stage "$WORK/tab-$tab.png" "${COMMON[@]}" "${TOURING[@]}" --tab "$tab" "${extra[@]}" > /dev/null
done

# The radar, with the real images of RainViewer: wide enough to hold some rain, opened halfway through
# the wait, and played once all its images have come.
"$PY" viewer.py stage "$WORK/radar.png" "${COMMON[@]}" "${TOURING[@]}" --tab 2 --item-set view=radar --item-set zoom=5 --wait 32000 --frames 14 --frame-interval 600 > /dev/null

# The viewer leaves 10 px of desktop around the widget and the Plasma frame has 6 px corners.
TOUR=("$WORK/today" "$WORK/tab-1.png:2500" "$WORK/tab-2.png:2200" "$WORK/radar" "$WORK/tab-3.png:2500" "$WORK/tab-4.png:2500")
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-sky.webp" 10 6 "$WORK/storm" "$WORK/sunny" "$WORK/snow" "$WORK/night"
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-tour.webp" 10 6 "${TOUR[@]}"

"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-store-1-storm.gif" 10 6 --loop-blend "$BLEND" "$WORK/storm"
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-store-2-sunny.gif" 10 6 --loop-blend "$BLEND" "$WORK/sunny"
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-store-3-snow.gif" 10 6 --loop-blend "$BLEND" "$WORK/snow"
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-store-4-night.gif" 10 6 --loop-blend "$BLEND" "$WORK/night"
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-store-5-tour.gif" 10 6 "${TOUR[@]}"

# The product picture, animated: 60 steps of its `phase`, 24 a second. Its corners are already round.
"$PY" "$HERE/render.py" "$HERE/logo.qml" "$WORK/logo.png" --frames 60 --fps 24 > /dev/null
"$PY" "$HERE/animate.py" "$ROOT/store/weather-now-logo.gif" 0 0 "$WORK/logo"
