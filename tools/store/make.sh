#!/usr/bin/env bash
# Makes the still pictures in store/: five screenshots in English, as wide as the animations
# (1040 × 520), from the recorded forecast and warnings, and the product picture of the KDE Store, still;
# animations.sh makes it animated.
#
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${PY:?the python of the viewer}"

"$PY" "$HERE/scenes.py" "$ROOT/tests/fixtures/forecast-constanta.json" "$WORK/scenes"

cd "$ROOT/tests/qml"
mkdir -p "$ROOT/store"
for shot in 0:1-today 1:2-hours 2:3-rain 3:4-days 4:5-details; do
    tab="${shot%%:*}" name="${shot#*:}"
    extra=()
    [ "$tab" = 4 ] && extra=(--air --pollen --aurora horizon)
    "$PY" viewer.py stage "$WORK/$name.png" --forecast "$WORK/scenes/tour.json" --tab "$tab" --alerts --landscape poppies --lang en --size 1040x520 "${extra[@]}" > /dev/null
    # The viewer leaves 10 px of desktop around the widget and the Plasma frame has 6 px corners.
    "$PY" "$HERE/finish.py" "$WORK/$name.png" "$ROOT/store/weather-now-$name.png" 10 6
done

"$PY" "$HERE/render.py" "$HERE/logo.qml" "$ROOT/store/weather-now-logo.png"

# The same picture, at 256 px, is the icon of the widget in Add Widgets ("Icon" in metadata.json, a path
# inside contents/ since Plasma 6.7). Still, as Plasma draws it: an animated one would stop at its first frame.
"$PY" -c 'import sys
from PySide6.QtCore import Qt
from PySide6.QtGui import QGuiApplication, QImage
QGuiApplication([])
QImage(sys.argv[1]).scaled(256, 256, Qt.KeepAspectRatio, Qt.SmoothTransformation).save(sys.argv[2])' "$ROOT/store/weather-now-logo.png" "$ROOT/package/contents/icons/weather-now.png"
