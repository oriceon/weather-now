#!/usr/bin/env bash
# Makes the animated pictures in store/, in English, with the widget twice as wide as it is tall
# (1040 × 520), as it usually sits on a desktop, on the background of a dark Plasma theme:
# - for the README, as WebP: the sky in four kinds of weather, and a tour of the tabs;
# - for the KDE Store, which takes five pictures at most and shows no WebP: five GIFs, the four skies
#   one by one and the tour, and the product picture, animated.
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
"$PY" viewer.py stage "$WORK/storm.png" "${COMMON[@]}" --forecast "$WORK/scenes/storm.json" --alerts "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/sunny.png" "${COMMON[@]}" --forecast "$WORK/scenes/sunny.json" "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/snow.png" "${COMMON[@]}" --forecast "$WORK/scenes/snow.json" --locality Brașov --region Brașov "${MOVING[@]}" > /dev/null
"$PY" viewer.py stage "$WORK/night.png" "${COMMON[@]}" --forecast "$WORK/scenes/night.json" "${MOVING[@]}" > /dev/null

# The tour: the recorded forecast and warnings.
"$PY" viewer.py stage "$WORK/today.png" "${COMMON[@]}" --alerts "${MOVING[@]}" > /dev/null

for tab in 1 2 3 4; do
    "$PY" viewer.py stage "$WORK/tab-$tab.png" "${COMMON[@]}" --tab "$tab" --alerts > /dev/null
done

# The viewer leaves 10 px of desktop around the widget and the Plasma frame has 6 px corners.
TOUR=("$WORK/today" "$WORK/tab-1.png:2500" "$WORK/tab-2.png:2500" "$WORK/tab-3.png:2500" "$WORK/tab-4.png:2500")
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
