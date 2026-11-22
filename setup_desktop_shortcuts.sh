#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Drop big-button desktop launchers operators can double-click without a
# terminal: Restart AutoDarts, Reboot, Shutdown, Open SUIT, Sound Test,
# Status. Icons live on ~/Desktop and are marked trusted/executable.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/shortcut_trust.sh"
DESKTOP="$ACTUAL_HOME/Desktop"
ICON_DIR="$ACTUAL_HOME/.local/share/icons"

sudo -u "$ACTUAL_USER" mkdir -p "$DESKTOP" "$ICON_DIR"

# Use the current AutoDarts icon for branded shortcuts.
sudo -u "$ACTUAL_USER" cp "$SCRIPT_DIR/images/autodarts-favicon.png" "$ICON_DIR/"
LOGO="$ICON_DIR/autodarts-favicon.png"

write_shortcut() {
    local name="$1" comment="$2" exec_cmd="$3" icon="$4"
    local file="$DESKTOP/${name// /_}.desktop"
    sudo -u "$ACTUAL_USER" tee "$file" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Icon=$icon
Terminal=false
StartupNotify=false
Categories=System;
EOF
    chmod +x "$file"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$file"
    ad_register_shortcut_trust "$ACTUAL_USER" "$ACTUAL_HOME" "$file" "$SCRIPT_DIR"
    # Mark trusted for pcmanfm-qt so double-click works without a prompt.
    if ! ad_trust_shortcut "$ACTUAL_USER" "$file"; then
        echo "Warning: could not mark $file trusted; use 'Trust this executable' on the desktop." >&2
    fi
}

write_shortcut "Restart AutoDarts" \
    "Reload the AutoDarts kiosk Chrome session" \
    "systemctl --user restart autodarts-chrome.service" \
    "$LOGO"

write_shortcut "Reboot" \
    "Reboot the system" \
    "systemctl reboot" \
    "system-reboot"

write_shortcut "Shutdown" \
    "Power off the system" \
    "systemctl poweroff" \
    "system-shutdown"

write_shortcut "Open SUIT" \
    "Launch the Simple UI Toolkit" \
    "bash -c 'cd $ACTUAL_HOME/SUIT && .venv/bin/python main.py'" \
    "$LOGO"

write_shortcut "Sound Test" \
    "Play a quick HDMI audio test" \
    "/usr/local/bin/sound-test" \
    "audio-volume-high"

write_shortcut "AutoDarts Status" \
    "Show kiosk health summary" \
    "x-terminal-emulator -e bash -c 'autodarts-status; read -p \"Press enter to close\"'" \
    "utilities-system-monitor"

echo "Desktop shortcuts written under $DESKTOP."
