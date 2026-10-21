#!/usr/bin/env bash
# Installs or upgrades the wallpaper for the current user, on a system with Plasma 6.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package="$here/package"

if ! command -v kpackagetool6 > /dev/null; then
    echo "kpackagetool6 is missing: run this on a system with Plasma 6." >&2
    exit 1
fi

"$here/sync.sh"

plugin_id="$(sed -n 's/.*"Id": *"\([^"]*\)".*/\1/p' "$package/metadata.json")"
installed="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$plugin_id"

if [[ -d "$installed" ]]; then
    kpackagetool6 --type Plasma/Wallpaper --upgrade "$package"
else
    kpackagetool6 --type Plasma/Wallpaper --install "$package"
fi

echo "The wallpaper is installed: right-click the desktop, Configure Desktop and Wallpaper, Wallpaper type: Weather Now."
echo "After an upgrade, Plasma keeps the old code in memory until it restarts: systemctl --user restart plasma-plasmashell.service"
