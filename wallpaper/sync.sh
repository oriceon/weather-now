#!/usr/bin/env bash
# Copies into the wallpaper what it shares with the widget: the animated scene, the code it runs on,
# the search of places and the icon. The widget is their source; the copies are not kept in git.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
widget="$here/../package/contents"
wallpaper="$here/package/contents"

rm -rf "$wallpaper/code" "$wallpaper/ui/scene" "$wallpaper/ui/PlaceSearch.qml" "$wallpaper/ui/Coverage.qml" "$wallpaper/icons"
cp -r "$widget/code" "$wallpaper/code"
cp -r "$widget/ui/scene" "$wallpaper/ui/scene"
cp "$widget/ui/PlaceSearch.qml" "$wallpaper/ui/PlaceSearch.qml"
cp "$widget/ui/Coverage.qml" "$wallpaper/ui/Coverage.qml"
mkdir -p "$wallpaper/icons"
cp "$widget/icons/weather-now.png" "$wallpaper/icons/weather-now.png"
cp "$here/../LICENSE" "$here/package/LICENSE"
