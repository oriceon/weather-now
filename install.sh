#!/usr/bin/env bash
# Installs or upgrades the widget for the current user, on a system with Plasma 6.
set -euo pipefail

package="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package"

if ! command -v kpackagetool6 > /dev/null; then
    echo "kpackagetool6 is missing: run this on a system with Plasma 6." >&2
    exit 1
fi

plugin_id="$(sed -n 's/.*"Id": *"\([^"]*\)".*/\1/p' "$package/metadata.json")"
installed="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$plugin_id"

if [[ -d "$installed" ]]; then
    kpackagetool6 --type Plasma/Applet --upgrade "$package"
else
    kpackagetool6 --type Plasma/Applet --install "$package"
fi

if [[ "${1:-}" == "--restart" ]]; then
    systemctl --user restart plasma-plasmashell.service
    echo "The widget is installed and Plasma has been restarted."
else
    echo "The widget is installed. After an upgrade Plasma keeps the old code in memory: run \"$0 --restart\"."
fi
